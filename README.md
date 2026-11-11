# Assignment 1: `s3` Shell Implementation

## Overview

This repository contains the implementation of **`s3` (Software Systems Shell)**, a custom Unix-like command-line shell written in C. The shell implements core features found in modern shells like Bash, including external command execution, I/O stream redirection, built-in directory navigation with a dynamic working-directory prompt, multi-stage pipelines, batched command execution, and nested subshells.

---

## Repository Structure

```text
├── src/
│   ├── s3main.c            # Main REPL control flow of the shell
│   ├── s3.h                # Function declarations, data structures, constants, and includes
│   ├── s3.c                # Implementation of shell parsing, built-ins, redirection, and execution
│   └── txt/
│       └── phrases.txt     # Sample text file for testing shell commands
├── testing/                # Automated regression & verification test suite
│   └── test_sec0_to_7.sh   # Master automated test suite (Sections 0–7, 62 tests)
├── assistance/             # Concept & system call study guides for Sections 1–8
├── TASKS.md                # Interactive sprint & test checklist
└── README.md
```

### Compiling and Running

From inside the `src/` directory:

```bash
gcc *.c -o s3
./s3
```

### Running the Master Automated Test Suite

From the repository root:

```bash
./testing/test_sec0_to_7.sh  # Runs all 62 tests covering Sections 0–7 (Core 70%)
```

---

## How `s3` Achieves Its Tasks (Implementation Details)

### 1. Section 1: Basic Command Execution & Process Lifecycle
- **Command Reading & Tokenization (`read_command_line`, `parse_command`):**
  - Reads user input lines via `fgets()` into a fixed buffer (`MAX_LINE`) and strips the trailing newline `'\n'`.
  - Tokenizes space-delimited arguments in-place using `strtok(line, " ")` into a `NULL`-terminated `char *args[MAX_ARGS]` vector with argument count `argsc`.
- **Built-in `exit` & Empty Input Handling (`launch_program`):**
  - Empty or whitespace-only inputs (`args[ARG_PROGNAME] == NULL`) return immediately without spawning a child process.
  - When `strcmp(args[ARG_PROGNAME], "exit") == 0`, the parent shell calls `exit(EXIT_SUCCESS)` directly so the shell session itself terminates cleanly.
- **`fork–exec–wait` Process Execution (`launch_program`, `child`, `reap`):**
  - The parent shell calls `fork()` to duplicate the process.
  - Inside the child process (`rc == 0`), `child()` invokes `execvp(args[ARG_PROGNAME], args)` to replace the child's memory image with the target program binary (searching the system `PATH`). If `execvp()` fails, `perror("execvp")` reports the error and `_exit(EXIT_FAILURE)` terminates the child immediately so it never loops back into the parent REPL.
  - Inside the parent process (`rc > 0`), `reap()` (`wait(NULL)`) blocks until the child process finishes and reaps its exit status from the OS process table.

### 2. Section 2: Commands with I/O Redirection (`<`, `>`, `>>`)
- **Redirection Data Structure (`RedirectType`, `Redirection` in `s3.h`):**
  - Represents redirection state via an enum (`REDIR_NONE`, `REDIR_INPUT`, `REDIR_OUTPUT`, `REDIR_APPEND`) paired with the target `char *filename`.
- **Parsing & Argument Stripping (`parse_redirection`):**
  - Scans `args[]` for `<`, `>`, or `>>`, validates syntax (rejecting missing filenames, operator-as-filename errors, or multiple redirection operators), records the `RedirectType` and `filename`, and shifts the remaining elements in `args[]` left by 2 slots (`*argsc -= 2`) so `execvp()` only receives the program and its flags/arguments.
- **File Descriptor Wiring (`apply_redirection`):**
  - Executed inside the forked child process prior to `child()`:
    - **Input (`<`):** Opens `filename` with `open(..., O_RDONLY)` and redirects `STDIN_FILENO` via `dup2(fd, STDIN_FILENO)`.
    - **Output Overwrite (`>`):** Opens `filename` with `open(..., O_WRONLY | O_CREAT | O_TRUNC, 0644)` and redirects `STDOUT_FILENO` via `dup2(fd, STDOUT_FILENO)`.
    - **Output Append (`>>`):** Opens `filename` with `open(..., O_WRONLY | O_CREAT | O_APPEND, 0644)` and redirects `STDOUT_FILENO` via `dup2(fd, STDOUT_FILENO)`.
  - Closes the temporary file descriptor `close(fd)` immediately after `dup2()` to avoid leaked descriptors.

### 3. Section 3: Support for Built-in `cd` & Dynamic Shell Prompt
- **Why `cd` Runs in the Parent Process (`is_cd`, `run_cd`):**
  - Because each process maintains its own current working directory (`cwd`) in its kernel Process Control Block (PCB), running `chdir()` inside a forked child would leave the parent shell's directory unchanged. `s3main.c` detects `cd` commands via `is_cd(line)` (skipping leading whitespace and verifying `"cd"` is followed by `' '` or `'\0'`) and executes `run_cd()` directly in the parent process without forking.
- **Previous Working Directory Tracking (`init_lwd`, `run_cd`):**
  - At shell startup, `init_lwd(lwd)` initializes `lwd` with the starting directory via `getcwd()`.
  - Before changing directories, `run_cd()` saves the current working directory into a temporary buffer `temp`.
  - Supports all three navigation modes:
    1. **`cd` (no arguments):** Resolves the user's home directory via `getenv("HOME")` and calls `chdir()`.
    2. **`cd -` (previous directory):** Calls `chdir(lwd)` to return to the previous directory and swaps `lwd` with `temp` so repeated `cd -` commands toggle back and forth.
    3. **`cd <path>` (relative/absolute paths, `.`, `..`):** Calls `chdir(args[1])`.
  - Updates `lwd` with `temp` only when `chdir()` succeeds (`rc == 0`), preserving `lwd` on invalid directory errors and reporting failures via `perror("cd failed")`.
- **Dynamic Shell Prompt (`construct_shell_prompt`):**
  - Queries `getcwd()` before each prompt render (falling back to `lwd` if needed) and formats the prompt string via `snprintf(shell_prompt, MAX_PROMPT_LEN, "[%s s3]$ ", cwd)`.

### 4. Section 4: Commands with Pipes (`|`)
- **Parenthesis-Aware Pipeline Splitting (`parse_pipe_stages`, `parse_pipe`):**
  - Scans a command string character-by-character while tracking parenthesis depth (`shell_depth`) and splits on `'|'` **only when `shell_depth == 0`**, storing each stage string in `char *pipe_stages[MAX_ARGS]`. Any `'|'` inside a subshell `(...)` is preserved intact for the child subshell to execute.
  - Validates pipeline syntax and rejects empty/malformed stages (`cmd |`, `| cmd`, `cmd | | cmd`) with `shell: malformed pipeline`.
- **Multi-Stage Pipeline Execution (`launch_pipeline_stages`):**
  - Supports pipelines of arbitrary length ($N$ stages) by chaining `prev_read_fd` across iterations and creating a `pipe(pipefd)` for each stage except the last (`i < num_stages - 1`).
  - In each forked child process:
    - Wires `prev_read_fd` to `STDIN_FILENO` via `dup2()` (for stages $i > 0$) and `pipefd[1]` to `STDOUT_FILENO` via `dup2()` (for stages $i < num_stages - 1$), then closes all raw pipe descriptors (`prev_read_fd`, `pipefd[0]`, `pipefd[1]`).
    - If the stage is a subshell (`find_subshell_bounds`), applies any outer stage redirection and executes the child `s3` binary via `child({shell_path, inner_cmd, NULL}, 2)`.
    - Otherwise, tokenizes the stage via `parse_command`, extracts and applies any stage-level `<`, `>`, or `>>` redirection via `parse_redirection` and `apply_redirection`, and calls `child()`.
  - In the parent process, closes `prev_read_fd` and `pipefd[1]`, advances `prev_read_fd = pipefd[0]`, and reaps all launched child PIDs in order via `waitpid()`.

### 5. Section 5: Batched Commands (`;`)
- **Top-Level Semicolon Splitting (`parse_batched_commands`):**
  - Scans the raw command line character-by-character while maintaining a parenthesis nesting counter (`shell_depth`), incrementing on `'('` and decrementing on `')'`.
  - Splits the line by replacing `';'` with `'\0'` **only when `shell_depth == 0`**, storing pointers to each sub-command in `char *batch_cmds[MAX_ARGS]`. Semicolons enclosed inside subshells `(...)` are preserved intact for the child subshell to parse.
  - Because `parse_batched_commands` walks the string manually instead of calling `strtok()`, subsequent `strtok()` calls inside `parse_command()` for individual sub-commands do not clobber the batch parser's state.
- **Sequential Execution (`main` in `s3main.c`):**
  - Iterates over all `batch_count` commands sequentially, dispatching each one to `is_subshell()`, `is_cd()`, or `parse_pipe_stages()` / `launch_pipeline_stages()` / `launch_program()` + `reap()` regardless of whether previous commands in the batch succeeded or failed.

### 6. Sections 6 & 7: Subshells & Arbitrary Nested Subshells (`(...)`)
- **Subshell Boundary Detection (`find_subshell_bounds`, `is_subshell`):**
  - Skips leading whitespace and verifies the command starts with `'('`.
  - Tracks parenthesis nesting depth (`shell_depth`) across the command string to locate the matching closing `')'` for the opening `'('`, and checks that only trailing whitespace or redirection (`<`, `>`, `>>`) follows that closing parenthesis. This accurately distinguishes a standalone subshell (including arbitrarily nested `(((...)))` expressions) from a subshell piped into another command `(cmd1) | cmd2`.
- **Recursive Subshell Execution (`launch_subshell`, `main` in `s3main.c`):**
  - At startup, `s3main.c` resolves the absolute path to the running `s3` executable via `realpath(argv[0], shell_path)` so child subshells can still locate the `s3` binary even after `cd` changes the working directory.
  - `launch_subshell(line, shell_path)` strips the outer `'('` and `')'` in-place, parses any trailing redirection on the subshell, and calls `launch_program({shell_path, inner_cmd, NULL}, 2, &redir)`.
  - When the spawned `s3` instance starts with `argc > 1`, `s3main.c` copies `argv[1]` into `line`, runs a single non-interactive pass of the batch/subshell/pipeline/command loop, and exits at the end of the loop (`if (argc > 1) break;`).
  - **Environment Isolation & Arbitrary Nesting:** Because every subshell runs in its own forked `s3` process, any `cd` directory changes or state modifications inside `(...)` are isolated to that child process's PCB and never affect the parent shell. Deeply nested subshells `((...))` naturally strip one layer of parentheses per recursion level until the innermost commands execute.

### 7. Section 8: Stretch Goals
- **Wildcard Globbing (`*` and `?` via `expand_globs`):**
  - Integrated at the end of command parsing (`parse_command`). Inspects each parsed argument token for wildcard characters (`*` and `?`).
  - Uses the POSIX `<glob.h>` API with `GLOB_NOCHECK` to expand matching filenames in alphabetical order. If no matching files exist in the filesystem, `GLOB_NOCHECK` preserves the argument string literally (matching standard shell semantics).
  - Memory allocated by `glob()` is cleanly freed via `globfree()`, and expanded path tokens are duplicated into the arguments array.
  - Fully integrated across built-in `cd` (e.g. `cd t*t`), redirection (`< txt/*.txt`), multi-stage pipelines (`cat txt/*.txt | grep burn | wc -l`), and subshells (`(cd t*t ; ls *.txt)`).
- **Usability Enhancements — Enhanced Custom Prompt (`construct_shell_prompt`):**
  - **Terminal Detection (`isatty`):** Differentiates between non-interactive scripted/piped execution and real interactive terminals via `isatty(STDIN_FILENO)`. Automated test scripts continue to receive the strict `[cwd s3]$ ` prompt format, while interactive terminal sessions receive the enhanced prompt.
  - **User & Host Resolution:** Dynamically fetches the current username via `getenv("USER")` (falling back to `"user"`) and system hostname via `gethostname()` (falling back to `"localhost"`).
  - **`$HOME` Path Shortening:** Inspects `cwd` against `getenv("HOME")`. When `cwd` is within the user's home directory, the home prefix is automatically shortened to `~` (e.g., `~/Documents/...`), preserving readability in deeply nested paths.
  - **ANSI Color Formatting:** Interactive prompt renders with distinct ANSI colors: yellow bracket and shell indicator `[... s3]$ `, bold green `user@host`, bold blue current working directory, and terminal attribute reset codes (`\033[0m`) before reading input.
- **Usability Enhancements — Command History & Line Editing (`read_command_line`):**
  - Configures terminal attributes using `<termios.h>` to disable canonical mode (`ICANON`) and character echoing (`ECHO`) for interactive TTY sessions.
  - **Up/Down Arrow Navigation:** Intercepts ANSI escape sequences for Up (`\033[A`) and Down (`\033[B`) arrows to navigate through the circular in-memory `history` buffer. Lines are dynamically redrawn via `\r\033[K` with prompt styling and command text. Navigating past the newest command restores a blank line.
  - **Backspace Support:** Handles both ASCII 127 (`DEL`) and `\b` to delete characters from the active buffer and terminal display (`\b \b`).
  - **History Filtering:** Skips blank and whitespace-only lines when appending to history via `add_to_history()`.
- **Usability Enhancements — Interactive Tab Completion (`read_command_line`):**
  - Intercepts `\t` keypresses to locate the prefix of the current in-progress token and globs for matching filesystem paths (`pattern*`).
  - **Single Match:** Immediately autocompletes the word inline and updates buffer length. The completed full command string is preserved and stored in history when executed.
  - **Multiple Matches:** Displays all matching candidates separated by spaces on a new line, then cleanly redraws the styled prompt and the user's partial input line, allowing immediate continued typing.
  - Restores original terminal attributes (`tcsetattr` with `TCSANOW`) upon hitting Enter (`\n`) before executing the command.

---

## Coursework Roadmap & Team Division

| Team Member | Assigned Areas |
| :--- | :--- |
| **Advait (Person 1)** | Basic execution, I/O Redirection (`<`, `>`, `>>`), Pipelines (`\|`), Process-management tests |
| **Srivathsan (Person 2)** | `cd` built-in & dynamic prompt, Batched commands (`;`), Subshells & nesting (`(...)`), Section 8 Stretch Goals (Wildcards, Custom Prompt, History & Tab Completion), Command parsing & test suites |

See **[TASKS.md](./TASKS.md)** for the full interactive checkbox list of implementation tasks and test cases across Sprints 0–4.
