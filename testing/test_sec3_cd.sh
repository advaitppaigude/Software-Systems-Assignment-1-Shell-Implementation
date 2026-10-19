#!/usr/bin/env bash
# ==============================================================================
# Automated Test Suite for Section 3 (cd Built-in & Dynamic Shell Prompt)
# ==============================================================================

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
trap 'rm -f "$SRC_DIR/s3"' EXIT

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

run_s3_raw() {
    local input="$1"
    (cd "$SRC_DIR" && printf "%b\n" "$input" | timeout 5s ./s3)
}

strip_prompts() {
    sed -E 's/\[[^]]* s3\]\$ //g'
}

# ==============================================================================
# 1. Compilation
# ==============================================================================
section "1. Section 3 — Compilation"

COMPILE_OUT=$(cd "$SRC_DIR" && gcc -Wall -Wextra -g s3main.c s3.c -o s3 2>&1)
COMPILE_RC=$?

if [[ $COMPILE_RC -eq 0 && -x "$SRC_DIR/s3" ]]; then
    pass "Compiles cleanly with 'gcc -Wall -Wextra -g *.c -o s3'"
else
    fail "Compilation failed" "$COMPILE_OUT"
    exit 1
fi

# ==============================================================================
# 2. Dynamic Shell Prompt Verification
# ==============================================================================
section "2. Section 3 — Dynamic Shell Prompt (construct_shell_prompt)"

PROMPT_OUT=$(run_s3_raw "cd txt\nexit")
if [[ "$PROMPT_OUT" == *"[$SRC_DIR s3]$ "* && "$PROMPT_OUT" == *"[$SRC_DIR/txt s3]$ "* ]]; then
    pass "Prompt displays initial cwd ([$SRC_DIR s3]$ ) and updates after 'cd txt' ([$SRC_DIR/txt s3]$ )"
else
    fail "Prompt did not display or update cwd as expected" "Got: $PROMPT_OUT"
fi

# ==============================================================================
# 3. Relative & Special Directory Navigation (cd txt, cd ., cd ..)
# ==============================================================================
section "3. Section 3 — Relative & Special Paths (cd txt, cd ., cd ..)"

# Test 1: cd txt and ls
OUT_TXT=$(run_s3_raw "cd txt\npwd\nls\nexit" | strip_prompts)
EXPECTED_TXT="$SRC_DIR/txt"$'\n'"phrases.txt"
if [[ "$OUT_TXT" == "$EXPECTED_TXT" ]]; then
    pass "'cd txt' changes into txt/ and 'ls' lists phrases.txt"
else
    fail "'cd txt' test failed" "Expected:\n$EXPECTED_TXT\nGot:\n$OUT_TXT"
fi

# Test 2: cd .
OUT_DOT=$(run_s3_raw "cd txt\ncd .\npwd\nexit" | strip_prompts)
if [[ "$OUT_DOT" == "$SRC_DIR/txt" ]]; then
    pass "'cd .' stays in current directory ($SRC_DIR/txt)"
else
    fail "'cd .' failed" "Got: $OUT_DOT"
fi

# Test 3: cd ..
OUT_DOTDOT=$(run_s3_raw "cd txt\ncd ..\npwd\nexit" | strip_prompts)
if [[ "$OUT_DOTDOT" == "$SRC_DIR" ]]; then
    pass "'cd ..' moves up to parent directory ($SRC_DIR)"
else
    fail "'cd ..' failed" "Got: $OUT_DOTDOT"
fi

# Test 4: Leading spaces before cd
OUT_LEADING=$(run_s3_raw "   cd txt\npwd\nexit" | strip_prompts)
if [[ "$OUT_LEADING" == "$SRC_DIR/txt" ]]; then
    pass "'   cd txt' (with leading spaces) is detected and executed properly"
else
    fail "Leading spaces before 'cd' failed" "Got: $OUT_LEADING"
fi

# ==============================================================================
# 4. Absolute Paths & Home Directory (cd /tmp, cd)
# ==============================================================================
section "4. Section 3 — Absolute Paths & Home Directory (cd /tmp, cd)"

# Test 5: cd /tmp
OUT_TMP=$(run_s3_raw "cd /tmp\npwd\nexit" | strip_prompts)
if [[ "$OUT_TMP" == "/tmp" ]]; then
    pass "'cd /tmp' moves to /tmp"
else
    fail "'cd /tmp' failed" "Got: $OUT_TMP"
fi

# Test 6: cd (no arguments -> HOME)
OUT_HOME=$(run_s3_raw "cd\npwd\nexit" | strip_prompts)
if [[ "$OUT_HOME" == "$HOME" ]]; then
    pass "'cd' (no arguments) moves to HOME ($HOME)"
else
    fail "'cd' (no arguments) failed" "Expected: $HOME, Got: $OUT_HOME"
fi

# ==============================================================================
# 5. Previous Directory Toggling (cd -) & init_lwd
# ==============================================================================
section "5. Section 3 — Previous Directory (cd -) & init_lwd"

# Test 7: cd - right at startup (uses init_lwd)
OUT_INIT_LWD=$(run_s3_raw "cd -\npwd\nexit" | strip_prompts)
if [[ "$OUT_INIT_LWD" == "$SRC_DIR" ]]; then
    pass "'cd -' immediately at startup uses init_lwd ($SRC_DIR)"
else
    fail "'cd -' at startup failed" "Got: $OUT_INIT_LWD"
fi

# Test 8: Toggling back and forth with cd -
OUT_TOGGLE=$(run_s3_raw "cd txt\npwd\ncd -\npwd\ncd -\npwd\nexit" | strip_prompts)
EXPECTED_TOGGLE="$SRC_DIR/txt"$'\n'"$SRC_DIR"$'\n'"$SRC_DIR/txt"
if [[ "$OUT_TOGGLE" == "$EXPECTED_TOGGLE" ]]; then
    pass "'cd -' toggles back and forth between previous and current directories"
else
    fail "'cd -' toggling failed" "Expected:\n$EXPECTED_TOGGLE\nGot:\n$OUT_TOGGLE"
fi

# ==============================================================================
# 6. Error Handling & Edge Cases
# ==============================================================================
section "6. Section 3 — Error Handling & Edge Cases"

# Test 9: Invalid directory does not crash shell or overwrite lwd
ERR_OUT=$( (cd "$SRC_DIR" && printf "cd txt\ncd nonexistent_dir_xyz\npwd\ncd -\npwd\nexit\n" | timeout 5s ./s3) 2>&1 )
CLEAN_ERR_STDOUT=$(echo "$ERR_OUT" | strip_prompts | grep -v "cd failed" || true)
EXPECTED_ERR_DIRS="$SRC_DIR/txt"$'\n'"$SRC_DIR"

if grep -q "cd failed" <<<"$ERR_OUT" && [[ "$CLEAN_ERR_STDOUT" == "$EXPECTED_ERR_DIRS" ]]; then
    pass "Invalid 'cd nonexistent_dir_xyz' prints error via perror, stays in cwd, and preserves lwd"
else
    fail "Invalid directory error handling failed" "Output:\n$ERR_OUT"
fi

# ==============================================================================
# Summary
# ==============================================================================
section "Test Summary"
echo -e "  ${GREEN}Passed: $PASSED${NC}"
echo -e "  ${RED}Failed: $FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All Section 3 (cd & Dynamic Prompt) tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
