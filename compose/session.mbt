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
fn copy_value_defs(
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
fn merge_shader_def_value_into_compose_defs(
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, ShaderDefValue],
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  name : String,
  value : ShaderDefValue,
) -> Unit {
  shader_defs.set(name, value)
  match value {
    Bool(flag) => defines.set(name, flag)
    Int(_) | UInt(_) | Raw(_) => value_defines.set(name, value)
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
}

///|
priv struct WgslComposeSymbolTable {
  assigned_final_names : WgslIrFinalNameTable
  emitted_final_names : WgslIrFinalNameTable
  virtual_override_final_names : Array[WgslVirtualOverrideFinalNameBinding]
  source_origins : Array[WgslSourceOriginEntry]
}

///|
priv struct WgslComposeSession {
  defines : @hashmap.HashMap[String, Bool]
  value_defines : @hashmap.HashMap[String, ShaderDefValue]
  modules : @hashmap.HashMap[String, String]
  redirects : Array[WgslSymbolRedirect]
  additional_imports : Array[ImportDefinition]
  global_alias_bindings : WgslComposeBindingSet
  redirect_match_counts : @hashmap.HashMap[String, Int]
  visited : @hashmap.HashMap[String, Bool]
  graph_planned_requests : @hashmap.HashMap[String, Bool]
  graph_planning_rel_paths : Array[String]
  mut graph_execution_complete : Bool
  symbols : WgslComposeSymbolTable
  link_graph : WgslIrLinkGraph
  semantic_facts : @hashmap.HashMap[String, WgslComposeSemanticFacts]
  active_rel_paths : Array[String]
}

///|
priv enum WgslComposeBindingScope {
  QualifiedAliasBinding
  UnqualifiedItemBinding
} derive(Eq)

///|
priv struct WgslComposeBinding {
  reference_path : WgslReferencePath
  target : WgslComposeSymbolTarget
  scope : WgslComposeBindingScope
  alias_name : String
}

///|
priv struct WgslComposeSymbolTarget {
  identity : WgslIrSymbolIdentity
  final_name : String
}

///|
priv struct WgslComposeBindingSet {
  bindings : Array[WgslComposeBinding]
  keys : @hashset.HashSet[String]
  conflicts : Array[String]
}

///|
priv struct WgslComposeBindingKey {
  text : String
}

///|
priv struct WgslVirtualOverrideFinalNameBinding {
  raw_target_name : String
  rel_path : String
  target_name : String
  override_name : String
}

///|
priv struct WgslVirtualOverrideFinalNameKey {
  text : String
}

///|
priv struct WgslLiveBindingPlan {
  bindings : Array[WgslLiveSymbolBinding]
}

///|
priv struct WgslLiveSymbolBinding {
  reference_path : WgslReferencePath
  target : WgslComposeSymbolTarget
}

///|
fn WgslComposeSymbolTable::WgslComposeSymbolTable() -> WgslComposeSymbolTable {
  WgslComposeSymbolTable::{
    assigned_final_names: WgslIrFinalNameTable(),
    emitted_final_names: WgslIrFinalNameTable(),
    virtual_override_final_names: [],
    source_origins: [],
  }
}

///|
fn WgslLiveBindingPlan::WgslLiveBindingPlan() -> WgslLiveBindingPlan {
  WgslLiveBindingPlan::{ bindings: [] }
}

///|
fn WgslLiveBindingPlan::push(
  self : WgslLiveBindingPlan,
  binding : WgslLiveSymbolBinding,
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
    plan.add_symbol_reference_binding(
      binding.target.identity,
      binding.reference_path,
      binding.target.final_name,
    )
  }
  for binding in session.symbols.virtual_override_final_names {
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
  WgslComposeBindingSet::{
    bindings: [],
    keys: @hashset.HashSet([]),
    conflicts: [],
  }
}

///|
fn WgslComposeBindingScope::label(self : WgslComposeBindingScope) -> String {
  match self {
    QualifiedAliasBinding => "qualified"
    UnqualifiedItemBinding => "unqualified"
  }
}

///|
fn WgslComposeBindingKey::WgslComposeBindingKey(
  binding : WgslComposeBinding,
) -> WgslComposeBindingKey {
  let identity_key = WgslComposeIrIdentityKey(binding.target.identity).text()
  WgslComposeBindingKey::{
    text: "\{binding.scope.label()}|\{binding.reference_path.text()}|\{binding.target.final_name}|\{binding.alias_name}|\{identity_key}",
  }
}

///|
fn WgslComposeBindingKey::text(self : WgslComposeBindingKey) -> String {
  self.text
}

///|
fn wgsl_compose_binding_conflict_message(
  existing : WgslComposeBinding,
  binding : WgslComposeBinding,
) -> String {
  let existing_identity = WgslComposeIrIdentityKey(existing.target.identity).text()
  let binding_identity = WgslComposeIrIdentityKey(binding.target.identity).text()
  let scope = if binding.alias_name == "" {
    binding.scope.label()
  } else {
    "\{binding.scope.label()} alias \{binding.alias_name}"
  }
  "\{binding.reference_path.text()} in \{scope}: \{existing_identity} conflicts with \{binding_identity}"
}

///|
fn WgslComposeSymbolTarget::WgslComposeSymbolTarget(
  identity : WgslIrSymbolIdentity,
  final_name : String,
) -> WgslComposeSymbolTarget {
  WgslComposeSymbolTarget::{
    identity,
    final_name: final_name.trim().to_owned(),
  }
}

///|
fn WgslComposeBinding::WgslComposeBinding(
  reference_path : WgslReferencePath,
  target : WgslComposeSymbolTarget,
  scope : WgslComposeBindingScope,
  alias_name : String,
) -> WgslComposeBinding {
  WgslComposeBinding::{ reference_path, target, scope, alias_name }
}

///|
fn WgslComposeBinding::for_alias_symbol(
  rel_path : String,
  alias_name : String,
  original_name : String,
  final_name : String,
  scope : WgslComposeBindingScope,
) -> WgslComposeBinding? {
  let identity = WgslIrSymbolIdentity(rel_path, original_name)
  match WgslReferencePath::from_text("\{alias_name}::\{original_name}") {
    Some(reference_path) =>
      Some(
        WgslComposeBinding(
          reference_path,
          WgslComposeSymbolTarget(identity, final_name),
          scope,
          alias_name,
        ),
      )
    None => None
  }
}

///|
fn WgslComposeBinding::for_unqualified_symbol(
  rel_path : String,
  original_name : String,
  final_name : String,
  scope : WgslComposeBindingScope,
) -> WgslComposeBinding? {
  let identity = WgslIrSymbolIdentity(rel_path, original_name)
  match WgslReferencePath::from_text(original_name) {
    Some(reference_path) =>
      Some(
        WgslComposeBinding(
          reference_path,
          WgslComposeSymbolTarget(identity, final_name),
          scope,
          "",
        ),
      )
    None => None
  }
}

///|
fn WgslComposeBinding::as_unqualified_binding(
  self : WgslComposeBinding,
  reference_name : String,
) -> WgslComposeBinding? {
  match WgslReferencePath::from_text(reference_name) {
    Some(reference_path) =>
      Some(
        WgslComposeBinding(
          reference_path,
          self.target,
          UnqualifiedItemBinding,
          self.alias_name,
        ),
      )
    None => None
  }
}

///|
fn WgslComposeBinding::with_target(
  self : WgslComposeBinding,
  target : WgslComposeSymbolTarget,
) -> WgslComposeBinding {
  WgslComposeBinding(self.reference_path, target, self.scope, self.alias_name)
}

///|
fn WgslComposeBinding::to_live_binding(
  self : WgslComposeBinding,
  target : WgslComposeSymbolTarget,
) -> WgslLiveSymbolBinding {
  WgslLiveSymbolBinding::{ reference_path: self.reference_path, target }
}

///|
fn WgslComposeBindingSet::push(
  self : WgslComposeBindingSet,
  binding : WgslComposeBinding,
) -> Unit {
  if binding.reference_path.segments().length() == 0 ||
    binding.target.final_name == "" {
    return
  }
  let binding_identity_key = WgslComposeIrIdentityKey(binding.target.identity).text()
  for existing in self.bindings {
    if existing.scope == binding.scope &&
      existing.alias_name == binding.alias_name &&
      existing.reference_path.matches(binding.reference_path) {
      let existing_identity_key = WgslComposeIrIdentityKey(
        existing.target.identity,
      ).text()
      if existing_identity_key == binding_identity_key {
        continue
      }
      self.conflicts.push(
        wgsl_compose_binding_conflict_message(existing, binding),
      )
      return
    }
  }
  let key = WgslComposeBindingKey(binding).text()
  if self.keys.contains(key) {
    return
  }
  self.keys.add(key)
  self.bindings.push(binding)
}

///|
fn WgslComposeBindingSet::first_conflict(
  self : WgslComposeBindingSet,
) -> String? {
  match self.conflicts {
    [message, ..] => Some(message)
    [] => None
  }
}

///|
fn WgslVirtualOverrideFinalNameKey::WgslVirtualOverrideFinalNameKey(
  binding : WgslVirtualOverrideFinalNameBinding,
) -> WgslVirtualOverrideFinalNameKey {
  WgslVirtualOverrideFinalNameKey::{
    text: "\{binding.raw_target_name}|\{binding.rel_path}|\{binding.target_name}|\{binding.override_name}",
  }
}

///|
fn WgslVirtualOverrideFinalNameKey::text(
  self : WgslVirtualOverrideFinalNameKey,
) -> String {
  self.text
}

///|
fn WgslComposeSession::record_virtual_override_final_name(
  self : WgslComposeSession,
  raw_target_name : String,
  rel_path : String,
  target_name : String,
  override_name : String,
) -> Unit {
  let binding = WgslVirtualOverrideFinalNameBinding::{
    raw_target_name,
    rel_path,
    target_name,
    override_name,
  }
  let key = WgslVirtualOverrideFinalNameKey(binding).text()
  for existing in self.symbols.virtual_override_final_names {
    if WgslVirtualOverrideFinalNameKey(existing).text() == key {
      return
    }
  }
  self.symbols.virtual_override_final_names.push(binding)
}

///|
fn WgslComposeSession::record_canonical_final_name(
  self : WgslComposeSession,
  identity : WgslIrSymbolIdentity,
  final_name : String,
) -> Unit {
  self.symbols.emitted_final_names.canonical_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity)
}

///|
fn WgslComposeSession::assign_canonical_final_name(
  self : WgslComposeSession,
  identity : WgslIrSymbolIdentity,
  final_name : String,
) -> Unit {
  self.symbols.assigned_final_names.canonical_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity)
}

///|
fn WgslComposeSession::assigned_canonical_final_name(
  self : WgslComposeSession,
  identity : WgslIrSymbolIdentity,
) -> String? {
  self.symbols.assigned_final_names.canonical_get(identity)
}

///|
fn WgslComposeSession::assign_alias_final_name(
  self : WgslComposeSession,
  identity : WgslIrAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  self.symbols.assigned_final_names.canonical_set(identity.symbol(), final_name)
  self.symbols.assigned_final_names.alias_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity.symbol())
}

///|
fn WgslComposeSession::record_canonical_final_name_if_absent(
  self : WgslComposeSession,
  identity : WgslIrSymbolIdentity,
  final_name : String,
) -> Unit {
  if self.symbols.emitted_final_names.canonical_get(identity) is None {
    self.record_canonical_final_name(identity, final_name)
  }
}

///|
fn WgslComposeSession::record_alias_final_name(
  self : WgslComposeSession,
  identity : WgslIrAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  self.symbols.emitted_final_names.alias_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity.symbol())
}

///|
fn WgslComposeSession::record_alias_final_name_if_absent(
  self : WgslComposeSession,
  identity : WgslIrAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  if self.symbols.emitted_final_names.alias_get(identity) is None {
    self.record_alias_final_name(identity, final_name)
  }
}

///|
priv struct WgslActiveComposeDefs {
  defines : @hashmap.HashMap[String, Bool]
  value_defines : @hashmap.HashMap[String, ShaderDefValue]
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
