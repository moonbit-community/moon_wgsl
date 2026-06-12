# Make composer graph and plan driven

The naga-oil composer will use structured `ComposeGraph`, `SymbolGraph`, `FinalNameTable`, and `EmissionPlan` models as its semantic facts instead of source fragments or rewrite maps. Source edit mechanisms may remain as final emission backends, but they must consume already-bound plans rather than deciding imports, reachability, aliases, or final names.

