# ddd-modeling (speckit-ddd)

> Domain-Driven Design modeling layer for spec-driven development —
> works with [Spec Kit](https://github.com/github/spec-kit),
> [OpenSpec](https://github.com/Fission-AI/OpenSpec), or no framework at all.

Adds a domain discovery and formalization phase between writing a spec and
planning it. Produces bounded context artifacts that agentic code generation
uses as explicit contracts — eliminating primitive obsession and anemic
domain models from AI-generated code.

## Why

Agentic code generation tools have a statistical prior toward primitive
types (`string email`, `number price`) because most training data is
low-quality code. Without an explicit domain model as a contract, every
task regenerates the same weak types independently.

This extension inserts a manual, architect-led modeling phase that
produces structured artifacts the agent cannot deviate from.

## Pipeline

| Spec Kit | OpenSpec | No framework |
|---|---|---|
| `/speckit.constitution` | `openspec/config.yaml` `context:` | `AGENTS.md` / `CLAUDE.md` |
| `/speckit.specify` | an active change (`proposal.md`) | describe the feature in chat |
| **`/speckit.speckit-ddd.bc`** | **`/ddd-bc`** | **`/ddd-bc`** |
| **`/speckit.speckit-ddd.model`** | **`/ddd-model`** | **`/ddd-model`** |
| `/speckit.plan` | `/opsx:propose` (design + tasks) | your planning step |

## Commands


### Discovery — `/ddd-bc` (`/speckit.speckit-ddd.bc` in Spec Kit)

Conversational session to identify the domain model of a bounded context.
Language and stack agnostic. The agent asks one question at a time, detects
candidates for aggregates, value objects, collections, invariants, domain
actions, domain events and read models, and updates
`docs/domain/{bc}/discovery.md` after every exchange. Read-only contexts
(logs, reporting, search) are first-class: they close with read models and
read invariants instead of aggregates.

Sessions are resumable — run the command again to continue where you left off.


### Formalization — `/ddd-model` (`/speckit.speckit-ddd.model` in Spec Kit)


Reads a completed discovery session and produces:

- `docs/domain/{bc}/model.md` — structured domain model
- `docs/domain/{bc}/model.mermaid` — Mermaid class diagram

These files are the contract for planning.

## Artifacts

```
docs/domain/                  # domain_docs_path in ddd-config.yml
├── shared-kernel/
│   └── model.md              # Types shared across bounded contexts
└── {bc-name}/
    ├── discovery.md          # Discovery session
    ├── model.md              # Formal domain model
    └── model.mermaid         # Class diagram
```

## Installation

Every install uses a release tag — the latest one unless you pin another.
See [releases](https://github.com/fredpalas/spec-kit-ddd/tags) for `vX.Y.Z`.

### Spec Kit

The extension is not in the official catalog yet, so install it from the tag
archive:

```bash
specify extension add speckit-ddd --from=https://github.com/fredpalas/spec-kit-ddd/archive/refs/tags/vX.Y.Z.zip
```

### Last version install

```bash
specify extension add speckit-ddd --from=https://github.com/fredpalas/spec-kit-ddd/archive/refs/tags/v0.4.0-alpha.zip
```

Spec Kit renders the commands for every agent it was initialised with, and
asks you to confirm because the source is not the official catalog. The
installer below does the same with the latest tag.

### OpenSpec or no framework

From the project root, pick one or more agents. The installer downloads the
latest release tag:

```bash
curl -fsSL https://raw.githubusercontent.com/fredpalas/spec-kit-ddd/main/scripts/install.sh \
  | bash -s -- --agent claude,copilot
```

Pin a version with `--ref vX.Y.Z`. To install the working tree of a clone
instead (development), run its script with `--dev`:

```bash
/path/to/spec-kit-ddd/scripts/install.sh --dev --agent claude
```

| `--agent` | Installed as |
|---|---|
| `claude` | `.claude/skills/ddd-{bc,model}/SKILL.md` |
| `copilot` | `.github/prompts/ddd-{bc,model}.prompt.md` |
| `cursor` | `.cursor/commands/ddd-{bc,model}.md` |
| `opencode` | `.opencode/command/ddd-{bc,model}.md` |
| `agents` | `.agents/skills/ddd-{bc,model}/SKILL.md` (Codex and other Agent Skills readers) |

The framework is detected (`.specify/` → Spec Kit, `openspec/` → OpenSpec,
otherwise none); force it with `--framework`. In a Spec Kit project the
installer runs the `specify extension add … --from=<tag zip>` command above
(`--dev` uses `specify extension add --dev <clone>`).


For OpenSpec, `--patch-openspec` appends `rules:` to `openspec/config.yaml` so
the design and tasks artifacts use the accepted models as their contract.
Without the flag — or if `rules:` already exists — the snippet is printed for
you to merge.

Both paths create `ddd-config.yml` from the template if it does not exist.

### Updating

Re-run the install command — for Spec Kit, `specify extension add` with
`--force` and the new tag's zip. `install.sh --check` reports the installed
version of every copy and exits non-zero if one is older than the latest tag. Artifacts record
the version that wrote them, and an older prompt warns before using them.

## Development

Prompts are assembled from a framework-agnostic core plus one adapter per
framework:

```
src/core/{bc,model}.md        # DDD rules
src/core/partials/            # shared bootstrap sections
src/frameworks/{fw}/          # root, context sources, handoff, command names
dist/{fw}/{bc,model}.md       # generated — committed
```

```bash
scripts/build.sh              # regenerate dist/
scripts/build.sh --check      # fail if dist/ is stale
bash tests/build_test.sh && bash tests/install_test.sh
```

Never reference a top-level directory of this repo (`dist/`, `src/`, …) or
`scripts/`, `templates/`, `memory/` from a prompt: Spec Kit rewrites such
references to `.specify/extensions/speckit-ddd/...` on install. The build test
guards this.

## License

MIT
