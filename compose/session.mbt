///|
fn copy_shader_def_values(
  defs : @hashmap.HashMap[String, ShaderDefValue],
) -> @hashmap.HashMap[String, ShaderDefValue] {
  let copied : @hashmap.HashMap[String, ShaderDefValue] = @hashmap.HashMap([])
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
  let copied : @hashmap.HashMap[String, Bool] = @hashmap.HashMap([])
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
  let copied : @hashmap.HashMap[String, Int] = @hashmap.HashMap([])
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
priv struct WgslComposeSession {
  defines : @hashmap.HashMap[String, Bool]
  value_defines : @hashmap.HashMap[String, Int]
  modules : @hashmap.HashMap[String, String]
  redirects : Array[WgslSymbolRedirect]
  composed_bindings : WgslComposeBindingSet
  additional_imports : Array[ImportDefinition]
  redirect_match_counts : @hashmap.HashMap[String, Int]
  visited : @hashmap.HashMap[String, Bool]
  graph_planned_requests : @hashmap.HashMap[String, Bool]
  graph_planning_rel_paths : Array[String]
  mut graph_execution_complete : Bool
  assigned_final_names : WgslIrFinalNameTable
  final_names : WgslIrFinalNameTable
  virtual_override_final_names : Array[WgslVirtualOverrideFinalNameBinding]
  link_graph : WgslIrLinkGraph
  semantic_facts : @hashmap.HashMap[String, WgslComposeSemanticFacts]
  active_rel_paths : Array[String]
  source_origins : Array[WgslSourceOriginEntry]
}

///|
priv enum WgslComposeBindingScope {
  QualifiedAliasBinding
  UnqualifiedItemBinding
} derive(Eq)

///|
priv struct WgslComposeBinding {
  from_name : String
  to_name : String
  scope : WgslComposeBindingScope
  identity : WgslIrSymbolIdentity?
  alias_name : String
}

///|
priv struct WgslComposeBindingSet {
  bindings : Array[WgslComposeBinding]
  keys : @hashset.HashSet[String]
}

///|
priv struct WgslVirtualOverrideFinalNameBinding {
  raw_target_name : String
  target_name : String
  override_name : String
}

///|
priv struct WgslLiveBindingPlan {
  bindings : Array[WgslComposeBinding]
}

///|
fn WgslLiveBindingPlan::WgslLiveBindingPlan() -> WgslLiveBindingPlan {
  WgslLiveBindingPlan::{ bindings: [] }
}

///|
fn WgslLiveBindingPlan::push(
  self : WgslLiveBindingPlan,
  binding : WgslComposeBinding,
) -> Unit {
  self.bindings.push(binding)
}

///|
fn WgslLiveBindingPlan::reference_rewrite_plan(
  self : WgslLiveBindingPlan,
  session : WgslComposeSession,
) -> WgslReferenceRewritePlan {
  let plan = WgslReferenceRewritePlan()
  for binding in self.bindings {
    match binding.identity {
      Some(identity) =>
        plan.add_symbol_binding(identity, binding.from_name, binding.to_name)
      None => ()
    }
  }
  for binding in session.virtual_override_final_names {
    plan.add_virtual_override_binding(
      binding.raw_target_name,
      binding.target_name,
      binding.override_name,
    )
  }
  plan
}

///|
fn WgslComposeBindingSet::WgslComposeBindingSet() -> WgslComposeBindingSet {
  WgslComposeBindingSet::{ bindings: [], keys: @hashset.HashSet([]) }
}

///|
fn wgsl_compose_binding_scope_key(scope : WgslComposeBindingScope) -> String {
  match scope {
    QualifiedAliasBinding => "qualified"
    UnqualifiedItemBinding => "unqualified"
  }
}

///|
fn wgsl_compose_binding_key(binding : WgslComposeBinding) -> String {
  let from_name = binding.from_name.trim().to_owned()
  let to_name = binding.to_name.trim().to_owned()
  let identity_key = match binding.identity {
    Some(identity) => identity.key()
    None => ""
  }
  "\{wgsl_compose_binding_scope_key(binding.scope)}|\{from_name}|\{to_name}|\{binding.alias_name}|\{identity_key}"
}

///|
fn WgslComposeBinding::WgslComposeBinding(
  from_name : String,
  to_name : String,
  scope : WgslComposeBindingScope,
  identity : WgslIrSymbolIdentity?,
  alias_name : String,
) -> WgslComposeBinding {
  WgslComposeBinding::{ from_name, to_name, scope, identity, alias_name }
}

///|
fn WgslComposeBinding::for_alias_symbol(
  rel_path : String,
  alias_name : String,
  original_name : String,
  final_name : String,
  scope : WgslComposeBindingScope,
) -> WgslComposeBinding {
  WgslComposeBinding(
    "\{alias_name}::\{original_name}",
    final_name,
    scope,
    Some(WgslIrSymbolIdentity(rel_path, original_name)),
    alias_name,
  )
}

///|
fn WgslComposeBinding::for_unqualified_symbol(
  rel_path : String,
  original_name : String,
  final_name : String,
  scope : WgslComposeBindingScope,
) -> WgslComposeBinding {
  WgslComposeBinding(
    original_name,
    final_name,
    scope,
    Some(WgslIrSymbolIdentity(rel_path, original_name)),
    "",
  )
}

///|
fn WgslComposeBinding::as_unqualified_binding(
  self : WgslComposeBinding,
  from_name : String,
) -> WgslComposeBinding {
  WgslComposeBinding(
    from_name,
    self.to_name,
    UnqualifiedItemBinding,
    self.identity,
    self.alias_name,
  )
}

///|
fn WgslComposeBinding::with_to_name(
  self : WgslComposeBinding,
  to_name : String,
) -> WgslComposeBinding {
  WgslComposeBinding(
    self.from_name,
    to_name,
    self.scope,
    self.identity,
    self.alias_name,
  )
}

///|
fn WgslComposeBindingSet::push(
  self : WgslComposeBindingSet,
  binding : WgslComposeBinding,
) -> Unit {
  if binding.alias_name != "" && binding.scope != UnqualifiedItemBinding {
    let binding_identity_key = match binding.identity {
      Some(identity) => identity.key()
      None => ""
    }
    for existing in self.bindings {
      if existing.scope == binding.scope &&
        existing.alias_name == binding.alias_name &&
        existing.from_name == binding.from_name {
        let existing_identity_key = match existing.identity {
          Some(identity) => identity.key()
          None => ""
        }
        if existing_identity_key != "" &&
          existing_identity_key == binding_identity_key {
          continue
        }
        return
      }
    }
  }
  let key = wgsl_compose_binding_key(binding)
  if self.keys.contains(key) {
    return
  }
  self.keys.add(key)
  self.bindings.push(binding)
}

///|
fn WgslComposeBindingSet::extend(
  self : WgslComposeBindingSet,
  other : WgslComposeBindingSet,
) -> Unit {
  for binding in other.bindings {
    self.push(binding)
  }
}

///|
fn WgslVirtualOverrideFinalNameBinding::key(
  self : WgslVirtualOverrideFinalNameBinding,
) -> String {
  "\{self.raw_target_name}|\{self.target_name}|\{self.override_name}"
}

///|
fn WgslComposeSession::record_virtual_override_final_name(
  self : WgslComposeSession,
  raw_target_name : String,
  target_name : String,
  override_name : String,
) -> Unit {
  let binding = WgslVirtualOverrideFinalNameBinding::{
    raw_target_name,
    target_name,
    override_name,
  }
  let key = binding.key()
  for existing in self.virtual_override_final_names {
    if existing.key() == key {
      return
    }
  }
  self.virtual_override_final_names.push(binding)
}

///|
fn WgslComposeSession::record_canonical_final_name(
  self : WgslComposeSession,
  identity : WgslIrSymbolIdentity,
  final_name : String,
) -> Unit {
  self.final_names.canonical_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity)
}

///|
fn WgslComposeSession::assign_canonical_final_name(
  self : WgslComposeSession,
  identity : WgslIrSymbolIdentity,
  final_name : String,
) -> Unit {
  self.assigned_final_names.canonical_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity)
}

///|
fn WgslComposeSession::assigned_canonical_final_name(
  self : WgslComposeSession,
  identity : WgslIrSymbolIdentity,
) -> String? {
  self.assigned_final_names.canonical_get(identity)
}

///|
fn WgslComposeSession::assign_alias_final_name(
  self : WgslComposeSession,
  identity : WgslIrAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  self.assigned_final_names.canonical_set(identity.symbol(), final_name)
  self.assigned_final_names.alias_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity.symbol())
}

///|
fn WgslComposeSession::record_canonical_final_name_if_absent(
  self : WgslComposeSession,
  identity : WgslIrSymbolIdentity,
  final_name : String,
) -> Unit {
  if self.final_names.canonical_get(identity) is None {
    self.record_canonical_final_name(identity, final_name)
  }
}

///|
fn WgslComposeSession::record_alias_final_name(
  self : WgslComposeSession,
  identity : WgslIrAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  self.final_names.alias_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity.symbol())
}

///|
fn WgslComposeSession::record_alias_final_name_if_absent(
  self : WgslComposeSession,
  identity : WgslIrAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  if self.final_names.alias_get(identity) is None {
    self.record_alias_final_name(identity, final_name)
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
