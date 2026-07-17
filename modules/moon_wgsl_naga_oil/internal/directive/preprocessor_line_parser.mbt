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
pub(all) enum WgslPreprocessorDirectiveKind {
  Ifdef
  Ifndef
  If
  Else
  Endif
  DefineImportPath
  Define
  Import
  Enable
  Requires
  Diagnostic
  Other
} derive(Eq, Debug)

///|
pub struct WgslPreprocessorIdent {
  priv name : String
  priv start : Int
  priv end : Int
} derive(Debug)

///|
fn WgslPreprocessorIdent::WgslPreprocessorIdent(
  name : String,
  start : Int,
  end : Int,
) -> WgslPreprocessorIdent {
  { name, start, end }
}

///|
pub fn WgslPreprocessorIdent::name(self : WgslPreprocessorIdent) -> String {
  self.name
}

///|
pub fn WgslPreprocessorIdent::start(self : WgslPreprocessorIdent) -> Int {
  self.start
}

///|
pub fn WgslPreprocessorIdent::end(self : WgslPreprocessorIdent) -> Int {
  self.end
}

///|
pub struct WgslPreprocessorDirectiveTail {
  priv text : String
  priv start : Int
  priv end : Int
  priv has_required_separator : Bool
} derive(Debug)

///|
fn WgslPreprocessorDirectiveTail::WgslPreprocessorDirectiveTail(
  text : String,
  start : Int,
  end : Int,
  has_required_separator : Bool,
) -> WgslPreprocessorDirectiveTail {
  { text, start, end, has_required_separator }
}

///|
pub struct WgslPreprocessorDirective {
  priv kind : WgslPreprocessorDirectiveKind
  priv name : WgslPreprocessorIdent
  priv tail : WgslPreprocessorDirectiveTail
  priv start : Int
  priv end : Int
} derive(Debug)

///|
fn WgslPreprocessorDirective::WgslPreprocessorDirective(
  kind : WgslPreprocessorDirectiveKind,
  name : WgslPreprocessorIdent,
  tail : WgslPreprocessorDirectiveTail,
  start : Int,
  end : Int,
) -> WgslPreprocessorDirective {
  { kind, name, tail, start, end }
}

///|
pub fn WgslPreprocessorDirective::kind(
  self : WgslPreprocessorDirective,
) -> WgslPreprocessorDirectiveKind {
  self.kind
}

///|
pub fn WgslPreprocessorDirective::name(
  self : WgslPreprocessorDirective,
) -> WgslPreprocessorIdent {
  self.name
}

///|
pub fn WgslPreprocessorDirective::tail(
  self : WgslPreprocessorDirective,
) -> String {
  self.tail.text
}

///|
pub fn WgslPreprocessorDirective::has_tail(
  self : WgslPreprocessorDirective,
) -> Bool {
  self.tail.text != ""
}

///|
pub fn WgslPreprocessorDirective::has_required_tail_separator(
  self : WgslPreprocessorDirective,
) -> Bool {
  self.tail.has_required_separator
}

///|
pub fn WgslPreprocessorDirective::start(
  self : WgslPreprocessorDirective,
) -> Int {
  self.start
}

///|
pub fn WgslPreprocessorDirective::end(self : WgslPreprocessorDirective) -> Int {
  self.end
}

///|
pub fn WgslPreprocessorDirective::tail_start(
  self : WgslPreprocessorDirective,
) -> Int {
  self.tail.start
}

///|
pub fn WgslPreprocessorDirective::tail_end(
  self : WgslPreprocessorDirective,
) -> Int {
  self.tail.end
}

///|
fn wgsl_directive_identifier_code_unit(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
fn wgsl_directive_line_trim_ascii_space_end(text : String, start : Int) -> Int {
  let mut end = text.length()
  while end > start {
    let code = text.code_unit_at(end - 1).to_int()
    if wgsl_regex_whitespace_code_point(code) {
      end = end - 1
      continue
    }
    break
  }
  end
}

///|
fn wgsl_directive_line_kind(name : String) -> WgslPreprocessorDirectiveKind {
  match name {
    "ifdef" => Ifdef
    "ifndef" => Ifndef
    "if" => If
    "else" => Else
    "endif" => Endif
    "define_import_path" => DefineImportPath
    "define" => Define
    "import" => Import
    "enable" => Enable
    "requires" => Requires
    "diagnostic" => Diagnostic
    _ => Other
  }
}

///|
pub fn parse_wgsl_directive_line_at(
  line : String,
  source_start : Int,
) -> WgslPreprocessorDirective? {
  let hash_start = wgsl_regex_skip_whitespace(line, 0)
  guard hash_start < line.length() &&
    line.code_unit_at(hash_start).to_int() == 35 else {
    return None
  }
  let body_start = wgsl_regex_skip_whitespace(line, hash_start + 1)
  let mut name_end = body_start
  while name_end < line.length() &&
        wgsl_directive_identifier_code_unit(
          line.code_unit_at(name_end).to_int(),
        ) {
    name_end = name_end + 1
  }
  guard name_end > body_start else { return None }
  let name = line[body_start:name_end].to_owned()
  let tail_start = wgsl_regex_skip_whitespace(line, name_end)
  let tail_end = wgsl_directive_line_trim_ascii_space_end(line, tail_start)
  let tail = if tail_end > tail_start {
    line[tail_start:tail_end].to_owned()
  } else {
    ""
  }
  let text_end = if tail != "" { tail_end } else { name_end }
  let absolute_hash_start = source_start + hash_start
  let absolute_text_end = source_start + text_end
  let absolute_name_start = source_start + body_start
  let absolute_name_end = source_start + name_end
  let absolute_tail_start = if tail == "" {
    absolute_name_end
  } else {
    source_start + tail_start
  }
  let absolute_tail_end = if tail == "" {
    absolute_name_end
  } else {
    source_start + tail_end
  }
  WgslPreprocessorDirective(
    wgsl_directive_line_kind(name),
    WgslPreprocessorIdent(name, absolute_name_start, absolute_name_end),
    WgslPreprocessorDirectiveTail(
      tail,
      absolute_tail_start,
      absolute_tail_end,
      tail != "" && absolute_tail_start > absolute_name_end,
    ),
    absolute_hash_start,
    absolute_text_end,
  )
  |> Some
}

///|
pub fn parse_wgsl_directive_line(line : String) -> WgslPreprocessorDirective? {
  parse_wgsl_directive_line_at(line, 0)
}
