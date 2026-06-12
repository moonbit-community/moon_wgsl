# Drop legacy subpackage compatibility

The workspace split will not preserve old internal paths such as `Milky2018/wgsl/parser`, `Milky2018/wgsl/ast`, `Milky2018/wgsl/ir`, or `Milky2018/wgsl/lex`. The `moon_wgsl` product may remain as a facade, but internal language and compatibility APIs should move to their ideal modules instead of being kept alive through forwarding packages.

