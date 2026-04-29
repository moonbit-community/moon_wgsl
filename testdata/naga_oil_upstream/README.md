This directory mirrors `bevyengine/naga_oil/src/compose/tests` at commit
`bc444c82bb593ede94c55cdbf799e9743800843e`.

It is the compatibility corpus for full naga_oil alignment. MoonBit tests use
the WGSL subset directly. The optional Rust oracle under `tools/naga_oil_oracle`
uses the same files to run upstream `naga_oil` when a Naga-backed comparison is
needed.
