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
fn parse_imports_snapshot(input : String) -> String {
  let declared_imports : Array[DeclaredImportBinding] = []
  parse_imports(input, declared_imports) catch {
    Parse(message, offset) => return "ERR \{offset.to_string()} \{message}"
  }

  let rows : Array[String] = []
  for binding in declared_imports {
    let full_paths = binding.full_paths.join(",")
    rows.push("\{binding.used_name}=\{full_paths}")
  }
  rows.join("\n")
}

///|
test "naga_oil wb: parse_imports matches upstream top-level item-list disambiguation" {
  debug_inspect(
    parse_imports_snapshot("#import a::b c, d\n"),
    content="\"c=a::b::c\\nd=a::b::d\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a::b c\n"),
    content="\"c=a::b::c\"",
  )
}

///|
test "naga_oil wb: parse_imports matches upstream grouped nested imports" {
  debug_inspect(
    parse_imports_snapshot(
      "#import a::b::{c::{d, e}, f, g::{h as i, j::k::l as m}}\n",
    ),
    content="\"d=a::b::c::d\\ne=a::b::c::e\\nf=a::b::f\\ni=a::b::g::h\\nm=a::b::g::j::k::l\"",
  )
}

///|
test "naga_oil wb: parse_imports matches upstream quoted path grouping" {
  debug_inspect(
    parse_imports_snapshot(
      "#import \"path//with\\\\ all sorts of .stuff\"::{a, b}\n",
    ),
    content="\"a=\\\"path//with\\\\\\\\ all sorts of .stuff\\\"::a\\nb=\\\"path//with\\\\\\\\ all sorts of .stuff\\\"::b\"",
  )
}

///|
test "naga_oil wb: parse_imports rejects malformed imports like upstream" {
  debug_inspect(
    parse_imports_snapshot("#import a::b::{{c}\n").has_prefix("ERR "),
    content="true",
  )
  debug_inspect(
    parse_imports_snapshot("#import a:b\n").has_prefix("ERR "),
    content="true",
  )
}
