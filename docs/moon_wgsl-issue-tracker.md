# moon_wgsl Issue Tracker

Last updated: 2026-04-15

## Status Legend

- `TODO`: not started
- `IN_PROGRESS`: currently being fixed
- `BLOCKED`: blocked by platform/public API limitations or external dependency constraints
- `DONE`: fixed and verified locally

## Issues

| ID | Source | Problem | Status | Notes |
| --- | --- | --- | --- | --- |
| `WGSL-001` | Local audit | Composer/export path does not report import cycles explicitly; recursive item imports can fail silently or truncate output. | `DONE` | Added `ComposerError::ImportCycle` and active import-stack checks in recursive composition. Verified with `moon test` on 2026-04-15 (`28/28` passing), including a new cycle regression test. |
| `WGSL-002` | Local audit | Registry APIs do not diagnose duplicate module names or conflicting rel-path ownership when bulk-registering source files. | `DONE` | Added `analyze_wgsl_source_files_for_registry` and `register_wgsl_source_files_checked`. Verified with `moon test` on 2026-04-15 (`30/30` passing), including duplicate module-name and normalized rel-path conflict cases. |
| `WGSL-003` | Local audit | Source-map output is declaration-level and best-effort; ambiguous same-name declarations across registered files only surface as warnings. | `DONE` | Added `build_registered_wgsl_source_catalog` and exposed `source_catalog` on `WgslExportOutput`. Verified with `moon test` on 2026-04-15 (`31/31` passing), including an ambiguous declaration regression test. |
| `WGSL-004` | Design constraint | Direct host filesystem scanning should not become the primary API because this library is intended to remain multi-backend. | `BLOCKED` | Keep registry input portable via `WgslSourceFile` batches unless a portable VFS abstraction is introduced. |
| `WGSL-005` | Upstream parity gap | Source-level `override` / redirect support is still missing from the MoonBit port. | `DONE` | Added `WgslSymbolRedirect`, `rewrite_wgsl_symbol_redirects`, and redirect-aware composer/export APIs. Verified with `moon test` on 2026-04-15 (`34/34` passing), including redirect-aware composition and tree-shaking regression tests. |

## Current work queue

- No active `TODO` / `IN_PROGRESS` issues
