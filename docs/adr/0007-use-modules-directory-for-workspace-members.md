# Use a modules directory for workspace members

Published workspace members will live under `modules/` rather than directly under the repository root. This keeps product modules such as `wgsl`, `moon_wgsl`, `moon_wgsl_naga`, and `moon_wgsl_naga_oil` separate from repository-level documentation, issues, tools, testdata, and CI infrastructure.

