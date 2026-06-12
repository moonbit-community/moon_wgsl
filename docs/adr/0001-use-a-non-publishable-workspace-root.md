# Use a non-publishable workspace root

The repository will be organized as a workspace whose root is not itself a published MoonBit product. Published modules such as `Milky2018/wgsl`, `Milky2018/moon_wgsl`, and the Naga or naga-oil compatibility modules will live under subdirectories so that workspace-level documentation, tools, testdata, and cross-module validation do not leak into a product package.

