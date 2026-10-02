#!/usr/bin/env bash
set -u
source "$(dirname "$0")/lib.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
VERSION="$(cat "$REPO/VERSION")"

echo "build: every framework gets a self-contained bc and model prompt"
"$REPO/scripts/build.sh" --out "$TMP/dist" >/dev/null
for fw in speckit openspec none; do
  for cmd in bc model; do
    f="$TMP/dist/$fw/$cmd.md"
    assert_file "$f"
    assert_first_line "$f" "<!-- ddd-modeling $VERSION · framework: $fw -->"
    assert_not_contains "$f" "@include"
    assert_not_contains "$f" "{{"
  done
done

echo "build: speckit reads the real Spec Kit layout and hands off to /speckit.plan"
assert_contains "$TMP/dist/speckit/bc.md" ".specify/memory/constitution.md"
assert_contains "$TMP/dist/speckit/bc.md" ".specify/feature.json"
assert_not_contains "$TMP/dist/speckit/bc.md" ".speckit.constitution"
assert_contains "$TMP/dist/speckit/bc.md" "/speckit.speckit-ddd.model"
assert_contains "$TMP/dist/speckit/model.md" "/speckit.plan"

echo "build: openspec reads openspec/ and hands off to /opsx:propose"
assert_contains "$TMP/dist/openspec/bc.md" "openspec/config.yaml"
assert_contains "$TMP/dist/openspec/bc.md" "/ddd-model"
assert_contains "$TMP/dist/openspec/model.md" "/opsx:propose"
for cmd in bc model; do
  assert_not_contains "$TMP/dist/openspec/$cmd.md" ".specify"
  assert_not_contains "$TMP/dist/openspec/$cmd.md" "speckit"
done

echo "build: none depends on no SDD framework"
for cmd in bc model; do
  for word in ".specify" "speckit" "/opsx" "openspec/"; do
    assert_not_contains "$TMP/dist/none/$cmd.md" "$word"
  done
done
assert_contains "$TMP/dist/none/bc.md" "/ddd-model"

echo "build: every framework carries the DDD rules from the Podium feedback"
for fw in speckit openspec none; do
  bc="$TMP/dist/$fw/bc.md"; model="$TMP/dist/$fw/model.md"
  assert_contains "$bc" "Does this context change state and protect its own rules"
  assert_contains "$bc" "### Read-only contexts"
  assert_contains "$bc" "Note-taking is mechanical"
  assert_contains "$bc" "Exception — read models"
  assert_contains "$bc" "### Collection rule"
  assert_contains "$bc" "SK::Criteria"
  assert_contains "$bc" "**Kind**: Read-write | Read-only"
  assert_contains "$bc" "## Rule placement"
  assert_contains "$bc" "**Generated with**: ddd-modeling $VERSION"
  assert_contains "$bc" "tell the architect which file you used"
  assert_contains "$model" "## Read Models"
  assert_contains "$model" "## Queries"
  assert_contains "$model" "<<ReadModel>>"
  assert_contains "$model" "<<Repository>>"
  assert_contains "$model" "<<Collection>>"
  assert_contains "$model" "🕓 Deferred"
  assert_contains "$model" "**Generated with**: ddd-modeling $VERSION"
  assert_contains "$model" "context map"
  for f in "$bc" "$model"; do assert_contains "$f" "this installed copy is older than"; done
done
assert_contains "$REPO/ddd-config.template.yml" "collections: typed-class"

echo "build: Spec Kit's install-time path rewrite leaves speckit prompts untouched"
# Spec Kit rewrites any "dir/..." reference where dir is a top-level directory of
# the extension package (plus scripts/, templates/, memory/) to
# .specify/extensions/<id>/dir/... — that is how artifacts once ended up there.
rewritten_dirs="scripts templates memory"
for d in "$REPO"/*/; do
  d="$(basename "$d")"
  case "$d" in commands|specs) ;; *) rewritten_dirs="$rewritten_dirs $d" ;; esac
done
for cmd in bc model; do
  f="$TMP/dist/speckit/$cmd.md"
  for d in $rewritten_dirs; do
    if grep -nE "(^|[[:space:]\`\"'(])(\./)?$d/" "$f" | grep -vF ".specify/memory/" >/dev/null; then
      fail "$cmd.md references '$d/', which Spec Kit rewrites on install"
    else
      pass "$cmd.md never references '$d/'"
    fi
  done
done

echo "build --check: passes when dist/ is in sync, fails when it drifts"
cp -r "$REPO" "$TMP/repo"
assert_succeeds "committed dist/ is in sync" "$TMP/repo/scripts/build.sh" --check
echo "drift" >> "$TMP/repo/dist/none/bc.md"
assert_fails "edited dist/ is detected" "$TMP/repo/scripts/build.sh" --check

finish
