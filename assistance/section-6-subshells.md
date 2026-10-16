# Section 6: Subshells — Concepts & Function Reference

**Coursework Goal:** Support subshells enclosed in parentheses `(...)`, both as standalone commands in a batch and as stages within a pipeline.  
**Lecture References:**
* **Lecture 1:** Slide 12 (`main(int argc, char *argv[])` command-line arguments)
* **Lecture 2:** Slides 7, 9, 15–18 (Process isolation via `fork()` — child has its own PCB and `cwd`)
* **Lecture 3:** Slides 6–9, 14, 24 (`execvp()`, FDT preservation across `fork()` and `execvp()`, pipelines)

---

## 1. Core Concept: What Is a Subshell and Why Use It?

Consider the example from **Section 6** of the assignment specification:
```bash
echo "Start processing..." ; (cd /var/log ; cat syslog | sort > sorted_syslog.txt) ; echo "Finished writing sorted log." ; date
```

1. In **Section 3**, you learned that `cd` normally runs in the **parent shell process** so that the shell's working directory changes permanently.
2. However, everything inside `(...)` is a **subshell** — an **isolated child shell process** spawned by the parent shell.
3. When `cd /var/log` runs inside the subshell `(cd /var/log ; ...)`, it changes the working directory of the **subshell child process only**.
4. Once the subshell finishes `cat syslog | sort > sorted_syslog.txt` and exits, control returns to the parent shell—whose current working directory is **still wherever it started**!

### Subshells Inside Pipelines
Because a subshell is just a child process that inherits `STDIN_FILENO` (`0`) and `STDOUT_FILENO` (`1`), it can also appear as a stage inside a pipeline:
```bash
(cd /var/log ; cat syslog) | sort | head
```
Here:
* Stage 0 is the subshell `(cd /var/log ; cat syslog)`. Its `STDOUT_FILENO` is redirected to the write end of Pipe 0 using `dup2()`.
* When the subshell runs `cat syslog`, `cat` inherits the subshell's redirected `STDOUT_FILENO`, so `cat`'s output flows into Pipe 0 and straight into `sort`!

---

## 2. How a Subshell Is Launched (`fork`, `execvp`, `argc` / `argv`)

The assignment specification notes:
> *"A subshell is simply a child process of the shell, just like any other command the shell runs. This child is a complete shell process in itself. It is created using `fork`, and the shell binary is loaded into it using `execvp` when needed. So, to support subshells correctly, the shell program should be able to process its `argc` and `argv` arguments appropriately."*

### How `main(int argc, char *argv[])` Can Support Both Interactive and Subshell Modes (Lecture 1, Slide 12)
1. **Interactive Mode (`argc == 1`):**
   * When you start `./s3` normally from your terminal with no extra arguments, `argc` is `1` (`argv[0]` is `"./s3"`).
   * `s3` enters its `while (1)` loop, printing the prompt and reading lines from `stdin`.
2. **Subshell / Command-Argument Mode (`argc > 1`):**
   * Suppose the parent shell sees a subshell `(cd /var/log ; cat syslog)`.
   * It strips the outer parentheses to get the inner command string `"cd /var/log ; cat syslog"`.
   * Inside the forked child process, it can `execvp` the `s3` shell binary passing that command string as an argument (e.g., `char *sub_args[] = { s3_path, inner_cmd, NULL }; execvp(s3_path, sub_args);`).
   * When the new `s3` process starts in `main(int argc, char *argv[])`, it sees `argc > 1`! Instead of entering the interactive `while (1)` prompt loop, it simply executes `argv[1]` once using your batch/pipeline/command execution function and returns `0` (exiting the subshell)!

*(Tip: Notice that in `main(int argc, char *argv[])`, `argv[0]` holds the path/name used to launch `s3`! Saving `argv[0]` or resolving the path to `s3` at startup before any `cd` happens ensures the child can always find the `s3` binary even after `cd /var/log` changes the working directory.)*

---

## 3. Parsing a Subshell Command

### A. Detecting if a Command Unit Is a Subshell
After splitting a command line by top-level `;` (Batches) and top-level `|` (Pipelines), how do you know if a single command unit is a subshell?
1. Ignore any leading spaces/tabs at the start of the string and any trailing spaces/tabs at the end.
2. Check if the first non-whitespace character is `'('` (and the matching closing `')'` is the last non-whitespace character, or precedes an outer redirection).

### B. Stripping the Outer Parentheses
Suppose a pipeline stage string is `"  (cd /var/log ; cat syslog)  "`:
1. Find the first `'('`.
2. Find its matching closing `')'` at the end of the subshell expression.
3. Replace that closing `')'` with `'\0'`, and pass the pointer `first_paren + 1` (`"cd /var/log ; cat syslog"`) as the inner command string to your subshell launcher.

---

## 4. Key Functions & System Calls Used in Section 6

All system calls used in Section 6 are ones you have already learned in Sections 1–5, combined in a new way:
* **`fork()` & `execvp()`** (see [section-1-basic-commands.md](./section-1-basic-commands.md)): Used to spawn the child `s3` process.
* **`pipe()` & `dup2()`** (see [section-4-pipes.md](./section-4-pipes.md)): Used when a subshell is a stage inside a pipeline so the entire subshell's `stdin` or `stdout` is connected to the pipe before the subshell runs.
* **`realpath()` or `getcwd()`** (`<stdlib.h>`, `<unistd.h>`):
  * **Man page:** `man 3 realpath`
  * **Why it's helpful:** If you launch `./s3`, `argv[0]` is a relative path `"./s3"`. If a user or subshell runs `cd /var/log` and then spawns another subshell using `execvp("./s3", ...)`, `/var/log/./s3` won't exist! Saving the absolute path of `s3` when `main()` starts (using `realpath(argv[0], ...)` or combining `getcwd` with `argv[0]`) guarantees `execvp` can always find your `s3` executable from any directory.
