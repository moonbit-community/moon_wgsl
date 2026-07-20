This fixture contains complete WGSL files copied from the public Bevy shader
tree at commit `0e49f63973daf8286963e6d749c5d487fef649b9`.

The root files under `mgstudio/render/renderer/` are import-only Bevy-style
entry roots used to verify strict upstream `naga_oil` tree-shaking behavior.
A small number of Bevy files include `#define_import_path` metadata so the
MoonBit test registry can resolve them without Bevy's host-side shader module
descriptors.
