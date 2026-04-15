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
| `WGSL-002` | Local audit | Registry APIs do not diagnose duplicate module names or conflicting rel-path ownership when bulk-registering source files. | `TODO` | Add preflight analysis or registration diagnostics before mutating global registry state. |
| `WGSL-003` | Local audit | Source-map output is declaration-level and best-effort; ambiguous same-name declarations across registered files only surface as warnings. | `TODO` | Improve precision or add explicit source-catalog APIs for downstream tooling. |
| `WGSL-004` | Design constraint | Direct host filesystem scanning should not become the primary API because this library is intended to remain multi-backend. | `BLOCKED` | Keep registry input portable via `WgslSourceFile` batches unless a portable VFS abstraction is introduced. |
| `WGSL-005` | Upstream parity gap | Source-level `override` / redirect support is still missing from the MoonBit port. | `TODO` | Design a WGSL-only rewrite pass that does not depend on Naga IR. |

## Current work queue

- `WGSL-002` registry collision diagnostics
- `WGSL-003` source-map precision improvements
- `WGSL-005` source-level override and redirect support
