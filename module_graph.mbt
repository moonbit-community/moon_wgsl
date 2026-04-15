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
pub struct WgslImportTarget {
  raw_path : String
  alias_name : String
} derive(Eq, Debug)

///|
pub struct WgslResolvedImportModule {
  module_path : String
  rel_path : String
} derive(Eq, Debug)

///|
fn join_wgsl_import_prefix(prefix : String, path : String) -> String {
  let lhs = prefix.trim().to_string()
  let rhs = path.trim().to_string()
  if lhs == "" {
    rhs
  } else if rhs == "" {
    lhs
  } else {
    "\{lhs}::\{rhs}"
  }
}

///|
fn find_top_level_wgsl_group_separator(text : String) -> Int {
  let mut depth = 0
  let mut in_quote = false
  let mut i = 0
  while i + 2 < text.length() {
    let ch = text.code_unit_at(i).to_int()
    if ch == 34 { // '"'
      in_quote = !in_quote
      i = i + 1
      continue
    }
    if in_quote {
      i = i + 1
      continue
    }
    if ch == 123 { // '{'
      depth = depth + 1
      i = i + 1
      continue
    }
    if ch == 125 { // '}'
      depth = depth - 1
      i = i + 1
      continue
    }
    if depth == 0 &&
      ch == 58 &&
      text.code_unit_at(i + 1).to_int() == 58 &&
      text.code_unit_at(i + 2).to_int() == 123 {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn split_top_level_wgsl_import_items(text : String) -> Array[String] {
  let items : Array[String] = []
  let mut start = 0
  let mut depth = 0
  let mut in_quote = false
  for i in 0..<text.length() {
    let ch = text.code_unit_at(i).to_int()
    if ch == 34 { // '"'
      in_quote = !in_quote
      continue
    }
    if in_quote {
      continue
    }
    if ch == 123 { // '{'
      depth = depth + 1
      continue
    }
    if ch == 125 { // '}'
      depth = depth - 1
      continue
    }
    if ch == 44 && depth == 0 { // ','
      let item = text[start:i].to_string().trim().to_string()
      if item != "" {
        items.push(trim_trailing_semicolons(item))
      }
      start = i + 1
    }
  }
  let tail = text[start:text.length()].to_string().trim().to_string()
  if tail != "" {
    items.push(trim_trailing_semicolons(tail))
  }
  items
}

///|
fn extract_wgsl_group_body(text : String, open_brace_index : Int) -> String {
  let mut depth = 0
  let mut body_start = open_brace_index + 1
  let mut in_quote = false
  for i in open_brace_index..<text.length() {
    let ch = text.code_unit_at(i).to_int()
    if ch == 34 { // '"'
      in_quote = !in_quote
      continue
    }
    if in_quote {
      continue
    }
    if ch == 123 { // '{'
      depth = depth + 1
      if depth == 1 {
        body_start = i + 1
      }
      continue
    }
    if ch == 125 { // '}'
      depth = depth - 1
      if depth == 0 {
        return text[body_start:i].to_string()
      }
    }
  }
  ""
}

///|
fn find_top_level_wgsl_alias_separator(text : String) -> Int {
  let mut depth = 0
  let mut in_quote = false
  let mut i = 0
  while i + 3 < text.length() {
    let ch = text.code_unit_at(i).to_int()
    if ch == 34 { // '"'
      in_quote = !in_quote
      i = i + 1
      continue
    }
    if in_quote {
      i = i + 1
      continue
    }
    if ch == 123 { // '{'
      depth = depth + 1
      i = i + 1
      continue
    }
    if ch == 125 { // '}'
      depth = depth - 1
      i = i + 1
      continue
    }
    if depth == 0 &&
      ch == 32 &&
      text.code_unit_at(i + 1).to_int() == 97 &&
      text.code_unit_at(i + 2).to_int() == 115 &&
      text.code_unit_at(i + 3).to_int() == 32 {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn find_top_level_wgsl_itemlist_separator(text : String) -> Int {
  let mut depth = 0
  let mut in_quote = false
  let mut i = 0
  while i < text.length() {
    let ch = text.code_unit_at(i).to_int()
    if ch == 34 { // '"'
      in_quote = !in_quote
      i = i + 1
      continue
    }
    if in_quote {
      i = i + 1
      continue
    }
    if ch == 123 { // '{'
      depth = depth + 1
      i = i + 1
      continue
    }
    if ch == 125 { // '}'
      depth = depth - 1
      i = i + 1
      continue
    }
    let is_whitespace = ch == 32 || ch == 9 || ch == 10 || ch == 13
    if depth == 0 && is_whitespace {
      let lhs = text[:i].to_string().trim().to_string()
      let mut j = i + 1
      while j < text.length() {
        let code = text.code_unit_at(j).to_int()
        let more_whitespace = code == 32 ||
          code == 9 ||
          code == 10 ||
          code == 13
        if !more_whitespace {
          break
        }
        j = j + 1
      }
      let rhs = text[j:text.length()].to_string().trim().to_string()
      if lhs != "" && rhs != "" && !starts_with_text(rhs, "as ") {
        return i
      }
    }
    i = i + 1
  }
  -1
}

///|
pub fn collect_wgsl_import_targets(
  spec : String,
  prefix : String,
  targets : Array[WgslImportTarget],
) -> Unit {
  let text = trim_trailing_semicolons(spec.trim().to_string())
  if text == "" {
    return
  }
  let group_separator = find_top_level_wgsl_group_separator(text)
  if group_separator >= 0 {
    let group_prefix = text[:group_separator].to_string().trim().to_string()
    let body = extract_wgsl_group_body(text, group_separator + 2)
    let next_prefix = join_wgsl_import_prefix(prefix, group_prefix)
    for item in split_top_level_wgsl_import_items(body) {
      collect_wgsl_import_targets(item, next_prefix, targets)
    }
    return
  }
  let mut raw_path = text
  let mut alias_name = ""
  let alias_separator = find_top_level_wgsl_alias_separator(text)
  if alias_separator >= 0 {
    raw_path = text[:alias_separator].to_string().trim().to_string()
    alias_name = trim_trailing_semicolons(
      text[alias_separator + 4:text.length()].to_string().trim().to_string(),
    )
  } else {
    let itemlist_separator = find_top_level_wgsl_itemlist_separator(text)
    if itemlist_separator >= 0 {
      let list_prefix = text[:itemlist_separator].to_string().trim().to_string()
      let body = text[itemlist_separator:text.length()]
        .to_string()
        .trim()
        .to_string()
      let next_prefix = join_wgsl_import_prefix(prefix, list_prefix)
      for item in split_top_level_wgsl_import_items(body) {
        collect_wgsl_import_targets(item, next_prefix, targets)
      }
      return
    }
  }
  raw_path = trim_trailing_semicolons(raw_path.trim().to_string())
  if raw_path == "" {
    return
  }
  targets.push(WgslImportTarget::{
    raw_path: join_wgsl_import_prefix(prefix, raw_path),
    alias_name,
  })
}

///|
pub fn normalize_shader_rel_path(rel : String) -> String {
  let mut text = rel.trim().to_string()
  let n = text.length()
  let mut i = 0
  while i < n && text.code_unit_at(i).to_int() == 47 { // '/'
    i = i + 1
  }
  if i != 0 {
    text = text[i:n].to_string()
  }
  while text.length() >= 2 && text[:2].to_string() == "./" {
    text = text[2:text.length()].to_string()
  }
  if text.length() >= 7 && text[:7].to_string() == "assets/" {
    text = text[7:text.length()].to_string()
  }
  let normalized_segments : Array[String] = []
  for raw_segment in text.split("/") {
    let segment = raw_segment.to_string().trim().to_string()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      if normalized_segments.length() > 0 {
        normalized_segments.pop() |> ignore
      }
      continue
    }
    normalized_segments.push(segment)
  }
  normalized_segments.join("/")
}

///|
fn shader_parent_rel_path(rel_path : String) -> String {
  let normalized = normalize_shader_rel_path(rel_path)
  if normalized == "" {
    return ""
  }
  let segments : Array[String] = []
  for raw_segment in normalized.split("/") {
    let segment = raw_segment.to_string()
    if segment != "" {
      segments.push(segment)
    }
  }
  if segments.length() == 0 {
    return ""
  }
  segments.pop() |> ignore
  segments.join("/")
}

///|
fn unquote_wgsl_import_path(import_path : String) -> String? {
  let trimmed = import_path.trim().to_string()
  if trimmed.length() >= 2 &&
    trimmed.code_unit_at(0).to_int() == 34 &&
    trimmed.code_unit_at(trimmed.length() - 1).to_int() == 34 {
    return Some(trimmed[1:trimmed.length() - 1].to_string())
  }
  None
}

///|
fn wgsl_import_looks_like_file_path(import_path : String) -> Bool {
  if unquote_wgsl_import_path(import_path) is Some(_) {
    return true
  }
  let trimmed = import_path.trim().to_string()
  if trimmed == "" {
    return false
  }
  trimmed.contains("/") ||
  trimmed.has_suffix(".wgsl") ||
  starts_with_text(trimmed, "./") ||
  starts_with_text(trimmed, "../")
}

///|
pub fn resolve_wgsl_import_file_path(
  importer_rel_path : String,
  import_path : String,
) -> String? {
  guard wgsl_import_looks_like_file_path(import_path) else { return None }
  let raw_path = match unquote_wgsl_import_path(import_path) {
    Some(path) => path
    None => import_path.trim().to_string()
  }
  let normalized = if starts_with_text(raw_path, "./") ||
    starts_with_text(raw_path, "../") {
    let parent = shader_parent_rel_path(importer_rel_path)
    if parent == "" {
      normalize_shader_rel_path(raw_path)
    } else {
      normalize_shader_rel_path("\{parent}/\{raw_path}")
    }
  } else {
    normalize_shader_rel_path(raw_path)
  }
  if normalized == "" {
    return None
  }
  if registered_wgsl_sources_ref.val.contains(normalized) {
    return Some(normalized)
  }
  None
}

///|
pub fn resolve_wgsl_source_file_path(
  _assets_base : String,
  rel : String,
) -> String? {
  let normalized_rel = normalize_shader_rel_path(rel)
  if normalized_rel == "" {
    return None
  }
  if registered_wgsl_sources_ref.val.contains(normalized_rel) {
    return Some(normalized_rel)
  }
  None
}

///|
let registered_wgsl_sources_ref : Ref[@hashmap.HashMap[String, String]] = Ref::new(
  @hashmap.HashMap::new(),
)

///|
let registered_wgsl_import_modules_ref : Ref[@hashmap.HashMap[String, String]] = Ref::new(
  @hashmap.HashMap::new(),
)

///|
pub fn clear_registered_wgsl_source_registry() -> Unit {
  registered_wgsl_sources_ref.val = @hashmap.HashMap::new()
  registered_wgsl_import_modules_ref.val = @hashmap.HashMap::new()
}

///|
pub fn register_wgsl_source(rel_path : String, source : String) -> Unit {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  if normalized_rel == "" {
    return
  }
  registered_wgsl_sources_ref.val.set(normalized_rel, source)
  let (import_path, _, _) = get_preprocessor_data(source)
  if import_path is Some(path) && path != "" {
    registered_wgsl_import_modules_ref.val.set(path, normalized_rel)
  }
}

///|
fn push_wgsl_registry_diagnostic(
  diagnostics : Array[WgslDiagnostic],
  severity : WgslDiagnosticSeverity,
  message : String,
  rel_path : String?,
  symbol_name : String?,
) -> Unit {
  diagnostics.push(WgslDiagnostic::{
    severity,
    message,
    rel_path,
    symbol_name,
    generated_start: None,
    source_start: None,
  })
}

///|
fn wgsl_diagnostics_has_error(diagnostics : Array[WgslDiagnostic]) -> Bool {
  for diagnostic in diagnostics {
    if diagnostic.severity == WgslDiagnosticSeverity::Error {
      return true
    }
  }
  false
}

///|
pub fn analyze_wgsl_source_files_for_registry(
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  let diagnostics : Array[WgslDiagnostic] = []
  let existing_sources = copy_registered_wgsl_source_files()
  let existing_rel_to_source : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for source_file in existing_sources {
    existing_rel_to_source.set(
      normalize_shader_rel_path(source_file.rel_path),
      source_file.source,
    )
  }
  let existing_modules = copy_registered_wgsl_import_module_paths()
  let batch_rel_to_source : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let batch_module_to_rel : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()

  for source_file in files {
    let normalized_rel = normalize_shader_rel_path(source_file.rel_path)
    if normalized_rel == "" {
      push_wgsl_registry_diagnostic(
        diagnostics,
        WgslDiagnosticSeverity::Error,
        "registry source file path resolves to an empty normalized path",
        Some(source_file.rel_path),
        None,
      )
      continue
    }

    if batch_rel_to_source.get(normalized_rel) is Some(existing_source) {
      if existing_source != source_file.source {
        push_wgsl_registry_diagnostic(
          diagnostics,
          WgslDiagnosticSeverity::Error,
          "multiple WGSL source files normalize to the same rel_path with different contents",
          Some(normalized_rel),
          None,
        )
      }
    } else if existing_rel_to_source.get(normalized_rel)
      is Some(existing_source) {
      if existing_source != source_file.source {
        push_wgsl_registry_diagnostic(
          diagnostics,
          WgslDiagnosticSeverity::Error,
          "bulk registry would overwrite an existing rel_path with different contents",
          Some(normalized_rel),
          None,
        )
      }
    }
    batch_rel_to_source.set(normalized_rel, source_file.source)

    let (import_path, _, _) = get_preprocessor_data(source_file.source)
    guard import_path is Some(module_path) && module_path != "" else {
      continue
    }

    if batch_module_to_rel.get(module_path) is Some(existing_rel) {
      if existing_rel != normalized_rel {
        push_wgsl_registry_diagnostic(
          diagnostics,
          WgslDiagnosticSeverity::Error,
          "multiple WGSL source files define the same #define_import_path in one batch",
          Some(normalized_rel),
          Some(module_path),
        )
      }
    } else if existing_modules.get(module_path) is Some(existing_rel) {
      if existing_rel != normalized_rel {
        push_wgsl_registry_diagnostic(
          diagnostics,
          WgslDiagnosticSeverity::Error,
          "bulk registry would overwrite an existing #define_import_path with a different rel_path",
          Some(normalized_rel),
          Some(module_path),
        )
      }
    }
    batch_module_to_rel.set(module_path, normalized_rel)
  }

  diagnostics
}

///|
pub fn register_wgsl_source_files_checked(
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  let diagnostics = analyze_wgsl_source_files_for_registry(files)
  if wgsl_diagnostics_has_error(diagnostics) {
    return diagnostics
  }
  register_wgsl_source_files(files)
  diagnostics
}

///|
pub fn register_wgsl_source_files(files : Array[WgslSourceFile]) -> Unit {
  for file in files {
    register_wgsl_source(file.rel_path, file.source)
  }
}

///|
pub fn registered_wgsl_source(rel_path : String) -> String? {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  if normalized_rel == "" {
    return None
  }
  registered_wgsl_sources_ref.val.get(normalized_rel)
}

///|
pub fn copy_registered_wgsl_source_files() -> Array[WgslSourceFile] {
  let files : Array[WgslSourceFile] = []
  for entry in registered_wgsl_sources_ref.val.iter() {
    let (rel_path, source) = entry
    files.push(WgslSourceFile::{ rel_path, source })
  }
  files
}

///|
pub fn copy_registered_wgsl_import_module_paths() -> @hashmap.HashMap[
  String,
  String,
] {
  let copied : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for entry in registered_wgsl_import_modules_ref.val.iter() {
    let (module_path, rel_path) = entry
    copied.set(module_path, rel_path)
  }
  copied
}

///|
fn wgsl_module_path_to_rel_path(module_path : String) -> String {
  let mut rel = "shaders/"
  let mut first = true
  for seg in module_path.split("::") {
    let text = seg.to_string()
    if text == "" {
      continue
    }
    if first {
      first = false
    } else {
      rel = "\{rel}/"
    }
    rel = "\{rel}\{text}"
  }
  "\{rel}.wgsl"
}

///|
fn wgsl_module_path_to_rel_path_namespace(module_path : String) -> String {
  let segments : Array[String] = []
  for seg in module_path.split("::") {
    let text = seg.to_string().trim().to_string()
    if text != "" {
      segments.push(text)
    }
  }
  if segments.length() == 0 {
    return ""
  }
  let mut rel = "shaders/\{segments[0]}"
  for i in 1..<segments.length() {
    rel = "\{rel}/\{segments[i]}"
  }
  "\{rel}.wgsl"
}

///|
pub fn build_wgsl_import_module_paths(
  _assets_base : String,
) -> @hashmap.HashMap[String, String] {
  copy_registered_wgsl_import_module_paths()
}

///|
pub fn resolve_wgsl_import_module(
  _assets_base : String,
  import_path : String,
  modules : @hashmap.HashMap[String, String],
) -> WgslResolvedImportModule? {
  let segments : Array[String] = []
  for seg in import_path.split("::") {
    let text = seg.to_string().trim().to_string()
    if text != "" {
      segments.push(text)
    }
  }
  while segments.length() > 0 {
    let mut module_path = segments[0]
    for i in 1..<segments.length() {
      module_path = "\{module_path}::\{segments[i]}"
    }
    if modules.get(module_path) is Some(rel_path) {
      return Some(WgslResolvedImportModule::{ module_path, rel_path })
    }
    let default_rel = wgsl_module_path_to_rel_path(module_path)
    if registered_wgsl_source(default_rel) is Some(_) {
      return Some(WgslResolvedImportModule::{
        module_path,
        rel_path: default_rel,
      })
    }
    let namespace_rel = wgsl_module_path_to_rel_path_namespace(module_path)
    if namespace_rel != "" &&
      namespace_rel != default_rel &&
      registered_wgsl_source(namespace_rel) is Some(_) {
      return Some(WgslResolvedImportModule::{
        module_path,
        rel_path: namespace_rel,
      })
    }
    segments.pop() |> ignore
  }
  None
}
