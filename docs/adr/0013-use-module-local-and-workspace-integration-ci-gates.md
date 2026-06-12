# Use module-local and workspace integration CI gates

CI will have module-local fast gates for `wgsl`, `moon_wgsl_naga`, `moon_wgsl_naga_oil`, and `moon_wgsl`, plus workspace-level integration gates for external corpora, naga-oil byte parity, wgpu validation, and publish packaging checks. This keeps failures attributable to the module that owns the behavior instead of routing every regression through one monolithic gate.

