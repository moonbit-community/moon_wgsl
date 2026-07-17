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
fn deduplicate_identical_wgsl_declarations(
  source : String,
) -> String raise ComposerError {
  let unit = parse_wgsl_translation_unit_strict(source) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  let declarations_by_name : Map[String, String] = Map([])
  let duplicate_spans : Array[(Int, Int)] = []
  for declaration in unit.declarations() {
    let name = declaration.name()
    if name == "" {
      continue
    }
    let start = declaration.start()
    let end_ = declaration.end()
    let declaration_source = source[start:end_].to_owned()
    match declarations_by_name.get(name) {
      None => declarations_by_name.set(name, declaration_source)
      Some(existing) =>
        if existing == declaration_source {
          duplicate_spans.push((start, end_))
        } else {
          raise InvalidWgslSyntax(
            "conflicting declarations for `\{name}` after shader import composition",
            start,
          )
        }
    }
  }
  if duplicate_spans.length() == 0 {
    return source
  }
  let out = StringBuilder::new(size_hint=source.length())
  let mut cursor = 0
  for span in duplicate_spans {
    let (start, end_) = span
    out.write_string(source[cursor:start].to_owned())
    cursor = end_
  }
  out.write_string(source[cursor:].to_owned())
  out.to_string()
}

///|
fn finalize_wgsl_output_source(source : String) -> String raise ComposerError {
  let source = deduplicate_identical_wgsl_declarations(source)
  validate_wgsl_translation_unit_strict(source)
  source
}
