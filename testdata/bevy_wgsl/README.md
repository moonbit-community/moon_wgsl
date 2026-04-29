This fixture contains complete WGSL files copied from the public Bevy shader
tree at commit `0e49f63973daf8286963e6d749c5d487fef649b9`.

The root files under `mgstudio/render/renderer/` model the Bevy-style entry
imports used by mgstudio. A small number of Bevy files include
`#define_import_path` metadata so the MoonBit test registry can resolve them
without Bevy's Rust-side shader module descriptors.
