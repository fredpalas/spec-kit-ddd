OpenSpec sources:

- **Project context** (principles, conventions, team context): the `context:`
  field of `openspec/config.yaml`, and any `rules:` it declares.
- **Current feature**: the active change — a directory under
  `openspec/changes/` other than `archive/`. Read its `proposal.md` (and
  `design.md` if present). If there are several active changes, ask the
  architect which one this session is about.
- **Existing capabilities**: `openspec/specs/*/spec.md` (or
  `openspec list --specs` when the CLI is available) — read them to align the
  ubiquitous language with behaviour that is already specified.
