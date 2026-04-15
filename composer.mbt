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
pub struct Composer {
  module_sets : @hashmap.HashMap[String, ComposableModuleDefinition]
  registered_wgsl_sources : @hashmap.HashMap[String, String]
  registered_wgsl_import_modules : @hashmap.HashMap[String, String]
  composable_module_registry_paths : @hashmap.HashMap[String, String]
}

///|
pub fn Composer::default() -> Composer {
  Composer::{
    module_sets: @hashmap.HashMap::new(),
    registered_wgsl_sources: copy_wgsl_source_registry_map(
      registered_wgsl_sources_ref.val,
    ),
    registered_wgsl_import_modules: copy_wgsl_import_module_map(
      registered_wgsl_import_modules_ref.val,
    ),
    composable_module_registry_paths: @hashmap.HashMap::new(),
  }
}

///|
pub(all) suberror ComposerError {
  EmptyAssetsBase(String)
  FailedToResolveImport(String)
  ImportCycle(String)
  MissingRegisteredSource(String)
  MissingStartupRegisteredSource(String)
  NoModuleName(String)
}

///|
pub fn ComposerError::message(self : ComposerError) -> String {
  match self {
    EmptyAssetsBase(rel) => "assets_base is empty; cannot load shader: \{rel}"
    FailedToResolveImport(import_path) =>
      "failed to resolve shader import: \{import_path}"
    ImportCycle(cycle) => "shader import cycle detected: \{cycle}"
    MissingRegisteredSource(rel) => "missing registered WGSL source: \{rel}"
    MissingStartupRegisteredSource(rel) =>
      "shader source was not startup-registered: \{rel}"
    NoModuleName(path) =>
      "shader module is missing #define_import_path: \{path}"
  }
}

///|
fn copy_shader_def_values(
  defs : @hashmap.HashMap[String, ShaderDefValue],
) -> @hashmap.HashMap[String, ShaderDefValue] {
  let copied : @hashmap.HashMap[String, ShaderDefValue] = @hashmap.HashMap::new()
  for entry in defs.iter() {
    let (name, value) = entry
    copied.set(name, value)
  }
  copied
}

///|
fn copy_import_definitions(
  imports : Array[ImportDefinition],
) -> Array[ImportDefinition] {
  let copied : Array[ImportDefinition] = []
  for import_definition in imports {
    copied.push(import_definition)
  }
  copied
}

///|
fn copy_bool_defs(
  defs : @hashmap.HashMap[String, Bool],
) -> @hashmap.HashMap[String, Bool] {
  let copied : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  for entry in defs.iter() {
    let (name, value) = entry
    copied.set(name, value)
  }
  copied
}

///|
fn copy_int_defs(
  defs : @hashmap.HashMap[String, Int],
) -> @hashmap.HashMap[String, Int] {
  let copied : @hashmap.HashMap[String, Int] = @hashmap.HashMap::new()
  for entry in defs.iter() {
    let (name, value) = entry
    copied.set(name, value)
  }
  copied
}

///|
fn hashset_strings_to_array(values : @hashset.HashSet[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values.iter() {
    out.push(value)
  }
  out.sort()
  out
}

///|
priv struct WgslComposeSession {
  assets_base : String
  defines : @hashmap.HashMap[String, Bool]
  value_defines : @hashmap.HashMap[String, Int]
  modules : @hashmap.HashMap[String, String]
  redirects : Array[WgslSymbolRedirect]
  visited : @hashmap.HashMap[String, Bool]
  active_rel_paths : Array[String]
  resolved_source_files : @hashmap.HashMap[String, String]
}

///|
fn composable_module_name_from_descriptor(
  desc : ComposableModuleDescriptor,
) -> String raise ComposerError {
  match desc.as_name {
    Some(as_name) => {
      let trimmed = as_name.trim().to_string()
      if trimmed == "" {
        raise ComposerError::NoModuleName(desc.file_path)
      }
      trimmed
    }
    None =>
      match get_preprocessor_metadata(desc.source).name {
        Some(name) if name.trim() != "" => name.trim().to_string()
        _ => raise ComposerError::NoModuleName(desc.file_path)
      }
  }
}

///|
fn composable_module_registry_rel_path(
  desc : ComposableModuleDescriptor,
  module_name : String,
) -> String {
  let normalized_file_path = normalize_shader_rel_path(desc.file_path)
  if normalized_file_path != "" {
    return normalized_file_path
  }
  default_shader_rel_path_for_module_path(module_name)
}

///|
pub fn Composer::clear_registered_wgsl_source_registry(self : Composer) -> Unit {
  clear_wgsl_source_registry(
    self.registered_wgsl_sources,
    self.registered_wgsl_import_modules,
  )
}

///|
pub fn Composer::register_wgsl_source(
  self : Composer,
  rel_path : String,
  source : String,
) -> Unit {
  ignore(
    register_wgsl_source_into(
      self.registered_wgsl_sources,
      self.registered_wgsl_import_modules,
      rel_path,
      source,
      None,
    ),
  )
}

///|
pub fn Composer::register_wgsl_source_files(
  self : Composer,
  files : Array[WgslSourceFile],
) -> Unit {
  register_wgsl_source_files_into(
    self.registered_wgsl_sources,
    self.registered_wgsl_import_modules,
    files,
  )
}

///|
pub fn Composer::analyze_wgsl_source_files_for_registry(
  self : Composer,
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  let diagnostics : Array[WgslDiagnostic] = []
  analyze_wgsl_source_files_for_registry_against(
    copy_wgsl_source_registry_map(self.registered_wgsl_sources),
    copy_wgsl_import_module_map(self.registered_wgsl_import_modules),
    files,
    diagnostics,
  )
  diagnostics
}

///|
pub fn Composer::register_wgsl_source_files_checked(
  self : Composer,
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  let diagnostics : Array[WgslDiagnostic] = []
  register_wgsl_source_files_checked_into(
    self.registered_wgsl_sources,
    self.registered_wgsl_import_modules,
    files,
    diagnostics,
  )
  diagnostics
}

///|
pub fn Composer::register_wgsl_source_tree(
  self : Composer,
  root : String,
  options : WgslSourceScanOptions,
) -> Unit raise @fs.IOError {
  self.register_wgsl_source_files(scan_wgsl_source_files(root, options))
}

///|
pub fn Composer::register_wgsl_source_tree_checked(
  self : Composer,
  root : String,
  options : WgslSourceScanOptions,
) -> Array[WgslDiagnostic] raise @fs.IOError {
  self.register_wgsl_source_files_checked(scan_wgsl_source_files(root, options))
}

///|
pub fn Composer::registered_wgsl_source(
  self : Composer,
  rel_path : String,
) -> String? {
  registered_wgsl_source_from_registry(self.registered_wgsl_sources, rel_path)
}

///|
pub fn Composer::copy_registered_wgsl_source_files(
  self : Composer,
) -> Array[WgslSourceFile] {
  copy_wgsl_source_files_from_registry(self.registered_wgsl_sources)
}

///|
pub fn Composer::copy_registered_wgsl_import_module_paths(
  self : Composer,
) -> @hashmap.HashMap[String, String] {
  copy_wgsl_import_module_map(self.registered_wgsl_import_modules)
}

///|
fn Composer::new_wgsl_compose_session(
  self : Composer,
  options : WgslComposeOptions,
) -> WgslComposeSession {
  WgslComposeSession::{
    assets_base: options.assets_base.trim().to_string(),
    defines: copy_bool_defs(options.defines),
    value_defines: copy_int_defs(options.value_defines),
    modules: self.copy_registered_wgsl_import_module_paths(),
    redirects: options.redirects.copy(),
    visited: @hashmap.HashMap::new(),
    active_rel_paths: [],
    resolved_source_files: @hashmap.HashMap::new(),
  }
}

///|
fn Composer::new_wgsl_legacy_session(
  self : Composer,
  assets_base : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
  visited : @hashmap.HashMap[String, Bool],
  modules : @hashmap.HashMap[String, String],
  redirects : Array[WgslSymbolRedirect],
) -> WgslComposeSession {
  let merged_modules = self.copy_registered_wgsl_import_module_paths()
  for entry in modules.iter() {
    let (module_path, rel_path) = entry
    merged_modules.set(module_path, rel_path)
  }
  WgslComposeSession::{
    assets_base: assets_base.trim().to_string(),
    defines,
    value_defines,
    modules: merged_modules,
    redirects: redirects.copy(),
    visited,
    active_rel_paths: [],
    resolved_source_files: @hashmap.HashMap::new(),
  }
}

///|
fn composer_remove_composable_module_recursive(
  composer : Composer,
  module_name : String,
) -> Unit {
  if !composer.module_sets.contains(module_name) {
    return
  }
  if composer.composable_module_registry_paths.get(module_name)
    is Some(rel_path) {
    ignore(composer.composable_module_registry_paths.remove(module_name))
    ignore(composer.registered_wgsl_import_modules.remove(module_name))
    ignore(composer.registered_wgsl_sources.remove(rel_path))
  }
  ignore(composer.module_sets.remove(module_name))
  let dependent_modules : Array[String] = []
  for entry in composer.module_sets.iter() {
    let (dependent_name, module_set) = entry
    if module_set.all_imports.contains(module_name) {
      dependent_modules.push(dependent_name)
    }
  }
  for dependent_name in dependent_modules {
    composer_remove_composable_module_recursive(composer, dependent_name)
  }
}

///|
priv struct WgslImportRequest {
  module_path : String
  rel_path : String
  mut import_full_module : Bool
  requested_items : Array[String]
  alias_name : String
}

///|
priv struct WgslDeclarationBlock {
  name : String
  text : String
}

///|
fn ends_with_text(text : String, suffix : String) -> Bool {
  text.length() >= suffix.length() &&
  text[text.length() - suffix.length():text.length()].to_string() == suffix
}

///|
fn strip_wgsl_line_comment(text : String) -> String {
  let mut i = 0
  while i + 1 < text.length() {
    if text.code_unit_at(i).to_int() == 47 &&
      text.code_unit_at(i + 1).to_int() == 47 {
      return text[:i].to_string()
    }
    i = i + 1
  }
  text
}

///|
fn wgsl_string_list_push_unique(items : Array[String], item : String) -> Unit {
  for existing in items {
    if existing == item {
      return
    }
  }
  items.push(item)
}

///|
fn wgsl_identifier_char(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
fn unresolved_wgsl_namespace_reference(source : String) -> String? {
  let cleaned = replace_comments(source)
  let mut i = 0
  while i + 1 < cleaned.length() {
    if cleaned.code_unit_at(i).to_int() == 58 &&
      cleaned.code_unit_at(i + 1).to_int() == 58 {
      let mut start = i
      while start > 0 {
        let cu = cleaned.code_unit_at(start - 1).to_int()
        if !wgsl_identifier_char(cu) && cu != 58 {
          break
        }
        start = start - 1
      }
      let mut end = i + 2
      while end < cleaned.length() {
        let cu = cleaned.code_unit_at(end).to_int()
        if !wgsl_identifier_char(cu) && cu != 58 {
          break
        }
        end = end + 1
      }
      let path = cleaned[start:end].to_string().trim().to_string()
      if path != "" && path != "::" {
        return Some(path)
      }
    }
    i = i + 1
  }
  None
}

///|
fn text_contains_code_unit(text : String, code : Int) -> Bool {
  for i in 0..<text.length() {
    if text.code_unit_at(i).to_int() == code {
      return true
    }
  }
  false
}

///|
fn wgsl_import_default_alias(module_path : String) -> String {
  let mut alias_name = ""
  for seg in module_path.split("::") {
    let text = seg.to_string().trim().to_string()
    if text != "" {
      alias_name = text
    }
  }
  alias_name
}

///|
fn wgsl_import_alias_prefix(alias_name : String) -> String {
  let mut prefix = ""
  for i in 0..<alias_name.length() {
    let code = alias_name.code_unit_at(i).to_int()
    if wgsl_identifier_char(code) {
      prefix = prefix + alias_name[i:i + 1].to_string()
    } else if !prefix.has_suffix("_") {
      prefix = prefix + "_"
    }
  }
  if prefix == "" {
    "import"
  } else {
    prefix
  }
}

///|
fn wgsl_import_requested_item_name(
  raw_path : String,
  module_path : String,
) -> String {
  let prefix = "\{module_path}::"
  if !starts_with_text(raw_path, prefix) {
    return ""
  }
  raw_path[prefix.length():raw_path.length()].to_string().trim().to_string()
}

///|
fn collect_wgsl_alias_requested_paths(
  source : String,
  alias_name : String,
  requested_paths : Array[String],
) -> Unit {
  let pattern = "\{alias_name}::"
  let mut search_from = 0
  while search_from + pattern.length() <= source.length() {
    let window = source[search_from:source.length()].to_string()
    let guard_pattern = window.contains(pattern)
    if !guard_pattern {
      break
    }
    let mut match_index = -1
    let limit = source.length() - pattern.length()
    for i in search_from..<=limit {
      if source[i:i + pattern.length()].to_string() == pattern {
        match_index = i
        break
      }
    }
    if match_index < 0 {
      break
    }
    let start = match_index + pattern.length()
    let mut end = start
    while end < source.length() &&
          (
            wgsl_identifier_char(source.code_unit_at(end).to_int()) ||
            (
              source.code_unit_at(end).to_int() == 58 &&
              end + 1 < source.length() &&
              source.code_unit_at(end + 1).to_int() == 58
            )
          ) {
      if source.code_unit_at(end).to_int() == 58 {
        end = end + 2
        continue
      }
      end = end + 1
    }
    if end > start {
      let item_path = source[start:end].to_string()
      wgsl_string_list_push_unique(requested_paths, item_path)
      search_from = end
    } else {
      search_from = start
    }
  }
}

///|
fn wgsl_path_separator_count(path : String) -> Int {
  let mut count = 0
  let mut i = 0
  while i + 1 < path.length() {
    if path.code_unit_at(i).to_int() == 58 &&
      path.code_unit_at(i + 1).to_int() == 58 {
      count = count + 1
      i = i + 2
      continue
    }
    i = i + 1
  }
  count
}

///|
fn split_last_wgsl_path(path : String) -> (String, String)? {
  let mut i = path.length() - 1
  while i > 0 {
    if path.code_unit_at(i - 1).to_int() == 58 &&
      path.code_unit_at(i).to_int() == 58 {
      let prefix = path[:i - 1].to_string().trim().to_string()
      let suffix = path[i + 1:path.length()].to_string().trim().to_string()
      if prefix != "" && suffix != "" {
        return Some((prefix, suffix))
      }
      return None
    }
    i = i - 1
  }
  None
}

///|
fn wgsl_import_targets_push_unique(
  targets : Array[WgslImportTarget],
  target : WgslImportTarget,
) -> Unit {
  for existing in targets {
    if existing.raw_path == target.raw_path &&
      existing.alias_name == target.alias_name {
      return
    }
  }
  targets.push(target)
}

///|
fn collect_wgsl_qualified_module_targets(
  source : String,
  current_rel_path : String,
  source_registry : @hashmap.HashMap[String, String],
  modules : @hashmap.HashMap[String, String],
  targets : Array[WgslImportTarget],
) -> Unit {
  let cleaned = replace_comments(source)
  for token in tokenize(cleaned, false) {
    match token {
      Token::Identifier(ident, _) => {
        if wgsl_path_separator_count(ident) < 2 {
          continue
        }
        guard resolve_wgsl_import_request_module(
            current_rel_path, ident, source_registry, modules,
          )
          is Some(resolved_module) else {
          continue
        }
        let requested_item = wgsl_import_requested_item_name(
          ident,
          resolved_module.module_path,
        )
        if requested_item == "" {
          continue
        }
        wgsl_import_targets_push_unique(targets, WgslImportTarget::{
          raw_path: resolved_module.module_path,
          alias_name: resolved_module.module_path,
        })
      }
      _ => ()
    }
  }
}

///|
fn build_wgsl_import_rename_map(
  source : String,
  alias_name : String,
) -> @hashmap.HashMap[String, String] {
  let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let alias_prefix = wgsl_import_alias_prefix(alias_name)
  let graph = build_wgsl_declaration_graph(source)
  for block in graph.declaration_blocks {
    if block.name == "" {
      continue
    }
    rename_map.set(block.name, "\{alias_prefix}__\{block.name}")
  }
  rename_map
}

///|
fn collect_wgsl_import_alias_redirects(
  alias_name : String,
  rename_map : @hashmap.HashMap[String, String],
  redirects : Array[WgslSymbolRedirect],
) -> Unit {
  for entry in rename_map.iter() {
    let (from_name, to_name) = entry
    redirects.push(WgslSymbolRedirect::{
      from_name: "\{alias_name}::\{from_name}",
      to_name,
    })
  }
}

///|
fn strip_wgsl_import_declarations(source : String) -> String {
  let lines : Array[String] = []
  for line_item in source.split("\n") {
    lines.push(line_item.to_string())
  }
  let mut out = ""
  let mut index = 0
  while index < lines.length() {
    let line = lines[index]
    let trimmed = line.trim().to_string()
    if starts_with_text(trimmed, "#define_import_path") {
      index = index + 1
      continue
    }
    if starts_with_text(trimmed, "#import ") {
      let mut brace_balance = import_brace_balance(
        trimmed[8:trimmed.length()].to_string(),
      )
      while brace_balance > 0 && index + 1 < lines.length() {
        index = index + 1
        brace_balance = brace_balance + import_brace_balance(lines[index])
      }
      index = index + 1
      continue
    }
    out = "\{out}\{line}\n"
    index = index + 1
  }
  out
}

///|
fn wgsl_source_contains_identifier(
  source : String,
  identifier : String,
) -> Bool {
  if identifier == "" || identifier.length() > source.length() {
    return false
  }
  let limit = source.length() - identifier.length()
  for i in 0..<=limit {
    if source[i:i + identifier.length()].to_string() != identifier {
      continue
    }
    let left_ok = i == 0 ||
      !wgsl_identifier_char(source.code_unit_at(i - 1).to_int())
    let right_index = i + identifier.length()
    let right_ok = right_index >= source.length() ||
      !wgsl_identifier_char(source.code_unit_at(right_index).to_int())
    if left_ok && right_ok {
      return true
    }
  }
  false
}

///|
fn find_wgsl_import_request_index(
  requests : Array[WgslImportRequest],
  module_path : String,
  rel_path : String,
  alias_name : String,
) -> Int? {
  for i in 0..<requests.length() {
    let request = requests[i]
    if request.module_path == module_path &&
      request.rel_path == rel_path &&
      request.alias_name == alias_name {
      return Some(i)
    }
  }
  None
}

///|
fn wgsl_import_request_visit_key(
  importer_rel_path : String,
  request : WgslImportRequest,
) -> String {
  let mut key = "\{importer_rel_path}=>\{request.rel_path}|\{request.alias_name}"
  if request.import_full_module {
    key = "\{key}|*"
  } else {
    let sorted_items : Array[String] = []
    for item in request.requested_items {
      sorted_items.push(item)
    }
    sorted_items.sort()
    for item in sorted_items {
      key = "\{key}|\{item}"
    }
  }
  key
}

///|
fn resolve_wgsl_import_request_module(
  importer_rel_path : String,
  import_path : String,
  source_registry : @hashmap.HashMap[String, String],
  modules : @hashmap.HashMap[String, String],
) -> WgslResolvedImportModule? {
  if resolve_wgsl_import_file_path_from_registry(
      source_registry, importer_rel_path, import_path,
    )
    is Some(rel_path) {
    let module_path = match
      registered_wgsl_source_from_registry(source_registry, rel_path) {
      Some(source) =>
        match get_preprocessor_metadata(source).name {
          Some(name) if name.trim() != "" => name.trim().to_string()
          _ => import_path
        }
      None => import_path
    }
    return Some(WgslResolvedImportModule::{ module_path, rel_path })
  }
  if split_last_identifier(import_path) is Some((module_path, _)) {
    if resolve_wgsl_import_file_path_from_registry(
        source_registry, importer_rel_path, module_path,
      )
      is Some(rel_path) {
      return Some(WgslResolvedImportModule::{ module_path, rel_path })
    }
  }
  resolve_wgsl_import_module("", import_path, modules)
}

///|
fn wgsl_visit_has_rel_prefix(
  visited : @hashmap.HashMap[String, Bool],
  rel_path : String,
) -> Bool {
  let prefix = "\{rel_path}|"
  for entry in visited.iter() {
    let (key, _) = entry
    if starts_with_text(key, prefix) {
      return true
    }
  }
  false
}

///|
fn wgsl_path_stack_contains(paths : Array[String], rel_path : String) -> Bool {
  for existing_path in paths {
    if existing_path == rel_path {
      return true
    }
  }
  false
}

///|
fn wgsl_import_cycle_string(
  active_rel_paths : Array[String],
  repeated_rel_path : String,
) -> String {
  let cycle_paths : Array[String] = []
  let mut found_cycle_start = false
  for rel_path in active_rel_paths {
    if rel_path == repeated_rel_path {
      found_cycle_start = true
    }
    if found_cycle_start {
      cycle_paths.push(rel_path)
    }
  }
  cycle_paths.push(repeated_rel_path)
  cycle_paths.join(" -> ")
}

///|
fn wgsl_declaration_name(line : String) -> String {
  let trimmed = line.trim().to_string()
  if trimmed == "" {
    return ""
  }
  if starts_with_text(trimmed, "@") {
    let mut i = 0
    while i + 3 < trimmed.length() {
      if trimmed.code_unit_at(i).to_int() == 32 &&
        trimmed.code_unit_at(i + 1).to_int() == 118 &&
        trimmed.code_unit_at(i + 2).to_int() == 97 &&
        trimmed.code_unit_at(i + 3).to_int() == 114 {
        return wgsl_declaration_name(
          trimmed[i + 1:trimmed.length()].to_string(),
        )
      }
      i = i + 1
    }
    return ""
  }
  if starts_with_text(trimmed, "struct ") {
    let rest = trimmed[7:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "fn ") {
    let rest = trimmed[3:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "const ") {
    let rest = trimmed[6:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "override ") {
    let rest = trimmed[9:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "alias ") {
    let rest = trimmed[6:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "type ") {
    let rest = trimmed[5:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "var") {
    let mut i = 3
    while i < trimmed.length() &&
          (
            trimmed.code_unit_at(i).to_int() == 32 ||
            trimmed.code_unit_at(i).to_int() == 9
          ) {
      i = i + 1
    }
    if i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 60 {
      while i < trimmed.length() && trimmed.code_unit_at(i).to_int() != 62 {
        i = i + 1
      }
      if i < trimmed.length() {
        i = i + 1
      }
    }
    while i < trimmed.length() &&
          (
            trimmed.code_unit_at(i).to_int() == 32 ||
            trimmed.code_unit_at(i).to_int() == 9
          ) {
      i = i + 1
    }
    let start = i
    while i < trimmed.length() &&
          wgsl_identifier_char(trimmed.code_unit_at(i).to_int()) {
      i = i + 1
    }
    return if i == start { "" } else { trimmed[start:i].to_string() }
  }
  ""
}

///|
fn collect_wgsl_declaration_dependencies(
  declaration_text : String,
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  for token in tokenize(declaration_text, false) {
    match token {
      Token::Identifier(ident, _) => {
        if ident.contains("\"") {
          continue
        }
        let segments : Array[String] = []
        for raw_segment in ident.split("::") {
          let segment = raw_segment.to_string().trim().to_string()
          if segment != "" {
            segments.push(segment)
          }
        }
        if segments.length() == 0 {
          if ident != self_name && declaration_names.contains(ident) {
            wgsl_string_list_push_unique(dependencies, ident)
          }
          continue
        }
        let dependency_name = segments[segments.length() - 1]
        if dependency_name != self_name &&
          declaration_names.contains(dependency_name) {
          wgsl_string_list_push_unique(dependencies, dependency_name)
        }
      }
      _ => ()
    }
  }
}

///|
fn extract_wgsl_module_items(
  source : String,
  requested_items : Array[String],
) -> String {
  if requested_items.length() == 0 {
    return source
  }
  let lines : Array[String] = []
  for line_item in source.split("\n") {
    lines.push(line_item.to_string())
  }
  let pending_prefix : Array[String] = []
  let import_blocks : Array[String] = []
  let declaration_blocks : Array[WgslDeclarationBlock] = []
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    let trimmed = line.trim().to_string()
    let decl_name_hint = wgsl_declaration_name(trimmed)
    if trimmed == "" ||
      starts_with_text(trimmed, "//") ||
      (starts_with_text(trimmed, "@") && decl_name_hint == "") {
      pending_prefix.push(line)
      i = i + 1
      continue
    }
    if starts_with_text(trimmed, "#define_import_path") {
      i = i + 1
      continue
    }
    if starts_with_text(trimmed, "#import ") {
      let mut import_block = line
      let mut balance = import_brace_balance(
        trimmed[8:trimmed.length()].to_string(),
      )
      while balance > 0 && i + 1 < lines.length() {
        i = i + 1
        let next_line = lines[i]
        import_block = "\{import_block}\n\{next_line}"
        balance = balance + import_brace_balance(next_line)
      }
      import_blocks.push("\{import_block}\n")
      pending_prefix.clear()
      i = i + 1
      continue
    }
    let block_lines : Array[String] = []
    for prefix_line in pending_prefix {
      block_lines.push(prefix_line)
    }
    pending_prefix.clear()
    let decl_name = decl_name_hint
    let mut saw_brace = false
    let mut brace_depth = 0
    let mut done = false
    while !done {
      let block_line = lines[i]
      block_lines.push(block_line)
      if text_contains_code_unit(block_line, 123) {
        saw_brace = true
      }
      brace_depth = brace_depth + import_brace_balance(block_line)
      let block_trimmed = block_line.trim().to_string()
      if saw_brace {
        done = brace_depth == 0
      } else {
        done = ends_with_text(block_trimmed, ";")
      }
      if !done {
        i = i + 1
        if i >= lines.length() {
          done = true
        }
      }
    }
    let mut block_text = ""
    for block_line in block_lines {
      block_text = "\{block_text}\{block_line}\n"
    }
    declaration_blocks.push(WgslDeclarationBlock::{
      name: decl_name,
      text: block_text,
    })
    i = i + 1
  }
  let declaration_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let declaration_indexes : @hashmap.HashMap[String, Int] = @hashmap.HashMap::new()
  for i in 0..<declaration_blocks.length() {
    let block = declaration_blocks[i]
    if block.name != "" {
      declaration_names.set(block.name, true)
      declaration_indexes.set(block.name, i)
    }
  }
  let included_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let worklist : Array[String] = []
  let mut matched_requested = 0
  for item in requested_items {
    if declaration_names.contains(item) {
      worklist.push(item)
      matched_requested = matched_requested + 1
    }
  }
  if matched_requested == 0 {
    source
  } else {
    while worklist.length() > 0 {
      let name = worklist.pop().unwrap()
      if included_names.contains(name) {
        continue
      }
      included_names.set(name, true)
      guard declaration_indexes.get(name) is Some(index) else { continue }
      let block = declaration_blocks[index]
      let dependencies : Array[String] = []
      collect_wgsl_declaration_dependencies(
        block.text,
        name,
        declaration_names,
        dependencies,
      )
      for dependency in dependencies {
        if !included_names.contains(dependency) {
          worklist.push(dependency)
        }
      }
    }
    let mut out = ""
    for import_block in import_blocks {
      out = out + import_block
    }
    for block in declaration_blocks {
      if block.name == "" || included_names.contains(block.name) {
        out = out + block.text
      }
    }
    out
  }
}

///|
fn wgsl_directive_tail(text : String, prefix_length : Int) -> String {
  strip_wgsl_line_comment(text[prefix_length:text.length()].to_string())
  .trim()
  .to_string()
}

///|
fn parse_wgsl_uint_literal(text : String) -> Int? {
  let mut token = strip_wgsl_line_comment(text).trim().to_string()
  if token == "" {
    return None
  }
  if ends_with_text(token, "u") || ends_with_text(token, "U") {
    token = token[:token.length() - 1].to_string().trim().to_string()
  }
  if token == "" {
    return None
  }
  let parsed = @string.parse_int(token[:], base=10) catch { _ => return None }
  Some(parsed)
}

///|
fn split_once_text(text : String, sep : String) -> (String, String)? {
  let parts : Array[String] = []
  for piece in text.split(sep) {
    parts.push(piece.to_string())
  }
  if parts.length() != 2 {
    return None
  }
  Some((parts[0], parts[1]))
}

///|
fn wgsl_define_value(
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
  name : String,
) -> Int {
  if value_defines.get(name) is Some(value) {
    return value
  }
  if defines.get(name) is Some(flag) && flag {
    return 1
  }
  0
}

///|
fn wgsl_define_enabled(
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
  name : String,
) -> Bool {
  if value_defines.contains(name) {
    return true
  }
  defines.get(name).unwrap_or(false)
}

///|
fn wgsl_if_expr_value(
  token : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> Int {
  let text = strip_wgsl_line_comment(token).trim().to_string()
  if text == "" {
    return 0
  }
  if text == "true" {
    return 1
  }
  if text == "false" {
    return 0
  }
  if parse_wgsl_uint_literal(text) is Some(value) {
    return value
  }
  wgsl_define_value(defines, value_defines, text)
}

///|
fn eval_wgsl_if_expr(
  expr : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> Bool {
  let text = strip_wgsl_line_comment(expr).trim().to_string()
  if text == "" {
    return false
  }
  if split_once_text(text, ">=") is Some((lhs, rhs)) {
    return wgsl_if_expr_value(lhs, defines, value_defines) >=
      wgsl_if_expr_value(rhs, defines, value_defines)
  }
  if split_once_text(text, "<=") is Some((lhs, rhs)) {
    return wgsl_if_expr_value(lhs, defines, value_defines) <=
      wgsl_if_expr_value(rhs, defines, value_defines)
  }
  if split_once_text(text, "==") is Some((lhs, rhs)) {
    return wgsl_if_expr_value(lhs, defines, value_defines) ==
      wgsl_if_expr_value(rhs, defines, value_defines)
  }
  if split_once_text(text, "!=") is Some((lhs, rhs)) {
    return wgsl_if_expr_value(lhs, defines, value_defines) !=
      wgsl_if_expr_value(rhs, defines, value_defines)
  }
  if split_once_text(text, ">") is Some((lhs, rhs)) {
    return wgsl_if_expr_value(lhs, defines, value_defines) >
      wgsl_if_expr_value(rhs, defines, value_defines)
  }
  if split_once_text(text, "<") is Some((lhs, rhs)) {
    return wgsl_if_expr_value(lhs, defines, value_defines) <
      wgsl_if_expr_value(rhs, defines, value_defines)
  }
  wgsl_if_expr_value(text, defines, value_defines) != 0
}

///|
fn apply_wgsl_template_consts(
  source : String,
  value_defines : @hashmap.HashMap[String, Int],
) -> String {
  let mut out = ""
  let mut i = 0
  let n = source.length()
  while i < n {
    if i + 1 < n &&
      source.code_unit_at(i).to_int() == 35 &&
      source.code_unit_at(i + 1).to_int() == 123 {
      let mut j = i + 2
      while j < n && source.code_unit_at(j).to_int() != 125 {
        j = j + 1
      }
      if j < n {
        let name = source[i + 2:j].to_string().trim().to_string()
        if value_defines.get(name) is Some(value) {
          out = out + value.to_string()
          i = j + 1
          continue
        }
      }
    }
    if i + 1 < n && source.code_unit_at(i).to_int() == 35 {
      let next = source.code_unit_at(i + 1).to_int()
      let starts_name = (next >= 65 && next <= 90) || next == 95
      if starts_name {
        let mut j = i + 1
        while j < n {
          let cu = source.code_unit_at(j).to_int()
          let continues_name = (cu >= 65 && cu <= 90) ||
            (cu >= 48 && cu <= 57) ||
            cu == 95
          if !continues_name {
            break
          }
          j = j + 1
        }
        let name = source[i + 1:j].to_string()
        if value_defines.get(name) is Some(value) {
          out = out + value.to_string()
          i = j
          continue
        }
      }
    }
    out = out + source[i:i + 1].to_string()
    i = i + 1
  }
  out
}

///|
pub fn default_wgsl_value_defines() -> @hashmap.HashMap[String, Int] {
  let defines : @hashmap.HashMap[String, Int] = @hashmap.HashMap::new()
  defines.set("AVAILABLE_STORAGE_BUFFER_BINDINGS", 8)
  defines.set("MAX_DIRECTIONAL_LIGHTS", 10)
  defines.set("MAX_CASCADES_PER_LIGHT", 4)
  defines.set("MATERIAL_BIND_GROUP", 3)
  defines.set("SORTED_FRAGMENT_MAX_COUNT", 8)
  defines.set("WORLD_CACHE_SIZE", 1048576)
  defines.set("PER_OBJECT_BUFFER_BATCH_SIZE", 1)
  defines.set("SCREEN_SPACE_SPECULAR_TRANSMISSION_BLUR_TAPS", 8)
  defines
}

///|
fn apply_wgsl_ifdefs(
  source : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> String {
  let mut out = ""
  let active_stack : Array[Bool] = [true]
  let branch_taken_stack : Array[Bool] = []
  for line_item in source.split("\n") {
    let line = line_item.to_string()
    let trimmed = line.trim().to_string()
    if starts_with_text(trimmed, "#ifdef ") {
      let name = wgsl_directive_tail(trimmed, 7)
      let cond = wgsl_define_enabled(defines, value_defines, name)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      continue
    }
    if starts_with_text(trimmed, "#ifndef ") {
      let name = wgsl_directive_tail(trimmed, 8)
      let cond = !wgsl_define_enabled(defines, value_defines, name)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      continue
    }
    if starts_with_text(trimmed, "#if ") {
      let expr = wgsl_directive_tail(trimmed, 4)
      let cond = eval_wgsl_if_expr(expr, defines, value_defines)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      continue
    }
    if starts_with_text(trimmed, "#else ifdef ") {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let name = wgsl_directive_tail(trimmed, 13)
        let cond = !branch_taken_stack[idx] &&
          wgsl_define_enabled(defines, value_defines, name)
        let parent = if active_stack.length() >= 2 {
          active_stack[active_stack.length() - 2]
        } else {
          true
        }
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if starts_with_text(trimmed, "#else ifndef ") {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let name = wgsl_directive_tail(trimmed, 14)
        let cond = !branch_taken_stack[idx] &&
          !wgsl_define_enabled(defines, value_defines, name)
        let parent = if active_stack.length() >= 2 {
          active_stack[active_stack.length() - 2]
        } else {
          true
        }
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if starts_with_text(trimmed, "#else") {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let cond = !branch_taken_stack[idx]
        let parent = if active_stack.length() >= 2 {
          active_stack[active_stack.length() - 2]
        } else {
          true
        }
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if starts_with_text(trimmed, "#endif") {
      if active_stack.length() > 1 {
        active_stack.pop() |> ignore
      }
      if branch_taken_stack.length() > 0 {
        branch_taken_stack.pop() |> ignore
      }
      continue
    }
    if active_stack[active_stack.length() - 1] {
      out = "\{out}\{line}\n"
    }
  }
  out
}

///|
pub fn Composer::contains_module(self : Composer, module_name : String) -> Bool {
  self.module_sets.contains(module_name)
}

///|
pub fn Composer::add_composable_module(
  self : Composer,
  desc : ComposableModuleDescriptor,
) -> ComposableModuleDefinition raise ComposerError {
  let metadata = get_preprocessor_metadata(desc.source)
  let module_name = composable_module_name_from_descriptor(desc) catch {
    err => raise err
  }

  let shader_defs = copy_shader_def_values(desc.shader_defs)
  let effective_defs = metadata.effective_defs.copy()
  let all_imports : @hashset.HashSet[String] = @hashset.HashSet::new()
  let additional_imports = copy_import_definitions(desc.additional_imports)
  for import_binding in metadata.imports {
    all_imports.add(import_binding.definition.import_path)
  }
  for import_definition in additional_imports {
    all_imports.add(import_definition.import_path)
  }

  for import_name in all_imports.iter() {
    guard self.module_sets.get(import_name) is Some(imported_module) else {
      raise ComposerError::FailedToResolveImport(import_name)
    }
    for effective_def in imported_module.effective_defs {
      effective_defs.add(effective_def)
    }
    for entry in imported_module.shader_defs.iter() {
      let (def_name, def_value) = entry
      shader_defs.set(def_name, def_value)
    }
  }

  for entry in shader_defs.iter() {
    let (def_name, _) = entry
    effective_defs.remove(def_name)
  }

  let definition = ComposableModuleDefinition::{
    name: module_name,
    sanitized_source: metadata.cleaned_source,
    language: desc.language,
    file_path: desc.file_path,
    shader_defs,
    effective_defs: hashset_strings_to_array(effective_defs),
    all_imports,
    additional_imports,
  }

  let registry_rel_path = composable_module_registry_rel_path(desc, module_name)
  composer_remove_composable_module_recursive(self, module_name)
  ignore(
    register_wgsl_source_into(
      self.registered_wgsl_sources,
      self.registered_wgsl_import_modules,
      registry_rel_path,
      desc.source,
      Some(module_name),
    ),
  )
  self.composable_module_registry_paths.set(module_name, registry_rel_path)
  self.module_sets.set(module_name, definition)
  match self.module_sets.get(module_name) {
    Some(module_definition) => module_definition
    None => abort("expected just-inserted composable module to exist")
  }
}

///|
pub fn Composer::remove_composable_module(
  self : Composer,
  module_name : String,
) -> Unit {
  composer_remove_composable_module_recursive(self, module_name)
}

///|
pub fn registered_wgsl_source_required(
  rel_path : String,
) -> String raise ComposerError {
  match registered_wgsl_source(rel_path) {
    Some(source) => source
    None => raise ComposerError::MissingRegisteredSource(rel_path)
  }
}

///|
pub fn Composer::load_wgsl_source_required_raw(
  self : Composer,
  _assets_base : String,
  rel : String,
) -> String raise ComposerError {
  let normalized_rel = normalize_shader_rel_path(rel)
  if normalized_rel == "" {
    return ""
  }
  match
    registered_wgsl_source_from_registry(
      self.registered_wgsl_sources,
      normalized_rel,
    ) {
    Some(source) => source
    None => raise ComposerError::MissingStartupRegisteredSource(normalized_rel)
  }
}

///|
fn Composer::preprocess_wgsl_source_with_path(
  self : Composer,
  current_rel_path : String,
  source : String,
  session : WgslComposeSession,
) -> String raise ComposerError {
  let redirected_source = rewrite_wgsl_symbol_redirects(
    source,
    session.redirects,
  )
  let mut merged = ""
  let active_source = apply_wgsl_template_consts(
    apply_wgsl_ifdefs(redirected_source, session.defines, session.value_defines),
    session.value_defines,
  )
  let active_scan_source = strip_wgsl_import_declarations(active_source)
  let alias_redirects : Array[WgslSymbolRedirect] = []
  let lines : Array[String] = []
  let qualified_targets : Array[WgslImportTarget] = []
  collect_wgsl_qualified_module_targets(
    active_scan_source,
    current_rel_path,
    self.registered_wgsl_sources,
    session.modules,
    qualified_targets,
  )
  for target in qualified_targets {
    lines.push("#import \{target.raw_path} as \{target.alias_name}")
  }
  let import_active_stack : Array[Bool] = [true]
  let import_branch_taken_stack : Array[Bool] = []
  for line_item in redirected_source.split("\n") {
    lines.push(line_item.to_string())
  }
  let mut line_index = 0
  while line_index < lines.length() {
    let line = lines[line_index]
    let trimmed = line.trim().to_string()
    if starts_with_text(trimmed, "#ifdef ") {
      let name = wgsl_directive_tail(trimmed, 7)
      let cond = wgsl_define_enabled(
        session.defines,
        session.value_defines,
        name,
      )
      let parent = import_active_stack[import_active_stack.length() - 1]
      import_active_stack.push(parent && cond)
      import_branch_taken_stack.push(cond)
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if starts_with_text(trimmed, "#ifndef ") {
      let name = wgsl_directive_tail(trimmed, 8)
      let cond = !wgsl_define_enabled(
        session.defines,
        session.value_defines,
        name,
      )
      let parent = import_active_stack[import_active_stack.length() - 1]
      import_active_stack.push(parent && cond)
      import_branch_taken_stack.push(cond)
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if starts_with_text(trimmed, "#if ") {
      let expr = wgsl_directive_tail(trimmed, 4)
      let cond = eval_wgsl_if_expr(expr, session.defines, session.value_defines)
      let parent = import_active_stack[import_active_stack.length() - 1]
      import_active_stack.push(parent && cond)
      import_branch_taken_stack.push(cond)
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if starts_with_text(trimmed, "#else ifdef ") {
      if import_branch_taken_stack.length() > 0 {
        let idx = import_branch_taken_stack.length() - 1
        let name = wgsl_directive_tail(trimmed, 13)
        let cond = !import_branch_taken_stack[idx] &&
          wgsl_define_enabled(session.defines, session.value_defines, name)
        let parent = if import_active_stack.length() >= 2 {
          import_active_stack[import_active_stack.length() - 2]
        } else {
          true
        }
        import_active_stack[import_active_stack.length() - 1] = parent && cond
        import_branch_taken_stack[idx] = import_branch_taken_stack[idx] || cond
      }
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if starts_with_text(trimmed, "#else ifndef ") {
      if import_branch_taken_stack.length() > 0 {
        let idx = import_branch_taken_stack.length() - 1
        let name = wgsl_directive_tail(trimmed, 14)
        let cond = !import_branch_taken_stack[idx] &&
          !wgsl_define_enabled(session.defines, session.value_defines, name)
        let parent = if import_active_stack.length() >= 2 {
          import_active_stack[import_active_stack.length() - 2]
        } else {
          true
        }
        import_active_stack[import_active_stack.length() - 1] = parent && cond
        import_branch_taken_stack[idx] = import_branch_taken_stack[idx] || cond
      }
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if starts_with_text(trimmed, "#else") {
      if import_branch_taken_stack.length() > 0 {
        let idx = import_branch_taken_stack.length() - 1
        let cond = !import_branch_taken_stack[idx]
        let parent = if import_active_stack.length() >= 2 {
          import_active_stack[import_active_stack.length() - 2]
        } else {
          true
        }
        import_active_stack[import_active_stack.length() - 1] = parent && cond
        import_branch_taken_stack[idx] = import_branch_taken_stack[idx] || cond
      }
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if starts_with_text(trimmed, "#endif") {
      if import_active_stack.length() > 1 {
        import_active_stack.pop() |> ignore
      }
      if import_branch_taken_stack.length() > 0 {
        import_branch_taken_stack.pop() |> ignore
      }
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if starts_with_text(trimmed, "#define_import_path") {
      line_index = line_index + 1
      continue
    }
    if starts_with_text(trimmed, "#import ") {
      if !import_active_stack[import_active_stack.length() - 1] {
        merged = "\{merged}\{line}\n"
        line_index = line_index + 1
        continue
      }
      let mut spec = trimmed[8:trimmed.length()].to_string()
      let mut brace_balance = import_brace_balance(spec)
      while brace_balance > 0 && line_index + 1 < lines.length() {
        line_index = line_index + 1
        let next_line = lines[line_index]
        spec = "\{spec}\n\{next_line}"
        brace_balance = brace_balance + import_brace_balance(next_line)
      }
      let targets : Array[WgslImportTarget] = []
      let requests : Array[WgslImportRequest] = []
      collect_wgsl_import_targets(spec, "", targets)
      let mut target_index = 0
      while target_index < targets.length() {
        let target = targets[target_index]
        target_index = target_index + 1
        let requested_items : Array[String] = []
        let mut request_module_prefix = target.raw_path
        if target.alias_name != "" {
          if !active_scan_source.contains("\{target.alias_name}::") {
            continue
          }
          let requested_paths : Array[String] = []
          collect_wgsl_alias_requested_paths(
            active_scan_source,
            target.alias_name,
            requested_paths,
          )
          for requested_path in requested_paths {
            if split_last_wgsl_path(requested_path) is Some((nested_prefix, _)) {
              wgsl_import_targets_push_unique(targets, WgslImportTarget::{
                raw_path: "\{target.raw_path}::\{nested_prefix}",
                alias_name: "\{target.alias_name}::\{nested_prefix}",
              })
              continue
            }
            wgsl_string_list_push_unique(requested_items, requested_path)
          }
          if requested_items.length() == 0 {
            continue
          }
        }
        guard resolve_wgsl_import_request_module(
            current_rel_path,
            target.raw_path,
            self.registered_wgsl_sources,
            session.modules,
          )
          is Some(resolved_module) else {
          raise ComposerError::FailedToResolveImport(target.raw_path)
        }
        let module_path = resolved_module.module_path
        if target.alias_name == "" {
          request_module_prefix = module_path
        }
        let module_alias = if target.alias_name != "" {
          target.alias_name
        } else if module_path == target.raw_path {
          wgsl_import_default_alias(module_path)
        } else {
          ""
        }
        let mut import_full_module = module_path == target.raw_path
        if target.alias_name == "" && module_alias != "" {
          if !active_scan_source.contains("\{module_alias}::") {
            continue
          }
          let requested_paths : Array[String] = []
          collect_wgsl_alias_requested_paths(
            active_scan_source, module_alias, requested_paths,
          )
          for requested_path in requested_paths {
            if split_last_wgsl_path(requested_path) is Some((nested_prefix, _)) {
              wgsl_import_targets_push_unique(targets, WgslImportTarget::{
                raw_path: "\{request_module_prefix}::\{nested_prefix}",
                alias_name: "\{module_alias}::\{nested_prefix}",
              })
              continue
            }
            wgsl_string_list_push_unique(requested_items, requested_path)
          }
          if requested_items.length() > 0 {
            import_full_module = false
          } else {
            continue
          }
        } else if module_path != target.raw_path {
          import_full_module = false
          let requested_item = wgsl_import_requested_item_name(
            target.raw_path,
            module_path,
          )
          if requested_item == "" {
            import_full_module = true
          } else {
            requested_items.push(requested_item)
          }
        }
        if !import_full_module {
          let used_requested_items : Array[String] = []
          for requested_item in requested_items {
            if wgsl_source_contains_identifier(
                active_scan_source, requested_item,
              ) {
              used_requested_items.push(requested_item)
            }
          }
          requested_items.clear()
          for requested_item in used_requested_items {
            requested_items.push(requested_item)
          }
          if requested_items.length() == 0 {
            continue
          }
        }
        if find_wgsl_import_request_index(
            requests,
            module_path,
            resolved_module.rel_path,
            module_alias,
          )
          is Some(request_index) {
          let request = requests[request_index]
          if import_full_module {
            request.import_full_module = true
          }
          for requested_item in requested_items {
            wgsl_string_list_push_unique(
              request.requested_items,
              requested_item,
            )
          }
        } else {
          requests.push(WgslImportRequest::{
            module_path,
            rel_path: resolved_module.rel_path,
            import_full_module,
            requested_items,
            alias_name: module_alias,
          })
        }
      }
      for request in requests {
        if wgsl_path_stack_contains(session.active_rel_paths, request.rel_path) {
          raise ComposerError::ImportCycle(
            wgsl_import_cycle_string(session.active_rel_paths, request.rel_path),
          )
        }
        if request.import_full_module {
          if wgsl_visit_has_rel_prefix(session.visited, request.rel_path) {
            continue
          }
        }
        if !request.import_full_module {
          let full_module_key = "\{request.rel_path}|*"
          if session.visited.contains(full_module_key) {
            continue
          }
        }
        let visit_key = wgsl_import_request_visit_key(current_rel_path, request)
        if session.visited.contains(visit_key) {
          continue
        }
        session.visited.set(visit_key, true)
        let raw_source = self.load_wgsl_source_required_raw(
          session.assets_base,
          request.rel_path,
        )
        session.resolved_source_files.set(request.rel_path, raw_source)
        session.active_rel_paths.push(request.rel_path)
        let module_source = if request.import_full_module {
          self.preprocess_wgsl_source_with_path(
            request.rel_path,
            raw_source,
            session,
          )
        } else {
          let prepared_source = apply_wgsl_template_consts(
            apply_wgsl_ifdefs(
              raw_source,
              session.defines,
              session.value_defines,
            ),
            session.value_defines,
          )
          let filtered_source = extract_wgsl_module_items(
            prepared_source,
            request.requested_items,
          )
          self.preprocess_wgsl_source_with_path(
            request.rel_path,
            filtered_source,
            session,
          )
        }
        session.active_rel_paths.pop() |> ignore
        if module_source != "" {
          let final_module_source = if request.alias_name != "" {
            let rename_map = build_wgsl_import_rename_map(
              module_source,
              request.alias_name,
            )
            collect_wgsl_import_alias_redirects(
              request.alias_name,
              rename_map,
              alias_redirects,
            )
            rewrite_wgsl_declaration_text_with_renamed_declarations(
              module_source, rename_map,
            )
          } else {
            module_source
          }
          merged = "\{merged}\{final_module_source}"
          let merged_len = merged.length()
          if merged_len == 0 ||
            merged.code_unit_at(merged_len - 1).to_int() != 10 {
            merged = "\{merged}\n"
          }
        }
      }
      line_index = line_index + 1
      continue
    }
    merged = "\{merged}\{line}\n"
    line_index = line_index + 1
  }
  let mut out = apply_wgsl_ifdefs(
    merged,
    session.defines,
    session.value_defines,
  )
  out = apply_wgsl_template_consts(out, session.value_defines)
  out = rewrite_wgsl_declaration_text_with_map(
    out,
    build_wgsl_symbol_redirect_map(alias_redirects),
    false,
  )
  if unresolved_wgsl_namespace_reference(out) is Some(path) {
    raise ComposerError::FailedToResolveImport(path)
  }
  out
}

///|
fn Composer::load_wgsl_preprocessed_into_session(
  self : Composer,
  rel : String,
  session : WgslComposeSession,
) -> String raise ComposerError {
  let normalized_rel = normalize_shader_rel_path(rel)
  if normalized_rel == "" {
    return ""
  }
  if session.visited.contains(normalized_rel) {
    return ""
  }
  session.visited.set(normalized_rel, true)
  let source = self.load_wgsl_source_required_raw(
    session.assets_base,
    normalized_rel,
  )
  session.resolved_source_files.set(normalized_rel, source)
  session.active_rel_paths.push(normalized_rel)
  let composed = self.preprocess_wgsl_source_with_path(
    normalized_rel, source, session,
  )
  session.active_rel_paths.pop() |> ignore
  composed
}

///|
pub fn Composer::preprocess_wgsl_source(
  self : Composer,
  assets_base : String,
  source : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
  visited : @hashmap.HashMap[String, Bool],
  modules : @hashmap.HashMap[String, String],
) -> String raise ComposerError {
  let session = self.new_wgsl_legacy_session(
    assets_base,
    defines,
    value_defines,
    visited,
    modules,
    [],
  )
  self.preprocess_wgsl_source_with_path("", source, session)
}

///|
pub fn Composer::load_wgsl_preprocessed(
  self : Composer,
  assets_base : String,
  rel : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
  visited : @hashmap.HashMap[String, Bool],
  modules : @hashmap.HashMap[String, String],
) -> String raise ComposerError {
  let session = self.new_wgsl_legacy_session(
    assets_base,
    defines,
    value_defines,
    visited,
    modules,
    [],
  )
  self.load_wgsl_preprocessed_into_session(rel, session)
}

///|
pub fn Composer::compose_wgsl(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  self.load_wgsl_preprocessed_into_session(rel, session)
}

///|
pub fn Composer::load_wgsl_from_assets_base_required(
  self : Composer,
  assets_base : String,
  rel : String,
) -> String raise ComposerError {
  let base = assets_base.trim().to_string()
  if base == "" {
    raise ComposerError::EmptyAssetsBase(rel)
  }
  self.compose_wgsl(rel, WgslComposeOptions::{
    assets_base: base,
    defines: @hashmap.HashMap::new(),
    value_defines: default_wgsl_value_defines(),
    redirects: [],
  })
}
