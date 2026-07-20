name = "Milky2018/moon_wesl"

version = "0.1.2"

import {
  "moonbitlang/x@0.4.43",
  "Milky2018/wgsl@0.16.0",
}

readme = "README.md"

repository = "https://github.com/moonbit-community/moon_wesl"

license = "Apache-2.0"

keywords = [ "wesl", "shader" ]

description = "A MoonBit WESL compiler extracted from mgstudio."

options(
  "bin-deps": { "moonbitlang/yacc": "0.7.13" },
)
