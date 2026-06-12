# Use CTS and Naga as WGSL oracle baselines

WGSL Core correctness will be measured against pinned GPUWeb CTS cases and pinned Naga parser/validator behavior. wgpu validation may remain as an isolated tool for pipeline and binding checks, but it must not become a dependency of the core WGSL module.

