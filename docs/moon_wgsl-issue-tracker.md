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
| `WGSL-004` | Portable I/O support | Cross-backend WGSL source tree scanning is not implemented yet, even though `moonbitlang/x/fs` now provides portable file I/O primitives. | `DONE` | Added `WgslSourceScanOptions`, `scan_wgsl_source_files`, `scan_wgsl_source_files_checked`, plus `Composer::register_wgsl_source_tree` and `Composer::register_wgsl_source_tree_checked` on top of `moonbitlang/x/fs`. Verified with `moon test` on 2026-04-15 (`41/41` passing), including source-tree scanning, duplicate-module diagnostics, and source-tree-backed composition regressions. |
| `WGSL-005` | Upstream parity gap | Source-level `override` / redirect support is still missing from the MoonBit port. | `DONE` | Added `WgslSymbolRedirect`, `rewrite_wgsl_symbol_redirects`, and redirect-aware composer/export APIs. Verified with `moon test` on 2026-04-15 (`34/34` passing), including redirect-aware composition and tree-shaking regression tests. |
| `WGSL-006` | Architecture review | `Composer::add_composable_module` maintains local module metadata, but compose/export still resolve through a separate registry path, so `Composer` is not the actual source-of-truth for composition. | `DONE` | Added Composer-owned registry/module maps plus Composer-scoped registry APIs, and wired `add_composable_module` into that state. Verified with `moon test` on 2026-04-15 (`37/37` passing), including Composer-local registry and composable-module integration tests. |
| `WGSL-007` | Architecture review | Export `source_catalog` / `source_map` currently derive from all registered files instead of the dependency closure of the current compose session. | `DONE` | Export now builds source catalogs and source maps from `WgslComposeSession.resolved_source_files` instead of the full registry. Verified with `moon test` on 2026-04-15 (`37/37` passing), including a dependency-closure scoping regression test. |
| `WGSL-008` | Architecture review | Public compose APIs leak internal session state (`visited`, `modules`) instead of exposing a stable config/session abstraction. | `DONE` | Added `WgslComposeOptions`, `Composer::compose_wgsl`, `Composer::build_wgsl_source_catalog`, and `Composer::export_wgsl_with_options`, while keeping legacy entry points as compatibility wrappers. Verified with `moon test` on 2026-04-15 (`37/37` passing), including config-based compose/export tests. |

## Current work queue

- None.
