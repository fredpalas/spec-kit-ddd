### Path resolution (do this first)

All paths in this prompt are relative to the **project root**.
<!-- @include framework/root.md -->
NEVER resolve a path relative to the current working subdirectory or to the
directory this prompt was installed in.

Resolve the artifact base path:

1. `root` = the project root.
2. Read config to get `domain_docs_path` and `shared_kernel_name`:
   - `{root}/ddd-config.yml` if it exists,
   - then `{root}/ddd-config.local.yml` overrides on top,
   - else fall back to the template defaults: `domain_docs_path: docs/domain`,
     `shared_kernel_name: shared-kernel`.
3. `base` = `{root}/{domain_docs_path}`.
   `shared_kernel` = `{base}/{shared_kernel_name}`.

Every artifact path in this prompt is written as `{base}/...` or
`{shared_kernel}/...` — the config-resolved, root-anchored location, never a
literal relative path.

**Hard write policy:**
- Read and write artifacts ONLY under `{base}`.
- NEVER write anywhere outside `{base}`, including the protected directories
  named above.
- If the project root cannot be determined unambiguously, STOP and ask the
  architect for the target location before writing.
