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
  registry : WgslSourceRegistry
  composable_module_registry_paths : @hashmap.HashMap[String, String]
}

///|
pub fn Composer::default() -> Composer {
  Composer::{
    module_sets: @hashmap.HashMap::new(),
    registry: WgslSourceRegistry::default(),
    composable_module_registry_paths: @hashmap.HashMap::new(),
  }
}

///|
pub fn Composer::from_registered_wgsl_source_registry() -> Composer {
  Composer::{
    module_sets: @hashmap.HashMap::new(),
    registry: registered_wgsl_source_registry_singleton.snapshot(),
    composable_module_registry_paths: @hashmap.HashMap::new(),
  }
}

///|
pub(all) suberror ComposerError {
  EmptyAssetsBase(String)
  FailedToResolveImport(String)
  ImportCycle(String)
  InvalidStructMemberIdentifier(String)
  InvalidOverride(String)
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
    InvalidStructMemberIdentifier(name) =>
      "composable module identifier requires naga writeback substitution: \{name}"
    InvalidOverride(name) =>
      "override is invalid because target is not virtual: \{name}"
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
fn serialize_wgsl_import_definition(
  import_definition : ImportDefinition,
) -> String {
  let import_path = import_definition.import_path.trim().to_owned()
  if import_path == "" {
    return ""
  }
  let items : Array[String] = []
  for item in import_definition.items {
    let trimmed_item = item.trim().to_owned()
    if trimmed_item != "" {
      items.push(trimmed_item)
    }
  }
  if items.length() == 0 {
    "#import \{import_path}"
  } else {
    let item_list = items.join(", ")
    "#import \{import_path} \{item_list}"
  }
}

///|
fn prepend_wgsl_additional_imports(
  source : String,
  additional_imports : Array[ImportDefinition],
) -> String {
  let lines : Array[String] = []
  for import_definition in additional_imports {
    let line = serialize_wgsl_import_definition(import_definition)
    if line != "" {
      lines.push(line)
    }
  }
  if lines.length() == 0 {
    return source
  }
  let import_block = lines.join("\n")
  "\{import_block}\n\{source}"
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
fn merge_shader_def_value_into_compose_defs(
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
  name : String,
  value : ShaderDefValue,
) -> Unit {
  match value {
    Bool(flag) => defines.set(name, flag)
    Int(int_value) => value_defines.set(name, int_value)
    UInt(uint_value) => value_defines.set(name, uint_value.reinterpret_as_int())
  }
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
pub(all) struct WgslComposeSession {
  assets_base : String
  defines : @hashmap.HashMap[String, Bool]
  value_defines : @hashmap.HashMap[String, Int]
  modules : @hashmap.HashMap[String, String]
  redirects : Array[WgslSymbolRedirect]
  additional_imports : Array[ImportDefinition]
  redirect_match_counts : @hashmap.HashMap[String, Int]
  visited : @hashmap.HashMap[String, Bool]
  imported_item_names : @hashmap.HashMap[String, String]
  active_rel_paths : Array[String]
  resolved_source_files : @hashmap.HashMap[String, String]
}

///|
priv struct WgslActiveComposeDefs {
  defines : @hashmap.HashMap[String, Bool]
  value_defines : @hashmap.HashMap[String, Int]
}

///|
fn composable_module_name_from_descriptor(
  desc : ComposableModuleDescriptor,
) -> String raise ComposerError {
  match desc.as_name {
    Some(as_name) => {
      let trimmed = as_name.trim().to_owned()
      if trimmed == "" {
        raise ComposerError::NoModuleName(desc.file_path)
      }
      trimmed
    }
    None =>
      match get_preprocessor_metadata(desc.source).name {
        Some(name) if name.trim() != "" => name.trim().to_owned()
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
  self.registry.clear()
}

///|
pub fn Composer::register_wgsl_source(
  self : Composer,
  rel_path : String,
  source : String,
) -> Unit {
  ignore(self.registry.register_source(rel_path, source, None))
}

///|
pub fn Composer::register_wgsl_source_files(
  self : Composer,
  files : Array[WgslSourceFile],
) -> Unit {
  self.registry.register_source_files(files)
}

///|
pub fn Composer::analyze_wgsl_source_files_for_registry(
  self : Composer,
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  self.registry.analyze_source_files(files)
}

///|
pub fn Composer::register_wgsl_source_files_checked(
  self : Composer,
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  let diagnostics : Array[WgslDiagnostic] = []
  self.registry.register_source_files_checked(files, diagnostics)
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
  self.registry.registered_source(rel_path)
}

///|
pub fn Composer::copy_registered_wgsl_source_files(
  self : Composer,
) -> Array[WgslSourceFile] {
  self.registry.copy_source_files()
}

///|
pub fn Composer::copy_registered_wgsl_import_module_paths(
  self : Composer,
) -> @hashmap.HashMap[String, String] {
  self.registry.copy_import_module_paths()
}

///|
pub fn Composer::new_wgsl_compose_session(
  self : Composer,
  options : WgslComposeOptions,
) -> WgslComposeSession {
  WgslComposeSession::{
    assets_base: options.assets_base.trim().to_owned(),
    defines: copy_bool_defs(options.defines),
    value_defines: copy_int_defs(options.value_defines),
    modules: self.registry.copy_import_module_paths(),
    redirects: options.redirects.copy(),
    additional_imports: copy_import_definitions(options.additional_imports),
    redirect_match_counts: @hashmap.HashMap::new(),
    visited: @hashmap.HashMap::new(),
    imported_item_names: @hashmap.HashMap::new(),
    active_rel_paths: [],
    resolved_source_files: @hashmap.HashMap::new(),
  }
}

///|
fn Composer::composable_module_definition_for_rel_path(
  self : Composer,
  rel_path : String,
) -> ComposableModuleDefinition? {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  for entry in self.composable_module_registry_paths.iter() {
    let (module_name, module_rel_path) = entry
    if normalize_shader_rel_path(module_rel_path) == normalized_rel {
      return self.module_sets.get(module_name)
    }
  }
  None
}

///|
fn Composer::active_compose_defs_for_rel_path(
  self : Composer,
  rel_path : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
) -> WgslActiveComposeDefs {
  let (defines, value_defines) = match inherited_defs {
    Some(parent_defs) =>
      (
        copy_bool_defs(parent_defs.defines),
        copy_int_defs(parent_defs.value_defines),
      )
    None =>
      (copy_bool_defs(session.defines), copy_int_defs(session.value_defines))
  }
  if self.composable_module_definition_for_rel_path(rel_path)
    is Some(module_definition) {
    for entry in module_definition.shader_defs.iter() {
      let (name, value) = entry
      merge_shader_def_value_into_compose_defs(
        defines, value_defines, name, value,
      )
    }
  }
  WgslActiveComposeDefs::{ defines, value_defines }
}

///|
fn collect_wgsl_cached_import_redirects(
  session : WgslComposeSession,
  rel_path : String,
  alias_name : String,
  redirects : Array[WgslSymbolRedirect],
) -> Int {
  let prefix = "\{rel_path}|"
  let mut count = 0
  for entry in session.imported_item_names.iter() {
    let (key, imported_name) = entry
    if !starts_with_text(key, prefix) {
      continue
    }
    let item_name = key[prefix.length():key.length()].to_owned()
    let from_name = if alias_name == "" {
      item_name
    } else {
      "\{alias_name}::\{item_name}"
    }
    redirects.push(WgslSymbolRedirect::{ from_name, to_name: imported_name })
    count = count + 1
  }
  count
}

///|
fn find_wgsl_cached_imported_item_name(
  session : WgslComposeSession,
  rel_path : String,
  item_name : String,
) -> String? {
  match
    session.imported_item_names.get(
      wgsl_imported_item_name_key(rel_path, item_name),
    ) {
    Some(imported_name) => Some(imported_name)
    None => {
      let suffix = "|\{item_name}"
      let mut found : String? = None
      for entry in session.imported_item_names.iter() {
        let (key, imported_name) = entry
        if !key.has_suffix(suffix) {
          continue
        }
        match found {
          Some(existing_name) if existing_name != imported_name => return None
          Some(_) => ()
          None => found = Some(imported_name)
        }
      }
      found
    }
  }
}

///|
fn record_wgsl_redirect_matches(
  source : String,
  session : WgslComposeSession,
) -> Unit {
  for redirect in session.redirects {
    let from_name = redirect.from_name.trim().to_owned()
    let to_name = redirect.to_name.trim().to_owned()
    if from_name == "" || to_name == "" || from_name == to_name {
      continue
    }
    if wgsl_source_contains_identifier(source, from_name) {
      let current = match session.redirect_match_counts.get(from_name) {
        Some(count) => count
        None => 0
      }
      session.redirect_match_counts.set(from_name, current + 1)
    }
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
    composer.registry.remove_source_and_module(rel_path, module_name)
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
fn strip_wgsl_line_comment(text : String) -> String {
  let mut i = 0
  while i + 1 < text.length() {
    if text.code_unit_at(i).to_int() == 47 &&
      text.code_unit_at(i + 1).to_int() == 47 {
      return text[:i].to_owned()
    }
    i = i + 1
  }
  text
}

///|
fn wgsl_clean_directive_tail(text : String) -> String {
  strip_wgsl_line_comment(text).trim().to_owned()
}

///|
fn parse_wgsl_uint_literal(text : String) -> Int? {
  let mut token = strip_wgsl_line_comment(text).trim().to_owned()
  if token == "" {
    return None
  }
  if token.has_suffix("u") || token.has_suffix("U") {
    token = token[:token.length() - 1].to_owned().trim().to_owned()
  }
  if token == "" {
    return None
  }
  let parsed = @string.parse_int(token[:], base=10) catch { _ => return None }
  Some(parsed)
}

///|
fn split_once_text(text : String, sep : String) -> (String, String)? {
  match text.find(sep) {
    Some(index) =>
      Some(
        (
          text[:index].to_owned(),
          text[index + sep.length():text.length()].to_owned(),
        ),
      )
    None => None
  }
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
  defines.contains(name)
}

///|
fn wgsl_parent_active(active_stack : Array[Bool]) -> Bool {
  if active_stack.length() >= 2 {
    active_stack[active_stack.length() - 2]
  } else {
    true
  }
}

///|
fn wgsl_if_expr_value(
  token : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> Int {
  let text = strip_wgsl_line_comment(token).trim().to_owned()
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
  let text = strip_wgsl_line_comment(expr).trim().to_owned()
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
pub fn apply_wgsl_template_consts(
  source : String,
  value_defines : @hashmap.HashMap[String, Int],
) -> String {
  let mut out = ""
  let mut scan = 0
  let mut copy_start = 0
  let n = source.length()
  while scan < n {
    if scan + 1 < n &&
      source.code_unit_at(scan).to_int() == 35 &&
      source.code_unit_at(scan + 1).to_int() == 123 {
      let mut j = scan + 2
      while j < n && source.code_unit_at(j).to_int() != 125 {
        j = j + 1
      }
      if j < n {
        let name = source[scan + 2:j].to_owned().trim().to_owned()
        if value_defines.get(name) is Some(value) {
          out = out + source[copy_start:scan].to_owned()
          out = out + value.to_string()
          scan = j + 1
          copy_start = scan
          continue
        }
      }
    }
    if scan + 1 < n && source.code_unit_at(scan).to_int() == 35 {
      let next = source.code_unit_at(scan + 1).to_int()
      let starts_name = (next >= 65 && next <= 90) || next == 95
      if starts_name {
        let mut j = scan + 1
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
        let name = source[scan + 1:j].to_owned()
        if value_defines.get(name) is Some(value) {
          out = out + source[copy_start:scan].to_owned()
          out = out + value.to_string()
          scan = j
          copy_start = scan
          continue
        }
      }
    }
    scan = scan + 1
  }
  if copy_start < n {
    out = out + source[copy_start:n].to_owned()
  }
  out
}

///|
pub fn apply_wgsl_ifdefs(
  source : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> String {
  let mut out = ""
  let active_stack : Array[Bool] = [true]
  let branch_taken_stack : Array[Bool] = []
  for line_item in source.split("\n") {
    let line = line_item.to_owned()
    let trimmed = line.trim().to_owned()
    if hash_directive_tail(trimmed, "ifdef") is Some(tail) {
      let name = wgsl_clean_directive_tail(tail)
      let cond = wgsl_define_enabled(defines, value_defines, name)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      continue
    }
    if hash_directive_tail(trimmed, "ifndef") is Some(tail) {
      let name = wgsl_clean_directive_tail(tail)
      let cond = !wgsl_define_enabled(defines, value_defines, name)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      continue
    }
    if hash_directive_tail(trimmed, "if") is Some(tail) {
      let expr = wgsl_clean_directive_tail(tail)
      let cond = eval_wgsl_if_expr(expr, defines, value_defines)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      continue
    }
    if hash_directive_tail(trimmed, "else") is Some(else_tail) &&
      word_tail(else_tail, "ifdef") is Some(tail) {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let name = wgsl_clean_directive_tail(tail)
        let cond = !branch_taken_stack[idx] &&
          wgsl_define_enabled(defines, value_defines, name)
        let parent = wgsl_parent_active(active_stack)
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if hash_directive_tail(trimmed, "else") is Some(else_tail) &&
      word_tail(else_tail, "ifndef") is Some(tail) {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let name = wgsl_clean_directive_tail(tail)
        let cond = !branch_taken_stack[idx] &&
          !wgsl_define_enabled(defines, value_defines, name)
        let parent = wgsl_parent_active(active_stack)
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if hash_directive_tail(trimmed, "else") is Some(else_tail) &&
      word_tail(else_tail, "if") is Some(tail) {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let cond = !branch_taken_stack[idx] &&
          eval_wgsl_if_expr(tail, defines, value_defines)
        let parent = wgsl_parent_active(active_stack)
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if hash_directive_tail(trimmed, "else") is Some(_) {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let cond = !branch_taken_stack[idx]
        let parent = wgsl_parent_active(active_stack)
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if hash_directive_tail(trimmed, "endif") is Some(_) {
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
  let registry_rel_path = composable_module_registry_rel_path(desc, module_name)

  let shader_defs = copy_shader_def_values(desc.shader_defs)
  let effective_defs = metadata.effective_defs.copy()
  let all_imports : @hashset.HashSet[String] = @hashset.HashSet::new()
  let additional_imports = copy_import_definitions(desc.additional_imports)
  let import_names : Array[String] = []
  for import_binding in metadata.imports {
    let import_name = import_binding.definition.import_path
    if import_name != "" {
      import_names.push(import_name)
    }
  }
  for import_definition in additional_imports {
    let import_name = import_definition.import_path
    if import_name != "" {
      import_names.push(import_name)
    }
  }

  for import_name in import_names {
    guard resolve_wgsl_import_request_module(
        registry_rel_path,
        import_name,
        self.registry,
        self.registry.copy_import_module_paths(),
      )
      is Some(resolved_module) else {
      raise ComposerError::FailedToResolveImport(import_name)
    }
    all_imports.add(resolved_module.module_path)
    if self.module_sets.get(resolved_module.module_path)
      is Some(imported_module) {
      for effective_def in imported_module.effective_defs {
        effective_defs.add(effective_def)
      }
      for entry in imported_module.shader_defs.iter() {
        let (def_name, def_value) = entry
        shader_defs.set(def_name, def_value)
      }
    }
  }

  for entry in shader_defs.iter() {
    let (def_name, _) = entry
    effective_defs.remove(def_name)
  }

  let source_with_additional_imports = prepend_wgsl_additional_imports(
    desc.source,
    additional_imports,
  )
  let definition = ComposableModuleDefinition::{
    name: module_name,
    sanitized_source: prepend_wgsl_additional_imports(
      metadata.cleaned_source,
      additional_imports,
    ),
    language: desc.language,
    file_path: desc.file_path,
    shader_defs,
    effective_defs: hashset_strings_to_array(effective_defs),
    all_imports,
    additional_imports,
  }

  composer_remove_composable_module_recursive(self, module_name)
  ignore(
    self.registry.register_source(
      registry_rel_path,
      source_with_additional_imports,
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
  match self.registry.registered_source(normalized_rel) {
    Some(source) => source
    None => raise ComposerError::MissingStartupRegisteredSource(normalized_rel)
  }
}

///|
priv struct WgslPreparedComposeSource {
  redirected_source : String
  active_scan_source : String
}

///|
fn prepare_wgsl_compose_source(
  source : String,
  session : WgslComposeSession,
  active_defs : WgslActiveComposeDefs,
) -> WgslPreparedComposeSource {
  record_wgsl_redirect_matches(source, session)
  let redirected_source = rewrite_wgsl_symbol_redirects(
    source,
    session.redirects,
  )
  let active_source = apply_wgsl_template_consts(
    apply_wgsl_ifdefs(
      redirected_source,
      active_defs.defines,
      active_defs.value_defines,
    ),
    active_defs.value_defines,
  )
  WgslPreparedComposeSource::{
    redirected_source,
    active_scan_source: strip_wgsl_import_declarations(active_source),
  }
}

///|
fn Composer::seed_wgsl_compose_lines(
  self : Composer,
  current_rel_path : String,
  prepared : WgslPreparedComposeSource,
  session : WgslComposeSession,
) -> Array[String] {
  let lines : Array[String] = []
  let qualified_targets : Array[WgslImportTarget] = []
  collect_wgsl_qualified_module_targets(
    prepared.active_scan_source,
    current_rel_path,
    self.registry,
    session.modules,
    qualified_targets,
  )
  for target in qualified_targets {
    lines.push("#import \{target.raw_path} as \{target.alias_name}")
  }
  for line_item in prepared.redirected_source.split("\n") {
    lines.push(line_item.to_owned())
  }
  lines
}

///|
fn Composer::build_wgsl_import_requests(
  self : Composer,
  current_rel_path : String,
  spec : String,
  active_scan_source : String,
  session : WgslComposeSession,
) -> Array[WgslImportRequest] raise ComposerError {
  let targets : Array[WgslImportTarget] = []
  let requests : Array[WgslImportRequest] = []
  collect_wgsl_import_targets(spec, "", targets)
  let mut target_index = 0
  while target_index < targets.length() {
    let target = targets[target_index]
    target_index = target_index + 1
    let requested_items : Array[String] = []
    let mut request_module_prefix = target.raw_path
    let mut keep_requested_items = false
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
        self.registry,
        session.modules,
      )
      is Some(resolved_module) else {
      raise ComposerError::FailedToResolveImport(target.raw_path)
    }
    let module_path = resolved_module.module_path
    if target.alias_name == "" {
      request_module_prefix = module_path
    }
    let import_source = match
      self.registry.registered_source(resolved_module.rel_path) {
      Some(source) => source
      None => ""
    }
    let imports_for_override_side_effect = wgsl_source_contains_override_directive(
      import_source,
    )
    let mut module_alias = if target.alias_name != "" {
      target.alias_name
    } else if module_path == target.raw_path {
      wgsl_import_default_alias(module_path)
    } else {
      ""
    }
    let mut import_full_module = module_path == target.raw_path
    if target.alias_name == "" && module_alias != "" {
      if !active_scan_source.contains("\{module_alias}::") &&
        !imports_for_override_side_effect {
        continue
      }
      if imports_for_override_side_effect &&
        !active_scan_source.contains("\{module_alias}::") {
        module_alias = ""
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
      } else if !imports_for_override_side_effect {
        continue
      }
    } else if module_path != target.raw_path {
      import_full_module = false
      keep_requested_items = true
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
        if wgsl_source_contains_identifier(active_scan_source, requested_item) {
          used_requested_items.push(requested_item)
        }
      }
      requested_items.clear()
      for requested_item in used_requested_items {
        requested_items.push(requested_item)
      }
      if requested_items.length() == 0 && !imports_for_override_side_effect {
        continue
      }
      if imports_for_override_side_effect {
        import_full_module = true
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
      if keep_requested_items {
        request.keep_requested_items = true
      }
      for requested_item in requested_items {
        wgsl_string_list_push_unique(request.requested_items, requested_item)
      }
    } else {
      requests.push(WgslImportRequest::{
        module_path,
        rel_path: resolved_module.rel_path,
        import_full_module,
        keep_requested_items,
        requested_items,
        alias_name: module_alias,
      })
    }
  }
  requests
}

///|
fn dedupe_wgsl_duplicate_declarations(source : String) -> String {
  let graph = build_wgsl_declaration_graph(source)
  let mut deduped = ""
  let emitted_blocks : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for import_block in graph.import_blocks {
    deduped = deduped + import_block.text
  }
  for block in graph.declaration_blocks {
    if block.name != "" {
      let normalized_text = block.text.trim().to_owned()
      match emitted_blocks.get(block.name) {
        Some(existing_text) if existing_text == normalized_text => continue
        _ => emitted_blocks.set(block.name, normalized_text)
      }
    }
    deduped = deduped + block.text
  }
  deduped
}

///|
fn wgsl_lowercase_identifier_start(name : String) -> Bool {
  if name == "" {
    return false
  }
  let code = name.code_unit_at(0).to_int()
  code >= 97 && code <= 122
}

///|
fn record_wgsl_lowered_suffix_redirect_candidate(
  suffix : String,
  lowered_name : String,
  declared_names : @hashmap.HashMap[String, Bool],
  candidate_redirects : @hashmap.HashMap[String, String],
  ambiguous_suffixes : @hashmap.HashMap[String, Bool],
) -> Unit {
  if suffix == "" ||
    !wgsl_lowercase_identifier_start(suffix) ||
    declared_names.contains(suffix) {
    return
  }
  match candidate_redirects.get(suffix) {
    Some(existing) if existing != lowered_name =>
      ambiguous_suffixes.set(suffix, true)
    Some(_) => ()
    None => candidate_redirects.set(suffix, lowered_name)
  }
}

///|
fn build_wgsl_unique_lowered_suffix_redirect_map(
  source : String,
) -> @hashmap.HashMap[String, String] {
  let graph = build_wgsl_declaration_graph(source)
  let declared_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let candidate_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let ambiguous_suffixes : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  for block in graph.declaration_blocks {
    if block.name != "" {
      declared_names.set(block.name, true)
    }
  }
  for block in graph.declaration_blocks {
    let mut i = 0
    while i + 1 < block.name.length() {
      if block.name.code_unit_at(i).to_int() == 95 &&
        block.name.code_unit_at(i + 1).to_int() == 95 {
        record_wgsl_lowered_suffix_redirect_candidate(
          block.name[i + 2:block.name.length()].to_owned(),
          block.name,
          declared_names,
          candidate_redirects,
          ambiguous_suffixes,
        )
        i = i + 2
        continue
      }
      i = i + 1
    }
  }
  let redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for entry in candidate_redirects.iter() {
    let (suffix, lowered_name) = entry
    if !ambiguous_suffixes.contains(suffix) {
      redirects.set(suffix, lowered_name)
    }
  }
  redirects
}

///|
fn token_identifier_value(token : Token) -> String? {
  match token {
    Token::Identifier(ident, _) => Some(ident)
    _ => None
  }
}

///|
fn token_other_code_value(token : Token) -> Int? {
  match token {
    Token::Other(code, _) => Some(code)
    _ => None
  }
}

///|
fn skip_wgsl_template_tokens(tokens : Array[Token], start : Int) -> Int {
  if start >= tokens.length() {
    return start
  }
  guard token_other_code_value(tokens[start]) is Some(60) else { return start }
  let mut depth = 1
  let mut i = start + 1
  while i < tokens.length() && depth > 0 {
    match token_other_code_value(tokens[i]) {
      Some(60) => depth = depth + 1
      Some(62) => depth = depth - 1
      _ => ()
    }
    i = i + 1
  }
  i
}

///|
fn collect_wgsl_block_local_names(
  block_text : String,
) -> @hashmap.HashMap[String, Bool] {
  let locals : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let tokens = tokenize(replace_comments(block_text), false)
  for i in 0..<tokens.length() {
    guard token_identifier_value(tokens[i]) is Some(ident) else { continue }
    if ident == "var" || ident == "let" || ident == "const" {
      let name_index = skip_wgsl_template_tokens(tokens, i + 1)
      if name_index < tokens.length() &&
        token_identifier_value(tokens[name_index]) is Some(name) {
        locals.set(name, true)
      }
      continue
    }
    if i + 1 < tokens.length() &&
      token_other_code_value(tokens[i + 1]) is Some(58) {
      locals.set(ident, true)
    }
  }
  locals
}

///|
fn rewrite_wgsl_declaration_blocks_with_suffix_redirects(
  source : String,
  redirect_map : @hashmap.HashMap[String, String],
) -> String {
  let graph = build_wgsl_declaration_graph(source)
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + import_block.text
  }
  for block in graph.declaration_blocks {
    let local_names = collect_wgsl_block_local_names(block.text)
    let block_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
    for entry in redirect_map.iter() {
      let (from_name, to_name) = entry
      if !local_names.contains(from_name) {
        block_redirects.set(from_name, to_name)
      }
    }
    if block_redirects.is_empty() {
      out = out + block.text
    } else {
      out = out +
        rewrite_wgsl_declaration_text_with_map(
          block.text,
          block_redirects,
          false,
        )
    }
  }
  out
}

///|
fn Composer::compose_wgsl_import_requests(
  self : Composer,
  current_rel_path : String,
  requests : Array[WgslImportRequest],
  alias_redirects : Array[WgslSymbolRedirect],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> String raise ComposerError {
  let mut merged = ""
  for request in requests {
    let full_module_key = wgsl_full_module_visit_key(
      request.rel_path,
      request.alias_name,
    )
    if wgsl_path_stack_contains(session.active_rel_paths, request.rel_path) {
      raise ComposerError::ImportCycle(
        wgsl_import_cycle_string(session.active_rel_paths, request.rel_path),
      )
    }
    if request.import_full_module {
      if session.visited.contains(full_module_key) {
        collect_wgsl_cached_import_redirects(
          session,
          request.rel_path,
          request.alias_name,
          alias_redirects,
        )
        |> ignore
        continue
      }
    }
    if !request.import_full_module && request.alias_name == "" {
      let mut resolved_requested_items = 0
      for requested_item in request.requested_items {
        match
          find_wgsl_cached_imported_item_name(
            session,
            request.rel_path,
            requested_item,
          ) {
          Some(imported_name) => {
            alias_redirects.push(WgslSymbolRedirect::{
              from_name: requested_item,
              to_name: imported_name,
            })
            resolved_requested_items = resolved_requested_items + 1
          }
          None => ()
        }
      }
      if request.requested_items.length() > 0 &&
        resolved_requested_items == request.requested_items.length() {
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
        Some(importer_defs),
      )
    } else {
      let import_defs = self.active_compose_defs_for_rel_path(
        request.rel_path,
        session,
        Some(importer_defs),
      )
      let prepared_source = apply_wgsl_template_consts(
        apply_wgsl_ifdefs(
          raw_source,
          import_defs.defines,
          import_defs.value_defines,
        ),
        import_defs.value_defines,
      )
      let filtered_source = extract_wgsl_module_items(
        prepared_source,
        request.requested_items,
      )
      self.preprocess_wgsl_source_with_path(
        request.rel_path,
        filtered_source,
        session,
        Some(importer_defs),
      )
    }
    session.active_rel_paths.pop() |> ignore
    if module_source == "" {
      continue
    }
    let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
    let final_module_source = if request.alias_name != "" {
      let request_rename_map = build_wgsl_import_rename_map(
        module_source,
        request.alias_name,
      )
      for entry in request_rename_map.iter() {
        let (from_name, to_name) = entry
        rename_map.set(from_name, to_name)
      }
      collect_wgsl_import_alias_redirects(
        request.alias_name,
        request_rename_map,
        alias_redirects,
      )
      rewrite_wgsl_declaration_text_with_renamed_declarations(
        module_source, request_rename_map,
      )
    } else {
      module_source
    }
    if rename_map.is_empty() {
      let final_graph = build_wgsl_declaration_graph(final_module_source)
      for block in final_graph.declaration_blocks {
        if block.name == "" {
          continue
        }
        session.imported_item_names.set(
          wgsl_imported_item_name_key(request.rel_path, block.name),
          block.name,
        )
      }
    } else {
      for entry in rename_map.iter() {
        let (from_name, to_name) = entry
        session.imported_item_names.set(
          wgsl_imported_item_name_key(request.rel_path, from_name),
          to_name,
        )
      }
    }
    if request.import_full_module {
      session.visited.set(full_module_key, true)
    }
    merged = "\{merged}\{final_module_source}"
    let merged_len = merged.length()
    if merged_len == 0 || merged.code_unit_at(merged_len - 1).to_int() != 10 {
      merged = "\{merged}\n"
    }
  }
  merged
}

///|
fn finalize_wgsl_composed_source(
  merged : String,
  alias_redirects : Array[WgslSymbolRedirect],
  active_defs : WgslActiveComposeDefs,
) -> String raise ComposerError {
  let mut out = apply_wgsl_ifdefs(
    merged,
    active_defs.defines,
    active_defs.value_defines,
  )
  out = apply_wgsl_template_consts(out, active_defs.value_defines)
  let alias_redirect_map = build_wgsl_symbol_redirect_map(alias_redirects)
  out = apply_wgsl_virtual_overrides(out, alias_redirect_map)
  out = rewrite_wgsl_declaration_text_with_map(out, alias_redirect_map, false)
  out = dedupe_wgsl_duplicate_declarations(out)
  let suffix_redirects = build_wgsl_unique_lowered_suffix_redirect_map(out)
  if !suffix_redirects.is_empty() {
    out = rewrite_wgsl_declaration_blocks_with_suffix_redirects(
      out, suffix_redirects,
    )
  }
  if unresolved_wgsl_namespace_reference(out) is Some(path) {
    raise ComposerError::FailedToResolveImport(path)
  }
  out
}

///|
fn Composer::preprocess_wgsl_source_with_path(
  self : Composer,
  current_rel_path : String,
  source : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
) -> String raise ComposerError {
  let active_defs = self.active_compose_defs_for_rel_path(
    current_rel_path, session, inherited_defs,
  )
  let prepared = prepare_wgsl_compose_source(source, session, active_defs)
  let mut merged = ""
  let alias_redirects : Array[WgslSymbolRedirect] = []
  let lines = self.seed_wgsl_compose_lines(current_rel_path, prepared, session)
  let import_active_stack : Array[Bool] = [true]
  let import_branch_taken_stack : Array[Bool] = []
  let mut line_index = 0
  while line_index < lines.length() {
    let line = lines[line_index]
    let trimmed = line.trim().to_owned()
    if hash_directive_tail(trimmed, "ifdef") is Some(tail) {
      let name = wgsl_clean_directive_tail(tail)
      let cond = wgsl_define_enabled(
        active_defs.defines,
        active_defs.value_defines,
        name,
      )
      let parent = import_active_stack[import_active_stack.length() - 1]
      import_active_stack.push(parent && cond)
      import_branch_taken_stack.push(cond)
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if hash_directive_tail(trimmed, "ifndef") is Some(tail) {
      let name = wgsl_clean_directive_tail(tail)
      let cond = !wgsl_define_enabled(
        active_defs.defines,
        active_defs.value_defines,
        name,
      )
      let parent = import_active_stack[import_active_stack.length() - 1]
      import_active_stack.push(parent && cond)
      import_branch_taken_stack.push(cond)
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if hash_directive_tail(trimmed, "if") is Some(tail) {
      let expr = wgsl_clean_directive_tail(tail)
      let cond = eval_wgsl_if_expr(
        expr,
        active_defs.defines,
        active_defs.value_defines,
      )
      let parent = import_active_stack[import_active_stack.length() - 1]
      import_active_stack.push(parent && cond)
      import_branch_taken_stack.push(cond)
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if hash_directive_tail(trimmed, "else") is Some(else_tail) &&
      word_tail(else_tail, "ifdef") is Some(tail) {
      if import_branch_taken_stack.length() > 0 {
        let idx = import_branch_taken_stack.length() - 1
        let name = wgsl_clean_directive_tail(tail)
        let cond = !import_branch_taken_stack[idx] &&
          wgsl_define_enabled(
            active_defs.defines,
            active_defs.value_defines,
            name,
          )
        let parent = wgsl_parent_active(import_active_stack)
        import_active_stack[import_active_stack.length() - 1] = parent && cond
        import_branch_taken_stack[idx] = import_branch_taken_stack[idx] || cond
      }
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if hash_directive_tail(trimmed, "else") is Some(else_tail) &&
      word_tail(else_tail, "ifndef") is Some(tail) {
      if import_branch_taken_stack.length() > 0 {
        let idx = import_branch_taken_stack.length() - 1
        let name = wgsl_clean_directive_tail(tail)
        let cond = !import_branch_taken_stack[idx] &&
          !wgsl_define_enabled(
            active_defs.defines,
            active_defs.value_defines,
            name,
          )
        let parent = wgsl_parent_active(import_active_stack)
        import_active_stack[import_active_stack.length() - 1] = parent && cond
        import_branch_taken_stack[idx] = import_branch_taken_stack[idx] || cond
      }
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if hash_directive_tail(trimmed, "else") is Some(else_tail) &&
      word_tail(else_tail, "if") is Some(tail) {
      if import_branch_taken_stack.length() > 0 {
        let idx = import_branch_taken_stack.length() - 1
        let cond = !import_branch_taken_stack[idx] &&
          eval_wgsl_if_expr(
            tail,
            active_defs.defines,
            active_defs.value_defines,
          )
        let parent = wgsl_parent_active(import_active_stack)
        import_active_stack[import_active_stack.length() - 1] = parent && cond
        import_branch_taken_stack[idx] = import_branch_taken_stack[idx] || cond
      }
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if hash_directive_tail(trimmed, "else") is Some(_) {
      if import_branch_taken_stack.length() > 0 {
        let idx = import_branch_taken_stack.length() - 1
        let cond = !import_branch_taken_stack[idx]
        let parent = wgsl_parent_active(import_active_stack)
        import_active_stack[import_active_stack.length() - 1] = parent && cond
        import_branch_taken_stack[idx] = import_branch_taken_stack[idx] || cond
      }
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if hash_directive_tail(trimmed, "endif") is Some(_) {
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
    if hash_directive_tail(trimmed, "define_import_path") is Some(_) {
      line_index = line_index + 1
      continue
    }
    if hash_directive_tail(trimmed, "import") is Some(import_tail) {
      if !import_active_stack[import_active_stack.length() - 1] {
        merged = "\{merged}\{line}\n"
        line_index = line_index + 1
        continue
      }
      let mut spec = import_tail
      let mut brace_balance = import_brace_balance(spec)
      while brace_balance > 0 && line_index + 1 < lines.length() {
        line_index = line_index + 1
        let next_line = lines[line_index]
        spec = "\{spec}\n\{next_line}"
        brace_balance = brace_balance + import_brace_balance(next_line)
      }
      let requests = self.build_wgsl_import_requests(
        current_rel_path,
        spec,
        prepared.active_scan_source,
        session,
      )
      let composed_imports = self.compose_wgsl_import_requests(
        current_rel_path, requests, alias_redirects, session, active_defs,
      )
      merged = "\{merged}\{composed_imports}"
      line_index = line_index + 1
      continue
    }
    merged = "\{merged}\{line}\n"
    line_index = line_index + 1
  }
  finalize_wgsl_composed_source(merged, alias_redirects, active_defs)
}

///|
pub fn Composer::load_root_wgsl_preprocessed_into_session(
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
    normalized_rel,
    prepend_wgsl_additional_imports(source, session.additional_imports),
    session,
    None,
  )
  session.active_rel_paths.pop() |> ignore
  composed
}

///|
pub fn Composer::compose_wgsl(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  let composed = strip_wgsl_virtual_functions(
    self.load_root_wgsl_preprocessed_into_session(rel, session),
  )
  finalize_wgsl_writeback_source(composed)
}

///|
pub fn Composer::compose_wgsl_source(
  self : Composer,
  source : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  let composed = strip_wgsl_virtual_functions(
    self.preprocess_wgsl_source_with_path(
      "",
      prepend_wgsl_additional_imports(source, session.additional_imports),
      session,
      None,
    ),
  )
  finalize_wgsl_writeback_source(composed)
}

///|
pub fn Composer::load_wgsl_from_assets_base_required(
  self : Composer,
  assets_base : String,
  rel : String,
) -> String raise ComposerError {
  let base = assets_base.trim().to_owned()
  if base == "" {
    raise ComposerError::EmptyAssetsBase(rel)
  }
  self.compose_wgsl(rel, WgslComposeOptions::{
    assets_base: base,
    defines: @hashmap.HashMap::new(),
    value_defines: default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  })
}
