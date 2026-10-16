# Section 7: Nested Subshells — Concepts & Parsing Reference

**Coursework Goal:** Relax the single-level restriction on subshells so that parentheses `((...))` can be nested to any depth.  
**Reference:** Assignment 1 Specification — Section 7

---

## 1. Core Concept: Why Nesting Works Naturally if Parsing Is Depth-Aware

Here is the good news about **Section 7**:
* On the **execution** side, each level of `( ... )` simply spawns a child `s3` process and passes it the inner string (with **one** layer of outer parentheses stripped). When that child `s3` process parses its own command line, if it encounters another `( ... )` inside, it naturally spawns its own child `s3` process!
* Therefore, **95% of Section 7 is purely a parsing problem**: making sure your shell only splits `;` and `|` at **nesting depth `0`**, and accurately matches an opening `'('` with its corresponding closing `')'`.

---

## 2. How Parenthesis Depth / Stack Matching Works

Consider a command with nested subshells:
```bash
(cd txt ; (cat phrases.txt | grep burn) | wc -l) ; echo "Done"
```

Let's trace the **parenthesis depth** (`depth`) at every character from left to right:
1. Start with `int depth = 0;`.
2. At the first `'('` before `cd txt`: `depth` becomes **`1`**.
3. At the `;` after `cd txt`: `depth` is `1` ($\ne 0$), so **do NOT split this `;` at the outer level!**
4. At the second `'('` before `cat phrases.txt`: `depth` becomes **`2`**.
5. At the `|` before `grep burn`: `depth` is `2` ($\ne 0$), so **do NOT split this `|`!**
6. At the `')'` after `grep burn`: `depth` decrements back to **`1`**.
7. At the `|` before `wc -l`: `depth` is `1` ($\ne 0$), so **do NOT split this `|` at the outer level either!**
8. At the `')'` after `wc -l`: `depth` decrements back to **`0`**.
9. At the `;` before `echo "Done"`: **`depth == 0`!** This `;` is a top-level batch separator, so we split here into two batch commands:
   * Batch Command 0: `(cd txt ; (cat phrases.txt | grep burn) | wc -l)`
   * Batch Command 1: `echo "Done"`

### What Happens Next Inside Batch Command 0?
1. Batch Command 0 has no top-level `;` or `|` (where `depth == 0`), and its outermost characters are `'('` (at the start) and its matching `')'` (at the end).
2. The shell strips **only that outermost pair** of parentheses, leaving:
   ```bash
   cd txt ; (cat phrases.txt | grep burn) | wc -l
   ```
3. That string is passed to a child `s3` subshell process.
4. When the child `s3` runs the exact same depth-aware `;` splitter on `cd txt ; (cat phrases.txt | grep burn) | wc -l`:
   * Now the `;` after `cd txt` **is at `depth == 0`**! So the child splits it into:
     * Sub-command 0: `cd txt`
     * Sub-command 1: `(cat phrases.txt | grep burn) | wc -l`
5. Then Sub-command 1 is split by the depth-aware `|` splitter at `depth == 0` into two pipeline stages:
   * Stage 0: `(cat phrases.txt | grep burn)` (another subshell!)
   * Stage 1: `wc -l`

---

## 3. Edge Case to Watch Out For: Two Separate Subshells on the Same Line

Consider this tricky case:
```bash
(cd dir1 ; ls) ; (cd dir2 ; ls)
```
or in a pipeline:
```bash
(cd txt ; cat phrases.txt) | (grep burn ; echo "---")
```

Notice that both strings **start** with `'('` and **end** with `')'`!
* **Common Bug:** If you check whether a command is a single subshell simply by checking *"does the string start with `'('` and end with `')'`?"*, you might mistakenly treat `(cd dir1 ; ls) ; (cd dir2 ; ls)` as a single subshell and strip the first `'('` and the last `')'`, leaving invalid syntax `cd dir1 ; ls) ; (cd dir2 ; ls`!
* **How to Avoid This Bug:**
  1. Always run your depth-aware `;` splitter and `|` splitter **before** checking if a single unit is a subshell.
  2. Even better, when checking if a trimmed string `s` is wrapped in outer parentheses, verify that the opening `'('` at `s[0]` only returns to **`depth == 0` at the very last character `s[len - 1]`** (and never hits `depth == 0` in the middle of the string!).
  * Additionally, if someone writes redundant double parentheses like `((ls -l))`, stripping outer matching parentheses in a `while` loop (as long as `s[0] == '('` matches the final `')'`) handles `((...))` effortlessly.
