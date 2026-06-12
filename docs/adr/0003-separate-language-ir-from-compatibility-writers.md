# Separate language IR from compatibility writers

WGSL Core may own semantic IR, validation, and a generic valid-WGSL writer, but it must not own Naga-compatible byte writers, naga-oil writer policy, trace tooling, or compatibility name-allocation behavior. Those mechanisms belong in the Naga or naga-oil compatibility modules so the language model remains smaller and does not accumulate upstream-specific output policy.

