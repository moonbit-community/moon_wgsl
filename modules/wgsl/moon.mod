name = "Milky2018/wgsl"

version = "0.15.1"

import {
  "moonbitlang/x@0.4.43",
  "moonbitlang/yacc@0.7.13",
}

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/moon_wgsl"

license = "Apache-2.0"

keywords = [ "wgsl", "shader" ]

description = "Official WGSL frontend for MoonBit."

options(
  "bin-deps": { "moonbitlang/yacc": "0.7.13" },
)
