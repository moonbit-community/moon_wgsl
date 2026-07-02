///|
fn wgsl_shader_def_value_cache_text(value : ShaderDefValue) -> String {
  match value {
    Bool(flag) => "b:\{flag}"
    Int(value) => "i:\{value}"
    UInt(value) => "u:\{value}"
    Raw(value) => "r:\{value.length()}:\{value}"
  }
}

///|
fn wgsl_active_defs_cache_key(
  rel_path : String,
  active_defs : WgslActiveComposeDefs,
) -> String {
  "\{normalize_shader_rel_path(rel_path)}|\{active_defs.cache_text()}"
}

///|
fn wgsl_redirects_cache_text(redirects : Array[WgslSymbolRedirect]) -> String {
  if redirects.length() == 0 {
    return ""
  }
  let entries : Array[String] = []
  for redirect in redirects {
    let from_name = redirect.from_name.trim().to_owned()
    let to_name = redirect.to_name.trim().to_owned()
    entries.push(
      "\{from_name.length()}:\{from_name}->\{to_name.length()}:\{to_name}",
    )
  }
  entries.join("|")
}

///|
fn wgsl_processed_module_cache_key(
  rel_path : String,
  active_defs : WgslActiveComposeDefs,
  session : WgslComposeSession,
) -> String {
  "\{wgsl_active_defs_cache_key(rel_path, active_defs)}|redirects:\{wgsl_redirects_cache_text(session.redirects)}"
}

///|
fn WgslActiveComposeDefs::cache_text(self : WgslActiveComposeDefs) -> String {
  match self.cache_text {
    Some(text) => text
    None => {
      let text = self.compute_cache_text()
      self.cache_text = Some(text)
      text
    }
  }
}

///|
fn WgslActiveComposeDefs::compute_cache_text(
  self : WgslActiveComposeDefs,
) -> String {
  let entries : Array[String] = []
  for entry in self.shader_defs.iter() {
    let (name, value) = entry
    entries.push("\{name}=\{wgsl_shader_def_value_cache_text(value)}")
  }
  entries.sort()
  entries.join("|")
}

///|
fn collect_wgsl_naga_pull_ranks(
  origins : Array[WgslModuleItemOrigin],
) -> Map[String, Int] {
  let ranks : Map[String, Int] = Map([])
  for origin in origins {
    if origin.name() != "" && !ranks.contains(origin.name()) {
      ranks.set(origin.name(), origin.source_start())
    }
  }
  ranks
}

///|
fn collect_wgsl_source_decl_ranks(
  extraction : WgslModuleItemExtraction,
) -> Map[String, Int] {
  let ranks : Map[String, Int] = Map([])
  let origins = extraction.origins()
  for i in 0..<origins.length() {
    let origin = origins[i]
    if origin.name() != "" && !ranks.contains(origin.name()) {
      ranks.set(origin.name(), origin.source_start())
    }
  }
  ranks
}

///|
fn wgsl_item_extraction_cache_key(requested_items : Array[String]) -> String {
  let items : Array[String] = []
  for item in requested_items {
    items.push(item)
  }
  items.sort()
  items.join("|")
}

///|
fn WgslProcessedComposeModule::translation_unit(
  self : WgslProcessedComposeModule,
) -> WgslTranslationUnit raise ComposerError {
  match self.unit {
    Some(unit) => unit
    None => {
      let unit = parse_wgsl_translation_unit_strict(self.prepared.active_source) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
      self.unit = Some(unit)
      unit
    }
  }
}

///|
fn WgslProcessedComposeModule::declaration_map(
  self : WgslProcessedComposeModule,
) -> Map[String, WgslGlobalDecl] raise ComposerError {
  match self.declarations_by_name {
    Some(declarations) => declarations
    None => {
      let declarations : Map[String, WgslGlobalDecl] = Map([])
      for declaration in self.translation_unit().declarations() {
        let name = declaration.name()
        if name != "" && !declarations.contains(name) {
          declarations.set(name, declaration)
        }
      }
      self.declarations_by_name = Some(declarations)
      declarations
    }
  }
}

///|
fn wgsl_processed_name_after_keyword(
  tokens : Array[WgslToken],
  start : Int,
) -> String? {
  let mut index = start
  let mut angle_depth = 0
  while index < tokens.length() {
    let token = tokens[index]
    if token.is_punctuation(59) || token.is_punctuation(123) {
      return None
    }
    if token.is_punctuation(60) {
      angle_depth = angle_depth + 1
    } else if token.is_punctuation(62) {
      if angle_depth > 0 {
        angle_depth = angle_depth - 1
      }
    } else if angle_depth == 0 {
      match token.identifier_text() {
        Some(name) => return Some(name)
        None => ()
      }
    }
    index = index + 1
  }
  None
}

///|
fn wgsl_processed_summary_insert(
  summaries : Map[String, WgslProcessedDeclarationSummary],
  name : String?,
  kind : WgslProcessedDeclarationKind,
  has_resource_binding : Bool,
) -> Unit {
  match name {
    Some(name) if name != "" && !summaries.contains(name) =>
      summaries.set(name, { kind, has_resource_binding })
    _ => ()
  }
}

///|
fn WgslProcessedComposeModule::scan_declaration_summaries(
  self : WgslProcessedComposeModule,
) -> Map[String, WgslProcessedDeclarationSummary] {
  let summaries : Map[String, WgslProcessedDeclarationSummary] = Map([])
  let source = self.prepared.active_source
  let tokens = tokenize_wgsl(replace_comments(source), false)
  let mut brace_depth = 0
  let mut pending_group = false
  let mut pending_binding = false
  let mut index = 0
  while index < tokens.length() {
    let token = tokens[index]
    if token.is_punctuation(35) {
      let line_end = wgsl_line_end(source, token.pos())
      while index < tokens.length() && tokens[index].pos() < line_end {
        index = index + 1
      }
      continue
    }
    if token.is_punctuation(123) {
      brace_depth = brace_depth + 1
      index = index + 1
      continue
    }
    if token.is_punctuation(125) {
      if brace_depth > 0 {
        brace_depth = brace_depth - 1
      }
      index = index + 1
      continue
    }
    if brace_depth != 0 {
      index = index + 1
      continue
    }
    if token.is_punctuation(64) && index + 1 < tokens.length() {
      let attr = tokens[index + 1]
      if attr.is_identifier("group") {
        pending_group = true
      } else if attr.is_identifier("binding") {
        pending_binding = true
      }
      index = index + 1
      continue
    }
    if token.is_punctuation(59) {
      pending_group = false
      pending_binding = false
      index = index + 1
      continue
    }
    match token.identifier_text() {
      Some("struct") => {
        wgsl_processed_summary_insert(
          summaries,
          wgsl_processed_name_after_keyword(tokens, index + 1),
          SummaryType,
          false,
        )
        pending_group = false
        pending_binding = false
      }
      Some("alias") | Some("type") => {
        wgsl_processed_summary_insert(
          summaries,
          wgsl_processed_name_after_keyword(tokens, index + 1),
          SummaryType,
          false,
        )
        pending_group = false
        pending_binding = false
      }
      Some("const") => {
        wgsl_processed_summary_insert(
          summaries,
          wgsl_processed_name_after_keyword(tokens, index + 1),
          SummaryConstant,
          false,
        )
        pending_group = false
        pending_binding = false
      }
      Some("override") =>
        if index + 1 < tokens.length() && tokens[index + 1].is_identifier("fn") {
          wgsl_processed_summary_insert(
            summaries,
            wgsl_processed_name_after_keyword(tokens, index + 2),
            SummaryFunction,
            false,
          )
          pending_group = false
          pending_binding = false
        } else {
          wgsl_processed_summary_insert(
            summaries,
            wgsl_processed_name_after_keyword(tokens, index + 1),
            SummaryOverride,
            false,
          )
          pending_group = false
          pending_binding = false
        }
      Some("virtual") =>
        if index + 1 < tokens.length() && tokens[index + 1].is_identifier("fn") {
          wgsl_processed_summary_insert(
            summaries,
            wgsl_processed_name_after_keyword(tokens, index + 2),
            SummaryFunction,
            false,
          )
          pending_group = false
          pending_binding = false
        }
      Some("fn") => {
        wgsl_processed_summary_insert(
          summaries,
          wgsl_processed_name_after_keyword(tokens, index + 1),
          SummaryFunction,
          false,
        )
        pending_group = false
        pending_binding = false
      }
      Some("var") => {
        wgsl_processed_summary_insert(
          summaries,
          wgsl_processed_name_after_keyword(tokens, index + 1),
          SummaryGlobalVariable,
          pending_group && pending_binding,
        )
        pending_group = false
        pending_binding = false
      }
      _ => ()
    }
    index = index + 1
  }
  summaries
}

///|
fn WgslProcessedComposeModule::declaration_summary_map(
  self : WgslProcessedComposeModule,
) -> Map[String, WgslProcessedDeclarationSummary] {
  match self.declaration_summaries {
    Some(summaries) => summaries
    None => {
      let summaries = self.scan_declaration_summaries()
      self.declaration_summaries = Some(summaries)
      summaries
    }
  }
}

///|
fn WgslProcessedComposeModule::declaration_summary(
  self : WgslProcessedComposeModule,
  name : String,
) -> WgslProcessedDeclarationSummary? {
  self.declaration_summary_map().get(name)
}

///|
fn WgslProcessedComposeModule::module_item_extractor(
  self : WgslProcessedComposeModule,
) -> WgslModuleItemExtractor raise ComposerError {
  match self.item_extractor {
    Some(extractor) => extractor
    None => {
      let extractor = new_wgsl_module_item_extractor_from_unit(
        self.prepared.active_source,
        self.translation_unit(),
      )
      self.item_extractor = Some(extractor)
      extractor
    }
  }
}

///|
fn WgslProcessedComposeModule::declares_all_items(
  self : WgslProcessedComposeModule,
  requested_items : Array[String],
) -> Bool raise ComposerError {
  let declarations = self.declaration_map()
  for item in requested_items {
    if !declarations.contains(item) {
      return false
    }
  }
  true
}

///|
fn WgslProcessedComposeModule::declares_non_resource_dependency_item(
  self : WgslProcessedComposeModule,
  item_name : String,
  referenced : Bool,
) -> Bool {
  if !referenced {
    return false
  }
  match self.declaration_summary(item_name) {
    Some(summary) =>
      match summary.kind {
        SummaryType | SummaryConstant | SummaryOverride | SummaryFunction =>
          true
        SummaryGlobalVariable => false
      }
    None => false
  }
}

///|
fn WgslProcessedComposeModule::declares_const_side_effect_item(
  self : WgslProcessedComposeModule,
  item_name : String,
) -> Bool {
  match self.declaration_summary(item_name) {
    Some(summary) =>
      match summary.kind {
        SummaryConstant | SummaryOverride => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslProcessedComposeModule::resource_side_effect_items(
  self : WgslProcessedComposeModule,
  candidate_items : Array[String],
) -> Array[String] {
  let items : Array[String] = []
  for candidate_item in candidate_items {
    match self.declaration_summary(candidate_item) {
      Some(summary) =>
        if summary.kind == SummaryGlobalVariable && summary.has_resource_binding {
          composer_string_list_push_unique(items, candidate_item)
        }
      None => ()
    }
  }
  items
}

///|
fn WgslProcessedComposeModule::const_side_effect_items(
  self : WgslProcessedComposeModule,
  candidate_items : Array[String],
) -> Array[String] {
  let items : Array[String] = []
  for candidate_item in candidate_items {
    if self.declares_const_side_effect_item(candidate_item) {
      composer_string_list_push_unique(items, candidate_item)
    }
  }
  items
}

///|
fn WgslProcessedComposeModule::imports_for_override_side_effect(
  self : WgslProcessedComposeModule,
) -> Bool {
  match self.has_override_function {
    Some(found) => found
    None => {
      self.scan_function_qualifier_flags()
      match self.has_override_function {
        Some(found) => found
        None => false
      }
    }
  }
}

///|
fn WgslProcessedComposeModule::imports_for_virtual_side_effect(
  self : WgslProcessedComposeModule,
) -> Bool {
  match self.has_virtual_function {
    Some(found) => found
    None => {
      self.scan_function_qualifier_flags()
      match self.has_virtual_function {
        Some(found) => found
        None => false
      }
    }
  }
}

///|
fn WgslProcessedComposeModule::scan_function_qualifier_flags(
  self : WgslProcessedComposeModule,
) -> Unit {
  let may_have_override = self.prepared.active_source.contains("override")
  let may_have_virtual = self.prepared.active_source.contains("virtual")
  if !may_have_override && !may_have_virtual {
    self.has_override_function = Some(false)
    self.has_virtual_function = Some(false)
    return
  }
  let tokens = tokenize_wgsl(
    replace_comments(self.prepared.active_source),
    false,
  )
  let mut has_override = false
  let mut has_virtual = false
  let mut depth = 0
  let mut index = 0
  while index < tokens.length() {
    let token = tokens[index]
    if token.is_punctuation(123) {
      depth = depth + 1
      index = index + 1
      continue
    }
    if token.is_punctuation(125) {
      if depth > 0 {
        depth = depth - 1
      }
      index = index + 1
      continue
    }
    if depth == 0 && index + 1 < tokens.length() {
      let next = tokens[index + 1]
      if next.is_identifier("fn") {
        if may_have_override && token.is_identifier("override") {
          has_override = true
        } else if may_have_virtual && token.is_identifier("virtual") {
          has_virtual = true
        }
        if (!may_have_override || has_override) &&
          (!may_have_virtual || has_virtual) {
          break
        }
      }
    }
    index = index + 1
  }
  self.has_override_function = Some(has_override)
  self.has_virtual_function = Some(has_virtual)
}

///|
fn WgslProcessedComposeModule::virtual_override_target_names(
  self : WgslProcessedComposeModule,
) -> Array[String] raise ComposerError {
  match self.virtual_override_targets {
    Some(targets) => targets.copy()
    None => {
      let targets : Array[String] = []
      for declaration in self.translation_unit().declarations() {
        match declaration.data() {
          Function(function) if function.qualifier() == Some(Override) => {
            let name = function.name().name()
            if name != "" {
              targets.push(name)
            }
          }
          _ => ()
        }
      }
      self.virtual_override_targets = Some(targets.copy())
      targets
    }
  }
}

///|
fn WgslProcessedComposeModule::item_extraction(
  self : WgslProcessedComposeModule,
  requested_items : Array[String],
) -> WgslModuleItemExtraction raise ComposerError {
  let key = wgsl_item_extraction_cache_key(requested_items)
  match self.item_extractions.get(key) {
    Some(extraction) => extraction
    None => {
      let extraction = self.module_item_extractor().extract(requested_items)
      self.item_extractions.set(key, extraction)
      extraction
    }
  }
}

///|
fn WgslProcessedComposeModule::semantic_declaration_names(
  self : WgslProcessedComposeModule,
) -> Array[String] raise ComposerError {
  match self.declaration_names {
    Some(names) => names
    None => {
      let names = collect_wgsl_semantic_declaration_names_from_unit(
        self.translation_unit(),
      )
      self.declaration_names = Some(names)
      names
    }
  }
}

///|
fn WgslProcessedComposeModule::compose_semantic_facts(
  self : WgslProcessedComposeModule,
) -> WgslComposeSemanticFacts raise ComposerError {
  match self.semantic_facts {
    Some(facts) => facts
    None => {
      let unit = self.translation_unit()
      let declarations = collect_wgsl_semantic_declaration_names_from_unit(unit)
      let global_variables = collect_wgsl_semantic_global_variable_names_from_unit(
        unit,
      )
      let references : Array[WgslReferencePath] = []
      collect_wgsl_semantic_reference_paths_from_unit(unit, references)
      let facts = WgslComposeSemanticFacts(
        declarations, global_variables, references,
      )
      self.declaration_names = Some(declarations)
      self.semantic_facts = Some(facts)
      facts
    }
  }
}

///|
fn WgslComposeSession::record_processed_semantic_facts(
  self : WgslComposeSession,
  processed : WgslProcessedComposeModule,
) -> Unit raise ComposerError {
  let active_source = processed.prepared.active_source
  match self.semantic_facts.get(active_source) {
    Some(_) => ()
    None =>
      self.semantic_facts.set(active_source, processed.compose_semantic_facts())
  }
  let importless_source = drop_wgsl_import_directives_from_compose_source_cached(
    self, active_source,
  )
  if importless_source != active_source {
    match self.semantic_facts.get(importless_source) {
      Some(_) => ()
      None =>
        self.semantic_facts.set(
          importless_source,
          processed.compose_semantic_facts(),
        )
    }
  }
}

///|
fn WgslProcessedComposeModule::naga_dependency_pull_ranks(
  self : WgslProcessedComposeModule,
) -> Map[String, Int] raise ComposerError {
  match self.naga_pull_ranks {
    Some(ranks) => ranks
    None => {
      let ranks = collect_wgsl_naga_pull_ranks(
        self.module_item_extractor().naga_dependency_pulled_item_origins(),
      )
      self.naga_pull_ranks = Some(ranks)
      ranks
    }
  }
}

///|
fn WgslProcessedComposeModule::declaration_source_ranks(
  self : WgslProcessedComposeModule,
) -> Map[String, Int] raise ComposerError {
  match self.source_decl_ranks {
    Some(ranks) => ranks
    None => {
      let ranks = collect_wgsl_source_decl_ranks(self.item_extraction([]))
      self.source_decl_ranks = Some(ranks)
      ranks
    }
  }
}

///|
fn Composer::processed_wgsl_compose_module(
  self : Composer,
  rel_path : String,
  raw_source : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
) -> WgslProcessedComposeModule raise ComposerError {
  let active_defs = self.active_compose_defs_for_rel_path(
    rel_path, session, inherited_defs,
  )
  merge_wgsl_source_local_shader_defs(
    active_defs,
    raw_source,
    session,
    normalize_shader_rel_path(rel_path),
  )
  let cache_key = wgsl_processed_module_cache_key(
    rel_path, active_defs, session,
  )
  match session.processed_modules.get(cache_key) {
    Some(processed) => processed
    None =>
      match self.processed_module_cache.get(cache_key) {
        Some(processed) => {
          session.processed_modules.set(cache_key, processed)
          processed
        }
        None => {
          let prepared = prepare_wgsl_compose_source(
            raw_source, session, active_defs,
          )
          let processed = WgslProcessedComposeModule::{
            raw_source,
            active_defs,
            prepared,
            unit: None,
            declarations_by_name: None,
            declaration_summaries: None,
            declaration_names: None,
            semantic_facts: None,
            item_extractor: None,
            item_extractions: Map([]),
            naga_pull_ranks: None,
            source_decl_ranks: None,
            virtual_override_targets: None,
            has_override_function: None,
            has_virtual_function: None,
          }
          session.processed_modules.set(cache_key, processed)
          self.processed_module_cache.set(cache_key, processed)
          processed
        }
      }
  }
}

///|
fn Composer::processed_registered_wgsl_compose_module(
  self : Composer,
  rel_path : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
) -> WgslProcessedComposeModule raise ComposerError {
  let raw_source = match self.registry.registered_source(rel_path) {
    Some(source) => source
    None => raise MissingRegisteredSource(rel_path)
  }
  self.processed_wgsl_compose_module(
    rel_path, raw_source, session, inherited_defs,
  )
}
