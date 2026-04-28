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
  imported_item_names : @hashmap.HashMap[String, String]
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
fn Composer::new_wgsl_compose_session(
  self : Composer,
  options : WgslComposeOptions,
) -> WgslComposeSession {
  WgslComposeSession::{
    assets_base: options.assets_base.trim().to_string(),
    defines: copy_bool_defs(options.defines),
    value_defines: copy_int_defs(options.value_defines),
    modules: self.registry.copy_import_module_paths(),
    redirects: options.redirects.copy(),
    visited: @hashmap.HashMap::new(),
    imported_item_names: @hashmap.HashMap::new(),
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
      return text[:i].to_string()
    }
    i = i + 1
  }
  text
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

  composer_remove_composable_module_recursive(self, module_name)
  ignore(
    self.registry.register_source(
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
) -> WgslPreparedComposeSource {
  let redirected_source = rewrite_wgsl_symbol_redirects(
    source,
    session.redirects,
  )
  let active_source = apply_wgsl_template_consts(
    apply_wgsl_ifdefs(redirected_source, session.defines, session.value_defines),
    session.value_defines,
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
    lines.push(line_item.to_string())
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
      let import_source = match
        self.registry.registered_source(resolved_module.rel_path) {
        Some(source) => source
        None => ""
      }
      let used_requested_items : Array[String] = []
      for requested_item in requested_items {
        if wgsl_source_contains_identifier(active_scan_source, requested_item) ||
          (
            keep_requested_items &&
            wgsl_source_declares_entry_point(import_source, requested_item)
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
fn Composer::compose_wgsl_import_requests(
  self : Composer,
  current_rel_path : String,
  requests : Array[WgslImportRequest],
  alias_redirects : Array[WgslSymbolRedirect],
  session : WgslComposeSession,
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
        continue
      }
    }
    if !request.import_full_module && request.alias_name == "" {
      let mut resolved_requested_items = 0
      for requested_item in request.requested_items {
        match
          session.imported_item_names.get(
            wgsl_imported_item_name_key(request.rel_path, requested_item),
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
      )
    } else {
      let prepared_source = apply_wgsl_template_consts(
        apply_wgsl_ifdefs(raw_source, session.defines, session.value_defines),
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
  session : WgslComposeSession,
) -> String raise ComposerError {
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
fn Composer::preprocess_wgsl_source_with_path(
  self : Composer,
  current_rel_path : String,
  source : String,
  session : WgslComposeSession,
) -> String raise ComposerError {
  let prepared = prepare_wgsl_compose_source(source, session)
  let mut merged = ""
  let alias_redirects : Array[WgslSymbolRedirect] = []
  let lines = self.seed_wgsl_compose_lines(current_rel_path, prepared, session)
  let import_active_stack : Array[Bool] = [true]
  let import_branch_taken_stack : Array[Bool] = []
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
      let requests = self.build_wgsl_import_requests(
        current_rel_path,
        spec,
        prepared.active_scan_source,
        session,
      )
      let composed_imports = self.compose_wgsl_import_requests(
        current_rel_path, requests, alias_redirects, session,
      )
      merged = "\{merged}\{composed_imports}"
      line_index = line_index + 1
      continue
    }
    merged = "\{merged}\{line}\n"
    line_index = line_index + 1
  }
  finalize_wgsl_composed_source(merged, alias_redirects, session)
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
pub fn Composer::compose_wgsl(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  self.load_wgsl_preprocessed_into_session(rel, session)
}

///|
pub fn Composer::compose_wgsl_source(
  self : Composer,
  source : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  self.preprocess_wgsl_source_with_path("", source, session)
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
