// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
test "naga_oil tokenizer treats numeric suffix letters as identifiers" {
  let tokens = tokenize("let x = 1u + 2.0e-3f;", false)
  let identifiers : Array[String] = []
  for token in tokens {
    match token {
      WgslToken::Identifier(name, _) => identifiers.push(name)
      _ => ()
    }
  }
  debug_inspect(
    identifiers,
    content=(
      #|["let", "x", "u", "e", "f"]
    ),
  )
}

///|
test "WGSL tokenizer does not split numeric suffixes into identifiers" {
  let tokens = tokenize_wgsl("let x = 1u + 2.0e-3f;", false)
  let identifiers : Array[String] = []
  for token in tokens {
    match token {
      WgslToken::Identifier(name, _) => identifiers.push(name)
      _ => ()
    }
  }
  debug_inspect(
    identifiers,
    content=(
      #|["let", "x"]
    ),
  )
}

///|
test "WGSL tokenizer emits numeric literals as semantic tokens" {
  let tokens = tokenize_wgsl("let x = 1u + 2.0e-3f;", false)
  debug_inspect(tokens[3], content="Number(\"1u\", 8)")
  debug_inspect(tokens[5], content="Number(\"2.0e-3f\", 13)")
}

///|
test "WGSL tokenizer emits adjacent compound operators only" {
  let tokens = tokenize_wgsl(
    "a >= b; c > = d; fn f() -> u32 { return 1u; }", false,
  )
  debug_inspect(tokens[1], content="Operator(\">=\", 2)")
  debug_inspect(tokens[5], content="Punctuation(62, 10)")
  debug_inspect(tokens[6], content="Punctuation(61, 12)")
  debug_inspect(tokens[13], content="Operator(\"->\", 24)")
}

///|
test "naga_oil tokenizer uses XID identifiers instead of all Unicode" {
  let tokens = tokenize("alpha💡β", false)
  debug_inspect(tokens.length(), content="3")
  debug_inspect(tokens[0], content="Identifier(\"alpha\", 0)")
  debug_inspect(tokens[1], content="Punctuation(128161, 5)")
  debug_inspect(tokens[2], content="Identifier(\"β\", 7)")
}

///|
test "naga_oil tokenizer accepts non-BMP XID identifiers as one token" {
  let tokens = tokenize("𐐀x", false)
  debug_inspect(tokens.length(), content="1")
  debug_inspect(tokens[0], content="Identifier(\"𐐀x\", 0)")
}
