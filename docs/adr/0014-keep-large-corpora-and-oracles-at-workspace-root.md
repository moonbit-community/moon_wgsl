# Keep large corpora and oracles at workspace root

Large WGSL corpora, upstream fixtures, manifests, oracle binaries, and wgpu validation tools will remain at the workspace root instead of inside publishable modules. Module-local tests may keep small fixtures, while heavyweight parity and validation gates run as workspace integration checks.

