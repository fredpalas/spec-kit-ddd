# Usage Guide — speckit-ddd

## The problem this extension solves

Without an explicit domain model, agentic code generation tasks produce
primitive-obsessed, anemic code. Each task independently decides that
`email` is a `string` and `price` is a `number`. The domain knowledge
exists only in the architect's head and leaks inconsistently into the
codebase.

`speckit-ddd` makes the domain model a first-class artifact that every
task references by contract.

---

## Workflow walkthrough

### Step 1 — Write your specification

Before running `/speckit.bc`, have a `/speckit.specify` that describes
the feature or system you are modeling. The discovery agent reads it
as context.

### Step 2 — Run `/speckit.bc`

The agent bootstraps from your constitution, existing models, and
specification. It will ask about the business domain.

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

Before running `/speckit.model`, review the discovery file.
You can edit it directly — the agent reads it, not the conversation.

Confirm that:
- All key terms are in the Ubiquitous Language table as `✅ Confirmed`
- Aggregates have at least one invariant listed
- Value objects have construction rules defined
- Open ambiguities that affect the model are resolved

### Step 4 — Run `/speckit.model`

The agent reads `discovery.md` and generates:

- `model.md` — structured model with aggregates, VOs, events, invariants
- `model.mermaid` — class diagram

Review both. Edit directly if needed. When satisfied:

```markdown
**Status**: Accepted
```

### Step 5 — Run `/speckit.plan`

Spec Kit's plan command reads `model.md` as a contract. Each generated
task will reference the specific aggregate, VO, or event it implements.

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

## File reference

Artifacts are written under `{domain_docs_path}` (default `docs/domain`),
**relative to the project root** (the directory containing `.specify/`), never
relative to the extension's install directory. Change the location by setting
`domain_docs_path` in `ddd-config.yml`. Both commands confirm the resolved path
with you before creating the first file in a session.

### `discovery.md` — status values

| Status | Meaning |
|---|---|
| `In Progress` | Session ongoing or paused |
| `Ready for Modeling` | Coverage complete, architect confirmed |

### `discovery.md` — row status markers

| Marker | Meaning |
|---|---|
| `🔍 Candidate` | Proposed, not yet confirmed by architect |
| `✅ Confirmed` | Architect validated this |
| `❌ Rejected` | Discarded — reason noted in comments |
| `⬆️ To Shared Kernel` | Proposed or confirmed move to SK |

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
