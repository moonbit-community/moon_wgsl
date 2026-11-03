name = "Milky2018/wgsl"

version = "0.17.5"

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/moon_wgsl"

license = "Apache-2.0"

keywords = [ "wgsl", "shader" ]

description = "Official WGSL frontend for MoonBit."

rule(
  name: "moonyacc-array",
  command: "moon runwasm moonbitlang/yacc@0.7.23 $input --input-mode array -o $output && sed 's/@list[.]empty()/List([])/g' $output > $output.tmp && mv $output.tmp $output && moonfmt -w $output",
)
