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
  let entries : Array[String] = []
  for entry in active_defs.shader_defs.iter() {
    let (name, value) = entry
    entries.push("\{name}=\{wgsl_shader_def_value_cache_text(value)}")
  }
  entries.sort()
  "\{normalize_shader_rel_path(rel_path)}|\{entries.join("|")}"
}

///|
fn collect_wgsl_naga_pull_ranks(
  source : String,
) -> Map[String, Int] raise ComposerError {
  let ranks : Map[String, Int] = Map([])
  let origins = collect_wgsl_naga_dependency_pulled_item_origins_strict(source) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
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
fn WgslProcessedComposeModule::declaration(
  self : WgslProcessedComposeModule,
  name : String,
) -> WgslGlobalDecl? raise ComposerError {
  self.declaration_map().get(name)
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
fn wgsl_global_variable_has_resource_binding(
  global : @ast.WgslGlobalVariable,
) -> Bool {
  let mut has_group = false
  let mut has_binding = false
  for attribute in global.attributes() {
    match attribute.name().name() {
      "group" => has_group = true
      "binding" => has_binding = true
      _ => ()
    }
  }
  has_group && has_binding
}

///|
fn WgslProcessedComposeModule::declares_non_resource_dependency_item(
  self : WgslProcessedComposeModule,
  item_name : String,
  referenced : Bool,
) -> Bool raise ComposerError {
  match self.declaration(item_name) {
    Some(declaration) =>
      match declaration.data() {
        Struct(_) | TypeAlias(_) | Const(_) | Override(_) | Function(_) =>
          referenced
        _ => false
      }
    None => false
  }
}

///|
fn WgslProcessedComposeModule::declares_const_side_effect_item(
  self : WgslProcessedComposeModule,
  item_name : String,
) -> Bool raise ComposerError {
  match self.declaration(item_name) {
    Some(declaration) =>
      match declaration.data() {
        Const(_) | Override(_) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslProcessedComposeModule::resource_side_effect_items(
  self : WgslProcessedComposeModule,
  candidate_items : Array[String],
) -> Array[String] raise ComposerError {
  let items : Array[String] = []
  for candidate_item in candidate_items {
    match self.declaration(candidate_item) {
      Some(declaration) =>
        match declaration.data() {
          GlobalVariable(global) =>
            if wgsl_global_variable_has_resource_binding(global) {
              composer_string_list_push_unique(items, candidate_item)
            }
          _ => ()
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
) -> Array[String] raise ComposerError {
  let items : Array[String] = []
  for candidate_item in candidate_items {
    if self.declares_const_side_effect_item(candidate_item) {
      composer_string_list_push_unique(items, candidate_item)
    }
  }
  items
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
fn WgslProcessedComposeModule::named_declarations(
  self : WgslProcessedComposeModule,
) -> Array[WgslEmittedDeclaration] raise ComposerError {
  match self.declarations {
    Some(declarations) => declarations
    None => {
      let declarations = collect_wgsl_named_declarations_strict(
        self.prepared.active_source,
      ) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
      self.declarations = Some(declarations)
      declarations
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
      let ranks = collect_wgsl_naga_pull_ranks(self.prepared.active_source)
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
  merge_wgsl_source_local_shader_defs(active_defs, raw_source, session)
  let cache_key = wgsl_active_defs_cache_key(rel_path, active_defs)
  match session.processed_modules.get(cache_key) {
    Some(processed) => processed
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
        declarations: None,
        item_extractor: None,
        item_extractions: Map([]),
        naga_pull_ranks: None,
        source_decl_ranks: None,
      }
      session.processed_modules.set(cache_key, processed)
      processed
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
