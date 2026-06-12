name = "Milky2018/moon_wgsl_tools"

version = "0.14.0"

import {
  "Milky2018/wgsl@0.14.0",
  "Milky2018/moon_wgsl_naga_oil@0.14.0",
  "moonbitlang/x@0.4.43",
}

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/moon_wgsl"

license = "Apache-2.0"

keywords = [ "wgsl", "shader", "tools" ]

description = "Workspace-only developer tools for moon_wgsl."

options(
  exclude: [ "naga_oil_oracle", "remotion_preprocess_demo", "wgpu_validation" ],
)
