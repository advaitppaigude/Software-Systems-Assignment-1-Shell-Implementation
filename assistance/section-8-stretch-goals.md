# Section 8: Stretch Goals — Concepts & Function Reference

**Coursework Goal:** Optional extensions beyond the 70% core specification to achieve marks in the 70–100% range (alongside code quality, modularity, and readability).  
**Reference:** Assignment 1 Specification — Section 8

---

## 1. Combined Input (`<`) and Output (`>` / `>>`) Redirection

### What It Is
Supporting both input and output redirection in the same command stage, e.g.:
```bash
sort < txt/phrases.txt > txt/sorted_output.txt
```
or
```bash
sort < txt/phrases.txt >> txt/sorted_output.txt
```

### Concepts & Functions Used
* Requires **no new system calls** beyond Section 2 (`open()`, `dup2()`, `close()`).
* Instead of assuming a command has *either* input redirection *or* output redirection, your redirection parser can extract:
  * `char *in_file` (set if `<` is present, otherwise `NULL`)
  * `char *out_file` (set if `>` or `>>` is present, otherwise `NULL`)
  * `int append` (`1` if `>>`, `0` if `>`)
* In the child process before `execvp()`:
  * If `in_file != NULL`, `open` `in_file` with `O_RDONLY` and `dup2` into `STDIN_FILENO`.
  * If `out_file != NULL`, `open` `out_file` with `O_WRONLY | O_CREAT | (append ? O_APPEND : O_TRUNC)` and `dup2` into `STDOUT_FILENO`.

---

## 2. Wildcard Globbing (`*` and `?`)

### What It Is
Expanding filename patterns containing `*` (matches any sequence of characters) or `?` (matches any single character) into matching file paths before passing `args[]` to `execvp()`, e.g.:
```bash
ls txt/*.txt
wc src/*.c
```

### Standard POSIX Library Functions (`<glob.h>`)
POSIX provides a built-in library specifically for wildcard expansion!
* **Man page:** `man 3 glob`
* **Header:** `#include <glob.h>`
* **Signatures:**
  ```c
  int glob(const char *pattern, int flags,
           int (*errfunc)(const char *epath, int eerrno),
           glob_t *pglob);
  void globfree(glob_t *pglob);
  ```
* **How it works:**
  * If an argument token in `args` contains `'*'` or `'?'`, pass that token as `pattern` to `glob(token, GLOB_NOCHECK, NULL, &glob_results)`.
  * `glob_results.gl_pathc` holds the count of matched file paths.
  * `glob_results.gl_pathv` is an array of strings (`char **`) containing each matched path in sorted order (and with `GLOB_NOCHECK`, if no files match, it returns the original pattern unchanged, just like Bash!).
  * Copy the matched strings into your `args[]` array, and call `globfree(&glob_results)` when done.

---

## 3. Foreground and Background Job Control (`&`, `fg`, `bg`)

### What It Is
Allowing commands to run in the background (using `&`) while the shell immediately prints the next prompt, and bringing background/stopped jobs to the foreground (`fg`) or background (`bg`).

### System Calls & Functions Involved
* **`waitpid()` (`<sys/wait.h>`) — `man 2 waitpid`:**
  ```c
  pid_t waitpid(pid_t pid, int *wstatus, int options);
  ```
  * Unlike `wait(NULL)`, `waitpid` lets you wait for a **specific** `pid`, and supports flags in `options`:
    * `WNOHANG`: Returns immediately (`0`) without blocking if the child is still running (useful for checking if background jobs have finished before printing the next prompt!).
    * `WUNTRACED`: Also returns if a child has been stopped (paused via Ctrl+Z / `SIGTSTP`), not just terminated.
* **Signals (`<signal.h>`) — `man 7 signal`, `man 2 kill`, `man 2 sigaction`:**
  * `kill(pid, SIGCONT)` sends the "continue" signal to resume a stopped process for `fg` or `bg`.
  * `SIGINT` (Ctrl+C) and `SIGTSTP` (Ctrl+Z) are signals sent by the terminal to the foreground process group.

---

## 4. Command History, Arrow Keys, & Tab Completion

### What It Is
Allowing users to press the Up/Down arrow keys to cycle through previously entered commands, or press Tab to autocomplete file and command names, instead of raw `fgets()` input.

### Library / API Options
1. **GNU Readline Library (`<readline/readline.h>`, `<readline/history.h>`):**
   * **Man page:** `man 3 readline`
   * Compiled by adding `-lreadline` to `gcc`.
   * Calling `char *input = readline(shell_prompt);` and `add_history(input);` automatically provides Up/Down arrow history, Left/Right cursor editing, and Tab filename completion out of the box!
2. **Built-in History Command (`history` / `!n`):**
   * Even with standard `fgets()`, you can store each entered `line` in a 2D array `char history[MAX_HISTORY][MAX_LINE]` and implement a built-in `history` command to list past commands and `!n` (or `!!`) to re-run them.
