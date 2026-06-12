# Publish Naga compatibility as a first-class module

The workspace will publish `Milky2018/moon_wgsl_naga` as a formal module rather than treating it as a hidden implementation detail. This makes Naga-compatible writer, validation, ordering, and trace behavior an explicit compatibility product with its own API boundary instead of leaking through `moon_wgsl` or `wgsl`.

