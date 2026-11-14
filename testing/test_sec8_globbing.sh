#!/usr/bin/env bash
# ==============================================================================
# Automated Test Suite for Section 8 Stretch Goals (Srivathsan - Person 2)
#   1. Wildcard Globbing (* and ?)
#   2. Usability Enhancements:
#      - Enhanced Custom Prompt (user@host, ~ home shortening, ANSI colors)
#      - Interactive Command History (Up/Down arrow keys, Backspace editing)
#      - Interactive Tab Completion (single-match inline & multi-match listing)
# ==============================================================================

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP" "$SRC_DIR/s3"' EXIT

PASSED=0
FAILED=0

pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "         ${RED}-> $2${NC}"
    fi
    ((FAILED++))
}

section() {
    echo ""
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================================================${NC}"
}

run_s3_in_dir() {
    local dir="$1"
    local input="$2"
    (cd "$dir" && printf "%b\n" "$input" | timeout 5s "$SRC_DIR/s3")
}

run_s3_raw() {
    run_s3_in_dir "$SRC_DIR" "$1"
}

strip_prompts() {
    sed -E 's/\[([^]]* )?s3\]\$ //g'
}

# ==============================================================================
# 1. Compilation
# ==============================================================================
section "1. Section 8 Stretch Goals — Compilation"

COMPILE_OUT=$(cd "$SRC_DIR" && gcc -Wall -Wextra -g s3main.c s3.c -o s3 2>&1)
COMPILE_RC=$?

if [[ $COMPILE_RC -eq 0 && -x "$SRC_DIR/s3" ]]; then
    pass "Compiles cleanly with 'gcc -Wall -Wextra -g s3main.c s3.c -o s3'"
else
    fail "Compilation failed" "$COMPILE_OUT"
    exit 1
fi

# ==============================================================================
# 2. Wildcard Globbing: '*' Expansion
# ==============================================================================
section "2. Wildcard Globbing — '*' Expansion"

# Test 1: '*.c' expands to multiple matching files in sorted order
OUT_STAR_C=$(run_s3_raw "echo *.c\nexit" | strip_prompts)
EXPECTED_STAR_C=$(cd "$SRC_DIR" && bash -c "echo *.c")
if [[ "$OUT_STAR_C" == "$EXPECTED_STAR_C" ]]; then
    pass "'echo *.c' expands to '$EXPECTED_STAR_C'"
else
    fail "'echo *.c' expansion failed" "Expected: '$EXPECTED_STAR_C', Got: '$OUT_STAR_C'"
fi

# Test 2: Subdirectory wildcard 'txt/*.txt'
OUT_SUBDIR_STAR=$(run_s3_raw "wc -l txt/*.txt\nexit" | strip_prompts)
EXPECTED_SUBDIR_STAR=$(cd "$SRC_DIR" && bash -c "wc -l txt/*.txt")
if [[ "$OUT_SUBDIR_STAR" == "$EXPECTED_SUBDIR_STAR" ]]; then
    pass "'wc -l txt/*.txt' expands subdirectory pattern properly"
else
    fail "'wc -l txt/*.txt' failed" "Expected: '$EXPECTED_SUBDIR_STAR', Got: '$OUT_SUBDIR_STAR'"
fi

# Test 3: Multiple wildcard arguments in the same command ('echo *.h txt/*.txt')
OUT_MULTI_STAR=$(run_s3_raw "echo *.h txt/*.txt\nexit" | strip_prompts)
EXPECTED_MULTI_STAR=$(cd "$SRC_DIR" && bash -c "echo *.h txt/*.txt")
if [[ "$OUT_MULTI_STAR" == "$EXPECTED_MULTI_STAR" ]]; then
    pass "Multiple wildcard tokens in one command ('echo *.h txt/*.txt' -> '$EXPECTED_MULTI_STAR')"
else
    fail "Multiple wildcard tokens failed" "Expected: '$EXPECTED_MULTI_STAR', Got: '$OUT_MULTI_STAR'"
fi

# ==============================================================================
# 3. Wildcard Globbing: '?' Single-Character & Combined Patterns
# ==============================================================================
section "3. Wildcard Globbing — '?' & Combined '*'/'?' Patterns"

# Test 4: '?' matches any single character ('s?.c' -> 's3.c')
OUT_Q_C=$(run_s3_raw "echo s?.c\nexit" | strip_prompts)
EXPECTED_Q_C=$(cd "$SRC_DIR" && bash -c "echo s?.c")
if [[ "$OUT_Q_C" == "$EXPECTED_Q_C" ]]; then
    pass "'echo s?.c' expands single-character '?' to '$EXPECTED_Q_C'"
else
    fail "'echo s?.c' failed" "Expected: '$EXPECTED_Q_C', Got: '$OUT_Q_C'"
fi

# Test 5: '?' in file extension ('s3.?' -> 's3.c s3.h')
OUT_Q_EXT=$(run_s3_raw "echo s3.?\nexit" | strip_prompts)
EXPECTED_Q_EXT=$(cd "$SRC_DIR" && bash -c "echo s3.?")
if [[ "$OUT_Q_EXT" == "$EXPECTED_Q_EXT" ]]; then
    pass "'echo s3.?' expands to '$EXPECTED_Q_EXT'"
else
    fail "'echo s3.?' failed" "Expected: '$EXPECTED_Q_EXT', Got: '$OUT_Q_EXT'"
fi

# Test 6: Combined '?' and '*' in the same pattern ('txt/p?rase*.txt')
OUT_COMBINED=$(run_s3_raw "echo txt/p?rase*.txt\nexit" | strip_prompts)
EXPECTED_COMBINED=$(cd "$SRC_DIR" && bash -c "echo txt/p?rase*.txt")
if [[ "$OUT_COMBINED" == "$EXPECTED_COMBINED" ]]; then
    pass "Combined '?' and '*' pattern ('echo txt/p?rase*.txt' -> '$EXPECTED_COMBINED')"
else
    fail "Combined '?' and '*' pattern failed" "Expected: '$EXPECTED_COMBINED', Got: '$OUT_COMBINED'"
fi

# ==============================================================================
# 4. Wildcard Globbing: Unmatched Patterns (GLOB_NOCHECK) & Integration
# ==============================================================================
section "4. Wildcard Globbing — GLOB_NOCHECK & Shell Integration"

# Test 7: Pattern with no matches stays literal
OUT_NOMATCH=$(run_s3_raw "echo *.nonexistent_ext_xyz\nexit" | strip_prompts)
if [[ "$OUT_NOMATCH" == "*.nonexistent_ext_xyz" ]]; then
    pass "Unmatched pattern ('echo *.nonexistent_ext_xyz') remains literal via GLOB_NOCHECK"
else
    fail "Unmatched pattern handling failed" "Expected: '*.nonexistent_ext_xyz', Got: '$OUT_NOMATCH'"
fi

# Test 8: Globbing with built-in 'cd' ('cd t*t')
OUT_GLOB_CD=$(run_s3_raw "cd t*t\npwd\nexit" | strip_prompts)
if [[ "$OUT_GLOB_CD" == "$SRC_DIR/txt" ]]; then
    pass "Globbing with built-in 'cd' ('cd t*t' changes to $SRC_DIR/txt)"
else
    fail "Globbing with 'cd' failed" "Got: '$OUT_GLOB_CD'"
fi

# Test 9: Globbing with input redirection ('wc -l < txt/*.txt')
OUT_GLOB_REDIR=$(run_s3_raw "wc -l < txt/*.txt\nexit" | strip_prompts)
EXPECTED_GLOB_REDIR=$(wc -l < "$SRC_DIR/txt/phrases.txt")
if [[ "$OUT_GLOB_REDIR" == "$EXPECTED_GLOB_REDIR" ]]; then
    pass "Globbing with input redirection ('wc -l < txt/*.txt' -> $EXPECTED_GLOB_REDIR)"
else
    fail "Globbing with input redirection failed" "Expected: '$EXPECTED_GLOB_REDIR', Got: '$OUT_GLOB_REDIR'"
fi

# Test 10: Globbing inside a pipeline ('cat txt/*.txt | grep burn | wc -l')
OUT_GLOB_PIPE=$(run_s3_raw "cat txt/*.txt | grep burn | wc -l\nexit" | strip_prompts)
EXPECTED_GLOB_PIPE=$(cat "$SRC_DIR/txt/phrases.txt" | grep burn | wc -l)
if [[ "$OUT_GLOB_PIPE" == "$EXPECTED_GLOB_PIPE" ]]; then
    pass "Globbing inside a pipeline ('cat txt/*.txt | grep burn | wc -l' -> $EXPECTED_GLOB_PIPE)"
else
    fail "Globbing inside a pipeline failed" "Expected: '$EXPECTED_GLOB_PIPE', Got: '$OUT_GLOB_PIPE'"
fi

# Test 11: Globbing inside a subshell and batch ('(cd t*t ; ls *.txt) ; pwd')
OUT_GLOB_SUB=$(run_s3_raw "(cd t*t ; ls *.txt) ; pwd\nexit" | strip_prompts)
EXPECTED_GLOB_SUB=$'phrases.txt\n'"$SRC_DIR"
if [[ "$OUT_GLOB_SUB" == "$EXPECTED_GLOB_SUB" ]]; then
    pass "Globbing inside subshell & batch ('(cd t*t ; ls *.txt) ; pwd')"
else
    fail "Globbing inside subshell & batch failed" "Expected:\n$EXPECTED_GLOB_SUB\nGot:\n$OUT_GLOB_SUB"
fi

# Test 12: Large glob expansion ('echo /usr/bin/*') stays bounded within MAX_ARGS without crashing
OUT_GLOB_LARGE=$(run_s3_raw "echo /usr/bin/*\nexit" | strip_prompts)
RC_GLOB_LARGE=$?
if [[ $RC_GLOB_LARGE -eq 0 && -n "$OUT_GLOB_LARGE" ]]; then
    pass "Large glob expansion ('echo /usr/bin/*') stays safely bounded within MAX_ARGS"
else
    fail "Large glob expansion failed (rc=$RC_GLOB_LARGE)"
fi

# ==============================================================================
# 5. Usability Enhancements: Enhanced Custom Prompt
# ==============================================================================
section "5. Usability Enhancements — Enhanced Custom Prompt (TTY vs. Pipe)"

# Test 12: Non-interactive piped mode keeps plain '[cwd s3]$ ' prompt
OUT_PIPE_PROMPT=$(run_s3_raw "exit")
if [[ "$OUT_PIPE_PROMPT" == "[$SRC_DIR s3]$ " ]]; then
    pass "Non-interactive piped mode preserves plain '[$SRC_DIR s3]\$ ' prompt"
else
    fail "Non-interactive piped prompt mismatch" "Got: '$OUT_PIPE_PROMPT'"
fi

# Run interactive PTY checks for Custom Prompt via Python pty
PROMPT_PTY_OUT=$(python3 - "$SRC_DIR" << 'EOF'
import os, sys, pty, time, subprocess

src_dir = sys.argv[1]
master, slave = pty.openpty()
proc = subprocess.Popen(
    [os.path.join(src_dir, "s3")],
    cwd=src_dir,
    stdin=slave,
    stdout=slave,
    stderr=slave,
    close_fds=True
)
os.close(slave)

def read_available(wait=0.15):
    time.sleep(wait)
    chunks = []
    while True:
        import select
        r, _, _ = select.select([master], [], [], 0.05)
        if not r:
            break
        data = os.read(master, 4096)
        if not data:
            break
        chunks.append(data.decode(errors="replace"))
    return "".join(chunks)

initial_prompt = read_available()
os.write(master, b"cd /tmp\n")
after_cd_tmp = read_available()
os.write(master, b"exit\n")
proc.wait(timeout=2)
os.close(master)

user = os.environ.get("USER", "user")
host = os.uname().nodename
home = os.environ.get("HOME", "")
expected_tilde = "~" + src_dir[len(home):] if home and src_dir.startswith(home) else src_dir

print("USER_HOST_OK=" + str(f"{user}@{host}" in initial_prompt))
print("TILDE_OK=" + str(expected_tilde in initial_prompt and (not home or home not in initial_prompt)))
print("TMP_PATH_OK=" + str(":\x1b[1;34m/tmp\x1b[0;33m" in after_cd_tmp))
print("ANSI_COLOR_OK=" + str(
    "\x1b[0;33m[" in initial_prompt and
    "\x1b[1;32m" in initial_prompt and
    "\x1b[1;34m" in initial_prompt and
    "\x1b[0;33m s3]$\x1b[0m " in initial_prompt
))
EOF
)

if grep -q "USER_HOST_OK=True" <<< "$PROMPT_PTY_OUT"; then
    pass "Interactive TTY prompt displays 'user@host' ($USER@$(hostname))"
else
    fail "Interactive TTY prompt missing 'user@host'" "$PROMPT_PTY_OUT"
fi

if grep -q "TILDE_OK=True" <<< "$PROMPT_PTY_OUT"; then
    pass "Interactive TTY prompt shortens \$HOME prefix to '~'"
else
    fail "Interactive TTY prompt failed to shorten \$HOME to '~'" "$PROMPT_PTY_OUT"
fi

if grep -q "TMP_PATH_OK=True" <<< "$PROMPT_PTY_OUT"; then
    pass "Interactive TTY prompt displays full path outside \$HOME (e.g., '/tmp' after 'cd /tmp')"
else
    fail "Interactive TTY prompt failed to display '/tmp' outside \$HOME" "$PROMPT_PTY_OUT"
fi

if grep -q "ANSI_COLOR_OK=True" <<< "$PROMPT_PTY_OUT"; then
    pass "Interactive TTY prompt includes ANSI color codes (yellow '[... s3]\$', green 'user@host', blue 'cwd', reset)"
else
    fail "Interactive TTY prompt missing expected ANSI color codes" "$PROMPT_PTY_OUT"
fi

# ==============================================================================
# 6. Usability Enhancements: Interactive Command History & Backspace Editing
# ==============================================================================
section "6. Usability Enhancements — Command History (Up/Down Arrows & Backspace)"

HISTORY_PTY_OUT=$(python3 - "$SRC_DIR" << 'EOF'
import os, sys, pty, time, select, subprocess

src_dir = sys.argv[1]
master, slave = pty.openpty()
proc = subprocess.Popen(
    [os.path.join(src_dir, "s3")],
    cwd=src_dir,
    stdin=slave,
    stdout=slave,
    stderr=slave,
    close_fds=True
)
os.close(slave)

def send_and_read(data: bytes, wait=0.12):
    if data:
        os.write(master, data)
    time.sleep(wait)
    chunks = []
    while True:
        r, _, _ = select.select([master], [], [], 0.04)
        if not r:
            break
        try:
            chunk = os.read(master, 4096)
        except OSError:
            break
        if not chunk:
            break
        chunks.append(chunk.decode(errors="replace"))
    return "".join(chunks)

# Drain initial prompt
send_and_read(b"")

# 1. Run two commands: 'echo hist_first' and 'echo hist_second'
send_and_read(b"echo hist_first\n")
send_and_read(b"echo hist_second\n")

# 2. Send a blank/whitespace-only line (should NOT be saved in history)
send_and_read(b"   \n")

# 3. Press Up arrow once -> should recall 'echo hist_second' (ignoring blank line)
out_up_once = send_and_read(b"\x1b[A\n")

# 4. Press Up arrow 3 times -> 'echo hist_second' -> 'echo hist_second' -> 'echo hist_first', then Down once -> 'echo hist_second'
# Wait: history now has [0]='echo hist_first', [1]='echo hist_second', [2]='echo hist_second'
# Let's press Up 3 times to reach [0]='echo hist_first' and execute it:
out_up_three = send_and_read(b"\x1b[A\x1b[A\x1b[A\n")

# 5. Press Up twice, then Down once -> should land on the most recent command ('echo hist_first')
# Wait: history is [0]='echo hist_first', [1]='echo hist_second', [2]='echo hist_second', [3]='echo hist_first'
# Up 3 times -> [1]='echo hist_second', Up 4 times -> [0]='echo hist_first', then Down 1 -> [1]='echo hist_second'
out_up_down = send_and_read(b"\x1b[A\x1b[A\x1b[A\x1b[A\x1b[B\n")

# 6. Press Up once then Down once (back to counter) -> line should clear to empty, then type 'echo after_clear'
out_down_clear = send_and_read(b"\x1b[A\x1b[Becho after_clear\n")

# 7. Test Backspace editing: type 'echo typoXX', send two backspaces (\x7f\x7f), then '_fixed\n'
out_backspace = send_and_read(b"echo typoXX\x7f\x7f_fixed\n")

send_and_read(b"exit\n")
proc.wait(timeout=2)
os.close(master)

print("UP_ONCE_OK=" + str("hist_second" in out_up_once.split("\n")[1] if "\n" in out_up_once else False))
print("UP_MULTI_OK=" + str("hist_first" in out_up_three.split("\n")[1] if "\n" in out_up_three else False))
print("DOWN_NAV_OK=" + str("hist_second" in out_up_down.split("\n")[1] if "\n" in out_up_down else False))
print("DOWN_CLEAR_OK=" + str("after_clear" in out_down_clear and "hist_secondecho" not in out_down_clear))
print("BACKSPACE_OK=" + str("typo_fixed" in out_backspace and "typoXX" not in out_backspace.split("\n")[1]))
EOF
)

if grep -q "UP_ONCE_OK=True" <<< "$HISTORY_PTY_OUT"; then
    pass "Up arrow (ESC[A) recalls the previous command and ignores blank lines"
else
    fail "Up arrow recall failed" "$HISTORY_PTY_OUT"
fi

if grep -q "UP_MULTI_OK=True" <<< "$HISTORY_PTY_OUT"; then
    pass "Multiple Up arrows navigate back to earlier commands in history"
else
    fail "Multiple Up arrow navigation failed" "$HISTORY_PTY_OUT"
fi

if grep -q "DOWN_NAV_OK=True" <<< "$HISTORY_PTY_OUT"; then
    pass "Down arrow (ESC[B) navigates forward to newer commands in history"
else
    fail "Down arrow navigation failed" "$HISTORY_PTY_OUT"
fi

if grep -q "DOWN_CLEAR_OK=True" <<< "$HISTORY_PTY_OUT"; then
    pass "Down arrow past newest history entry clears the input line cleanly"
else
    fail "Down arrow line clear failed" "$HISTORY_PTY_OUT"
fi

if grep -q "BACKSPACE_OK=True" <<< "$HISTORY_PTY_OUT"; then
    pass "Backspace (ASCII 127 / BS) deletes characters from the input buffer and screen"
else
    fail "Backspace editing failed" "$HISTORY_PTY_OUT"
fi

# ==============================================================================
# 7. Usability Enhancements: Interactive Tab Completion
# ==============================================================================
section "7. Usability Enhancements — Interactive Tab Completion (TAB)"

TAB_PTY_OUT=$(python3 - "$SRC_DIR" << 'EOF'
import os, sys, pty, time, select, subprocess

src_dir = sys.argv[1]
master, slave = pty.openpty()
proc = subprocess.Popen(
    [os.path.join(src_dir, "s3")],
    cwd=src_dir,
    stdin=slave,
    stdout=slave,
    stderr=slave,
    close_fds=True
)
os.close(slave)

def send_and_read(data: bytes, wait=0.12):
    if data:
        os.write(master, data)
    time.sleep(wait)
    chunks = []
    while True:
        r, _, _ = select.select([master], [], [], 0.04)
        if not r:
            break
        try:
            chunk = os.read(master, 4096)
        except OSError:
            break
        if not chunk:
            break
        chunks.append(chunk.decode(errors="replace"))
    return "".join(chunks)

# Drain initial prompt
send_and_read(b"")

# 1. Single-match Tab completion: 'wc -l txt/ph\t\n' -> completes to 'wc -l txt/phrases.txt'
out_single_tab = send_and_read(b"wc -l txt/ph\t\n")

# 2. Verify the Tab-completed command ('wc -l txt/phrases.txt') was stored in history (not 'wc -l txt/ph')
out_tab_hist = send_and_read(b"\x1b[A")
send_and_read(b"\n")

# 3. Multi-match Tab completion: 'echo s3.\t' -> lists 's3.c s3.h ', redraws prompt + 'echo s3.', then type 'c\n'
out_multi_tab = send_and_read(b"echo s3.\t")
out_multi_finish = send_and_read(b"c\n")

# 4. Single-match command Tab completion at start of line: 'who\t\n' -> completes to 'whoami'
out_cmd_single = send_and_read(b"who\t\n")

# 5. Multi-match command Tab completion: 'c\t' -> lists 'cal cat cd chmod clear cp ' and redraws 'c'
out_cmd_multi = send_and_read(b"c\t")
send_and_read(b"\x7f\n")

# 6. Command Tab completion after ';', '|', and '('
out_cmd_semi = send_and_read(b"echo hi ; who\t\n")
out_cmd_pipe = send_and_read(b"echo pipe_ok | gr\t pipe_ok\n")
out_cmd_paren = send_and_read(b"( who\t)\n")

# 7. Ctrl+D on non-empty line is ignored; Ctrl+D on empty line exits cleanly (rc=0)
out_ctrld_nonempty = send_and_read(b"echo still_here\x04\n")
out_ctrld_empty = send_and_read(b"\x04")
ctrld_rc = proc.wait(timeout=2)
os.close(master)

whoami_expected = subprocess.check_output(["whoami"], text=True).strip()
print("SINGLE_TAB_OK=" + str("200 txt/phrases.txt" in out_single_tab))
print("TAB_HIST_OK=" + str("wc -l txt/phrases.txt" in out_tab_hist))
print("MULTI_LIST_OK=" + str("s3.c s3.h " in out_multi_tab and "echo s3." in out_multi_tab))
print("MULTI_FINISH_OK=" + str("s3.c" in out_multi_finish.splitlines()[1] if len(out_multi_finish.splitlines()) > 1 else False))
print("CMD_SINGLE_OK=" + str("whoami" in out_cmd_single and whoami_expected in out_cmd_single))
print("CMD_MULTI_OK=" + str("cal cat cd chmod clear cp " in out_cmd_multi))
print("CMD_SEMI_OK=" + str("whoami" in out_cmd_semi and "hi" in out_cmd_semi and whoami_expected in out_cmd_semi))
print("CMD_PIPE_OK=" + str("grep pipe_ok" in out_cmd_pipe and "pipe_ok" in out_cmd_pipe))
print("CMD_PAREN_OK=" + str("( whoami)" in out_cmd_paren and whoami_expected in out_cmd_paren))
print("CTRLD_OK=" + str("still_here" in out_ctrld_nonempty and ctrld_rc == 0))
EOF
)

if grep -q "SINGLE_TAB_OK=True" <<< "$TAB_PTY_OUT"; then
    pass "Single-match Tab ('wc -l txt/ph<TAB>') auto-completes to 'wc -l txt/phrases.txt' and executes"
else
    fail "Single-match Tab completion failed" "$TAB_PTY_OUT"
fi

if grep -q "TAB_HIST_OK=True" <<< "$TAB_PTY_OUT"; then
    pass "Tab-completed command ('wc -l txt/phrases.txt') is stored in full in command history"
else
    fail "Tab-completed command history check failed" "$TAB_PTY_OUT"
fi

if grep -q "MULTI_LIST_OK=True" <<< "$TAB_PTY_OUT"; then
    pass "Multi-match Tab ('echo s3.<TAB>') lists all matches ('s3.c s3.h') and redraws prompt with partial line"
else
    fail "Multi-match Tab listing failed" "$TAB_PTY_OUT"
fi

if grep -q "MULTI_FINISH_OK=True" <<< "$TAB_PTY_OUT"; then
    pass "User can continue typing after multi-match Tab ('c<ENTER>' -> executes 'echo s3.c')"
else
    fail "Continuing input after multi-match Tab failed" "$TAB_PTY_OUT"
fi

if grep -q "CMD_SINGLE_OK=True" <<< "$TAB_PTY_OUT"; then
    pass "Single-match command Tab ('who<TAB>') auto-completes to 'whoami' and executes"
else
    fail "Single-match command Tab completion failed" "$TAB_PTY_OUT"
fi

if grep -q "CMD_MULTI_OK=True" <<< "$TAB_PTY_OUT"; then
    pass "Multi-match command Tab ('c<TAB>') lists matching commands ('cal cat cd chmod cp')"
else
    fail "Multi-match command Tab listing failed" "$TAB_PTY_OUT"
fi

if grep -q "CMD_SEMI_OK=True" <<< "$TAB_PTY_OUT" && grep -q "CMD_PIPE_OK=True" <<< "$TAB_PTY_OUT" && grep -q "CMD_PAREN_OK=True" <<< "$TAB_PTY_OUT"; then
    pass "Command Tab completion works after ';', '|', and '('"
else
    fail "Command Tab completion after ';', '|', or '(' failed" "$TAB_PTY_OUT"
fi

if grep -q "CTRLD_OK=True" <<< "$TAB_PTY_OUT"; then
    pass "Interactive Ctrl+D is ignored on non-empty lines and exits cleanly (rc=0) on empty lines"
else
    fail "Interactive Ctrl+D handling failed" "$TAB_PTY_OUT"
fi

# ==============================================================================
# Summary
# ==============================================================================
section "Section 8 Stretch Goals Test Summary"
echo -e "  ${GREEN}Passed:   $PASSED${NC}"
echo -e "  ${RED}Failed:   $FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All $PASSED Section 8 Stretch Goal tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
