# Keep the moon_wgsl facade thin

`Milky2018/moon_wgsl` will expose the user-facing preprocessing and composition API, but it will not re-export WGSL AST, parser, IR, Naga compatibility internals, source edit backends, or symbol graph implementation types. Users who need those layers should import the owning module directly.

