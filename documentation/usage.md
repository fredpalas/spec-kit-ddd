# Usage Guide — ddd-modeling (speckit-ddd)

## The problem this extension solves

Without an explicit domain model, agentic code generation tasks produce
primitive-obsessed, anemic code. Each task independently decides that
`email` is a `string` and `price` is a `number`. The domain knowledge
exists only in the architect's head and leaks inconsistently into the
codebase.

ddd-modeling makes the domain model a first-class artifact that every
task references by contract.

Command names below use the OpenSpec / framework-less form (`/ddd-bc`,
`/ddd-model`). In Spec Kit they are `/speckit.speckit-ddd.bc` and
`/speckit.speckit-ddd.model`.

---

## Workflow walkthrough

### Step 1 — Describe the feature

Before running `/ddd-bc`, describe the feature or system you are modeling:
a Spec Kit spec (`/speckit.specify`), an OpenSpec change (`proposal.md`), or —
without a framework — just tell the agent. The discovery agent reads it as
context, together with the project context (Spec Kit constitution, OpenSpec
`config.yaml` `context:`, or `AGENTS.md` / `CLAUDE.md`). When that is missing
it falls back to a context map or architecture doc and tells you which file it
used.

### Step 2 — Run `/ddd-bc`

The agent bootstraps from the project context, existing models, and the
current feature. It will ask about the business domain — and, early on,
whether this context changes state or only reads data produced elsewhere.

**Good answers to give the agent:**
- Describe the business problem in business language, not technical terms
- Name the things the business talks about (customers, orders, invoices)
- Describe rules the business enforces ("an order cannot ship if unpaid")
- Describe what happens that other parts of the system care about

**The agent will:**
- Ask one question at a time
- Propose candidates — you confirm, reject, or modify
- Surface ambiguities and ask you to resolve them
- Propose shared kernel candidates and wait for your decision
- Update `discovery.md` after every exchange

**The session ends when:**
- You say you are ready, after the agent proposes closure, OR
- You end the session — it will resume next time

### Step 3 — Review `discovery.md`

Before running `/ddd-model`, review the discovery file.
You can edit it directly — the agent reads it, not the conversation.

Confirm that:
- All key terms are in the Ubiquitous Language table as `✅ Confirmed`
- Aggregates have at least one invariant listed
- Value objects have construction rules defined
- Open ambiguities that affect the model are resolved

### Step 4 — Run `/ddd-model`

The agent reads `discovery.md` and generates:

- `model.md` — structured model with aggregates, VOs, events, invariants
- `model.mermaid` — class diagram

Review both. Edit directly if needed. When satisfied:

```markdown
**Status**: Accepted
```

### Step 5 — Plan

- **Spec Kit**: `/speckit.plan` reads `model.md` as a contract.
- **OpenSpec**: `/opsx:propose`. Install with `--patch-openspec` (or merge the
  printed snippet) so the design and tasks artifacts are told to use the
  accepted models.
- **No framework**: hand `model.md` to your planning step.

Each task should reference the specific aggregate, VO, read model or event
it implements.

---

## Modeling patterns

### Read-only contexts

A context that only reads data another part of the system produces (logs,
metrics, search, reporting) has no aggregate and usually no domain events.
Discovery records `**Kind**: Read-only` and closes on a different checklist:
read models with their fields, read invariants (what a read must never
return), the producer of the data, and how reads are expressed. Events that
will exist later are recorded as `🕓 Deferred`.

### Primitives are value objects

As soon as you describe a value by its primitive shape ("an ISO 8601 date in
UTC", "a number between 1 and 1000"), the agent records a basic VO with that
construction rule. Only rule-free fields of a read model (free text, opaque
payload) may stay primitive.

### Collections

"A list of X" becomes a named collection (`MemberCollection`) with its element
type and list-level rules (not empty, no duplicates…). Set `collections` in
`ddd-config.yml`: `typed-class` (a class per collection — e.g. PHP) or
`native` (`List<X>`, with `X` still a named type).

### Rule placement

Each confirmed rule is recorded with where it lives — domain, Criteria,
boundary (validation, authorization) or infrastructure — so the application
service only orchestrates. Dynamic reads ("filter by X, last N") are proposed
as `SK::Criteria` given to a repository.

---

## Shared Kernel patterns

### When to propose a type for the shared kernel

Propose a type for the shared kernel when:
- It will appear in more than one bounded context
- Its construction rule and meaning are identical across contexts
- Changing its rule would require changes in multiple BCs

Common shared kernel candidates: `Email`, `Money`, `PhoneNumber`,
`DateRange`, `Address`, identity types like `UserId` or `CustomerId`.

### When NOT to use the shared kernel

Do not share types that are contextually different even if they have
the same name. An `Address` in a shipping context has different rules
than an `Address` in a billing context — keep them local.

### Shared kernel discipline

The shared kernel is a coordination point. Types added to it create
coupling between BCs. Treat it like a public API — conservative,
well-named, and changed by coordination, not unilaterally.

---

## Keeping installed copies up to date

Re-run the install from the latest release tag: for Spec Kit,
`specify extension add speckit-ddd --force --from=https://github.com/fredpalas/spec-kit-ddd/archive/refs/tags/vX.Y.Z.zip`;
for OpenSpec / no framework, `install.sh --agent …` (it picks the latest tag;
`--ref vX.Y.Z` pins one). `install.sh --check` lists the version of every
installed copy and fails if one is older than the latest tag. Artifacts
record `**Generated with**: ddd-modeling {version}`; a prompt older than an
artifact it reads warns you before continuing.

---

## File reference

Artifacts are written under `{domain_docs_path}` (default `docs/domain`),
**relative to the project root** (the directory containing `.specify/` or
`openspec/`, else the git root), never relative to where the prompt is
installed. Change the location by setting
`domain_docs_path` in `ddd-config.yml`. Both commands confirm the resolved path
with you before creating the first file in a session.

### `discovery.md` — status values

| Status | Meaning |
|---|---|
| `In Progress` | Session ongoing or paused |
| `Ready for Modeling` | Coverage complete, architect confirmed |

### `discovery.md` — kind

| Kind | Meaning |
|---|---|
| `Read-write` | Changes state through aggregates (default) |
| `Read-only` | Only reads data produced elsewhere; read models instead of aggregates |

### `discovery.md` — row status markers

| Marker | Meaning |
|---|---|
| `🔍 Candidate` | Proposed, not yet confirmed by architect |
| `✅ Confirmed` | Architect validated this |
| `❌ Rejected` | Discarded — reason noted in comments |
| `⬆️ To Shared Kernel` | Proposed or confirmed move to SK |
| `🕓 Deferred` | Confirmed to exist later, out of scope for this model |

### `model.md` — status values

| Status | Meaning |
|---|---|
| `Draft` | Generated, not yet reviewed |
| `Reviewed` | Architect has reviewed, open questions resolved |
| `Accepted` | Final — `/speckit.plan` can use this as contract |

### VO scope values in `model.md`

| Scope | Meaning |
|---|---|
| `Local` | Belongs only to this BC |
| `SK::{TypeName}` | References a shared kernel type |
