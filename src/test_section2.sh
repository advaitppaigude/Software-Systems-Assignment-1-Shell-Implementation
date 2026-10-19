#!/usr/bin/env bash
# Section 2 regression check: compare the student shell with Bash.
# Usage: bash test_section2.sh [path/to/s3] [path/to/txt]
set -u

shell_bin="${1:-./s3}"
fixtures="${2:-./txt}"
shell_bin="$(realpath "$shell_bin")"
fixtures="$(realpath "$fixtures")"

if [[ ! -x "$shell_bin" ]]; then
  echo "ERROR: shell executable not found or not executable: $shell_bin" >&2
  exit 2
fi
if [[ ! -d "$fixtures" ]]; then
  echo "ERROR: fixture directory not found: $fixtures" >&2
  exit 2
fi
if [[ ! -f "$fixtures/phrases.txt" ]]; then
  echo "ERROR: expected $fixtures/phrases.txt" >&2
  exit 2
fi
for command in cal tac sort head wc grep tr ls echo; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ERROR: required command not installed: $command" >&2
    exit 2
  fi
done

tmp="$(mktemp -d)" || exit 2
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/student" "$tmp/reference"
cp -a "$fixtures" "$tmp/student/txt"
cp -a "$fixtures" "$tmp/reference/txt"

commands=(
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

# Run one command at a time but retain files between commands. Every invocation
# includes "exit" to avoid the starter shell's imperfect EOF handling.
student_stdout="$tmp/student_stdout"
reference_stdout="$tmp/reference_stdout"
: > "$student_stdout"
: > "$reference_stdout"

for i in "${!commands[@]}"; do
  cmd="${commands[$i]}"
  (
    cd "$tmp/student" || exit 2
    printf '%s\nexit\n' "$cmd" | "$shell_bin"
  ) > "$tmp/student_output" 2> "$tmp/student_error"
  student_rc=$?
  (
    cd "$tmp/reference" || exit 2
    bash -c "$cmd"
  ) > "$tmp/reference_output" 2> "$tmp/reference_error"
  reference_rc=$?

  # The starter shell prints the fixed prompt [s3]$ even for piped input.
  # Remove it only for comparing command stdout (not generated files).
  sed 's/\[s3\]\$ //g' "$tmp/student_output" > "$tmp/student_clean"
  stdout_ok=1
  diff -u "$tmp/reference_output" "$tmp/student_clean" > "$tmp/stdout_diff" || stdout_ok=0

  files_ok=1
  for file in folder_contents.txt calendar.txt phrases_reversed.txt phrases_sorted.txt phrases_stats.txt; do
    student_file="$tmp/student/txt/$file"
    reference_file="$tmp/reference/txt/$file"
    if [[ -e "$student_file" || -e "$reference_file" ]]; then
      if [[ ! -e "$student_file" || ! -e "$reference_file" ]] || ! cmp -s "$student_file" "$reference_file"; then
        files_ok=0
        printf '  File mismatch: txt/%s\n' "$file"
        if [[ -f "$student_file" && -f "$reference_file" ]]; then
          diff -u "$reference_file" "$student_file" | head -n 25 || true
        fi
      fi
    fi
  done

  if (( stdout_ok && files_ok && student_rc == 0 && reference_rc == 0 )); then
    printf 'PASS %2d: %s\n' "$((i+1))" "$cmd"
  else
    printf 'FAIL %2d: %s\n' "$((i+1))" "$cmd"
    if (( ! stdout_ok )); then
      echo '  Stdout difference:'
      head -n 25 "$tmp/stdout_diff"
    fi
    if [[ -s "$tmp/student_error" ]]; then
      echo '  Shell stderr:'
      sed 's/^/    /' "$tmp/student_error"
    fi
    if [[ -s "$tmp/reference_error" ]]; then
      echo '  Bash stderr:'
      sed 's/^/    /' "$tmp/reference_error"
    fi
    printf '  Exit status: shell=%d, bash=%d\n' "$student_rc" "$reference_rc"
  fi
done

echo
printf 'Note: Test 3 uses quoted text. Your current space-only strtok parser\n'
printf 'does not implement shell quoting, so a mismatch is expected there.\n'