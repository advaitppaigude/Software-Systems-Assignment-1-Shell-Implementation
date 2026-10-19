#!/usr/bin/env bash
# ==============================================================================
# Automated Test Suite for Sprint 0 & Section 1 (Basic Commands)
# ==============================================================================

set -u

# Colours for output
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

# Helper to run commands in s3 (from inside src/) and capture stdout/stderr
# Strips the "[s3]$ " prompts and optional debug PID lines for content comparison
run_s3_raw() {
    local input="$1"
    (cd "$SRC_DIR" && printf "%b\n" "$input" | timeout 5s ./s3)
}

strip_s3_noise() {
    sed -E 's/\[([^]]* )?s3\]\$ //g' | grep -v -E '^(Parent|Child) \(pid: [0-9]+\)$' || true
}

# ==============================================================================
# 1. SPRINT 0: Setup & Compilation Checks
# ==============================================================================
section "1. Sprint 0 — Setup & Compilation"

if [[ -f "$SRC_DIR/s3main.c" && -f "$SRC_DIR/s3.h" && -f "$SRC_DIR/s3.c" ]]; then
    pass "Starter files exist (src/s3main.c, src/s3.h, src/s3.c)"
else
    fail "Missing one or more source files in src/"
fi

COMPILE_OUT=$(cd "$SRC_DIR" && gcc -Wall -Wextra -g s3main.c s3.c -o s3 2>&1)
COMPILE_RC=$?

if [[ $COMPILE_RC -eq 0 && -x "$SRC_DIR/s3" ]]; then
    pass "Compiles successfully with 'gcc -Wall -Wextra -g *.c -o s3'"
else
    fail "Compilation failed" "$COMPILE_OUT"
    exit 1
fi

if [[ -n "$COMPILE_OUT" ]]; then
    warn "Compiler produced warnings with -Wall -Wextra:" "$(echo "$COMPILE_OUT" | tr '\n' ' ')"
else
    pass "Zero compiler warnings with -Wall -Wextra"
fi

# ==============================================================================
# 2. SECTION 1: Built-in 'exit' & Empty Line Handling
# ==============================================================================
section "2. Section 1 — Built-in 'exit' & Empty Inputs"

# Test exit terminates shell cleanly
OUT_EXIT=$(run_s3_raw "exit\necho SHOULD_NOT_RUN")
RC_EXIT=$?
if [[ $RC_EXIT -eq 0 ]] && ! grep -q "SHOULD_NOT_RUN" <<<"$OUT_EXIT"; then
    pass "Built-in 'exit' terminates the parent shell immediately (exit code 0)"
else
    fail "Built-in 'exit' did not terminate cleanly (rc=$RC_EXIT)" "$OUT_EXIT"
fi

# Test empty lines and whitespace-only lines
OUT_EMPTY=$(run_s3_raw "\n   \n\necho AFTER_EMPTY\nexit" | strip_s3_noise)
if [[ "$OUT_EMPTY" == "AFTER_EMPTY" ]]; then
    pass "Empty lines and whitespace-only lines are ignored without crashing"
else
    fail "Empty line handling failed" "Got: '$OUT_EMPTY'"
fi

# Check if debug PID prints are present
RAW_CHECK=$(run_s3_raw "echo hello\nexit")
if grep -q -E '(Parent|Child) \(pid: [0-9]+\)' <<<"$RAW_CHECK"; then
    warn "Debug PID prints detected in launch_program()" "Found 'Parent (pid: ...)' / 'Child (pid: ...)' in stdout. Consider removing before Section 2/4."
else
    pass "No stray debug PID prints in stdout"
fi

# ==============================================================================
# 3. SECTION 1: Basic System Commands
# ==============================================================================
section "3. Section 1 — Basic Commands (whoami, pwd, ls, cal)"

 compare_cmd() {
    local label="$1"
    local cmd="$2"
    local expected actual

    expected=$(cd "$SRC_DIR" && eval "$cmd")
    actual=$(run_s3_raw "$cmd\nexit" | strip_s3_noise)

    if [[ "$actual" == "$expected" ]]; then
        pass "$label ($cmd)"
    else
        fail "$label ($cmd)" "Output mismatch against bash"
    fi
}

compare_cmd "whoami" "whoami"
compare_cmd "pwd" "pwd"
compare_cmd "ls" "ls"
compare_cmd "ls -R" "ls -R"

if command -v cal >/dev/null 2>&1; then
    compare_cmd "cal" "cal"
    compare_cmd "cal -y" "cal -y"
else
    warn "'cal' utility is not installed on this system (skipping cal test)"
fi

# ==============================================================================
# 4. SECTION 1: Text Processing Commands on txt/phrases.txt
# ==============================================================================
section "4. Section 1 — Text Processing & Grep (txt/phrases.txt)"

compare_cmd "cat txt/phrases.txt" "cat txt/phrases.txt"
compare_cmd "uniq txt/phrases.txt" "uniq txt/phrases.txt"
compare_cmd "wc txt/phrases.txt" "wc txt/phrases.txt"
compare_cmd "sort txt/phrases.txt" "sort txt/phrases.txt"
compare_cmd "grep burn txt/phrases.txt" "grep burn txt/phrases.txt"
compare_cmd "grep -n burn txt/phrases.txt" "grep -n burn txt/phrases.txt"

# ==============================================================================
# 5. SECTION 1: File Manipulation Commands (touch, cp, chmod, ls -l)
# ==============================================================================
section "5. Section 1 — File Operations (touch, cp, chmod, ls -l)"

TEST_FILE1="$TEST_TMP/test_file.txt"
TEST_FILE2="$TEST_TMP/test_copy.txt"

run_s3_raw "touch $TEST_FILE1\ncp $TEST_FILE1 $TEST_FILE2\nchmod 755 $TEST_FILE2\nexit" >/dev/null

if [[ -f "$TEST_FILE1" && -f "$TEST_FILE2" ]]; then
    pass "'touch' and 'cp' created files successfully"
else
    fail "'touch' and/or 'cp' failed to create test files"
fi

PERMS=$(stat -c "%a" "$TEST_FILE2" 2>/dev/null || true)
if [[ "$PERMS" == "755" ]]; then
    pass "'chmod 755' updated file permissions properly"
else
    fail "'chmod 755' failed (got permissions: $PERMS)"
fi

LS_L_OUT=$(run_s3_raw "ls -l $TEST_FILE2\nexit" | strip_s3_noise)
if [[ "$LS_L_OUT" == *"-rwxr-xr-x"* ]]; then
    pass "'ls -l' displays expected permissions and file info"
else
    fail "'ls -l' output unexpected" "Got: $LS_L_OUT"
fi

# ==============================================================================
# 6. SECTION 1: Error Handling & Process Lifecycle Verification
# ==============================================================================
section "6. Section 1 — Error Handling & Child Reaping"

# Test invalid command: child must exit (_exit) and parent must continue to next command
ERR_OUT=$( (cd "$SRC_DIR" && printf "nonexistent_cmd_12345\necho SURVIVED\nexit\n" | timeout 5s ./s3) 2>&1 )
CLEAN_ERR_STDOUT=$(echo "$ERR_OUT" | strip_s3_noise)

if grep -q "SURVIVED" <<<"$CLEAN_ERR_STDOUT" && grep -q "execvp" <<<"$ERR_OUT"; then
    # Count how many times SURVIVED was printed (if child didn't exit, 2 shells would run!)
    SURVIVED_COUNT=$(grep -c "SURVIVED" <<<"$CLEAN_ERR_STDOUT")
    if [[ "$SURVIVED_COUNT" -eq 1 ]]; then
        pass "Invalid command reports error via perror('execvp'), child exits, parent continues cleanly"
    else
        fail "Child process did not exit after failed execvp (SURVIVED printed $SURVIVED_COUNT times)"
    fi
else
    fail "Invalid command error handling failed" "$ERR_OUT"
fi

# Sequential commands test (verifies wait/reap works across multiple commands in a session)
SEQ_OUT=$(run_s3_raw "echo first\necho second\necho third\nexit" | strip_s3_noise)
EXPECTED_SEQ=$'first\nsecond\nthird'
if [[ "$SEQ_OUT" == "$EXPECTED_SEQ" ]]; then
    pass "Multiple sequential commands execute and reap in deterministic order"
else
    fail "Sequential command execution order mismatch" "Got: $SEQ_OUT"
fi

# ==============================================================================
# Summary
# ==============================================================================
section "Test Summary"
echo -e "  ${GREEN}Passed:   $PASSED${NC}"
echo -e "  ${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "  ${RED}Failed:   $FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All Sprint 0 & Section 1 functional tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
