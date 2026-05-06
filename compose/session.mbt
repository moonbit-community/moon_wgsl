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
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  name : String,
  value : ShaderDefValue,
) -> Unit {
  shader_defs.set(name, value)
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
priv struct WgslComposeSemanticFacts {
  declarations : Array[WgslEmittedDeclaration]
  reference_paths : @hashset.HashSet[String]
}

///|
priv struct WgslCanonicalFinalNameEntry {
  identity : WgslSymbolIdentity
  generated_name : String
}

///|
priv struct WgslAliasFinalNameEntry {
  identity : WgslAliasSymbolIdentity
  generated_name : String
}

///|
priv struct WgslFinalNameTables {
  canonical : @hashmap.HashMap[String, String]
  alias_scoped : @hashmap.HashMap[String, String]
  canonical_entries : Array[WgslCanonicalFinalNameEntry]
  alias_entries : Array[WgslAliasFinalNameEntry]
}

///|
fn WgslFinalNameTables::new() -> WgslFinalNameTables {
  WgslFinalNameTables::{
    canonical: @hashmap.HashMap::new(),
    alias_scoped: @hashmap.HashMap::new(),
    canonical_entries: [],
    alias_entries: [],
  }
}

///|
fn WgslFinalNameTables::canonical_set(
  self : WgslFinalNameTables,
  identity : WgslSymbolIdentity,
  generated_name : String,
) -> Unit {
  let key = identity.key()
  self.canonical.set(key, generated_name)
  for i in 0..<self.canonical_entries.length() {
    if self.canonical_entries[i].identity.key() == key {
      self.canonical_entries[i] = WgslCanonicalFinalNameEntry::{
        identity,
        generated_name,
      }
      return
    }
  }
  self.canonical_entries.push(WgslCanonicalFinalNameEntry::{
    identity,
    generated_name,
  })
}

///|
fn WgslFinalNameTables::canonical_get(
  self : WgslFinalNameTables,
  identity : WgslSymbolIdentity,
) -> String? {
  self.canonical.get(identity.key())
}

///|
fn WgslFinalNameTables::canonical_entries_for_rel_path(
  self : WgslFinalNameTables,
  rel_path : String,
) -> Array[WgslCanonicalFinalNameEntry] {
  let entries : Array[WgslCanonicalFinalNameEntry] = []
  for entry in self.canonical_entries {
    if entry.identity.rel_path == rel_path {
      entries.push(entry)
    }
  }
  entries
}

///|
fn WgslFinalNameTables::alias_set(
  self : WgslFinalNameTables,
  identity : WgslAliasSymbolIdentity,
  generated_name : String,
) -> Unit {
  let key = identity.key()
  self.alias_scoped.set(key, generated_name)
  for i in 0..<self.alias_entries.length() {
    if self.alias_entries[i].identity.key() == key {
      self.alias_entries[i] = WgslAliasFinalNameEntry::{
        identity,
        generated_name,
      }
      return
    }
  }
  self.alias_entries.push(WgslAliasFinalNameEntry::{ identity, generated_name })
}

///|
fn WgslFinalNameTables::alias_get(
  self : WgslFinalNameTables,
  identity : WgslAliasSymbolIdentity,
) -> String? {
  self.alias_scoped.get(identity.key())
}

///|
fn WgslFinalNameTables::alias_entries_for_scope(
  self : WgslFinalNameTables,
  rel_path : String,
  alias_name : String,
) -> Array[WgslAliasFinalNameEntry] {
  let entries : Array[WgslAliasFinalNameEntry] = []
  for entry in self.alias_entries {
    if entry.identity.alias_name == alias_name &&
      entry.identity.symbol.rel_path == rel_path {
      entries.push(entry)
    }
  }
  entries
}

///|
priv struct WgslComposeSession {
  defines : @hashmap.HashMap[String, Bool]
  value_defines : @hashmap.HashMap[String, Int]
  modules : @hashmap.HashMap[String, String]
  redirects : Array[WgslSymbolRedirect]
  composed_alias_redirects : WgslScopedAliasRedirectSet
  additional_imports : Array[ImportDefinition]
  redirect_match_counts : @hashmap.HashMap[String, Int]
  visited : @hashmap.HashMap[String, Bool]
  final_names : WgslFinalNameTables
  symbol_graph : WgslComposeSymbolGraph
  semantic_facts : @hashmap.HashMap[String, WgslComposeSemanticFacts]
  active_rel_paths : Array[String]
  source_origins : Array[WgslSourceOriginEntry]
}

///|
priv enum WgslAliasRedirectScope {
  QualifiedAliasReference
  CachedQualifiedAliasReference
  UnqualifiedItemBinding
} derive(Eq)

///|
priv struct WgslScopedAliasRedirect {
  redirect : WgslSymbolRedirect
  scope : WgslAliasRedirectScope
  identity : WgslSymbolIdentity?
  alias_name : String
}

///|
priv struct WgslScopedAliasRedirectSet {
  redirects : Array[WgslScopedAliasRedirect]
  keys : @hashset.HashSet[String]
}

///|
priv struct WgslLiveAliasBindingPlan {
  bindings : Array[WgslScopedAliasRedirect]
}

///|
fn WgslLiveAliasBindingPlan::new() -> WgslLiveAliasBindingPlan {
  WgslLiveAliasBindingPlan::{ bindings: [] }
}

///|
fn WgslLiveAliasBindingPlan::push(
  self : WgslLiveAliasBindingPlan,
  binding : WgslScopedAliasRedirect,
) -> Unit {
  self.bindings.push(binding)
}

///|
fn WgslLiveAliasBindingPlan::symbol_redirects(
  self : WgslLiveAliasBindingPlan,
) -> Array[WgslSymbolRedirect] {
  let redirects : Array[WgslSymbolRedirect] = []
  for binding in self.bindings {
    redirects.push(binding.redirect)
  }
  redirects
}

///|
fn WgslLiveAliasBindingPlan::redirect_map(
  self : WgslLiveAliasBindingPlan,
) -> @hashmap.HashMap[String, String] {
  build_wgsl_symbol_redirect_map(self.symbol_redirects())
}

///|
fn WgslScopedAliasRedirectSet::new() -> WgslScopedAliasRedirectSet {
  WgslScopedAliasRedirectSet::{ redirects: [], keys: @hashset.HashSet::new() }
}

///|
fn wgsl_alias_redirect_scope_key(scope : WgslAliasRedirectScope) -> String {
  match scope {
    QualifiedAliasReference => "qualified"
    CachedQualifiedAliasReference => "cached"
    UnqualifiedItemBinding => "unqualified"
  }
}

///|
fn wgsl_scoped_alias_redirect_key(
  scoped_redirect : WgslScopedAliasRedirect,
) -> String {
  let redirect = scoped_redirect.redirect
  let from_name = redirect.from_name.trim().to_owned()
  let to_name = redirect.to_name.trim().to_owned()
  let identity_key = match scoped_redirect.identity {
    Some(identity) => identity.key()
    None => ""
  }
  "\{wgsl_alias_redirect_scope_key(scoped_redirect.scope)}|\{from_name}|\{to_name}|\{scoped_redirect.alias_name}|\{identity_key}"
}

///|
fn WgslScopedAliasRedirect::new(
  redirect : WgslSymbolRedirect,
  scope : WgslAliasRedirectScope,
  identity : WgslSymbolIdentity?,
  alias_name : String,
) -> WgslScopedAliasRedirect {
  WgslScopedAliasRedirect::{ redirect, scope, identity, alias_name }
}

///|
fn WgslScopedAliasRedirect::for_alias_symbol(
  rel_path : String,
  alias_name : String,
  original_name : String,
  generated_name : String,
  scope : WgslAliasRedirectScope,
) -> WgslScopedAliasRedirect {
  WgslScopedAliasRedirect::new(
    WgslSymbolRedirect::{
      from_name: "\{alias_name}::\{original_name}",
      to_name: generated_name,
    },
    scope,
    Some(WgslSymbolIdentity::new(rel_path, original_name)),
    alias_name,
  )
}

///|
fn WgslScopedAliasRedirect::for_unqualified_symbol(
  rel_path : String,
  original_name : String,
  generated_name : String,
  scope : WgslAliasRedirectScope,
) -> WgslScopedAliasRedirect {
  WgslScopedAliasRedirect::new(
    WgslSymbolRedirect::{ from_name: original_name, to_name: generated_name },
    scope,
    Some(WgslSymbolIdentity::new(rel_path, original_name)),
    "",
  )
}

///|
fn WgslScopedAliasRedirect::as_unqualified_binding(
  self : WgslScopedAliasRedirect,
  from_name : String,
) -> WgslScopedAliasRedirect {
  WgslScopedAliasRedirect::new(
    WgslSymbolRedirect::{ from_name, to_name: self.redirect.to_name },
    UnqualifiedItemBinding,
    self.identity,
    self.alias_name,
  )
}

///|
fn WgslScopedAliasRedirectSet::push(
  self : WgslScopedAliasRedirectSet,
  scoped_redirect : WgslScopedAliasRedirect,
) -> Unit {
  let key = wgsl_scoped_alias_redirect_key(scoped_redirect)
  if self.keys.contains(key) {
    return
  }
  self.keys.add(key)
  self.redirects.push(scoped_redirect)
}

///|
fn WgslScopedAliasRedirectSet::extend(
  self : WgslScopedAliasRedirectSet,
  other : WgslScopedAliasRedirectSet,
) -> Unit {
  for redirect in other.redirects {
    self.push(redirect)
  }
}

///|
fn WgslComposeSession::record_canonical_final_name(
  self : WgslComposeSession,
  identity : WgslSymbolIdentity,
  generated_name : String,
) -> Unit {
  self.final_names.canonical_set(identity, generated_name)
  self.symbol_graph.record_reachable_symbol(identity)
}

///|
fn WgslComposeSession::record_canonical_final_name_if_absent(
  self : WgslComposeSession,
  identity : WgslSymbolIdentity,
  generated_name : String,
) -> Unit {
  if self.final_names.canonical_get(identity) is None {
    self.record_canonical_final_name(identity, generated_name)
  }
}

///|
fn WgslComposeSession::record_alias_final_name(
  self : WgslComposeSession,
  identity : WgslAliasSymbolIdentity,
  generated_name : String,
) -> Unit {
  self.final_names.alias_set(identity, generated_name)
  self.symbol_graph.record_reachable_symbol(identity.symbol)
}

///|
fn WgslComposeSession::record_alias_final_name_if_absent(
  self : WgslComposeSession,
  identity : WgslAliasSymbolIdentity,
  generated_name : String,
) -> Unit {
  if self.final_names.alias_get(identity) is None {
    self.record_alias_final_name(identity, generated_name)
  }
}

///|
priv struct WgslActiveComposeDefs {
  defines : @hashmap.HashMap[String, Bool]
  value_defines : @hashmap.HashMap[String, Int]
  shader_defs : @hashmap.HashMap[String, ShaderDefValue]
}

///|
fn composable_module_name_from_descriptor(
  desc : ComposableModuleDescriptor,
  metadata_name : String?,
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
      match metadata_name {
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
