# Use synchronized workspace releases

The first workspace phase will release `Milky2018/wgsl`, `Milky2018/moon_wgsl_naga`, `Milky2018/moon_wgsl_naga_oil`, and `Milky2018/moon_wgsl` with the same version number. A top-level `publish.mbtx` script will update each member `moon.mod` version and publish them in dependency order with `moon -C modules/<module-name> publish`.

