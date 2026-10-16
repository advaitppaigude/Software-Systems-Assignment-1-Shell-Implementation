# Section 2: Commands with Redirection — Concepts & Function Reference

**Coursework Goal:** Support single-operator input (`<`) and output (`>` overwrite, `>>` append) redirection using `command_with_redirection` and `launch_program_with_redirection`.  
**Lecture References:**
* **Lecture 2:** Slide 28 (Standard file descriptors `0`, `1`, `2`)
* **Lecture 3:** Slides 11–16 (File Descriptor Table `FDT`, Open File Table `OFT`, inodes, and why `FDT` is copied on `fork()` and kept across `execvp()`), Slide 21 (`dup2`)

---

## 1. Core OS Concepts: How Redirection Actually Works

### A. File Descriptors and the Per-Process FDT (Lecture 3, Slides 11–14)
Every Unix process has a **File Descriptor Table (FDT)** stored inside its Process Control Block (PCB). A **file descriptor (`fd`)** is simply a small non-negative integer (`0, 1, 2, 3, ...`) that indexes into this table.

By default, every process starts with three open descriptors connected to the terminal:
| Integer | Constant (`<unistd.h>`) | Stream | Default Target |
| :--- | :--- | :--- | :--- |
| `0` | `STDIN_FILENO` | Standard Input (`stdin`) | Keyboard |
| `1` | `STDOUT_FILENO` | Standard Output (`stdout`) | Terminal screen |
| `2` | `STDERR_FILENO` | Standard Error (`stderr`) | Terminal screen |

### B. Why Programs Like `ls` or `sort` Don't Know About `>` or `<`
When you run `sort txt/phrases.txt > txt/phrases_sorted.txt`:
* The `sort` binary does **not** know what `>` means! `sort` simply writes its output to file descriptor `1` (`STDOUT_FILENO`).
* **How the shell tricks `sort` (Lecture 3, Slides 14 & 21):**
  1. The parent shell `fork()`s a child process. The child inherits a copy of the parent's FDT.
  2. **Inside the child process (before calling `execvp`)**, the child calls `open("txt/phrases_sorted.txt", ...)` which opens the file at a new descriptor (say `fd = 3`).
  3. The child calls `dup2(fd, STDOUT_FILENO)`, which overwrites entry `1` (`STDOUT_FILENO`) in the child's FDT so that descriptor `1` now points to `txt/phrases_sorted.txt` instead of the terminal!
  4. The child closes the extra descriptor `fd` (`close(fd)`) and calls `execvp("sort", args)`.
  5. Because **`execvp()` preserves the child's FDT** (Lecture 3, Slide 14), everything `sort` writes to `STDOUT_FILENO` (`1`) goes straight into the file—while the parent shell's `STDOUT_FILENO` remains untouched!

---

## 2. Parsing Considerations for Redirection

Suppose the user enters:
```bash
sort txt/phrases.txt > txt/phrases_sorted.txt
```
If you tokenize by spaces, `args` inicialmente contains:
```text
args[0] = "sort"
args[1] = "txt/phrases.txt"
args[2] = ">"
args[3] = "txt/phrases_sorted.txt"
args[4] = NULL
```
**Crucial Rule:** Before calling `execvp()`, you must **remove `">"` and `"txt/phrases_sorted.txt"` from `args`** (for example, by setting `args[2] = NULL;` after saving the pointer `args[3]` as your target filename). Otherwise, `sort` will think `">"` and `"txt/phrases_sorted.txt"` are two additional input files to sort!

*(Bonus tip: Think about whether a user might type `ls >out.txt` without spaces around `>`, or if tokens are always space-separated. Checking `strchr` / `strstr` for `">>"`, `">"`, and `"<"` helps detect redirection reliably.)*

---

## 3. Breakdown of Functions & System Calls Needed in Section 2

### `open` — Open or create a file (`<fcntl.h>`, `<sys/stat.h>`)
* **Man page:** `man 2 open`
* **Signatures:**
  ```c
  int open(const char *pathname, int flags);
  int open(const char *pathname, int flags, mode_t mode); // Required when O_CREAT is used!
  ```
* **Parameters:**
  * `pathname`: C string containing the file path (e.g., `"txt/phrases_sorted.txt"`).
  * `flags`: Bitwise-OR (`|`) combination of access mode and creation/status flags:
    * **Access mode (must pick one):**
      * `O_RDONLY`: Open for reading only (use for `<`).
      * `O_WRONLY`: Open for writing only (use for `>` and `>>`).
      * `O_RDWR`: Open for both reading and writing.
    * **Creation & truncation flags (combine with `|`):**
      * `O_CREAT`: Create the file if it does not exist.
      * `O_TRUNC`: If the file already exists, truncate (wipe) its length to 0 bytes (use for `>`).
      * `O_APPEND`: Write data at the very end of the file (use for `>>`).
  * `mode` (file permissions when `O_CREAT` creates a new file):
    * Whenever you include `O_CREAT`, you **must** pass a 3rd argument specifying permissions for the newly created file, such as `0644` (octal: owner read/write `rw-`, group read `r--`, others read `r--`) or `S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH`.
* **Flag Combinations Cheat Sheet for `s3`:**
  | Operator | Purpose | `open()` Call Pattern |
  | :--- | :--- | :--- |
  | `< file` | Input redirection | `open(file, O_RDONLY)` |
  | `> file` | Output (create/overwrite) | `open(file, O_WRONLY \| O_CREAT \| O_TRUNC, 0644)` |
  | `>> file` | Output (create/append) | `open(file, O_WRONLY \| O_CREAT \| O_APPEND, 0644)` |
* **Return Value:**
  * Returns a new non-negative file descriptor (`int fd >= 0`) on success.
  * Returns **`-1`** on error (e.g., input file doesn't exist for `<`). Always check `if (fd < 0) { perror("open failed"); exit(1); }`.

---

### `dup2` — Duplicate a file descriptor (`<unistd.h>`)
* **Man page:** `man 2 dup2`
* **Signature:**
  ```c
  int dup2(int oldfd, int newfd);
  ```
* **Parameters (Lecture 3, Slide 21):**
  * `oldfd`: The file descriptor you already opened with `open()` (e.g., `fd`).
  * `newfd`: The standard descriptor number you want to redirect (`STDIN_FILENO` for input `<`, or `STDOUT_FILENO` for output `>` / `>>`).
* **How it works:**
  * Closes `newfd` if it was open, and copies the file table pointer from `oldfd` into slot `newfd` of the process's FDT.
  * After `dup2(fd, STDOUT_FILENO)`, both `fd` and `STDOUT_FILENO` (`1`) point to your opened file.
* **Return Value:** Returns `newfd` on success, or **`-1`** on error.

---

### `close` — Close a file descriptor (`<unistd.h>`)
* **Man page:** `man 2 close`
* **Signature:**
  ```c
  int close(int fd);
  ```
* **Why you call `close(fd)` right after `dup2(fd, STDOUT_FILENO)`:**
  * Once `dup2` has copied `fd` into `STDOUT_FILENO` (`1`), you don't need the extra duplicate slot `fd` (e.g., slot `3`) anymore. Calling `close(fd)` frees slot `3` while keeping `STDOUT_FILENO` (`1`) connected to the file.

---

### `strstr` & `strchr` — Locate operators in a string (`<string.h>`)
* **Man pages:** `man 3 strstr`, `man 3 strchr`
* **Signatures:**
  ```c
  char *strstr(const char *haystack, const char *needle);
  char *strchr(const char *s, int c);
  ```
* **How they help in `command_with_redirection(char line[])`:**
  * `strchr(line, '<')` returns a non-`NULL` pointer if `'<'` appears in `line`.
  * `strchr(line, '>')` returns a non-`NULL` pointer if `'>'` appears in `line` (covers both `>` and `>>`).
  * `strstr(line, ">>")` specifically checks for the two-character append operator `">>"` (check for `">>"` **before** checking for single `">"` so you don't mistake `">>"` for `">"`!).
