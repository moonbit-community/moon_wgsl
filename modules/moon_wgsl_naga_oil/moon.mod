name = "Milky2018/moon_wgsl_naga_oil"

version = "0.16.1"

import {
  "Milky2018/wgsl@0.16.1",
  "Milky2018/moon_wgsl_naga@0.16.1",
  "moonbitlang/x@0.4.43",
}

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/moon_wgsl"

license = "Apache-2.0"

keywords = [ "wgsl", "naga-oil", "shader" ]

description = "naga-oil compatible preprocessing and composition for MoonBit WGSL."

rule(
  name: "moonyacc-array",
  command: "moon runwasm moonbitlang/yacc@0.7.17 $input --input-mode array -o $output && moonfmt -w $output",
)
