# Minimal assertion helpers shared by the shell test suites.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

fail() { echo "  ✗ $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo "  ✓ $1"; }

assert_file() { [ -f "$1" ] && pass "exists: ${1#$TMP/}" || fail "missing file: $1"; }
assert_no_file() { [ ! -e "$1" ] && pass "absent: ${1#$TMP/}" || fail "unexpected file: $1"; }
assert_contains() { grep -qF -- "$2" "$1" && pass "${1##*/} contains '$2'" || fail "${1} does not contain '$2'"; }
assert_not_contains() { ! grep -qF -- "$2" "$1" && pass "${1##*/} lacks '$2'" || fail "${1} unexpectedly contains '$2'"; }
assert_first_line() { [ "$(head -n1 "$1")" = "$2" ] && pass "${1##*/} starts with '$2'" || fail "${1} first line is '$(head -n1 "$1")', expected '$2'"; }
assert_succeeds() { local d="$1"; shift; "$@" >/dev/null 2>&1 && pass "$d" || fail "$d (command failed: $*)"; }
assert_fails() { local d="$1"; shift; ! "$@" >/dev/null 2>&1 && pass "$d" || fail "$d (command unexpectedly succeeded: $*)"; }

finish() {
  if [ "$FAILURES" -gt 0 ]; then echo "$FAILURES failure(s)"; exit 1; fi
  echo "all passed"
}
