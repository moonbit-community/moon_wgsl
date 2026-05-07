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
    match token.identifier_text() {
      Some(name) => identifiers.push(name)
      None => ()
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
    match token.identifier_text() {
      Some(name) => identifiers.push(name)
      None => ()
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
  debug_inspect(tokens[3].number_text(), content="Some(\"1u\")")
  debug_inspect(tokens[3].pos(), content="8")
  debug_inspect(tokens[5].number_text(), content="Some(\"2.0e-3f\")")
  debug_inspect(tokens[5].pos(), content="13")
}

///|
test "WGSL identifier policy is centralized" {
  debug_inspect(wgsl_identifier_text("_valid123"), content="true")
  debug_inspect(wgsl_identifier_text("__"), content="true")
  debug_inspect(wgsl_identifier_text("123bad"), content="false")
  debug_inspect(wgsl_identifier_text("bad💡"), content="false")
  let tokens = tokenize_wgsl("_valid123 __ 123bad bad💡", false)
  debug_inspect(tokens[0].identifier_text(), content="Some(\"_valid123\")")
  debug_inspect(tokens[1].identifier_text(), content="Some(\"__\")")
  debug_inspect(tokens[2].number_text(), content="Some(\"123bad\")")
  debug_inspect(tokens[4].punctuation_code(), content="Some(128161)")
}

///|
test "WGSL tokenizer emits adjacent compound operators only" {
  let tokens = tokenize_wgsl(
    "a >= b; c > = d; fn f() -> u32 { i++; j--; return 1u; }", false,
  )
  debug_inspect(tokens[1].operator_text(), content="Some(\">=\")")
  debug_inspect(tokens[1].pos(), content="2")
  debug_inspect(tokens[5].punctuation_code(), content="Some(62)")
  debug_inspect(tokens[5].pos(), content="10")
  debug_inspect(tokens[6].punctuation_code(), content="Some(61)")
  debug_inspect(tokens[6].pos(), content="12")
  debug_inspect(tokens[13].operator_text(), content="Some(\"->\")")
  debug_inspect(tokens[13].pos(), content="24")
  debug_inspect(tokens[17].operator_text(), content="Some(\"++\")")
  debug_inspect(tokens[17].pos(), content="34")
  debug_inspect(tokens[20].operator_text(), content="Some(\"--\")")
  debug_inspect(tokens[20].pos(), content="39")
}

///|
test "naga_oil tokenizer uses XID identifiers instead of all Unicode" {
  let tokens = tokenize("alpha💡β", false)
  debug_inspect(tokens.length(), content="3")
  debug_inspect(tokens[0].identifier_text(), content="Some(\"alpha\")")
  debug_inspect(tokens[1].punctuation_code(), content="Some(128161)")
  debug_inspect(tokens[1].pos(), content="5")
  debug_inspect(tokens[2].identifier_text(), content="Some(\"β\")")
  debug_inspect(tokens[2].pos(), content="7")
}

///|
test "naga_oil tokenizer accepts non-BMP XID identifiers as one token" {
  let tokens = tokenize("𐐀x", false)
  debug_inspect(tokens.length(), content="1")
  debug_inspect(tokens[0].identifier_text(), content="Some(\"𐐀x\")")
}
