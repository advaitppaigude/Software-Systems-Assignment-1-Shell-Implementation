# `s3` Shell Implementation — Interactive Task Checklist

> **Tip:** On GitHub, you can click any checkbox below directly in the web view to mark tasks complete as you and your partner progress through each sprint.

---

## Sprint 0: Setup & Section 1 — Basic Commands (`feat/sec1-basics`)

### Setup & Environment (Both)
- [x] Clone repository and verify `gcc -Wall -Wextra -g *.c -o s3` compiles inside `src/`
- [x] Review starter code in `src/s3main.c`, `src/s3.h`, and `src/s3.c`
- [x] Review Lectures 2 & 3 on `fork()`, `execvp()`, and `wait()`

### Section 1 Implementation (Both — Pair Programming)
- [x] Implement `child(char *args[], int argsc)` using `execvp()` and handle execution errors (`perror` + `exit`)
- [x] Implement `launch_program(char *args[], int argsc)` using `fork()`
- [x] Handle built-in `exit` command so the parent shell exits cleanly
- [x] Handle empty input lines (pressing Enter with no command) without crashing or spawning stray processes

### Section 1 Verification Tests
- [x] `whoami`, `pwd`, `ls`, `ls -R`, `cal`, `cal -y`, `clear`
- [x] `man cat` and `less txt/phrases.txt` (interactive commands)
- [x] `cat txt/phrases.txt`, `uniq txt/phrases.txt`, `wc txt/phrases.txt`, `sort txt/phrases.txt`
- [x] `grep burn txt/phrases.txt` and `grep -n burn txt/phrases.txt`
- [x] `cp`, `touch`, `chmod`, `ls -l` on test files
- [x] `exit` terminates the `s3` shell session
- [x] Merge `feat/sec1-basics` into `main`

---

## Sprint 1: Sections 2 & 3 — Redirection & `cd`

### Advait (Person 1) — Section 2: Commands with Redirection (`feat/sec2-redirection`)
- [ ] Declare redirection functions in `src/s3.h`
- [ ] Implement `command_with_redirection(char line[])` to detect `<`, `>`, and `>>`
- [ ] Implement parsing helper(s) to extract the redirection operator and target filename, and strip them from `args[]`
- [ ] Implement output redirection (`>`) using `open()` (`O_WRONLY | O_CREAT | O_TRUNC`) and `dup2(..., STDOUT_FILENO)`
- [ ] Implement append output redirection (`>>`) using `open()` (`O_WRONLY | O_CREAT | O_APPEND`) and `dup2(..., STDOUT_FILENO)`
- [ ] Implement input redirection (`<`) using `open()` (`O_RDONLY`) and `dup2(..., STDIN_FILENO)`
- [ ] Close the opened file descriptor after `dup2()` and handle `open()` errors gracefully
- [ ] Implement `launch_program_with_redirection(char *args[], int argsc)`
- [ ] **Test Section 2 commands:**
  - [ ] `ls > txt/folder_contents.txt` and `ls -R > txt/folder_contents.txt`
  - [ ] `echo "=== Full-Year Calendar ===" > txt/calendar.txt`
  - [ ] `cal -y >> txt/calendar.txt`
  - [ ] `tac txt/phrases.txt > txt/phrases_reversed.txt`
  - [ ] `sort txt/phrases.txt > txt/phrases_sorted.txt`
  - [ ] `head -n 5 txt/phrases.txt >> txt/phrases_sorted.txt`
  - [ ] `wc txt/phrases.txt > txt/phrases_stats.txt`
  - [ ] `grep June < txt/calendar.txt`
  - [ ] `tr a-z A-Z < txt/phrases.txt`

### Srivathsan (Person 2) — Section 3: Support for `cd` & Dynamic Prompt (`feat/sec3-cd-prompt`)
- [ ] Declare `cd` and `lwd` functions in `src/s3.h`
- [ ] Implement `init_lwd(char lwd[])` using `getcwd()`
- [ ] Update `construct_shell_prompt` and `read_command_line` to display the current working directory (e.g. `[/path/to/cwd s3]$ `)
- [ ] Implement `is_cd(char line[])` to accurately detect `cd` commands (without false positives on commands starting with `"cd..."`)
- [ ] Implement `run_cd(char *args[], int argsc, char lwd[])` using `chdir()`:
  - [ ] Support standard relative/absolute paths (`cd txt`, `cd ..`, `cd .`)
  - [ ] Support `cd` with no arguments (change to user's home directory via `getenv("HOME")`)
  - [ ] Support `cd -` (switch to previous directory stored in `lwd` and update `lwd`)
  - [ ] Update `lwd` before changing directory and handle invalid paths with `perror`
- [ ] **Test Section 3 commands:**
  - [ ] `cd txt` and verify prompt updates and `ls` lists `phrases.txt`
  - [ ] `cd ..` and `cd .`
  - [ ] `cd` (with no arguments) goes to home directory
  - [ ] `cd -` toggles back and forth between the previous and current directories

### Sprint 1 Integration (Both)
- [ ] Merge `feat/sec2-redirection` and `feat/sec3-cd-prompt` into `main`
- [ ] Verify `s3main.c` matches the Section 3 control flow and passes both Redirection and `cd` tests

---

## Sprint 2: Sections 4 & 5 — Pipelines & Batched Commands

### Pre-Sprint Refactoring (Both)
- [ ] Extract single-command execution logic (`cd` / redirection / basic command) into a reusable helper function
- [ ] Agree on a parenthesis-aware delimiter splitting approach so `;` and `|` inside `(...)` are not split prematurely

### Advait (Person 1) — Section 4: Commands with Pipes (`feat/sec4-pipes`)
- [ ] Implement detection function for pipelined commands (`|`)
- [ ] Implement tokenizer to split a pipeline into individual stage strings (ignoring `|` inside parentheses)
- [ ] Implement pipeline launcher supporting arbitrary pipeline lengths ($N$ stages):
  - [ ] Create pipes using `pipe()` and wire stage $i$ `stdout` $\rightarrow$ stage $i+1$ `stdin` via `dup2()`
  - [ ] Reuse existing basic and redirection child/launch logic for stages with `<`, `>`, or `>>`
  - [ ] Close all unused pipe file descriptors in both parent and child processes
  - [ ] Reap all child processes in the pipeline
- [ ] **Test Section 4 commands:**
  - [ ] `cat txt/phrases.txt | sort > txt/phrases_sorted.txt`
  - [ ] `tr a-z A-Z < txt/phrases.txt | grep BURN | sort | wc -l` (expect `3`)
  - [ ] `ps aux | grep python | sort -k 3 -nr | head`
  - [ ] Verify mid-pipeline output redirection (`>`) behavior

### Srivathsan (Person 2) — Section 5: Batched Commands (`feat/sec5-batches`)
- [ ] Implement detection/splitting for batched commands separated by `;` (ignoring `;` inside parentheses)
- [ ] Ensure tokenization does not break when sub-commands also tokenize arguments (avoid nested `strtok` global-state bugs)
- [ ] Execute each batched command/pipeline sequentially regardless of whether the previous command succeeded or failed
- [ ] **Test Section 5 commands:**
  - [ ] `mkdir results ; cat txt/phrases.txt | sort | tac > results/rev_sort_phr.txt ; echo "Processing complete."`
  - [ ] Batch containing `cd` followed by a command in the new directory (e.g. `cd txt ; ls ; cd -`)

### Sprint 2 Integration (Both)
- [ ] Merge `feat/sec4-pipes` and `feat/sec5-batches` into `main`
- [ ] Verify combined batch + pipeline + redirection + `cd` commands work end-to-end

---

## Sprint 3: Sections 6 & 7 — Subshells & Nested Subshells (`feat/sec6-7-subshells`)

### Srivathsan (Person 2) — Subshell Parsing, Execution & Arbitrary Nesting (Sections 6 & 7)
- [ ] Implement subshell detection for commands wrapped in `(...)`
- [ ] Implement parenthesis-matching/stripping logic (using depth counter/stack) to support arbitrary nesting levels `((...))`
- [ ] Update `main(int argc, char *argv[])` (or child subshell handler) so a spawned child `s3` process can execute a subshell command string
- [ ] Verify environment isolation: `cd` or state changes inside `(...)` do not affect the parent shell after the subshell finishes
- [ ] Write command parsing tests covering batches, pipes, whitespace edge cases, and deeply nested subshells

### Advait (Person 1) — Pipeline Subshell Integration & Process-Management Tests
- [ ] Support launching a subshell as a stage within a pipeline with `stdin`/`stdout` redirected to pipe ends
- [ ] Verify subshells with file redirection (e.g. `(cd txt ; cat phrases.txt) > out.txt`)
- [ ] Write process-management tests verifying no zombie processes or leaked file descriptors remain

### Sprint 3 Verification Tests & Core 70% Sign-off (Both)
- [ ] `echo "Start processing..." ; (cd /var/log ; cat syslog | sort > sorted_syslog.txt) ; echo "Finished writing sorted log." ; date`
- [ ] `(cd /var/log ; cat syslog) | sort | head`
- [ ] Nested subshells test: e.g. `(cd txt ; (cat phrases.txt | grep burn) | wc -l) ; pwd` (verify `pwd` is unchanged)
- [ ] Merge `feat/sec6-7-subshells` into `main`

---

## Sprint 4: Section 8 — Stretch Goals, Polish & Submission

### Candidate Stretch Goals (Select 1–2+ as a Pair)
- [ ] **Combined Input & Output Redirection (Advait - Person 1):** Support `<` and `>`/`>>` in the same command (e.g. `sort < txt/phrases.txt > txt/sorted_output.txt`)
- [ ] **Wildcard Globbing (Srivathsan - Person 2):** Expand `*` and `?` filename patterns in command arguments
- [ ] **Job Control (Advait - Person 1):** Background execution (`&`) and `fg` / `bg` built-ins
- [ ] **Usability Enhancements (Srivathsan - Person 2):** Command history, tab completion, or enhanced custom prompt
- [ ] **Stream Routing:** `tee`-like multi-output syntax

### Final Code Quality & Submission Checklist (Both)
- [ ] Compile with `gcc -Wall -Wextra -g *.c -o s3` and resolve all compiler warnings
- [ ] Review code for functional decomposition, consistent naming, and clear comments
- [ ] Update `README.md` with final documentation of implemented features and stretch extensions
- [ ] Ensure no temporary test files or compiled binaries are tracked in Git (`git status` is clean)
