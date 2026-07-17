///|
fn copy_shader_def_values(
  defs : Map[String, ShaderDefValue],
) -> Map[String, ShaderDefValue] {
  let copied : Map[String, ShaderDefValue] = Map([])
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
fn copy_bool_defs(defs : Map[String, Bool]) -> Map[String, Bool] {
  let copied : Map[String, Bool] = Map([])
  for entry in defs.iter() {
    let (name, value) = entry
    copied.set(name, value)
  }
  copied
}

///|
fn copy_value_defs(
  defs : Map[String, ShaderDefValue],
) -> Map[String, ShaderDefValue] {
  let copied : Map[String, ShaderDefValue] = Map([])
  for entry in defs.iter() {
    let (name, value) = entry
    copied.set(name, value)
  }
  copied
}

///|
fn merge_shader_def_value_into_compose_defs(
  defines : Map[String, Bool],
  value_defines : Map[String, ShaderDefValue],
  shader_defs : Map[String, ShaderDefValue],
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
fn set_strings_to_array(values : @set.Set[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values.iter() {
    out.push(value)
  }
  out.sort()
  out
}

///|
priv struct WgslComposeSemanticFacts {
  declarations : Array[String]
  global_variables : Array[String]
  references : Array[WgslReferencePath]
  reference_keys : @set.Set[String]
  unqualified_reference_names : @set.Set[String]
}

///|
priv struct WgslComposeSymbolTable {
  assigned_final_names : WgslComposeFinalNameTable
  emitted_final_names : WgslComposeFinalNameTable
  virtual_override_final_names : Array[WgslVirtualOverrideFinalNameBinding]
  local_import_final_names : Array[WgslLocalImportFinalNameBinding]
  local_spelling_final_names : Array[WgslLocalSpellingFinalNameBinding]
  source_origins : Array[WgslSourceOriginEntry]
  import_arena_events : Array[WgslComposeImportArenaEvent]
}

///|
priv struct WgslComposeSession {
  defines : Map[String, Bool]
  value_defines : Map[String, ShaderDefValue]
  modules : Map[String, String]
  redirects : Array[WgslSymbolRedirect]
  additional_imports : Array[ImportDefinition]
  global_alias_bindings : WgslComposeBindingSet
  redirect_match_counts : Map[String, Int]
  visited : @set.Set[String]
  graph_planned_requests : @set.Set[String]
  graph_planning_rel_paths : Array[String]
  mut graph_execution_complete : Bool
  mut emitted_virtual_functions : Bool
  symbols : WgslComposeSymbolTable
  link_graph : WgslComposeLinkGraph
  semantic_facts : Map[String, WgslComposeSemanticFacts]
  directive_scans : Map[String, Array[WgslDirectiveScanItem]]
  importless_sources : Map[String, String]
  directive_import_targets : Map[String, Array[WgslImportTarget]]
  directive_single_import_targets : Map[String, Array[WgslImportTarget]]
  semantic_reference_first_starts : Map[String, Map[String, Int]]
  source_local_shader_defs : Map[String, Map[String, ShaderDefValue]]
  source_cache_ids : Map[String, Int]
  mut next_source_cache_id : Int
  processed_modules : Map[String, WgslProcessedComposeModule]
  selected_import_candidate_rel_paths : Map[String, String]
  import_request_plans : Map[String, Array[WgslImportRequest]]
  emitted_item_import_requests : Map[String, Array[WgslImportRequest]]
  active_rel_paths : Array[String]
}

///|
fn WgslComposeSession::source_cache_id(
  self : WgslComposeSession,
  source : String,
) -> Int {
  match self.source_cache_ids.get(source) {
    Some(id) => id
    None => {
      let id = self.next_source_cache_id
      self.next_source_cache_id = id + 1
      self.source_cache_ids.set(source, id)
      id
    }
  }
}

///|
priv struct WgslProcessedComposeModule {
  raw_source : String
  active_defs : WgslActiveComposeDefs
  prepared : WgslPreparedComposeSource
  mut unit : WgslTranslationUnit?
  mut declarations_by_name : Map[String, WgslGlobalDecl]?
  mut declaration_summaries : Map[String, WgslProcessedDeclarationSummary]?
  mut declaration_names : Array[String]?
  mut item_extractor : WgslModuleItemExtractor?
  item_extractions : Map[String, WgslModuleItemExtraction]
  mut naga_pull_ranks : Map[String, Int]?
  mut source_decl_ranks : Map[String, Int]?
  mut virtual_override_targets : Array[String]?
  mut has_override_function : Bool?
  mut has_virtual_function : Bool?
}

///|
priv enum WgslProcessedDeclarationKind {
  SummaryType
  SummaryConstant
  SummaryOverride
  SummaryGlobalVariable
  SummaryFunction
} derive(Eq)

///|
priv struct WgslProcessedDeclarationSummary {
  kind : WgslProcessedDeclarationKind
  has_resource_binding : Bool
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
  key : String
}

///|
priv struct WgslComposeSymbolTarget {
  identity : WgslComposeSymbolIdentity
  identity_key : String
  final_name : String
}

///|
priv struct WgslComposeBindingSet {
  bindings : Array[WgslComposeBinding]
  keys : @set.Set[String]
}

///|
priv struct WgslVirtualOverrideFinalNameBinding {
  raw_target_name : String
  rel_path : String
  target_name : String
  override_name : String
}

///|
priv struct WgslLocalImportFinalNameBinding {
  rel_path : String
  source_name : String
  final_name : String
}

///|
priv struct WgslLocalSpellingFinalNameBinding {
  visible_rel_path : String
  symbol_rel_path : String
  source_name : String
  final_name : String
}

///|
priv struct WgslVirtualOverrideFinalNameKey {
  text : String
}

///|
priv struct WgslLocalImportFinalNameKey {
  text : String
}

///|
priv struct WgslLocalSpellingFinalNameKey {
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
  scope : WgslComposeBindingScope
  alias_name : String
}

///|
fn WgslComposeSymbolTable::WgslComposeSymbolTable() -> WgslComposeSymbolTable {
  {
    assigned_final_names: WgslComposeFinalNameTable(),
    emitted_final_names: WgslComposeFinalNameTable(),
    virtual_override_final_names: [],
    local_import_final_names: [],
    local_spelling_final_names: [],
    source_origins: [],
    import_arena_events: [],
  }
}

///|
fn WgslLiveBindingPlan::WgslLiveBindingPlan() -> WgslLiveBindingPlan {
  { bindings: [] }
}

///|
fn WgslLiveBindingPlan::push(
  self : WgslLiveBindingPlan,
  binding : WgslLiveSymbolBinding,
) -> Unit {
  self.bindings.push(binding)
}

///|
fn wgsl_live_binding_conflict_message(
  existing : WgslLiveSymbolBinding,
  binding : WgslLiveSymbolBinding,
) -> String {
  let existing_identity = existing.target.identity_key
  let binding_identity = binding.target.identity_key
  let scope = if binding.alias_name == "" {
    binding.scope.label()
  } else {
    "\{binding.scope.label()} alias \{binding.alias_name}"
  }
  "\{binding.reference_path.text()} in \{scope}: \{existing_identity} -> \{existing.target.final_name} conflicts with \{binding_identity} -> \{binding.target.final_name}"
}

///|
fn WgslLiveBindingPlan::first_conflict(self : WgslLiveBindingPlan) -> String? {
  for i in 0..<self.bindings.length() {
    let existing = self.bindings[i]
    for j in (i + 1)..<self.bindings.length() {
      let binding = self.bindings[j]
      if existing.scope == binding.scope &&
        existing.alias_name == binding.alias_name &&
        existing.reference_path.matches(binding.reference_path) {
        let existing_identity = existing.target.identity_key
        let binding_identity = binding.target.identity_key
        if existing_identity != binding_identity ||
          existing.target.final_name != binding.target.final_name {
          return Some(wgsl_live_binding_conflict_message(existing, binding))
        }
      }
    }
  }
  None
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
    match WgslReferencePath::from_text(binding.raw_target_name) {
      Some(reference_path) =>
        plan.add_symbol_reference_binding(
          WgslComposeSymbolIdentity(binding.rel_path, binding.raw_target_name),
          reference_path,
          binding.target_name,
        )
      None => ()
    }
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
  { bindings: [], keys: Set([]) }
}

///|
fn WgslComposeBindingScope::label(self : WgslComposeBindingScope) -> String {
  match self {
    QualifiedAliasBinding => "qualified"
    UnqualifiedItemBinding => "unqualified"
  }
}

///|
fn WgslComposeSymbolTarget::WgslComposeSymbolTarget(
  identity : WgslComposeSymbolIdentity,
  final_name : String,
) -> WgslComposeSymbolTarget {
  {
    identity,
    identity_key: identity.key(),
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
  let alias_name = alias_name.trim().to_owned()
  let key = "\{scope.label()}|\{reference_path.text()}|\{target.final_name}|\{alias_name}|\{target.identity_key}"
  { reference_path, target, scope, alias_name, key }
}

///|
fn WgslComposeBinding::for_alias_symbol(
  rel_path : String,
  alias_name : String,
  original_name : String,
  final_name : String,
  scope : WgslComposeBindingScope,
) -> WgslComposeBinding? {
  let identity = WgslComposeSymbolIdentity(rel_path, original_name)
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
  let identity = WgslComposeSymbolIdentity(rel_path, original_name)
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
  {
    reference_path: self.reference_path,
    target,
    scope: self.scope,
    alias_name: self.alias_name,
  }
}

///|
fn WgslComposeBindingSet::push(
  self : WgslComposeBindingSet,
  binding : WgslComposeBinding,
) -> Unit {
  if binding.target.final_name == "" {
    return
  }
  let key = binding.key
  if self.keys.contains(key) {
    return
  }
  self.keys.add(key)
  self.bindings.push(binding)
}

///|
fn WgslComposeBindingSet::has_unqualified_local_name(
  self : WgslComposeBindingSet,
  name : String,
) -> Bool {
  for binding in self.bindings {
    if binding.scope == UnqualifiedItemBinding &&
      binding.alias_name == "" &&
      binding.reference_path.text() == name &&
      binding.target.final_name == name {
      return true
    }
  }
  false
}

///|
fn WgslComposeBindingSet::has_unqualified_reference_name(
  self : WgslComposeBindingSet,
  name : String,
) -> Bool {
  for binding in self.bindings {
    if binding.scope == UnqualifiedItemBinding &&
      binding.alias_name == "" &&
      binding.reference_path.text() == name {
      return true
    }
  }
  false
}

///|
fn WgslVirtualOverrideFinalNameKey::WgslVirtualOverrideFinalNameKey(
  binding : WgslVirtualOverrideFinalNameBinding,
) -> WgslVirtualOverrideFinalNameKey {
  {
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
fn WgslLocalImportFinalNameKey::WgslLocalImportFinalNameKey(
  binding : WgslLocalImportFinalNameBinding,
) -> WgslLocalImportFinalNameKey {
  { text: "\{binding.rel_path}|\{binding.source_name}|\{binding.final_name}" }
}

///|
fn WgslLocalImportFinalNameKey::text(
  self : WgslLocalImportFinalNameKey,
) -> String {
  self.text
}

///|
fn WgslLocalSpellingFinalNameKey::WgslLocalSpellingFinalNameKey(
  binding : WgslLocalSpellingFinalNameBinding,
) -> WgslLocalSpellingFinalNameKey {
  {
    text: "\{binding.visible_rel_path}|\{binding.symbol_rel_path}|\{binding.source_name}|\{binding.final_name}",
  }
}

///|
fn WgslLocalSpellingFinalNameKey::text(
  self : WgslLocalSpellingFinalNameKey,
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
fn WgslComposeSession::record_local_import_final_name(
  self : WgslComposeSession,
  rel_path : String,
  source_name : String,
  final_name : String,
) -> Unit {
  let rel_path = normalize_shader_rel_path(rel_path)
  let source_name = source_name.trim().to_owned()
  let final_name = final_name.trim().to_owned()
  if rel_path == "" ||
    source_name == "" ||
    final_name == "" ||
    source_name == final_name {
    return
  }
  let binding = WgslLocalImportFinalNameBinding::{
    rel_path,
    source_name,
    final_name,
  }
  let key = WgslLocalImportFinalNameKey(binding).text()
  for existing in self.symbols.local_import_final_names {
    if WgslLocalImportFinalNameKey(existing).text() == key {
      return
    }
  }
  self.symbols.local_import_final_names.push(binding)
}

///|
fn WgslComposeSession::record_local_spelling_final_name(
  self : WgslComposeSession,
  visible_rel_path : String,
  symbol_rel_path : String,
  source_name : String,
  final_name : String,
) -> Unit {
  let visible_rel_path = normalize_shader_rel_path(visible_rel_path)
  let symbol_rel_path = normalize_shader_rel_path(symbol_rel_path)
  let source_name = source_name.trim().to_owned()
  let final_name = final_name.trim().to_owned()
  if visible_rel_path == "" ||
    symbol_rel_path == "" ||
    source_name == "" ||
    source_name == final_name {
    return
  }
  let binding = WgslLocalSpellingFinalNameBinding::{
    visible_rel_path,
    symbol_rel_path,
    source_name,
    final_name,
  }
  let key = WgslLocalSpellingFinalNameKey(binding).text()
  for existing in self.symbols.local_spelling_final_names {
    if WgslLocalSpellingFinalNameKey(existing).text() == key {
      return
    }
  }
  self.symbols.local_spelling_final_names.push(binding)
}

///|
fn WgslComposeSession::record_canonical_final_name(
  self : WgslComposeSession,
  identity : WgslComposeSymbolIdentity,
  final_name : String,
) -> Unit {
  self.symbols.emitted_final_names.canonical_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity)
}

///|
fn WgslComposeSession::assign_canonical_final_name(
  self : WgslComposeSession,
  identity : WgslComposeSymbolIdentity,
  final_name : String,
) -> Unit {
  self.symbols.assigned_final_names.canonical_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity)
}

///|
fn WgslComposeSession::assigned_canonical_final_name(
  self : WgslComposeSession,
  identity : WgslComposeSymbolIdentity,
) -> String? {
  self.symbols.assigned_final_names.canonical_get(identity)
}

///|
fn WgslComposeSession::assign_alias_final_name(
  self : WgslComposeSession,
  identity : WgslComposeAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  self.symbols.assigned_final_names.canonical_set(identity.symbol(), final_name)
  self.symbols.assigned_final_names.alias_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity.symbol())
}

///|
fn WgslComposeSession::record_canonical_final_name_if_absent(
  self : WgslComposeSession,
  identity : WgslComposeSymbolIdentity,
  final_name : String,
) -> Unit {
  if self.symbols.emitted_final_names.canonical_get(identity) is None {
    self.record_canonical_final_name(identity, final_name)
  }
}

///|
fn WgslComposeSession::record_alias_final_name(
  self : WgslComposeSession,
  identity : WgslComposeAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  self.symbols.emitted_final_names.alias_set(identity, final_name)
  self.link_graph.record_reachable_symbol(identity.symbol())
}

///|
fn WgslComposeSession::record_alias_final_name_if_absent(
  self : WgslComposeSession,
  identity : WgslComposeAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  if self.symbols.emitted_final_names.alias_get(identity) is None {
    self.record_alias_final_name(identity, final_name)
  }
}

///|
priv struct WgslActiveComposeDefs {
  defines : Map[String, Bool]
  value_defines : Map[String, ShaderDefValue]
  shader_defs : Map[String, ShaderDefValue]
  mut cache_text : String?
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
        raise NoModuleName(desc.file_path)
      }
      trimmed
    }
    None =>
      match metadata_name {
        Some(name) if name.trim() != "" => name.trim().to_owned()
        _ => raise NoModuleName(desc.file_path)
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
