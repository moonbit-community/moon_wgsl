name = "Milky2018/moon_wesl"

version = "0.17.5"

import {
  "Milky2018/wgsl@0.17.5",
}

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/moon_wgsl"

license = "Apache-2.0"

keywords = [ "wesl", "wgsl", "shader" ]

description = "A WESL module compiler for MoonBit backed by WGSL Core."

rule(
  name: "moonyacc-tokens",
  command: "moon runwasm moonbitlang/yacc@0.7.23 $input --mode only-tokens -o $output && sed 's/@list[.]empty()/List([])/g' $output > $output.tmp && mv $output.tmp $output && moonfmt -w $output",
)

rule(
  name: "moonyacc-external-array",
  command: "moon runwasm moonbitlang/yacc@0.7.23 $input --external-tokens --input-mode array -o $output && sed 's/@list[.]empty()/List([])/g' $output > $output.tmp && mv $output.tmp $output && moonfmt -w $output",
)
