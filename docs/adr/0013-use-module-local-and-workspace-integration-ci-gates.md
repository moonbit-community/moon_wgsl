# Use module-local and workspace integration CI gates

CI has module-local fast gates for `wgsl`, `moon_wgsl_naga`, `moon_wgsl_naga_oil`, `moon_wgsl`, and `moon_wesl`, plus workspace-level integration gates for MoonBit-owned corpora, architecture checks, performance checks, and publish packaging. External implementation parity is not a release gate. This keeps failures attributable to the module that owns the behavior instead of routing every regression through one monolithic gate.
