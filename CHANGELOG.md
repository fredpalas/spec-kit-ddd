# Changelog

All notable changes to speckit-ddd will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/).

## [0.4.0-alpha] - 2026-10-02

### Added
- OpenSpec and framework-less support: prompts are built from a
  framework-agnostic core plus a Spec Kit, OpenSpec or "none" adapter
  (`scripts/build.sh` → `dist/`)
- `scripts/install.sh` — installs `/ddd-bc` and `/ddd-model` for Claude Code,
  Copilot, Cursor, OpenCode and generic Agent Skills from the latest release
  tag (`--ref` pins one, `--dev` uses a local clone); in Spec Kit projects it
  runs `specify extension add speckit-ddd --from=<tag zip>`, since the
  extension is not in the official catalog; `--check` reports copies older
  than the latest tag;
  `--patch-openspec` adds design/tasks rules to `openspec/config.yaml`
- Read-only bounded contexts: early read/write question, read-only question
  set and closure checklist, Read Models and Queries in the model,
  `🕓 Deferred` events, `<<ReadModel>>` / `<<Repository>>` in Mermaid
- Collection rule, `collection` VO kind, `<<Collection>>` in Mermaid, and the
  `collections: typed-class | native` config key
- `## Rule placement` in discovery.md; `SK::Criteria` proposed for dynamic reads
- Version stamp in every prompt and artifact (`**Generated with**`), with a
  warning when an installed prompt is older than an artifact it reads
- Fallback to a context map or architecture doc when there is no project
  context, stating which file was used; the context map is updated with new
  shared kernel types

### Changed
- Primitive note-taking is mechanical, with an exception for rule-free
  read-model fields
- Spec Kit context is read from `.specify/memory/constitution.md` and the
  feature in `.specify/feature.json` (the previous `.speckit.constitution` and
  `.speckit.specify` never existed)

### Fixed
- Artifacts written under `.specify/extensions/speckit-ddd/docs/`: Spec Kit
  rewrites references to the extension's own top-level directories, and this
  repo had a `docs/` directory. It is now `documentation/`, prompts reference
  only `{base}/` and `{shared_kernel}/`, and a build test guards it

## [1.0.0] - 2026-05-20

### Added
- `/speckit.bc` command — conversational domain discovery session
- `/speckit.model` command — formalization of discovery into model artifacts
- Shared kernel detection and promotion during discovery
- Resumable discovery sessions via `discovery.md`
- Mermaid class diagram generation in `/speckit.model`
- `ddd-config.template.yml` for project-level configuration
