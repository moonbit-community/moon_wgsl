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
priv struct WgslFinalNameTables {
  canonical : @hashmap.HashMap[String, String]
  alias_scoped : @hashmap.HashMap[String, String]
}

///|
fn WgslFinalNameTables::new() -> WgslFinalNameTables {
  WgslFinalNameTables::{
    canonical: @hashmap.HashMap::new(),
    alias_scoped: @hashmap.HashMap::new(),
  }
}

///|
fn WgslFinalNameTables::canonical_set(
  self : WgslFinalNameTables,
  identity : WgslSymbolIdentity,
  generated_name : String,
) -> Unit {
  self.canonical.set(identity.key(), generated_name)
}

///|
fn WgslFinalNameTables::canonical_set_if_absent(
  self : WgslFinalNameTables,
  identity : WgslSymbolIdentity,
  generated_name : String,
) -> Unit {
  let key = identity.key()
  if !self.canonical.contains(key) {
    self.canonical.set(key, generated_name)
  }
}

///|
fn WgslFinalNameTables::canonical_get(
  self : WgslFinalNameTables,
  identity : WgslSymbolIdentity,
) -> String? {
  self.canonical.get(identity.key())
}

///|
fn WgslFinalNameTables::alias_set(
  self : WgslFinalNameTables,
  identity : WgslAliasSymbolIdentity,
  generated_name : String,
) -> Unit {
  self.alias_scoped.set(identity.key(), generated_name)
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
}

///|
priv struct WgslScopedAliasRedirectSet {
  redirects : Array[WgslScopedAliasRedirect]
  keys : @hashset.HashSet[String]
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
  "\{wgsl_alias_redirect_scope_key(scoped_redirect.scope)}|\{from_name}|\{to_name}"
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
