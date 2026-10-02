#!/usr/bin/env bash
# Installs the ddd-modeling prompts (/ddd-bc, /ddd-model) into a project.
#
#   install.sh --agent claude[,copilot,...] [--framework auto|speckit|openspec|none]
#              [--target DIR] [--ref vX.Y.Z | --dev] [--patch-openspec]
#   install.sh --check [--target DIR] [--ref vX.Y.Z | --dev]
#
# Installs the latest release tag by default; --ref pins a tag, and --dev uses
# the clone this script lives in. Spec Kit projects are handed to
# `specify extension add --from=<tag zip>`, which renders the commands for every
# agent Spec Kit was initialised with. OpenSpec and framework-less projects get
# the prompt copied into each agent's own location. --patch-openspec appends
# rules to openspec/config.yaml so OpenSpec's design and tasks use the domain
# model as their contract (otherwise they are printed).
set -euo pipefail

REPO_URL="${DDD_REPO_URL:-https://github.com/fredpalas/spec-kit-ddd}"
AGENTS_SUPPORTED="claude copilot cursor opencode agents"

FRAMEWORK=auto
AGENTS=""
TARGET="$PWD"
REF=""
DEV=0
CHECK=0
PATCH_OPENSPEC=0

usage() { sed -n '2,15p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'; }
die() { echo "install.sh: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENTS="${AGENTS:+$AGENTS,}$2"; shift 2 ;;
    --framework) FRAMEWORK="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --dev) DEV=1; shift ;;
    --check) CHECK=1; shift ;;
    --patch-openspec) PATCH_OPENSPEC=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || (cd "$TARGET" && pwd))"

# Source: the clone this script lives in (--dev), else the archive of a tag.
SRC=""
if [ "$DEV" -eq 1 ]; then
  [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ] \
    && SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  [ -n "$SRC" ] && [ -d "$SRC/dist" ] || die "--dev needs install.sh to be run from a clone of $REPO_URL"
elif [ -z "$REF" ]; then
  command -v git >/dev/null || die "git is needed to find the latest release — pass --ref vX.Y.Z"
  # sort -V puts v1.0.0 before v1.0.0-alpha; "~" sorts before anything, as
  # semver wants for prereleases.
  REF="$(git ls-remote --tags --refs "$REPO_URL" 'v*' | sed 's#.*refs/tags/##; s/-/~/' \
    | sort -V | tail -n1 | sed 's/~/-/')"
  [ -n "$REF" ] || die "no release tag found in $REPO_URL — pass --ref vX.Y.Z or use --dev"
fi

DOWNLOAD_DIR=""
trap '[ -z "$DOWNLOAD_DIR" ] || rm -rf "$DOWNLOAD_DIR"' EXIT
fetch_source() {
  [ -n "$SRC" ] && return
  DOWNLOAD_DIR="$(mktemp -d)"
  curl -fsSL "$REPO_URL/archive/refs/tags/$REF.tar.gz" | tar -xz -C "$DOWNLOAD_DIR" --strip-components=1 \
    || die "could not download $REF from $REPO_URL"
  [ -f "$DOWNLOAD_DIR/VERSION" ] && [ -d "$DOWNLOAD_DIR/dist" ] \
    || die "$REF predates install.sh (it has no dist/) — use a newer tag with --ref"
  SRC="$DOWNLOAD_DIR"
}

agent_path() { # agent cmd
  case "$1" in
    claude) echo ".claude/skills/ddd-$2/SKILL.md" ;;
    copilot) echo ".github/prompts/ddd-$2.prompt.md" ;;
    cursor) echo ".cursor/commands/ddd-$2.md" ;;
    opencode) echo ".opencode/command/ddd-$2.md" ;;
    agents) echo ".agents/skills/ddd-$2/SKILL.md" ;;
  esac
}

description() {
  case "$1" in
    bc) echo "DDD domain discovery: a conversational session that identifies the domain model of a bounded context (aggregates, value objects, invariants, events, read models) and records it in discovery.md." ;;
    model) echo "DDD model formalization: turns a ready discovery.md into model.md and model.mermaid, the contract for planning and code generation." ;;
  esac
}

frontmatter() { # agent cmd
  local desc; desc="$(description "$2")"
  case "$1" in
    claude|agents) printf -- '---\nname: ddd-%s\ndescription: "%s"\n---\n\n' "$2" "$desc" ;;
    copilot) printf -- '---\ndescription: "%s"\nagent: agent\n---\n\n' "$desc" ;;
    opencode) printf -- '---\ndescription: "%s"\n---\n\n' "$desc" ;;
    cursor) ;;
  esac
}

installed_files() {
  local agent cmd f
  for agent in $AGENTS_SUPPORTED; do
    for cmd in bc model; do
      f="$(agent_path "$agent" "$cmd")"
      [ -f "$ROOT/$f" ] && echo "$f"
    done
  done
  find "$ROOT/.specify/extensions/speckit-ddd/dist" -name '*.md' 2>/dev/null | sed "s#^$ROOT/##"
  return 0
}

if [ "$CHECK" -eq 1 ]; then
  if [ "$DEV" -eq 1 ]; then latest="$(cat "$SRC/VERSION")"; else latest="${REF#v}"; fi
  outdated=0; found=0
  for f in $(installed_files); do
    found=1
    v="$(grep -o 'ddd-modeling [0-9][0-9.]*' "$ROOT/$f" | head -n1 | cut -d' ' -f2)"
    echo "$f: ${v:-unknown}"
    [ "$v" = "$latest" ] || outdated=1
  done
  [ "$found" -eq 1 ] || die "no ddd-modeling prompts installed in $ROOT"
  if [ "$outdated" -eq 1 ]; then echo "outdated — latest is $latest; run install.sh again"; exit 1; fi
  echo "up to date ($latest)"
  exit 0
fi

if [ "$FRAMEWORK" = auto ]; then
  if [ -d "$ROOT/.specify" ]; then FRAMEWORK=speckit
  elif [ -d "$ROOT/openspec" ]; then FRAMEWORK=openspec
  else FRAMEWORK=none; fi
fi
case "$FRAMEWORK" in speckit|openspec|none) ;; *) die "unknown framework: $FRAMEWORK" ;; esac

fetch_source

if [ ! -f "$ROOT/ddd-config.yml" ]; then
  cp "$SRC/ddd-config.template.yml" "$ROOT/ddd-config.yml"
  echo "created ddd-config.yml"
fi

if [ "$FRAMEWORK" = speckit ]; then
  command -v specify >/dev/null || die "Spec Kit project detected but 'specify' is not installed — see https://github.com/github/spec-kit"
  [ -z "$AGENTS" ] || echo "note: --agent is ignored for Spec Kit; it renders the commands for its own configured agents"
  if [ "$DEV" -eq 1 ]; then
    set -- extension add --dev "$SRC" --force
  else
    set -- extension add speckit-ddd --force "--from=$REPO_URL/archive/refs/tags/$REF.zip"
  fi
  # specify asks for confirmation on unofficial sources. When this script is
  # piped (curl | bash) stdin is the script itself, so answer from the terminal.
  if { : </dev/tty; } 2>/dev/null; then
    (cd "$ROOT" && specify "$@" </dev/tty) || die "specify $* failed"
  else
    (cd "$ROOT" && specify "$@" </dev/null) || die "no terminal to confirm — run in $ROOT: specify $*"
  fi
  echo "installed speckit-ddd $(cat "$SRC/VERSION") into Spec Kit ($ROOT)"
  exit 0
fi

[ -n "$AGENTS" ] || die "--agent is required (one or more of: ${AGENTS_SUPPORTED// /, })"
for agent in ${AGENTS//,/ }; do
  case " $AGENTS_SUPPORTED " in *" $agent "*) ;; *) die "unknown agent: $agent (supported: ${AGENTS_SUPPORTED// /, })" ;; esac
  for cmd in bc model; do
    dest="$ROOT/$(agent_path "$agent" "$cmd")"
    mkdir -p "$(dirname "$dest")"
    { frontmatter "$agent" "$cmd"; cat "$SRC/dist/$FRAMEWORK/$cmd.md"; } > "$dest"
    echo "installed ${dest#$ROOT/}"
  done
done

openspec_rules() {
  local docs
  docs="$(sed -n 's/^domain_docs_path:[[:space:]]*//p' "$ROOT/ddd-config.yml" | tr -d "\"'" | head -n1)"
  docs="${docs:-docs/domain}"
  cat <<RULES
# ddd-modeling: the accepted domain models are the contract for design and tasks
rules:
  design:
    - Read every model.md with Status Accepted under $docs/ and use it as the contract - aggregates, value objects, collections, read models and domain events by their model names.
    - No primitive-typed field outside a basic value object, and no generic list of primitives - lists are the named collections from the model.
    - Application services only orchestrate (load, call the domain, persist, dispatch events) - each rule lives where the model's Rule placement says.
  tasks:
    - Each task names the aggregate, value object, read model or domain event from model.md that it implements.
RULES
}

if [ "$FRAMEWORK" = openspec ]; then
  config="$ROOT/openspec/config.yaml"
  if grep -q '^# ddd-modeling:' "$config" 2>/dev/null; then
    :
  elif [ "$PATCH_OPENSPEC" -eq 1 ] && ! grep -q '^rules:' "$config" 2>/dev/null; then
    { echo; openspec_rules; } >> "$config"
    echo "added ddd-modeling rules to openspec/config.yaml"
  else
    if grep -q '^rules:' "$config" 2>/dev/null; then
      echo "openspec/config.yaml already has rules: — merge these by hand:"
    else
      echo "to make OpenSpec use the domain model as its contract, add this to openspec/config.yaml (or re-run with --patch-openspec):"
    fi
    echo; openspec_rules; echo
  fi
fi

for legacy in "$ROOT"/.claude/skills/speckit-speckit-ddd-* "$ROOT"/.github/prompts/speckit.speckit-ddd.* "$ROOT"/.github/agents/speckit.speckit-ddd.*; do
  [ -e "$legacy" ] && echo "warning: legacy copy ${legacy#$ROOT/} is not managed by this installer and may be stale — remove it if /ddd-bc replaces it"
done

echo "ddd-modeling $(cat "$SRC/VERSION") installed for $FRAMEWORK — run /ddd-bc to start a discovery session"
