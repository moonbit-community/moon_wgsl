# Use synchronized workspace releases

The synchronized workspace line releases `Milky2018/wgsl`, `Milky2018/moon_wgsl_naga`, `Milky2018/moon_wgsl_naga_oil`, and `Milky2018/moon_wgsl` with the same version number. `Milky2018/moon_wesl` follows its own semantic version because its public API began in a separate repository, but it pins the synchronized WGSL Core version. A top-level `publish.mbtx` script updates both version lines and publishes the modules in dependency order with `moon -C modules/<module-name> publish`.
