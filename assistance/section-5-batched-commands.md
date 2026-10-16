# Section 5: Batched Commands — Concepts & Function Reference

**Coursework Goal:** Support executing a batch of independent commands (standalone or piped) separated by `;` one after another in sequence, regardless of whether previous commands succeed or fail.  
**Reference:** Assignment 1 Specification — Section 5

---

## 1. Core Concept: How Batched Commands Work

In a shell, the semicolon operator (`;`) separates independent command units on a single input line:
```bash
mkdir results ; cat txt/phrases.txt | sort | tac > results/rev_sort_phr.txt ; echo "Processing complete."
```
Here, the shell splits the input line on `;` into **3 sequential units**:
1. `mkdir results` (a basic command)
2. `cat txt/phrases.txt | sort | tac > results/rev_sort_phr.txt` (a pipeline with redirection)
3. `echo "Processing complete."` (a basic command)

Each unit is executed **completely (including waiting/reaping its child processes)** before the next unit in the batch starts—which is why `results/` already exists by the time the second unit writes `results/rev_sort_phr.txt`!

---

## 2. The Key C Pitfall in Section 5: Why Nested `strtok()` Calls Fail

Suppose you write a loop using `strtok(line, ";")` to get each command in a batch, and inside the loop body you call `parse_command(...)` (which calls `strtok(cmd, " ")`):

```c
// WARNING: BUGGY PATTERN!
char *cmd = strtok(line, ";");
while (cmd != NULL) {
    parse_command(cmd, args, &argsc); // <-- Calls strtok(cmd, " ") internally!
    launch_program(args, argsc);
    reap();
    cmd = strtok(NULL, ";");          // <-- BROKEN! Returns NULL!
}
```

### Why does this break?
* `strtok()` uses a **single hidden `static` pointer inside the C library** to remember where it is in the string.
* When `parse_command` calls `strtok(cmd, " ")`, it overwrites that hidden pointer to point to the end of `cmd`.
* When the outer loop calls `strtok(NULL, ";")`, `strtok` looks at the end of `cmd` instead of the rest of `line`, and immediately returns `NULL` after the first command!

---

## 3. Three Clean Ways to Avoid the `strtok` Trap

### Approach 1: Split into an Array First, Then Loop
If you finish extracting all `;`-separated command pointers into an array `char *batch_cmds[MAX_ARGS]` *before* calling `parse_command` on any of them, the two tokenizers never run at the same time.

### Approach 2: Use `strtok_r` (Reentrant Tokenizer — `<string.h>`)
* **Man page:** `man 3 strtok_r`
* **Signature:**
  ```c
  char *strtok_r(char *str, const char *delim, char **saveptr);
  ```
* **How it works:** Instead of using a global static pointer, `strtok_r` stores its bookmark inside a local `char *saveptr` variable that you provide (`&saveptr`). Because each loop has its own `saveptr`, nested tokenization loops never interfere with each other.

### Approach 3 (Recommended — Prepares You for Sections 6 & 7): Depth-Aware Character Loop
In **Section 6**, a command line can look like:
```bash
echo "Start" ; (cd /var/log ; cat syslog) ; date
```
Neither `strtok` nor `strtok_r` knows that the `;` inside `(cd /var/log ; cat syslog)` is inside parentheses and should **not** be split at the outer batch level!

By writing a simple `for` loop that walks through `line[i]` character by character:
1. Keep an integer `int depth = 0;`.
2. Increment `depth++` when `line[i] == '('`, and decrement `depth--` when `line[i] == ')'`.
3. Whenever `line[i] == ';'` **and `depth == 0`**, overwrite `line[i] = '\0'`, record the start of the next command at `&line[i + 1]`, and continue!

This ~15-line loop solves **both** the nested `strtok` bug **and** parenthesis-aware splitting for Sections 6 & 7 at the same time.
