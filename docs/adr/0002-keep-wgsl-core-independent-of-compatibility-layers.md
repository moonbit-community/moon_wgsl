# Keep WGSL Core independent of compatibility layers

`Milky2018/wgsl` will be the language fact source and must not depend on `Milky2018/moon_wgsl`, `Milky2018/moon_wgsl_naga`, `Milky2018/moon_wgsl_naga_oil`, or future WESL modules. Compatibility behavior for Naga, naga-oil, and WESL must live outside WGSL Core so real-world compatibility fixes do not corrupt the base WGSL model.

