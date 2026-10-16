# Section 1: Basic Commands — Concepts & Function Reference

**Coursework Goal:** Understand the starter code (`s3main.c`, `s3.h`, `s3.c`), implement `launch_program` and `child` to execute external commands, and handle the `exit` built-in command.  
**Lecture References:**
* **Lecture 1:** Slide 12 (`argc` / `argv` vector layout)
* **Lecture 2:** Slides 13–26 (`fork()`, Copy-on-Write, `wait()`, reaping & zombies)
* **Lecture 3:** Slides 4–9 (`execvp()` and the `fork–exec–wait` lifecycle in a shell)

---

## 1. Core Concepts You Need for Section 1

### A. How C Strings & `char *args[]` Work in the Starter Code
In C, a string is a contiguous array of `char` bytes ending with a null terminator character `'\0'` (byte value `0`).

In `s3main.c`, two arrays are declared:
```c
char line[MAX_LINE];   // Stores the raw characters typed by the user
char *args[MAX_ARGS];  // Stores pointers (memory addresses) to each word in line
int argsc;             // Stores how many words (arguments) were found
```
When the user types `ls -l txt`, `parse_command(line, args, &argsc)` uses `strtok` to overwrite each space in `line` with `'\0'` and stores the starting address of each word in `args`:
* `args[0]` (`args[ARG_PROGNAME]`) points to `"ls"`
* `args[1]` (`args[ARG_1]`) points to `"-l"`
* `args[2]` (`args[ARG_2]`) points to `"txt"`
* `args[3]` (`args[argsc]`) is set to `NULL` (required by `execvp` to mark the end of the array).

### B. Why `parse_command` Takes `int *argsc`
In C, arguments are passed by value (copied). Because `parse_command` needs to update `argsc` inside `main()`, `main()` passes the **memory address** `&argsc`. Inside `parse_command`, `*argsc` dereferences that pointer to read/write `main`'s variable.

### C. The `fork–exec–wait` Shell Lifecycle (Lecture 3, Slides 8–9)
Every time a user runs an external command (like `ls`, `wc`, `grep`), the shell performs three steps:
1. **Parent calls `fork()`** to create a child process that is a duplicate of the shell.
2. **Child calls `execvp()`** to replace its own code/memory with the requested program (e.g., `ls`).
3. **Parent calls `wait(NULL)`** (via `reap()`) to pause until the child finishes and clean up its process table entry.

### D. Why `exit` Must Be Handled Before/Without Forking
If `exit` were run inside the forked child process, only the child process would terminate while the parent `s3` shell kept looping forever! Therefore, `launch_program` (or `main`) must check if `args[ARG_PROGNAME]` is `"exit"` in the **parent process** and call `exit(0)` directly.

---

## 2. Breakdown of Starter Functions (Already Used in `s3.c`)

### `fgets` — Read a line of text (`<stdio.h>`)
* **Man page:** `man 3 fgets`
* **Signature:** `char *fgets(char *s, int size, FILE *stream);`
* **How it works:** Reads at most `size - 1` characters from `stream` (`stdin`) into `s` (`line`), stopping at a newline `'\n'` or `EOF`, and appends `'\0'`.
* **Return Value:** Returns `s` on success, or `NULL` on error or `EOF` (Ctrl+D).
* **Note:** `fgets` keeps the `' \n'` character at the end of the buffer, which is why `read_command_line` removes it with `line[strlen(line) - 1] = '\0';`.

### `strtok` — Split a string into tokens (`<string.h>`)
* **Man page:** `man 3 strtok`
* **Signature:** `char *strtok(char *str, const char *delim);`
* **How it works:**
  * First call: `strtok(line, " ")` skips leading spaces, returns a pointer to the first word, and replaces the space after that word with `'\0'`.
  * Subsequent calls: `strtok(NULL, " ")` continues scanning the same string from where it left off.
* **Return Value:** Pointer to the next token string, or `NULL` when no tokens remain.

---

## 3. Breakdown of Functions You Need to Use in Section 1

### `fork` — Create a child process (`<unistd.h>`)
* **Man page:** `man 2 fork`
* **Signature:**
  ```c
  pid_t fork(void);
  ```
* **How it works (Lecture 2, Slides 15–18):**
  * Duplicates the calling process. After `fork()`, **two** processes (parent and child) are running the exact same code starting from the return of `fork()`.
* **Return Value (`pid_t` / `int`):**
  * **`< 0` (`-1`)**: Creation failed. Handle with `perror("fork failed"); exit(1);`.
  * **`== 0`**: You are inside the **child process**. Call `child(args, argsc);`.
  * **`> 0`**: You are inside the **parent process** (the returned value is the child's PID).

---

### `execvp` — Load and execute a new program (`<unistd.h>`)
* **Man page:** `man 3 execvp`
* **Signature:**
  ```c
  int execvp(const char *file, char *const argv[]);
  ```
* **Parameters (Lecture 3, Slides 6–7):**
  * `file`: Name of the binary to execute (`args[ARG_PROGNAME]`). Because of the `p` in `execvp`, the OS searches the system `PATH` automatically (so `"ls"` finds `/bin/ls`).
  * `argv`: The `NULL`-terminated array of argument strings (`args`), where `args[0]` is the program name.
* **Return Value:**
  * **Does NOT return if successful!** The child process is completely replaced by the new program.
  * Returns **`-1` only if it fails** (e.g., command not found).
* **Critical Pitfall:** Always put `perror("execvp failed"); exit(1);` right after `execvp(...)` in the child! If `execvp` fails (e.g., the user makes a typo like `lss`) and the child does not call `exit(1)`, the child process will return back into `main`'s `while (1)` loop, leaving two shells running at once.

---

### `wait` — Wait for a child process to terminate (`<sys/wait.h>`)
* **Man page:** `man 2 wait`
* **Signature:**
  ```c
  pid_t wait(int *wstatus);
  ```
* **How it works (Lecture 2, Slides 22–26):**
  * Suspends the parent process until one child terminates, and **reaps** the terminated child from the OS process table so it doesn't remain a zombie process.
  * Already wrapped in `s3.h` as `static inline void reap() { wait(NULL); }`.

---

### `strcmp` — Compare two C strings (`<string.h>`)
* **Man page:** `man 3 strcmp`
* **Signature:**
  ```c
  int strcmp(const char *s1, const char *s2);
  ```
* **How it works:** Compares two null-terminated strings character by character.
* **Return Value:** Returns **`0`** when the strings are **equal**!
* **Why you need it:** In C, `args[ARG_PROGNAME] == "exit"` compares memory addresses, **not** string contents. Always use `strcmp(args[ARG_PROGNAME], "exit") == 0`.
* **Edge Case Tip:** If the user presses Enter on an empty line, `argsc` will be `0` and `args[ARG_PROGNAME]` will be `NULL`. Passing `NULL` to `strcmp` causes a Segmentation Fault—so always check `if (argsc == 0)` (or `args[ARG_PROGNAME] == NULL`) first!
