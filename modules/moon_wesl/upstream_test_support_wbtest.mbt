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
let upstream_pending_spec_declaration_case_names : Array[String] = []

///|
let upstream_pending_spec_eval_case_names : Array[String] = []

///|
let upstream_pending_import_case_names : Array[String] = []

///|
let upstream_pending_conditional_case_names : Array[String] = []

///|
let upstream_pending_import_syntax_case_names : Array[String] = []

///|
let upstream_pending_circular_case_names : Array[String] = []

///|
let upstream_pending_bevy_parse_case_paths : Array[String] = []

///|
let upstream_pending_wgpu_parse_case_paths : Array[String] = []

///|
fn upstream_is_whitespace(code : Int) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn upstream_is_digit(code : Int) -> Bool {
  code >= 48 && code <= 57
}

///|
fn upstream_is_ascii_letter(code : Int) -> Bool {
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

///|
fn upstream_is_word_char(code : Int) -> Bool {
  upstream_is_ascii_letter(code) ||
  upstream_is_digit(code) ||
  code == 95 ||
  code >= 128
}

///|
fn upstream_normalize_text(text : String) -> String {
  let parts : Array[String] = []
  let mut word_start : Int? = None
  for i = 0; i < text.length(); i = i + 1 {
    let code = text.code_unit_at(i).to_int()
    if upstream_is_whitespace(code) {
      match word_start {
        Some(begin) => {
          parts.push(text[begin:i].to_owned())
          word_start = None
        }
        None => ()
      }
      continue
    }
    if upstream_is_word_char(code) {
      if word_start is None {
        word_start = Some(i)
      }
      continue
    }
    match word_start {
      Some(begin) => {
        parts.push(text[begin:i].to_owned())
        word_start = None
      }
      None => ()
    }
    parts.push(text[i:i + 1].to_owned())
  }
  match word_start {
    Some(begin) => parts.push(text[begin:text.length()].to_owned())
    None => ()
  }
  parts.join(" ")
}

///|
fn upstream_canonicalize_mangle(text : String) -> String {
  let parts : Array[String] = []
  let mut start = 0
  let mut i = 0
  while i < text.length() {
    let current = text.code_unit_at(i).to_int()
    let next = if i + 1 < text.length() {
      text.code_unit_at(i + 1).to_int()
    } else {
      -1
    }
    let after = if i + 2 < text.length() {
      text.code_unit_at(i + 2).to_int()
    } else {
      -1
    }
    if current == 95 && next == 95 && upstream_is_digit(after) {
      if start < i {
        parts.push(text[start:i].to_owned())
      }
      parts.push("_")
      i = i + 2
      while i < text.length() &&
            upstream_is_digit(text.code_unit_at(i).to_int()) {
        i = i + 1
      }
      start = i
      continue
    }
    i = i + 1
  }
  if start < text.length() {
    parts.push(text[start:text.length()].to_owned())
  }
  parts.join("")
}

///|
fn upstream_normalize_compiled_text(text : String) -> String {
  upstream_normalize_text(upstream_canonicalize_mangle(text))
}

///|
fn upstream_strip_trailing_commas(text : String) -> String {
  let parts : Array[String] = []
  let mut index = 0
  while index < text.length() {
    let code = text.code_unit_at(index).to_int()
    let mut skip_comma = false
    if code == 44 {
      let mut lookahead = index + 1
      while lookahead < text.length() {
        let next_code = text.code_unit_at(lookahead).to_int()
        if !upstream_is_whitespace(next_code) {
          if next_code == 125 || next_code == 41 || next_code == 93 {
            skip_comma = true
          }
          break
        }
        lookahead += 1
      }
    }
    if skip_comma {
      index += 1
      continue
    }
    parts.push(text[index:index + 1].to_owned())
    index += 1
  }
  parts.join("")
}

///|
fn upstream_sort_strings(values : Array[String]) -> Array[String] {
  let sorted : Array[String] = []
  for value in values {
    sorted.push(value)
  }
  for i = 0; i < sorted.length(); i = i + 1 {
    let mut min_index = i
    for j = i + 1; j < sorted.length(); j = j + 1 {
      if sorted[j] < sorted[min_index] {
        min_index = j
      }
    }
    if min_index != i {
      let current = sorted[i]
      sorted[i] = sorted[min_index]
      sorted[min_index] = current
    }
  }
  sorted
}

///|
fn upstream_canonicalize_decl_order(text : String) -> String {
  let path = ModulePath::from_path("/main.wgsl")
  let stripped = upstream_strip_trailing_commas(text)
  let parsed = try parse_translation_unit(path, stripped, true) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match parsed {
    Ok(unit) => {
      let parts : Array[String] = []
      for declaration in unit.declarations() {
        parts.push(upstream_normalize_compiled_text(declaration.source_text()))
      }
      upstream_sort_strings(parts).join("\n")
    }
    Err(_) => upstream_normalize_compiled_text(text)
  }
}

///|
fn upstream_has_suffix(text : String, suffix : String) -> Bool {
  let text_len = text.length()
  let suffix_len = suffix.length()
  if suffix_len > text_len {
    return false
  }
  text[text_len - suffix_len:text_len].to_owned() == suffix
}

///|
fn upstream_is_shader_path(path : String) -> Bool {
  upstream_has_suffix(path, ".wgsl") || upstream_has_suffix(path, ".wesl")
}

///|
fn upstream_fixture_module_path(path : String) -> ModulePath {
  let normalized = if path.length() >= 2 && path[0:2].to_owned() == "./" {
    "/\{path[2:path.length()].to_owned()}"
  } else if path.length() > 0 && path[0:1].to_owned() == "/" {
    path
  } else {
    "/\{path}"
  }
  ModulePath::from_path(normalized)
}

///|
fn upstream_root_module_path(case : UpstreamModuleCase) -> ModulePath {
  for source in case.wesl_sources {
    if source.0 == "./main.wgsl" || source.0 == "./main.wesl" {
      return upstream_fixture_module_path(source.0)
    }
  }
  ModulePath::from_path("/main.wgsl")
}

///|
fn upstream_resolver_for_case(
  case : UpstreamModuleCase,
) -> (VirtualResolver, ModulePath) {
  let resolver = VirtualResolver::new()
  for source in case.wesl_sources {
    resolver.add_module(upstream_fixture_module_path(source.0), source.1)
  }
  (resolver, upstream_root_module_path(case))
}

///|
fn upstream_compile_options(case : UpstreamModuleCase) -> CompileOptions {
  {
    ..CompileOptions::default(),
    keep_root: true,
    lazy_resolution: !case.requires_eager,
    validate: false,
  }
}

///|
fn upstream_compile_module_case(
  case : UpstreamModuleCase,
) -> String raise WeslCompileError {
  let (resolver, root_path) = upstream_resolver_for_case(case)
  compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    upstream_compile_options(case),
  ).to_string()
}

///|
fn upstream_expected_output(case : UpstreamModuleCase) -> String? {
  match case.expected_underscore_wgsl {
    Some(expected) => Some(expected)
    None => case.expected_wgsl
  }
}

///|
fn upstream_array_contains(items : Array[String], target : String) -> Bool {
  for item in items {
    if item == target {
      return true
    }
  }
  false
}
