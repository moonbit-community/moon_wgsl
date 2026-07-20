name = "Milky2018/moon_wesl"

version = "0.2.0"

import {
  "Milky2018/wgsl@0.16.1",
}

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/moon_wgsl"

license = "Apache-2.0"

keywords = [ "wesl", "wgsl", "shader" ]

description = "A WESL module compiler for MoonBit backed by WGSL Core."

rule(
  name: "moonyacc-tokens",
  command: "moon runwasm moonbitlang/yacc@0.7.17 $input --mode only-tokens -o $output && moonfmt -w $output",
)

rule(
  name: "moonyacc-external-array",
  command: "moon runwasm moonbitlang/yacc@0.7.17 $input --external-tokens --input-mode array -o $output && moonfmt -w $output",
)
