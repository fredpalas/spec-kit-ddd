#!/usr/bin/env bash
set -u
source "$(dirname "$0")/lib.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
VERSION="$(cat "$REPO/VERSION")"
INSTALL="$REPO/scripts/install.sh"
install_dev() { "$INSTALL" --dev "$@"; }

# A stand-in for the GitHub repo: tags for `git ls-remote`, and the archives
# GitHub serves at archive/refs/tags/<tag>.tar.gz.
REMOTE="$TMP/remote"
mkdir -p "$TMP/pkg"
cp -r "$REPO" "$REMOTE"; rm -rf "$REMOTE/.git"
git -C "$REMOTE" init -q && git -C "$REMOTE" add -A && git -C "$REMOTE" -c user.email=t@t -c user.name=t commit -qm fake
for tag in v1.0.0 v1.2.0 v1.10.0-alpha v1.10.0; do
  git -C "$REMOTE" tag "$tag"
  mkdir -p "$REMOTE/archive/refs/tags"
  cp -r "$REPO" "$TMP/pkg/spec-kit-ddd-${tag#v}"; rm -rf "$TMP/pkg/spec-kit-ddd-${tag#v}/.git"
  echo "${tag#v}" > "$TMP/pkg/spec-kit-ddd-${tag#v}/VERSION"
  tar -czf "$REMOTE/archive/refs/tags/$tag.tar.gz" -C "$TMP/pkg" "spec-kit-ddd-${tag#v}"
done
# A release from before dist/ existed (prompts lived in commands/).
mkdir -p "$TMP/pkg/spec-kit-ddd-0.3.0-alpha/commands"
tar -czf "$REMOTE/archive/refs/tags/v0.3.0-alpha.tar.gz" -C "$TMP/pkg" spec-kit-ddd-0.3.0-alpha
git -C "$REMOTE" tag v0.3.0-alpha
export DDD_REPO_URL="file://$REMOTE"

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
    (cd "$dir" && install_dev --agent "$agent" >/dev/null) || fail "install.sh exited non-zero"
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
(cd "$dir/src/deep" && install_dev --agent claude,cursor >/dev/null) || fail "install.sh exited non-zero"
assert_file "$dir/.claude/skills/ddd-bc/SKILL.md"
assert_file "$dir/.cursor/commands/ddd-model.md"
assert_no_file "$dir/src/deep/.claude"

echo "install: --target and an explicit --framework override detection"
dir="$(new_project explicit openspec)"
install_dev --target "$dir" --framework none --agent claude >/dev/null || fail "install.sh exited non-zero"
assert_contains "$dir/.claude/skills/ddd-bc/SKILL.md" "framework: none"

echo "install: an existing ddd-config.yml is never overwritten"
dir="$(new_project keepcfg none)"; echo "domain_docs_path: docs/my-domain" > "$dir/ddd-config.yml"
install_dev --target "$dir" --agent claude >/dev/null
assert_contains "$dir/ddd-config.yml" "docs/my-domain"
assert_not_contains "$dir/ddd-config.yml" "shared_kernel_name"

echo "install: rejects unknown agents and a missing --agent"
dir="$(new_project bad none)"
assert_fails "unknown agent" install_dev --target "$dir" --agent emacs
assert_fails "missing agent" install_dev --target "$dir"

echo "install --check: reports up to date, then outdated"
dir="$(new_project check openspec)"
install_dev --target "$dir" --agent claude,copilot >/dev/null
assert_succeeds "fresh install is up to date" install_dev --target "$dir" --check
sed -i "s/ddd-modeling $VERSION/ddd-modeling 0.0.1/" "$dir/.github/prompts/ddd-bc.prompt.md"
assert_fails "older copy is reported" install_dev --target "$dir" --check
install_dev --target "$dir" --check > "$TMP/check.out" 2>&1
assert_contains "$TMP/check.out" ".github/prompts/ddd-bc.prompt.md: 0.0.1"

echo "install: warns about legacy Spec Kit copies in a non-Spec Kit project"
dir="$(new_project legacy openspec)"; mkdir -p "$dir/.claude/skills/speckit-speckit-ddd-bc"
install_dev --target "$dir" --agent claude > "$TMP/legacy.out" 2>&1
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
assert_contains "$TMP/specify.args" "extension add speckit-ddd --force --from=$DDD_REPO_URL/archive/refs/tags/v1.10.0.zip"
(cd "$dir" && PATH="$TMP/bin:$PATH" install_dev >/dev/null) || fail "install.sh --dev exited non-zero"
assert_contains "$TMP/specify.args" "extension add --dev $REPO --force"
assert_no_file "$dir/.claude/skills/ddd-bc"
assert_file "$dir/ddd-config.yml"

echo "install: OpenSpec rules — suggested by default, appended with --patch-openspec"
dir="$(new_project os-suggest openspec)"
install_dev --target "$dir" --agent claude > "$TMP/os.out" 2>&1
assert_not_contains "$dir/openspec/config.yaml" "ddd-modeling"
assert_contains "$TMP/os.out" "rules:"

dir="$(new_project os-patch openspec)"; echo "domain_docs_path: docs/podium-domain" > "$dir/ddd-config.yml"
install_dev --target "$dir" --agent claude --patch-openspec >/dev/null
assert_contains "$dir/openspec/config.yaml" "schema: spec-driven"
assert_contains "$dir/openspec/config.yaml" "rules:"
assert_contains "$dir/openspec/config.yaml" "  design:"
assert_contains "$dir/openspec/config.yaml" "  tasks:"
assert_contains "$dir/openspec/config.yaml" "docs/podium-domain"
install_dev --target "$dir" --agent claude --patch-openspec >/dev/null
[ "$(grep -c '^rules:' "$dir/openspec/config.yaml")" = 1 ] && pass "patch is idempotent" || fail "rules: appended twice"

dir="$(new_project os-existing openspec)"; printf 'rules:\n  proposal:\n    - Keep it short\n' >> "$dir/openspec/config.yaml"
cp "$dir/openspec/config.yaml" "$TMP/before.yaml"
install_dev --target "$dir" --agent claude --patch-openspec > "$TMP/os.out" 2>&1
assert_succeeds "existing rules: are left untouched" diff -q "$TMP/before.yaml" "$dir/openspec/config.yaml"
assert_contains "$TMP/os.out" "merge"

echo "install: by default the latest tag is installed (semver order: v1.10.0 > v1.10.0-alpha > v1.2.0)"
dir="$(new_project tagged openspec)"
"$INSTALL" --target "$dir" --agent claude > "$TMP/tag.out" 2>&1 || { fail "install from tag exited non-zero"; cat "$TMP/tag.out"; }
assert_contains "$TMP/tag.out" "ddd-modeling 1.10.0 installed"
assert_file "$dir/.claude/skills/ddd-bc/SKILL.md"

echo "install: a tag older than the installer layout fails before touching the project"
dir="$(new_project old-tag none)"
"$INSTALL" --target "$dir" --agent claude --ref v0.3.0-alpha > "$TMP/old.out" 2>&1 && fail "old tag install succeeded" || pass "old tag install fails"
assert_contains "$TMP/old.out" "v0.3.0-alpha predates install.sh"
assert_no_file "$dir/ddd-config.yml"
assert_no_file "$dir/.claude"

echo "install --ref: installs that tag"
dir="$(new_project pinned none)"
"$INSTALL" --target "$dir" --agent cursor --ref v1.2.0 > "$TMP/ref.out" 2>&1 || fail "install --ref exited non-zero"
assert_contains "$TMP/ref.out" "ddd-modeling 1.2.0 installed"

echo "install --check: compares against the latest tag"
dir="$(new_project check-tag none)"
install_dev --target "$dir" --agent claude >/dev/null
assert_fails "a copy older than the latest tag is outdated" "$INSTALL" --target "$dir" --check
"$INSTALL" --target "$dir" --check > "$TMP/check-tag.out" 2>&1
assert_contains "$TMP/check-tag.out" "latest is 1.10.0"

echo "install: piped through bash (curl | bash) downloads the latest tag and cleans up"
dir="$(new_project piped none)"
(cd "$dir" && bash -s -- --agent claude < "$INSTALL" > "$TMP/piped.out" 2>&1) \
  && pass "piped install exits 0" || { fail "piped install exited non-zero"; cat "$TMP/piped.out"; }
assert_file "$dir/.claude/skills/ddd-bc/SKILL.md"
assert_contains "$TMP/piped.out" "ddd-modeling 1.10.0 installed"
assert_not_contains "$TMP/piped.out" "unbound variable"
assert_not_contains "$TMP/piped.out" "sin asignar"

echo "install: --dev only works from a clone"
dir="$(new_project devpipe none)"
assert_fails "--dev when piped" bash -c "cd '$dir' && bash -s -- --dev --agent claude < '$INSTALL'"

finish
