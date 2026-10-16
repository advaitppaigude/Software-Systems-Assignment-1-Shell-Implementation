# Section 3: Support for `cd` & Dynamic Prompt — Concepts & Function Reference

**Coursework Goal:** Implement `cd` as a shell built-in (`is_cd`, `run_cd`, `init_lwd`) supporting paths, home directory (`cd`), and previous directory (`cd -`), and update `construct_shell_prompt` to show the current working directory.  
**Lecture References:**
* **Lecture 2:** Slides 7 & 9 (Process Control Block `PCB` stores `cwd` — the current working directory per process)

---

## 1. Core Concept: Why `cd` Must Be a Shell Built-in

As shown in **Lecture 2 (Slides 7 & 9)**, every process has its own `cwd` (current working directory) field inside its Process Control Block (PCB) in the kernel.

What would happen if `s3` treated `cd txt` like a normal external command?
1. Parent shell (`cwd = /home/user/s3`) forks a child process (`cwd = /home/user/s3`).
2. Child changes its directory to `/home/user/s3/txt` and immediately exits.
3. Parent shell is still in `/home/user/s3`!

Therefore, `cd` **cannot** be run in a forked child process. The main `s3` shell process must detect `cd` (via `is_cd(line)`) and call the `chdir()` system call **directly in the parent process** (via `run_cd(args, argsc, lwd)`), without calling `fork()` or `reap()`.

---

## 2. The Three `cd` Cases You Need to Support

After parsing the command line with `parse_command(line, args, &argsc)`:

1. **`cd <path>` (`argsc >= 2`, where `args[ARG_1]` is not `"-"`):**
   * Save the current working directory into `lwd` (so a future `cd -` knows where we came from) **only if `chdir` succeeds**.
   * Call `chdir(args[ARG_1])`.
   * Note: Special directory names `.` (current directory) and `..` (parent directory) are actual filesystem entries in Unix—`chdir(".")` and `chdir("..")` work automatically without any special string logic!
2. **`cd` with no arguments (`argsc == 1`):**
   * Should change to the user's home directory.
   * Since `chdir()` does not accept `NULL` or empty strings for home, use `getenv("HOME")` to get the path to the user's home directory, then pass that path to `chdir()`.
3. **`cd -` (`argsc >= 2` and `strcmp(args[ARG_1], "-") == 0`):**
   * Should switch to the **last (previous) working directory** stored in `char lwd[]`.
   * **Important detail:** If you are in `/dirA` (with `lwd = /dirB`) and run `cd -`, you move to `/dirB`, **and `lwd` must now become `/dirA`** (so running `cd -` a second time takes you back to `/dirA`!).
   * Therefore, get the current directory into a temporary buffer *before* calling `chdir(lwd)`, and once `chdir(lwd)` succeeds, copy that temporary buffer into `lwd`.

---

## 3. Breakdown of Functions & System Calls Needed in Section 3

### `chdir` — Change current working directory (`<unistd.h>`)
* **Man page:** `man 2 chdir`
* **Signature:**
  ```c
  int chdir(const char *path);
  ```
* **Parameters:**
  * `path`: C string specifying the target directory (relative like `"txt"` or `".."`, or absolute like `"/var/log"`).
* **Return Value:**
  * Returns **`0`** on success.
  * Returns **`-1`** on error (e.g., directory does not exist or permission denied) and sets `errno`.
  * **Error Handling Note:** Because `run_cd` runs in the **parent shell process**, if `chdir` returns `-1`, call `perror("cd failed");` **but do NOT call `exit(1)`** (otherwise a typo in `cd non_existent_folder` would kill the entire shell!).

---

### `getcwd` — Get current working directory (`<unistd.h>`)
* **Man page:** `man 3 getcwd`
* **Signature:**
  ```c
  char *getcwd(char *buf, size_t size);
  ```
* **Parameters:**
  * `buf`: Character array where the null-terminated absolute pathname of the current working directory will be written.
  * `size`: Size in bytes of the array `buf` (e.g., `MAX_PROMPT_LEN - 6` for `lwd`).
* **Return Value:**
  * On success, returns a pointer to `buf` (which now contains a null-terminated string like `"/home/user/s3/src"`).
  * On failure (e.g., if the path is longer than `size`), returns `NULL`.
* **Where you use `getcwd` in Section 3:**
  1. Inside `init_lwd(char lwd[])` at the start of `main()` to initialize `lwd` with the starting directory.
  2. Inside `run_cd(...)` to record the current directory before changing to a new one.
  3. Inside `construct_shell_prompt(...)` to display the current working directory in the prompt: `[/path/to/cwd s3]$ `.

---

### `getenv` — Get an environment variable (`<stdlib.h>`)
* **Man page:** `man 3 getenv`
* **Signature:**
  ```c
  char *getenv(const char *name);
  ```
* **Parameters:**
  * `name`: Name of the environment variable to look up (pass `"HOME"` to get the user's home directory path, e.g., `"/home/srivathsann"`).
* **Return Value:**
  * Returns a pointer to the value string in the environment, or `NULL` if there is no match.

---

### Detecting `cd` Accurately in `is_cd(char line[])`
Be careful when writing `is_cd(char line[])`:
* Remember not to call `strtok(line, " ")` directly on `line` inside `is_cd(line)` unless you copy `line` first, because `s3main.c` calls `parse_command(line, ...)` *after* `is_cd(line)`! If `is_cd` modifies `line` in-place with `strtok`, `parse_command` will only see the first word `"cd"` and lose the directory argument!
* Also make sure `is_cd` skips any leading spaces and checks that `"cd"` is followed by either a space `' '` or the end of the string `'\0'` (so a command like `cdrom` isn't mistaken for `cd`).
