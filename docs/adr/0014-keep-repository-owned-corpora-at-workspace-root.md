# Keep repository-owned corpora at workspace root

Large repository-owned WGSL corpora and manifests remain at the workspace root instead of inside publishable modules. Module-local tests may keep small fixtures, while workspace integration checks exercise the shared corpus using MoonBit implementations only. External implementation oracles and their generated parity inventories are not maintained in this repository.
