#!/usr/bin/env bash
# Installs the ddd-modeling prompts (/ddd-bc, /ddd-model) into a project.
#
#   install.sh --agent claude[,copilot,...] [--framework auto|speckit|openspec|none]
#              [--target DIR] [--ref REF]
#   install.sh --check [--target DIR]
#
# Spec Kit projects are handed to `specify extension add`, which renders the
# commands for every agent Spec Kit was initialised with. OpenSpec and
# framework-less projects get the prompt copied into each agent's own location.
# Run it from a clone, or: curl -fsSL <raw url>/scripts/install.sh | bash -s -- ...
set -euo pipefail

REPO_URL="https://github.com/fredpalas/spec-kit-ddd"
AGENTS_SUPPORTED="claude copilot cursor opencode agents"

FRAMEWORK=auto
AGENTS=""
TARGET="$PWD"
REF=main
CHECK=0

usage() { sed -n '2,11p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'; }
die() { echo "install.sh: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENTS="${AGENTS:+$AGENTS,}$2"; shift 2 ;;
    --framework) FRAMEWORK="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --check) CHECK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

ROOT="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || (cd "$TARGET" && pwd))"

# Source: the clone this script lives in, else a downloaded archive of REF.
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  [ -d "$candidate/dist" ] && SRC="$candidate"
fi
fetch_source() {
  [ -n "$SRC" ] && return
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "$REPO_URL/archive/$REF.tar.gz" | tar -xz -C "$tmp" --strip-components=1 \
    || die "could not download $REPO_URL ($REF)"
  SRC="$tmp"
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
  fetch_source
  latest="$(cat "$SRC/VERSION")"; outdated=0; found=0
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
  (cd "$ROOT" && specify extension add --dev "$SRC" --force)
  echo "installed speckit-ddd into Spec Kit ($ROOT)"
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

for legacy in "$ROOT"/.claude/skills/speckit-speckit-ddd-* "$ROOT"/.github/prompts/speckit.speckit-ddd.* "$ROOT"/.github/agents/speckit.speckit-ddd.*; do
  [ -e "$legacy" ] && echo "warning: legacy copy ${legacy#$ROOT/} is not managed by this installer and may be stale — remove it if /ddd-bc replaces it"
done

echo "ddd-modeling $(cat "$SRC/VERSION") installed for $FRAMEWORK — run /ddd-bc to start a discovery session"
