# Split transform into analysis and compatibility rewrite

The old `transform` package combines WGSL declaration analysis, composer binding rewrites, and naga-oil virtual override handling. The workspace split will separate generic WGSL analysis into WGSL Core while moving binding rewrite, virtual override behavior, and source edit backends into compatibility modules so text rewriting does not become a hidden language semantics layer.

