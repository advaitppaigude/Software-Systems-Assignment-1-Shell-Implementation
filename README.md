# Assignment 1: `s3` Shell Implementation

## Overview

This repository contains the implementation of **`s3` (Software Systems Shell)**, a custom Unix-like command-line shell written in C. The shell implements core features found in modern shells like Bash, including external command execution, I/O redirection, built-in directory navigation, multi-stage pipelines, batched command execution, and nested subshells.

---

## Repository Structure

```text
├── src/
│   ├── s3main.c        # Main REPL control flow of the shell
│   ├── s3.h            # Function declarations, constants, and includes
│   ├── s3.c            # Implementation of shell parsing and execution functions
│   └── txt/
│       └── phrases.txt # Sample text file for testing shell commands
├── testing/            # Local scratch/testing directory (git-ignored)
├── TASKS.md            # Interactive sprint & test checklist
└── README.md
```

### Compiling and Running

From inside the `src/` directory:

```bash
gcc -Wall -Wextra -g *.c -o s3
./s3
```

---

## Coursework Requirements

### Core Functionality (Sections 1–7 — up to 70%)
1. **Basic Commands:** Prompt display, space-delimited argument parsing, process creation (`fork`, `execvp`, `wait`), and the `exit` built-in command.
2. **Commands with Redirection:** Input (`<`) and output (`>` overwrite, `>>` append) stream redirection using `open()` and `dup2()`.
3. **Support for `cd` & Dynamic Prompt:** Shell built-in `cd` (`chdir()`) supporting standard paths, home directory (`cd`), and previous working directory (`cd -`), plus a dynamic prompt displaying the current working directory (`getcwd()`).
4. **Commands with Pipes:** Multi-stage command pipelines (`|`) of arbitrary length using `pipe()` and `dup2()`, including stages with file redirection.
5. **Batched Commands:** Sequential execution of independent commands or pipelines separated by `;`.
6. **Subshells:** Isolated command groups inside parentheses `(...)` executed in a child shell process, both standalone and within pipelines.
7. **Nested Subshells:** Support for arbitrary levels of nested parentheses `((...))`.

---

## Team Division (Option B — Feature Split)

| Team Member | Assigned Areas |
| :--- | :--- |
| **Person 1** | Basic execution, I/O Redirection (`<`, `>`, `>>`), Pipelines (`\|`), Process-management tests |
| **Person 2** | `cd` built-in & dynamic prompt, Batched commands (`;`), Subshells & nesting (`(...)`), Command parsing tests |

---

## Project Timeline & Sprint Plan

See **[TASKS.md](./TASKS.md)** for the full interactive checkbox list of implementation tasks and test cases.

| Sprint | Milestone / Focus | Person 1 Tasks | Person 2 Tasks | Branch(es) |
| :--- | :--- | :--- | :--- | :--- |
| **Sprint 0** | **Setup & Section 1 (Basic Commands)** | Pair-program `launch_program`, `child`, and `exit` built-in; test basic commands | Pair-program `launch_program`, `child`, and `exit` built-in; test basic commands | `feat/sec1-basics` |
| **Sprint 1** | **Sections 2 & 3 (Redirection + `cd`)** | Implement Section 2: `<`, `>`, `>>` redirection parsing & `open`/`dup2` execution | Implement Section 3: dynamic `getcwd` prompt, `init_lwd`, `is_cd`, and `run_cd` (`cd`, `cd -`, `cd <dir>`) | `feat/sec2-redirection`<br>`feat/sec3-cd-prompt` |
| **Sprint 2** | **Sections 4 & 5 (Pipes + Batches)** | Implement Section 4: multi-stage pipelines (`\|`) using `pipe()` and `dup2()` | Implement Section 5: batched commands (`;`) with parenthesis-aware splitting | `feat/sec4-pipes`<br>`feat/sec5-batches` |
| **Sprint 3** | **Sections 6 & 7 (Subshells & Nesting)** | Support subshell stages inside pipelines and write process-management tests | Implement Sections 6 & 7: subshell execution `(...)`, arbitrary nesting, and command parsing tests | `feat/sec6-7-subshells` |
| **Sprint 4** | **Section 8 (Stretch Goals & Polish)** | Stretch feature(s), code review, optimization, and final testing | Stretch feature(s), code review, final testing, and `README.md` documentation | `feat/stretch-*` |

---

## Git Workflow

1. **Start a feature branch from an updated `main`:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feat/<branch-name>
   ```
2. **Stage and commit only source files:**
   ```bash
   git add src/s3.c src/s3.h src/s3main.c
   git commit -m "Describe change"
   git push -u origin feat/<branch-name>
   ```
3. **Integrate at the end of each sprint:**
   * Pull `origin/main` into your feature branch, verify `gcc -Wall -Wextra -g *.c -o s3` compiles cleanly and passes tests, then merge into `main`.
