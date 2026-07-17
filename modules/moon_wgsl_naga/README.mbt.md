# Milky2018/moon_wgsl_naga

Naga-compatible WGSL utilities for MoonBit.

This module is the public boundary for compatibility writer behavior used by
parity and composer pipelines. It depends on `Milky2018/wgsl` and exposes
Naga-shaped roundtrip and trace entry points without requiring users to import
the facade module.

Use this module when you need writer/order/name compatibility checks or
diagnostic traces. Use `Milky2018/wgsl` for the language frontend itself and
`Milky2018/moon_wgsl_naga_oil` for naga-oil preprocessing and composition.

The writer reuses WGSL Core's neutral reachability, expression-type, and type
spelling services through narrow interfaces. This module still owns the
compatibility view, arena ordering, final names, temporary scheduling, byte
policy, and trace behavior; no writer source is shared through filesystem
links or copied neutral implementations.
