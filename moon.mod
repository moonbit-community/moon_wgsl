name = "Milky2018/moon_wgsl"

version = "0.14.0"

import {
  "moonbitlang/x@0.4.43",
  "moonbitlang/yacc@0.7.13",
}

readme = "README.md"

repository = "https://github.com/moonbit-community/moon_wgsl"

license = "Apache-2.0"

keywords = [ "wgsl", "shader" ]

description = "WGSL preprocess and composer utilities aligned with naga_oil."

options(
  "bin-deps": { "moonbitlang/yacc": "0.7.13" },
  exclude: [
    "testdata",
    "tools/naga_oil_oracle",
    "tools/remotion_preprocess_demo",
  ],
)
