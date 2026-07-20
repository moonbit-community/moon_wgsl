name = "Milky2018/wgsl"

version = "0.16.1"

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/moon_wgsl"

license = "Apache-2.0"

keywords = [ "wgsl", "shader" ]

description = "Official WGSL frontend for MoonBit."

rule(
  name: "moonyacc-array",
  command: "moon runwasm moonbitlang/yacc@0.7.17 $input --input-mode array -o $output && moonfmt -w $output",
)
