# speckit-ddd

> Domain-Driven Design modeling layer for [Spec Kit](https://github.com/github/spec-kit).

Adds a domain discovery and formalization phase between `/speckit.specify`
and `/speckit.plan`. Produces bounded context artifacts that agentic
code generation tasks use as explicit contracts — eliminating primitive
obsession and anemic domain models from AI-generated code.

## Why

Agentic code generation tools have a statistical prior toward primitive
types (`string email`, `number price`) because most training data is
low-quality code. Without an explicit domain model as a contract, every
task regenerates the same weak types independently.

This extension inserts a manual, architect-led modeling phase that
produces structured artifacts the agent cannot deviate from.

## Pipeline

```
/speckit.constitution
  └─ /speckit.specify
       └─ /speckit.bc      ← conversational discovery (this extension)
            └─ /speckit.model   ← formalization (this extension)
                 └─ /speckit.plan    ← tasks with domain contracts
                      └─ code generation
```

## Commands

### `/speckit.speckit-ddd.bc` — Domain Discovery

Conversational session to identify the domain model of a bounded context.
Language and stack agnostic. The agent interrogates the domain, detects
candidates for aggregates, value objects, invariants, and domain events,
and updates `docs/domain/{bc}/discovery.md` incrementally.

Sessions are resumable — run `/speckit.bc` again to continue where you
left off.

### `/speckit.speckit-ddd.model` — Model Formalization

Reads a completed discovery session and produces:

- `docs/domain/{bc}/model.md` — structured domain model
- `docs/domain/{bc}/model.mermaid` — Mermaid class diagram

These files are the contract for `/speckit.plan`.

## Artifacts

```
docs/domain/
├── shared-kernel/
│   ├── model.md          # Types shared across bounded contexts
│   └── model.mermaid
└── {bc-name}/
    ├── discovery.md      # Discovery session (Fase 1 output)
    ├── model.md          # Formal domain model (Fase 2 output)
    └── model.mermaid     # Class diagram
```

## Installation

### Generic install

```bash
specify extension add speckit-ddd --from=https://github.com/fredpalas/spec-kit-ddd/archive/refs/tags/vX.Y.Z.zip
```

### Last version install

```bash
specify extension add speckit-ddd --from=https://github.com/fredpalas/spec-kit-ddd/archive/refs/tags/v0.3.0-alpha.zip
```

### Set up configuration:

```bash
cp .specify/extensions/ddd/ddd-config.template.yml \
   .specify/extensions/ddd/ddd-config.yml
```

## Usage

### Starting a discovery session

*Copilot:*
```
/speckit.speckit-ddd.bc
```

*Claude:*
```
/speckit-speckit-ddd-bc
```

The agent reads your constitution, existing models, and current
specification. It will ask about the domain — describe the business
problem. The session updates `discovery.md` after every exchange.

When coverage is complete, the agent proposes closure. Confirm to
mark the session as ready for formalization.

### Formalizing the model

```
/speckit.speckit-ddd.model
```

Reads the discovery session and generates `model.md` and
`model.mermaid`. Review both files. When satisfied, set
`**Status**: Accepted` in `model.md` and run `/speckit.plan`.

### Resuming a session

```
/speckit.speckit-ddd.bc
```

The agent detects the existing `discovery.md` and resumes from the
open items.

## Shared Kernel

Types proposed during discovery as shared kernel candidates are added
to `docs/domain/shared-kernel/model.md` during `/speckit.model`.

All BCs reference shared kernel types as `SK::{TypeName}` — they are
never redefined locally.

## Requirements

- Spec Kit >= 1.0.0
- A project initialized with `specify init`
- `.speckit.constitution` describing your project context

## License

MIT
