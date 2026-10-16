# Section 4: Commands with Pipes — Concepts & Function Reference

**Coursework Goal:** Support pipelines of any length (`cmd1 | cmd2 | ... | cmdN`), including pipeline stages that also use file redirection (`<`, `>`, `>>`).  
**Lecture References:**
* **Lecture 3:** Slides 10, 17–24 (Inter-Process Communication `IPC`, kernel circular buffer, `pipe()`, FDT duplication across `fork()`, `dup2()`, and Slide 24 `echo hello | wc` shell walkthrough)
* **Lecture 4:** Slides 2–4 (Repeated code walkthrough of `pipe()` + `fork()` + `dup2()` + `execvp()`)

---

## 1. Core OS Concepts: What Is a Pipe?

### A. Kernel Circular Buffer (Lecture 3, Slides 17–18)
Processes in Unix have isolated virtual address spaces—one process cannot directly read or write another process's memory. To pass data from one process to another (**Inter-Process Communication / IPC**), the OS provides a **pipe**:
* A pipe is a **one-way (unidirectional) data channel** managed by the kernel as an in-memory circular buffer (typically 64 KB on Linux).
* It is accessed through **two file descriptors**:
  1. **`fd[0]` (`FD_PREAD`)**: The **read end** of the pipe.
  2. **`fd[1]` (`FD_PWRITE`)**: The **write end** of the pipe.
* Whatever bytes are written into `fd[1]` can be read in FIFO order from `fd[0]`.

### B. How Two Processes Connect via a Pipe (Lecture 3, Slide 24)
Consider the two-stage pipeline from **Lecture 3, Slide 24**:
```bash
echo hello | wc
```
1. **Parent shell creates a pipe `P`** by calling `pipe(fd)`. Now the parent has `fd[0]` (read end) and `fd[1]` (write end) in its File Descriptor Table (FDT).
2. **Parent forks Child 1 (`C1`, for `echo hello`):**
   * `C1` inherits `fd[0]` and `fd[1]`.
   * `C1` does not read from the pipe, so `C1` closes the read end: `close(fd[0])`.
   * `C1` redirects its `STDOUT_FILENO` (`1`) to the pipe's write end: `dup2(fd[1], STDOUT_FILENO)`, then calls `close(fd[1])`.
   * `C1` calls `execvp("echo", ...)`. Everything `echo` prints to `stdout` now flows into the pipe!
3. **Parent forks Child 2 (`C2`, for `wc`):**
   * `C2` inherits `fd[0]` and `fd[1]`.
   * `C2` does not write to the pipe, so `C2` closes the write end: `close(fd[1])`.
   * `C2` redirects its `STDIN_FILENO` (`0`) to the pipe's read end: `dup2(fd[0], STDIN_FILENO)`, then calls `close(fd[0])`.
   * `C2` calls `execvp("wc", ...)`. `wc` now reads its `stdin` directly from the pipe!
4. **Parent closes BOTH ends of the pipe (`close(fd[0]); close(fd[1]);`)** and **reaps both children** (`reap(); reap();`).

---

## 2. The #1 Bug in Section 4: Why Unclosed Pipe Ends Cause Deadlock

When a reader process (like `sort`, `wc`, or `grep`) reads from a pipe (`STDIN_FILENO`), how does it know when the writer has finished sending all data?
* The kernel sends **`EOF` (`read()` returns `0`)** to the reader **ONLY when EVERY open file descriptor pointing to the write end (`fd[1]`) of that pipe has been closed across ALL processes!**
* Remember **Lecture 3 (Slide 14)**: Each entry in the system-wide Open File Table (OFT) tracks a **reference count** of how many processes have that descriptor open.
* **What goes wrong if the parent shell forgets `close(fd[1])`:**
  * Even after `C1` (`echo`) finishes and exits, the **parent shell itself** still holds `fd[1]` open!
  * Therefore, the kernel sees that 1 process still has the write end open, so `C2` (`wc` or `sort`) sits waiting for more input forever, and the parent sits in `wait(NULL)` waiting for `C2` to exit forever (**deadlock**)!
* **Rule:** Every process (parent and every child) **must** close every pipe descriptor it is not actively using.

---

## 3. Scaling to Arbitrary Length Pipelines ($N$ Stages)

In **Section 4**, your shell must support pipelines of any length, e.g.:
```bash
tr a-z A-Z < txt/phrases.txt | grep BURN | sort | wc -l
```
Here there are $N = 4$ stages connected by $N - 1 = 3$ pipes:
```text
[Stage 0: tr] ===Pipe 0===> [Stage 1: grep] ===Pipe 1===> [Stage 2: sort] ===Pipe 2===> [Stage 3: wc]
```

### How to Think About Stage $i$ (for $i = 0 \dots N-1$)
You don't even need $N-1$ pipes open at the same time if you loop from $i = 0$ to $N - 1$:
* Maintain a variable `int prev_read_fd = -1;` (which holds the read end of the pipe created in the *previous* iteration).
* For stage $i$:
  * If $i < N - 1$ (not the last stage), create a new pipe `int fd[2]; pipe(fd);` to connect stage $i \rightarrow$ stage $i+1$.
  * `fork()` child $i$:
    * **In the child:**
      * If $i > 0$ (`prev_read_fd != -1`): redirect `STDIN_FILENO` from `prev_read_fd` (`dup2(prev_read_fd, STDIN_FILENO); close(prev_read_fd);`).
      * If $i < N - 1$: close `fd[0]` (unused read end of current pipe) and redirect `STDOUT_FILENO` to `fd[1]` (`dup2(fd[1], STDOUT_FILENO); close(fd[1]);`).
      * **What if stage $i$ also has file redirection (`<`, `>`, `>>`)?**
        * Applying file redirection (`open` + `dup2`) *after* wiring the pipe descriptors naturally overrides `STDIN_FILENO` (for `<`) or `STDOUT_FILENO` (for `>` / `>>`), which automatically satisfies the spec requirement for mid-pipeline redirection!
      * Execute the command for stage $i$.
    * **In the parent:**
      * If `prev_read_fd != -1`, the parent is done with the previous pipe's read end, so `close(prev_read_fd);`.
      * If $i < N - 1$, the parent never writes to the current pipe, so `close(fd[1]);` and save `prev_read_fd = fd[0];` for stage $i + 1$!
* After the loop finishes launching all $N$ children, the parent calls `reap()` $N$ times in a loop.

---

## 4. Breakdown of System Calls Needed in Section 4

### `pipe` — Create an inter-process channel (`<unistd.h>`)
* **Man page:** `man 2 pipe`
* **Signature:**
  ```c
  int pipe(int pipefd[2]);
  ```
* **Parameters:**
  * `pipefd`: An array of two integers (`int fd[2]`). On success, the kernel fills in:
    * `pipefd[0]`: File descriptor for the **read end** of the pipe.
    * `pipefd[1]`: File descriptor for the **write end** of the pipe.
* **Return Value:**
  * Returns **`0`** on success.
  * Returns **`-1`** on error (handle with `perror("pipe failed");`).
* **Crucial Ordering:** Always call `pipe(fd)` **before** calling `fork()` for the child processes that need to share that pipe (so the child inherits the pipe's file descriptors when `fork()` copies the parent's FDT).
