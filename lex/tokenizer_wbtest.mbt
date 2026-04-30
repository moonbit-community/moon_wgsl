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
test "naga_oil tokenizer uses XID identifiers instead of all Unicode" {
  let tokens = tokenize("alpha💡β", false)
  debug_inspect(tokens.length(), content="4")
  debug_inspect(tokens[0], content="Identifier(\"alpha\", 0)")
  debug_inspect(tokens[1], content="Other(55357, 5)")
  debug_inspect(tokens[2], content="Other(56481, 6)")
  debug_inspect(tokens[3], content="Identifier(\"β\", 7)")
}
