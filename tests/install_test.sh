#!/usr/bin/env bash
set -u
source "$(dirname "$0")/lib.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
VERSION="$(cat "$REPO/VERSION")"
INSTALL="$REPO/scripts/install.sh"

new_project() { # name framework
  local dir="$TMP/$1"
  mkdir -p "$dir"; git -C "$dir" init -q
  case "$2" in
    openspec) mkdir -p "$dir/openspec"; printf 'schema: spec-driven\n' > "$dir/openspec/config.yaml" ;;
    speckit) mkdir -p "$dir/.specify" ;;
  esac
  echo "$dir"
}

expected_path() { # agent cmd
  case "$1" in
    claude) echo ".claude/skills/ddd-$2/SKILL.md" ;;
    copilot) echo ".github/prompts/ddd-$2.prompt.md" ;;
    cursor) echo ".cursor/commands/ddd-$2.md" ;;
    opencode) echo ".opencode/command/ddd-$2.md" ;;
    agents) echo ".agents/skills/ddd-$2/SKILL.md" ;;
  esac
}

for fw in openspec none; do
  for agent in claude copilot cursor opencode agents; do
    echo "install: $fw × $agent"
    dir="$(new_project "$fw-$agent" "$fw")"
    (cd "$dir" && "$INSTALL" --agent "$agent" >/dev/null) || fail "install.sh exited non-zero"
    for cmd in bc model; do
      f="$dir/$(expected_path "$agent" "$cmd")"
      assert_file "$f"
      [ -f "$f" ] || continue
      assert_contains "$f" "<!-- ddd-modeling $VERSION · framework: $fw -->"
      assert_contains "$f" "/ddd-model"
      case "$agent" in
        claude|agents) assert_first_line "$f" "---"; assert_contains "$f" "name: ddd-$cmd"; assert_contains "$f" "description: " ;;
        copilot) assert_first_line "$f" "---"; assert_contains "$f" "agent: agent"; assert_contains "$f" "description: " ;;
        opencode) assert_first_line "$f" "---"; assert_contains "$f" "description: " ;;
        cursor) assert_first_line "$f" "<!-- ddd-modeling $VERSION · framework: $fw -->" ;;
      esac
    done
    assert_file "$dir/ddd-config.yml"
  done
done

echo "install: several agents at once, from a subdirectory of the project"
dir="$(new_project multi openspec)"; mkdir -p "$dir/src/deep"
(cd "$dir/src/deep" && "$INSTALL" --agent claude,cursor >/dev/null) || fail "install.sh exited non-zero"
assert_file "$dir/.claude/skills/ddd-bc/SKILL.md"
assert_file "$dir/.cursor/commands/ddd-model.md"
assert_no_file "$dir/src/deep/.claude"

echo "install: --target and an explicit --framework override detection"
dir="$(new_project explicit openspec)"
"$INSTALL" --target "$dir" --framework none --agent claude >/dev/null || fail "install.sh exited non-zero"
assert_contains "$dir/.claude/skills/ddd-bc/SKILL.md" "framework: none"

echo "install: an existing ddd-config.yml is never overwritten"
dir="$(new_project keepcfg none)"; echo "domain_docs_path: docs/my-domain" > "$dir/ddd-config.yml"
"$INSTALL" --target "$dir" --agent claude >/dev/null
assert_contains "$dir/ddd-config.yml" "docs/my-domain"
assert_not_contains "$dir/ddd-config.yml" "shared_kernel_name"

echo "install: rejects unknown agents and a missing --agent"
dir="$(new_project bad none)"
assert_fails "unknown agent" "$INSTALL" --target "$dir" --agent emacs
assert_fails "missing agent" "$INSTALL" --target "$dir"

echo "install --check: reports up to date, then outdated"
dir="$(new_project check openspec)"
"$INSTALL" --target "$dir" --agent claude,copilot >/dev/null
assert_succeeds "fresh install is up to date" "$INSTALL" --target "$dir" --check
sed -i "s/ddd-modeling $VERSION/ddd-modeling 0.0.1/" "$dir/.github/prompts/ddd-bc.prompt.md"
assert_fails "older copy is reported" "$INSTALL" --target "$dir" --check
"$INSTALL" --target "$dir" --check > "$TMP/check.out" 2>&1
assert_contains "$TMP/check.out" ".github/prompts/ddd-bc.prompt.md: 0.0.1"

echo "install: warns about legacy Spec Kit copies in a non-Spec Kit project"
dir="$(new_project legacy openspec)"; mkdir -p "$dir/.claude/skills/speckit-speckit-ddd-bc"
"$INSTALL" --target "$dir" --agent claude > "$TMP/legacy.out" 2>&1
assert_contains "$TMP/legacy.out" ".claude/skills/speckit-speckit-ddd-bc"
[ -d "$dir/.claude/skills/speckit-speckit-ddd-bc" ] && pass "legacy copy left in place" || fail "legacy copy was deleted"

echo "install: Spec Kit projects delegate to specify, which renders per agent"
dir="$(new_project sk speckit)"; mkdir -p "$TMP/bin"
cat > "$TMP/bin/specify" <<STUB
#!/usr/bin/env bash
echo "\$@" > "$TMP/specify.args"
STUB
chmod +x "$TMP/bin/specify"
(cd "$dir" && PATH="$TMP/bin:$PATH" "$INSTALL" >/dev/null) || fail "install.sh exited non-zero"
assert_contains "$TMP/specify.args" "extension add --dev $REPO --force"
assert_no_file "$dir/.claude/skills/ddd-bc"
assert_file "$dir/ddd-config.yml"

echo "install: piped through bash (curl | bash) downloads the archive and cleans up"
mkdir -p "$TMP/archive" "$TMP/pkg"
cp -r "$REPO" "$TMP/pkg/spec-kit-ddd-main"
tar -czf "$TMP/archive/main.tar.gz" -C "$TMP/pkg" spec-kit-ddd-main
dir="$(new_project piped none)"
(cd "$dir" && DDD_REPO_URL="file://$TMP" bash -s -- --agent claude < "$INSTALL" > "$TMP/piped.out" 2>&1) \
  && pass "piped install exits 0" || { fail "piped install exited non-zero"; cat "$TMP/piped.out"; }
assert_file "$dir/.claude/skills/ddd-bc/SKILL.md"
assert_not_contains "$TMP/piped.out" "unbound variable"
assert_not_contains "$TMP/piped.out" "sin asignar"

finish
