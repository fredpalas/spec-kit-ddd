#!/usr/bin/env bash
# Assembles src/core prompts with each framework adapter into self-contained
# prompts under dist/{framework}/. dist/ is committed so Spec Kit and the
# installer can consume it without running a build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist"
CHECK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --check) CHECK=1; shift ;;
    *) echo "usage: build.sh [--out DIR] [--check]" >&2; exit 2 ;;
  esac
done

VERSION="$(cat "$ROOT/VERSION")"
FRAMEWORKS=(speckit openspec none)
COMMANDS=(bc model)

expand() {
  local fw="$1" file="$2" line target
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^\<!--\ @include\ ([^ ]+)\ --\>$ ]]; then
      target="${BASH_REMATCH[1]}"
      case "$target" in
        framework/*) expand "$fw" "$ROOT/src/frameworks/$fw/${target#framework/}" ;;
        *) expand "$fw" "$ROOT/src/core/$target" ;;
      esac
    else
      printf '%s\n' "$line"
    fi
  done < "$file"
}

render() {
  local fw="$1" cmd="$2" content key value
  content="$(expand "$fw" "$ROOT/src/core/$cmd.md")"
  content="${content//\{\{VERSION\}\}/$VERSION}"
  while IFS='=' read -r key value; do
    [ -n "$key" ] && content="${content//\{\{$key\}\}/$value}"
  done < "$ROOT/src/frameworks/$fw/vars"
  printf '<!-- ddd-modeling %s · framework: %s -->\n\n%s\n' "$VERSION" "$fw" "$content"
}

build() {
  local out="$1" fw cmd
  rm -rf "$out"
  for fw in "${FRAMEWORKS[@]}"; do
    mkdir -p "$out/$fw"
    for cmd in "${COMMANDS[@]}"; do
      render "$fw" "$cmd" > "$out/$fw/$cmd.md"
    done
  done
}

if [ "$CHECK" -eq 1 ]; then
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  build "$tmp/dist"
  if ! diff -r "$tmp/dist" "$ROOT/dist" >/dev/null 2>&1; then
    echo "dist/ is out of date — run scripts/build.sh" >&2
    exit 1
  fi
  echo "dist/ is up to date"
else
  build "$OUT"
  echo "built $OUT (ddd-modeling $VERSION)"
fi
