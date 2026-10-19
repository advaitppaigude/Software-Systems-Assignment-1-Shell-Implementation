#!/usr/bin/env bash
# ==============================================================================
# Comprehensive Combined Test Suite for Sections 0, 1, 2, 3, and 4
# ==============================================================================

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP" "$SRC_DIR/s3"' EXIT

PASSED=0
FAILED=0
WARNINGS=0

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

warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "         ${YELLOW}-> $2${NC}"
    fi
    ((WARNINGS++))
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

compare_cmd() {
    local label="$1"
    local cmd="$2"
    local expected actual

    expected=$(cd "$SRC_DIR" && bash -c "$cmd")
    actual=$(run_s3_raw "$cmd\nexit" | strip_prompts)

    if [[ "$actual" == "$expected" ]]; then
        pass "$label ($cmd)"
    else
        fail "$label ($cmd)" "Expected: '$(echo "$expected" | head -n 2)' | Got: '$(echo "$actual" | head -n 2)'"
    fi
}

# ==============================================================================
# PART 0: Compilation & Setup
# ==============================================================================
section "0. Sprint 0 — Setup & Compilation"

if [[ -f "$SRC_DIR/s3main.c" && -f "$SRC_DIR/s3.h" && -f "$SRC_DIR/s3.c" ]]; then
    pass "Core source files exist (src/s3main.c, src/s3.h, src/s3.c)"
else
    fail "Missing core source files in src/"
    exit 1
fi

COMPILE_OUT=$(cd "$SRC_DIR" && gcc -Wall -Wextra -g s3main.c s3.c -o s3 2>&1)
COMPILE_RC=$?

if [[ $COMPILE_RC -eq 0 && -x "$SRC_DIR/s3" ]]; then
    pass "Compiles cleanly with 'gcc -Wall -Wextra -g s3main.c s3.c -o s3'"
else
    fail "Compilation failed" "$COMPILE_OUT"
    exit 1
fi

# ==============================================================================
# PART 1: Section 1 — Basic Commands, Built-in 'exit', Empty Lines, Errors
# ==============================================================================
section "1. Section 1 — Basic Commands & Process Lifecycle"

# Built-in exit
OUT_EXIT=$(run_s3_raw "exit\necho SHOULD_NOT_RUN")
RC_EXIT=$?
if [[ $RC_EXIT -eq 0 ]] && ! grep -q "SHOULD_NOT_RUN" <<<"$OUT_EXIT"; then
    pass "Built-in 'exit' terminates parent shell immediately (rc=0)"
else
    fail "Built-in 'exit' failed" "$OUT_EXIT"
fi

# Empty & whitespace lines
OUT_EMPTY=$(run_s3_raw "\n   \n\necho AFTER_EMPTY\nexit" | strip_prompts)
if [[ "$OUT_EMPTY" == "AFTER_EMPTY" ]]; then
    pass "Empty and whitespace-only lines handled cleanly"
else
    fail "Empty line handling failed" "Got: '$OUT_EMPTY'"
fi

# System & text commands
compare_cmd "whoami" "whoami"
compare_cmd "pwd" "pwd"
compare_cmd "ls" "ls"
compare_cmd "ls -R" "ls -R"
if command -v cal >/dev/null 2>&1; then
    compare_cmd "cal" "cal"
    compare_cmd "cal -y" "cal -y"
fi
compare_cmd "cat txt/phrases.txt" "cat txt/phrases.txt"
compare_cmd "uniq txt/phrases.txt" "uniq txt/phrases.txt"
compare_cmd "wc txt/phrases.txt" "wc txt/phrases.txt"
compare_cmd "sort txt/phrases.txt" "sort txt/phrases.txt"
compare_cmd "grep burn txt/phrases.txt" "grep burn txt/phrases.txt"
compare_cmd "grep -n burn txt/phrases.txt" "grep -n burn txt/phrases.txt"

# File manipulation
FILE_A="$TEST_TMP/file_a.txt"
FILE_B="$TEST_TMP/file_b.txt"
run_s3_raw "touch $FILE_A\ncp $FILE_A $FILE_B\nchmod 755 $FILE_B\nexit" >/dev/null
if [[ -f "$FILE_A" && -f "$FILE_B" && "$(stat -c '%a' "$FILE_B")" == "755" ]]; then
    pass "File operations ('touch', 'cp', 'chmod 755') succeeded"
else
    fail "File operations ('touch', 'cp', 'chmod 755') failed"
fi

# Invalid command handling
ERR_CMD_OUT=$( (run_s3_raw "nonexistent_cmd_999\necho SURVIVED\nexit") 2>&1 )
CLEAN_ERR_CMD=$(echo "$ERR_CMD_OUT" | strip_prompts)
if grep -q "execvp" <<<"$ERR_CMD_OUT" && [[ "$(grep -c "SURVIVED" <<<"$CLEAN_ERR_CMD")" -eq 1 ]]; then
    pass "Invalid command reports perror('execvp'), child exits, parent continues"
else
    fail "Invalid command error handling failed" "$ERR_CMD_OUT"
fi

# ==============================================================================
# PART 2: Section 2 — Commands with Redirection (<, >, >>)
# ==============================================================================
section "2. Section 2 — Input & Output Redirection (<, >, >>)"

mkdir -p "$TEST_TMP/student" "$TEST_TMP/ref"
cp -a "$SRC_DIR/txt" "$TEST_TMP/student/txt"
cp -a "$SRC_DIR/txt" "$TEST_TMP/ref/txt"

REDIR_CMDS=(
    'ls > txt/folder_contents.txt'
    'ls -R > txt/folder_contents.txt'
    'echo === Full-Year Calendar === > txt/calendar.txt'
    'cal -y >> txt/calendar.txt'
    'tac txt/phrases.txt > txt/phrases_reversed.txt'
    'sort txt/phrases.txt > txt/phrases_sorted.txt'
    'head -n 5 txt/phrases.txt >> txt/phrases_sorted.txt'
    'wc txt/phrases.txt > txt/phrases_stats.txt'
    'grep June < txt/calendar.txt'
    'tr a-z A-Z < txt/phrases.txt'
)

for cmd in "${REDIR_CMDS[@]}"; do
    STU_OUT=$(run_s3_in_dir "$TEST_TMP/student" "$cmd\nexit" | strip_prompts)
    REF_OUT=$(cd "$TEST_TMP/ref" && bash -c "$cmd")

    FILES_MATCH=1
    for f in folder_contents.txt calendar.txt phrases_reversed.txt phrases_sorted.txt phrases_stats.txt; do
        if [[ -e "$TEST_TMP/ref/txt/$f" || -e "$TEST_TMP/student/txt/$f" ]]; then
            if ! cmp -s "$TEST_TMP/ref/txt/$f" "$TEST_TMP/student/txt/$f"; then
                FILES_MATCH=0
            fi
        fi
    done

    if [[ "$STU_OUT" == "$REF_OUT" && $FILES_MATCH -eq 1 ]]; then
        pass "Redirection: $cmd"
    else
        fail "Redirection: $cmd" "Output or generated file mismatch"
    fi
done

# Redirection syntax error handling tests
REDIR_ERR1=$( (run_s3_in_dir "$TEST_TMP/student" "echo hello >\necho OK1\nexit") 2>&1 )
if grep -q "missing redirection filename" <<<"$REDIR_ERR1" && grep -q "OK1" <<<"$REDIR_ERR1"; then
    pass "Malformed redirection ('echo hello >') rejected cleanly without crashing"
else
    fail "Malformed redirection ('echo hello >') check failed" "$REDIR_ERR1"
fi

REDIR_ERR2=$( (run_s3_in_dir "$TEST_TMP/student" "echo hello > <\necho OK2\nexit") 2>&1 )
if grep -q "cannot provide redirection operator as filename" <<<"$REDIR_ERR2" && grep -q "OK2" <<<"$REDIR_ERR2"; then
    pass "Malformed redirection ('echo hello > <') rejected cleanly"
else
    fail "Malformed redirection ('echo hello > <') check failed" "$REDIR_ERR2"
fi

REDIR_ERR3=$( (run_s3_in_dir "$TEST_TMP/student" "echo hello > a.txt > b.txt\necho OK3\nexit") 2>&1 )
if grep -q "multiple redirection tokens" <<<"$REDIR_ERR3" && grep -q "OK3" <<<"$REDIR_ERR3"; then
    pass "Multiple redirection tokens ('> a.txt > b.txt') rejected cleanly"
else
    fail "Multiple redirection tokens check failed" "$REDIR_ERR3"
fi

# ==============================================================================
# PART 3: Section 3 — Built-in 'cd' & Dynamic Shell Prompt
# ==============================================================================
section "3. Section 3 — Built-in 'cd' & Dynamic Prompt"

PROMPT_CHECK=$(run_s3_raw "cd txt\nexit")
if [[ "$PROMPT_CHECK" == *"[$SRC_DIR s3]$ "* && "$PROMPT_CHECK" == *"[$SRC_DIR/txt s3]$ "* ]]; then
    pass "Dynamic prompt displays cwd and updates after 'cd txt'"
else
    fail "Dynamic prompt check failed" "Got: $PROMPT_CHECK"
fi

OUT_CD_TXT=$(run_s3_raw "cd txt\npwd\nls\nexit" | strip_prompts)
if [[ "$OUT_CD_TXT" == "$SRC_DIR/txt"$'\n'"phrases.txt" ]]; then
    pass "'cd txt' changes directory and 'ls' lists phrases.txt"
else
    fail "'cd txt' failed" "Got: $OUT_CD_TXT"
fi

OUT_CD_DOT=$(run_s3_raw "cd txt\ncd .\npwd\ncd ..\npwd\nexit" | strip_prompts)
if [[ "$OUT_CD_DOT" == "$SRC_DIR/txt"$'\n'"$SRC_DIR" ]]; then
    pass "'cd .' and 'cd ..' navigate current and parent directories properly"
else
    fail "'cd .' / 'cd ..' failed" "Got: $OUT_CD_DOT"
fi

OUT_CD_HOME=$(run_s3_raw "cd\npwd\nexit" | strip_prompts)
if [[ "$OUT_CD_HOME" == "$HOME" ]]; then
    pass "'cd' (with no arguments) changes to HOME ($HOME)"
else
    fail "'cd' (no arguments) failed" "Got: $OUT_CD_HOME"
fi

OUT_CD_TOGGLE=$(run_s3_raw "cd txt\npwd\ncd -\npwd\ncd -\npwd\nexit" | strip_prompts)
if [[ "$OUT_CD_TOGGLE" == "$SRC_DIR/txt"$'\n'"$SRC_DIR"$'\n'"$SRC_DIR/txt" ]]; then
    pass "'cd -' toggles back and forth between previous and current directories"
else
    fail "'cd -' toggling failed" "Got: $OUT_CD_TOGGLE"
fi

CD_ERR_OUT=$( (run_s3_raw "cd txt\ncd bad_folder_xyz\npwd\ncd -\npwd\nexit") 2>&1 )
CLEAN_CD_ERR=$(echo "$CD_ERR_OUT" | strip_prompts | grep -v "cd failed" || true)
if grep -q "cd failed" <<<"$CD_ERR_OUT" && [[ "$CLEAN_CD_ERR" == "$SRC_DIR/txt"$'\n'"$SRC_DIR" ]]; then
    pass "Invalid 'cd bad_folder_xyz' reports error, stays in cwd, and preserves lwd"
else
    fail "Invalid 'cd' error handling failed" "$CD_ERR_OUT"
fi

# ==============================================================================
# PART 4: Section 5 — Batched Commands (;)
# ==============================================================================
section "4. Section 5 — Batched Commands (;)"

# Test 1: Multiple sequential basic commands in a batch
OUT_BATCH_BASIC=$(run_s3_raw "echo alpha ; echo beta ; echo gamma\nexit" | strip_prompts)
if [[ "$OUT_BATCH_BASIC" == $'alpha\nbeta\ngamma' ]]; then
    pass "Sequential batched basic commands ('echo alpha ; echo beta ; echo gamma')"
else
    fail "Sequential batched basic commands failed" "Got: $OUT_BATCH_BASIC"
fi

# Test 2: TASKS.md test — Batch containing 'cd' followed by a command in the new directory ('cd txt ; ls ; cd -')
OUT_BATCH_CD=$(run_s3_raw "cd txt ; ls ; cd - ; pwd\nexit" | strip_prompts)
EXPECTED_BATCH_CD="phrases.txt"$'\n'"$SRC_DIR"
if [[ "$OUT_BATCH_CD" == "$EXPECTED_BATCH_CD" ]]; then
    pass "Batched 'cd' & commands ('cd txt ; ls ; cd - ; pwd')"
else
    fail "Batched 'cd' & commands failed" "Expected:\n$EXPECTED_BATCH_CD\nGot:\n$OUT_BATCH_CD"
fi

# Test 3: TASKS.md test — Batch with mkdir, file processing/redirection, and echo
OUT_BATCH_REDIR=$(run_s3_in_dir "$TEST_TMP/student" "mkdir results ; sort txt/phrases.txt > results/rev_sort_phr.txt ; echo Processing complete.\nexit" | strip_prompts)
if [[ "$OUT_BATCH_REDIR" == "Processing complete." && -f "$TEST_TMP/student/results/rev_sort_phr.txt" ]] && cmp -s <(sort "$SRC_DIR/txt/phrases.txt") "$TEST_TMP/student/results/rev_sort_phr.txt"; then
    pass "Batched mkdir + redirection + echo ('mkdir results ; sort txt/phrases.txt > results/rev_sort_phr.txt ; echo Processing complete.')"
else
    fail "Batched mkdir + redirection + echo failed" "Got: '$OUT_BATCH_REDIR'"
fi

# Test 4: TASKS.md requirement — Next command in batch executes even if previous command fails
OUT_BATCH_FAIL=$( (run_s3_raw "nonexistent_batch_cmd_123 ; echo BATCH_CONTINUED ; cd bad_dir_123 ; echo AFTER_BAD_CD\nexit") 2>&1 | strip_prompts )
if grep -q "BATCH_CONTINUED" <<<"$OUT_BATCH_FAIL" && grep -q "AFTER_BAD_CD" <<<"$OUT_BATCH_FAIL"; then
    pass "Batch continues executing subsequent commands even when a command or 'cd' fails"
else
    fail "Batch stopped or failed after an erroring command" "Got: $OUT_BATCH_FAIL"
fi

# Test 5: TASKS.md requirement — Parenthesis-aware splitting (ignores ';' inside '(...)')
cat << 'EOF' > "$TEST_TMP/batch_paren_test.c"
#include "s3.h"
#include <string.h>

int main(void) {
    char line[MAX_LINE] = "echo start ; (cd /var/log ; cat syslog) ; date";
    char *batch_cmds[MAX_ARGS];
    int batch_count = 0;

    parse_batched_commands(line, batch_cmds, &batch_count);
    if (batch_count != 3) return 1;
    if (strcmp(batch_cmds[0], "echo start ") != 0) return 2;
    if (strcmp(batch_cmds[1], " (cd /var/log ; cat syslog) ") != 0) return 3;
    if (strcmp(batch_cmds[2], " date") != 0) return 4;
    return 0;
}
EOF

if gcc -Wall -Wextra -I"$SRC_DIR" "$TEST_TMP/batch_paren_test.c" "$SRC_DIR/s3.c" -o "$TEST_TMP/batch_paren_test" 2>/dev/null && "$TEST_TMP/batch_paren_test"; then
    pass "Parenthesis-aware splitting: ';' inside '(...)' is not split prematurely"
else
    fail "Parenthesis-aware splitting check failed"
fi

# ==============================================================================
# PART 5: Sections 6 & 7 — Subshells & Nested Subshells ((...))
# ==============================================================================
section "5. Sections 6 & 7 — Subshells & Nested Subshells ((...))"

# Test 1: Standalone subshell environment isolation (cd inside subshell does NOT change parent cwd)
OUT_SUB_ISO=$(run_s3_raw "(cd txt ; pwd ; ls)\npwd\nexit" | strip_prompts)
EXPECTED_SUB_ISO="$SRC_DIR/txt"$'\n'"phrases.txt"$'\n'"$SRC_DIR"
if [[ "$OUT_SUB_ISO" == "$EXPECTED_SUB_ISO" ]]; then
    pass "Subshell environment isolation: '(cd txt ; pwd ; ls)' does not change parent shell's cwd ($SRC_DIR)"
else
    fail "Subshell environment isolation failed" "Expected:\n$EXPECTED_SUB_ISO\nGot:\n$OUT_SUB_ISO"
fi

# Test 2: Subshell inside a batched command (Section 6 spec example)
OUT_SUB_BATCH=$(run_s3_in_dir "$TEST_TMP/student" "echo Start processing... ; (cd txt ; sort phrases.txt > sorted_phrases.txt) ; echo Finished writing sorted file. ; pwd\nexit" | strip_prompts)
EXPECTED_SUB_BATCH=$'Start processing...\nFinished writing sorted file.\n'"$TEST_TMP/student"
if [[ "$OUT_SUB_BATCH" == "$EXPECTED_SUB_BATCH" && -f "$TEST_TMP/student/txt/sorted_phrases.txt" ]] && cmp -s <(sort "$SRC_DIR/txt/phrases.txt") "$TEST_TMP/student/txt/sorted_phrases.txt"; then
    pass "Subshell inside a batch ('echo Start... ; (cd txt ; sort phrases.txt > sorted_phrases.txt) ; echo Finished... ; pwd')"
else
    fail "Subshell inside a batch failed" "Expected:\n$EXPECTED_SUB_BATCH\nGot:\n$OUT_SUB_BATCH"
fi

# Test 3: Multiple subshells in the same batch
OUT_MULTI_SUB=$(run_s3_raw "(cd txt ; pwd) ; (cd /tmp ; pwd) ; pwd\nexit" | strip_prompts)
EXPECTED_MULTI_SUB="$SRC_DIR/txt"$'\n'"/tmp"$'\n'"$SRC_DIR"
if [[ "$OUT_MULTI_SUB" == "$EXPECTED_MULTI_SUB" ]]; then
    pass "Multiple subshells on the same line ('(cd txt ; pwd) ; (cd /tmp ; pwd) ; pwd')"
else
    fail "Multiple subshells on the same line failed" "Expected:\n$EXPECTED_MULTI_SUB\nGot:\n$OUT_MULTI_SUB"
fi

# Test 4: Section 7 — Nested subshells (2 levels of nesting)
OUT_NESTED_2=$(run_s3_raw "(cd txt ; (pwd ; ls) ; pwd) ; pwd\nexit" | strip_prompts)
EXPECTED_NESTED_2="$SRC_DIR/txt"$'\n'"phrases.txt"$'\n'"$SRC_DIR/txt"$'\n'"$SRC_DIR"
if [[ "$OUT_NESTED_2" == "$EXPECTED_NESTED_2" ]]; then
    pass "Section 7 Nested subshells (2 levels): '(cd txt ; (pwd ; ls) ; pwd) ; pwd'"
else
    fail "Section 7 Nested subshells (2 levels) failed" "Expected:\n$EXPECTED_NESTED_2\nGot:\n$OUT_NESTED_2"
fi

# Test 5: Section 7 — Deeply nested subshells (3+ levels with isolated cd at each level)
OUT_NESTED_DEEP=$(run_s3_raw "(((echo deep_inner))) ; (cd txt ; (cd /tmp ; (pwd)) ; pwd) ; pwd\nexit" | strip_prompts)
EXPECTED_NESTED_DEEP=$'deep_inner\n/tmp\n'"$SRC_DIR/txt"$'\n'"$SRC_DIR"
if [[ "$OUT_NESTED_DEEP" == "$EXPECTED_NESTED_DEEP" ]]; then
    pass "Section 7 Deeply nested subshells (3 levels): '(((echo deep_inner))) ; (cd txt ; (cd /tmp ; (pwd)) ; pwd) ; pwd'"
else
    fail "Section 7 Deeply nested subshells (3 levels) failed" "Expected:\n$EXPECTED_NESTED_DEEP\nGot:\n$OUT_NESTED_DEEP"
fi

# ==============================================================================
# Summary
# ==============================================================================
section "Overall Test Summary (Sections 0, 1, 2, 3, 5, 6, and 7)"
echo -e "  ${GREEN}Passed:   $PASSED${NC}"
echo -e "  ${RED}Failed:   $FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All Sections 0, 1, 2, 3, 5, 6, and 7 tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
