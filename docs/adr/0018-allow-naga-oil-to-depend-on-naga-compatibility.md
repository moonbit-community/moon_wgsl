# Allow naga-oil to depend on Naga compatibility

`Milky2018/moon_wgsl_naga_oil` may depend on `Milky2018/moon_wgsl_naga` for explicitly Naga-shaped writer, ordering, and parity behavior. It must still own naga-oil import, alias, reachability, and composition semantics instead of deriving those facts from Naga temporary names or writer plans.

