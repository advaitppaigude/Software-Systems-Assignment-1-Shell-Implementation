# `s3` Shell Coursework — Section-by-Section Learning Guides

This `assistance/` folder contains preliminary study guides for every section of **Assignment 1 (`s3` Shell Implementation)**, cross-referenced with your **ELEC50014 Lecture Slides (Lectures 1–4)** and the assignment specification.

---

## Section Guides

| Section File | Coursework Topic | Key Concepts & Functions Covered | Team Member (Option B) | Lecture References |
| :--- | :--- | :--- | :--- | :--- |
| **[section-1-basic-commands.md](./section-1-basic-commands.md)** | **1. Basic Commands** | C strings (`'\0'`), `char *args[]`, `int *argsc`, `fgets`, `strtok`, `fork()`, `execvp()`, `wait()`, `strcmp()`, `exit` built-in | **Both** (Sprint 0) | Lecture 1 (Slide 12)<br>Lecture 2 (Slides 13–26)<br>Lecture 3 (Slides 4–9) |
| **[section-2-redirection.md](./section-2-redirection.md)** | **2. Commands with Redirection** | File descriptors (`0`, `1`, `2`), FDT & OFT tables, stripping `<`/`>`/`>>` from `args[]`, `open()`, flags (`O_CREAT`, `O_TRUNC`, `O_APPEND`), `dup2()`, `close()`, `strchr`, `strstr` | **Person 1** (Sprint 1) | Lecture 2 (Slide 28)<br>Lecture 3 (Slides 11–16, 21) |
| **[section-3-cd-and-prompt.md](./section-3-cd-and-prompt.md)** | **3. Support for `cd` & Prompt** | Why `cd` is a parent built-in (PCB `cwd`), `chdir()`, `getcwd()`, `getenv("HOME")`, `snprintf()`, tracking `lwd` for `cd -` | **Person 2** (Sprint 1) | Lecture 2 (Slides 7, 9)<br>Spec Section 3 |
| **[section-4-pipes.md](./section-4-pipes.md)** | **4. Commands with Pipes** | Inter-Process Communication (IPC), kernel circular buffer, `pipe()`, `dup2()`, why unclosed pipe FDs cause `EOF` deadlock, $N$-stage pipelines | **Person 1** (Sprint 2) | Lecture 3 (Slides 10, 17–24)<br>Lecture 4 (Slides 2–4) |
| **[section-5-batched-commands.md](./section-5-batched-commands.md)** | **5. Batched Commands** | Sequential `;` execution, why nested `strtok()` calls fail (static state), `strtok_r()`, parenthesis-aware splitting | **Person 2** (Sprint 2) | Spec Section 5 |
| **[section-6-subshells.md](./section-6-subshells.md)** | **6. Subshells** | Process isolation for `(...)`, handling `main(int argc, char *argv[])`, stripping outer parentheses, subshells inside pipelines | **Person 2 & Person 1** (Sprint 3) | Lecture 1 (Slide 12)<br>Lecture 3 (Slides 6–9, 24) |
| **[section-7-nested-subshells.md](./section-7-nested-subshells.md)** | **7. Nested Subshells** | Arbitrary nesting `((...))`, parenthesis depth counter/stack, avoiding the `(...) ; (...)` matching trap | **Person 2** (Sprint 3) | Spec Section 7 |
| **[section-8-stretch-goals.md](./section-8-stretch-goals.md)** | **8. Stretch Goals** | Combined `<` and `>`, wildcard globbing (`<glob.h>`), job control (`waitpid`, signals), command history & `readline` | **Both** (Sprint 4) | Spec Section 8 |

---

## Quick Terminal `man` Page Commands

As emphasized in Lecture 1 (Slide 21) and Lecture 2 (Slide 13), you can look up the official specification for any system call (Section 2) or C library function (Section 3) directly in your terminal:

```bash
# POSIX System Calls (Manual Section 2)
man 2 fork
man 2 wait
man 2 waitpid
man 2 open
man 2 close
man 2 dup2
man 2 pipe
man 2 chdir

# Standard C Library Functions (Manual Section 3)
man 3 execvp
man 3 getcwd
man 3 getenv
man 3 fgets
man 3 strtok
man 3 strtok_r
man 3 strcmp
man 3 strchr
man 3 strstr
man 3 snprintf
man 3 perror
man 3 exit
```
