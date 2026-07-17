///|
pub(all) enum WgslNagaGeneratedImportProvenanceKind {
  ImportedSourceSymbol
  VirtualOverrideSymbol
} derive(Eq, Debug)

///|
pub(all) enum WgslNagaImportEdgeKind {
  FullModule
  AliasModule
  ItemBinding
} derive(Eq, Debug)

///|
pub(all) enum WgslNagaDeclarationKind {
  Type
  Constant
  Override
  GlobalVariable
  Function
} derive(Eq, Debug)

///|
pub(all) struct WgslNagaGeneratedImportProvenance {
  generated_symbol_name : String
  rel_path : String
  source_symbol_name : String
  kind : WgslNagaGeneratedImportProvenanceKind
  inline_value : Bool
  local_spelling : Bool
  root_local_spelling : Bool
  local_spelling_visible_rel_paths : Array[String]
  import_sequence : Int
  source_start : Int
  source_end : Int
  composed_source_start : Int
} derive(Eq, Debug)

///|
pub fn WgslNagaGeneratedImportProvenance::WgslNagaGeneratedImportProvenance(
  generated_symbol_name : String,
  rel_path : String,
  source_symbol_name : String,
  kind : WgslNagaGeneratedImportProvenanceKind,
  inline_value : Bool,
  local_spelling? : Bool = false,
  root_local_spelling? : Bool = false,
  local_spelling_visible_rel_paths? : Array[String] = [],
  import_sequence? : Int = -1,
  source_start? : Int = -1,
  source_end? : Int = -1,
  composed_source_start? : Int = -1,
) -> WgslNagaGeneratedImportProvenance {
  {
    generated_symbol_name,
    rel_path,
    source_symbol_name,
    kind,
    inline_value,
    local_spelling,
    root_local_spelling,
    local_spelling_visible_rel_paths,
    import_sequence,
    source_start,
    source_end,
    composed_source_start,
  }
}

///|
pub fn WgslNagaGeneratedImportProvenance::generated_symbol_name(
  self : WgslNagaGeneratedImportProvenance,
) -> String {
  self.generated_symbol_name
}

///|
pub struct WgslNagaImportArenaSymbol {
  priv kind : WgslNagaDeclarationKind
  priv source_symbol_name : String
  priv generated_symbol_name : String
  priv source_decl_rank : Int
  priv source_order_rank : Int
} derive(Eq, Debug)

///|
pub fn WgslNagaImportArenaSymbol::WgslNagaImportArenaSymbol(
  kind : WgslNagaDeclarationKind,
  source_symbol_name : String,
  generated_symbol_name : String,
  source_decl_rank? : Int = -1,
  source_order_rank? : Int = -1,
) -> WgslNagaImportArenaSymbol {
  {
    kind,
    source_symbol_name,
    generated_symbol_name,
    source_decl_rank,
    source_order_rank,
  }
}

///|
pub fn WgslNagaImportArenaSymbol::kind(
  self : WgslNagaImportArenaSymbol,
) -> WgslNagaDeclarationKind {
  self.kind
}

///|
pub fn WgslNagaImportArenaSymbol::source_symbol_name(
  self : WgslNagaImportArenaSymbol,
) -> String {
  self.source_symbol_name
}

///|
pub fn WgslNagaImportArenaSymbol::generated_symbol_name(
  self : WgslNagaImportArenaSymbol,
) -> String {
  self.generated_symbol_name
}

///|
pub fn WgslNagaImportArenaSymbol::source_decl_rank(
  self : WgslNagaImportArenaSymbol,
) -> Int {
  self.source_decl_rank
}

///|
pub fn WgslNagaImportArenaSymbol::source_order_rank(
  self : WgslNagaImportArenaSymbol,
) -> Int {
  self.source_order_rank
}

///|
pub struct WgslNagaImportArenaEvent {
  priv sequence : Int
  priv importer_rel_path : String
  priv target_rel_path : String
  priv module_path : String
  priv alias_name : String
  priv item_names : Array[String]
  priv kind : WgslNagaImportEdgeKind
  priv generated_symbols : Array[WgslNagaImportArenaSymbol]
} derive(Eq, Debug)

///|
pub fn WgslNagaImportArenaEvent::WgslNagaImportArenaEvent(
  sequence : Int,
  importer_rel_path : String,
  target_rel_path : String,
  module_path : String,
  alias_name : String,
  item_names : Array[String],
  kind : WgslNagaImportEdgeKind,
  generated_symbols : Array[WgslNagaImportArenaSymbol],
) -> WgslNagaImportArenaEvent {
  {
    sequence,
    importer_rel_path,
    target_rel_path,
    module_path,
    alias_name,
    item_names,
    kind,
    generated_symbols,
  }
}

///|
pub fn WgslNagaImportArenaEvent::sequence(
  self : WgslNagaImportArenaEvent,
) -> Int {
  self.sequence
}

///|
pub fn WgslNagaImportArenaEvent::importer_rel_path(
  self : WgslNagaImportArenaEvent,
) -> String {
  self.importer_rel_path
}

///|
pub fn WgslNagaImportArenaEvent::target_rel_path(
  self : WgslNagaImportArenaEvent,
) -> String {
  self.target_rel_path
}

///|
pub fn WgslNagaImportArenaEvent::module_path(
  self : WgslNagaImportArenaEvent,
) -> String {
  self.module_path
}

///|
pub fn WgslNagaImportArenaEvent::alias_name(
  self : WgslNagaImportArenaEvent,
) -> String {
  self.alias_name
}

///|
pub fn WgslNagaImportArenaEvent::item_names(
  self : WgslNagaImportArenaEvent,
) -> Array[String] {
  self.item_names.copy()
}

///|
pub fn WgslNagaImportArenaEvent::kind(
  self : WgslNagaImportArenaEvent,
) -> WgslNagaImportEdgeKind {
  self.kind
}

///|
pub fn WgslNagaImportArenaEvent::generated_symbols(
  self : WgslNagaImportArenaEvent,
) -> Array[WgslNagaImportArenaSymbol] {
  self.generated_symbols.copy()
}

///|
priv struct WgslNagaCompatibilityView {
  generated_import_provenance : Map[String, WgslNagaGeneratedImportProvenance]
  import_arena_events : Array[WgslNagaImportArenaEvent]
  root_visible_rel_path : String
}

///|
priv enum WgslNagaLocalSpellingMode {
  Root
  Visible(String)
}

///|
fn WgslNagaCompatibilityView::empty() -> WgslNagaCompatibilityView {
  {
    generated_import_provenance: Map([]),
    import_arena_events: [],
    root_visible_rel_path: "",
  }
}

///|
fn WgslNagaCompatibilityView::from_context(
  context : WgslNagaComposeContext,
) -> WgslNagaCompatibilityView {
  let generated_import_provenance = Map([])
  for provenance in context.generated_import_provenance {
    generated_import_provenance.set(
      provenance.generated_symbol_name,
      provenance,
    )
  }
  {
    generated_import_provenance,
    import_arena_events: context.import_arena_events.copy(),
    root_visible_rel_path: context.root_visible_rel_path,
  }
}

///|
fn WgslNagaCompatibilityView::generated_import(
  self : WgslNagaCompatibilityView,
  name : String,
) -> WgslNagaGeneratedImportProvenance? {
  self.generated_import_provenance.get(name)
}

///|
fn WgslNagaCompatibilityView::is_generated_import(
  self : WgslNagaCompatibilityView,
  name : String?,
) -> Bool {
  match name {
    Some(value) => self.generated_import_provenance.contains(value)
    None => false
  }
}

///|
fn WgslNagaCompatibilityView::constant_should_inline(
  self : WgslNagaCompatibilityView,
  name : String?,
) -> Bool {
  match name {
    Some(value) =>
      match self.generated_import_provenance.get(value) {
        Some(provenance) => provenance.inline_value
        None => false
      }
    None => false
  }
}

///|
fn WgslNagaCompatibilityView::generated_function_rel_path(
  self : WgslNagaCompatibilityView,
  name : String?,
) -> String {
  match name {
    Some(value) =>
      match self.generated_import_provenance.get(value) {
        Some(provenance) if provenance.kind == ImportedSourceSymbol =>
          provenance.rel_path
        _ => self.root_visible_rel_path
      }
    None => self.root_visible_rel_path
  }
}

///|
fn WgslNagaCompatibilityView::local_spelling(
  self : WgslNagaCompatibilityView,
  source_name : String,
  visible_rel_path : String,
) -> String {
  let mut target : String? = None
  for entry in self.generated_import_provenance.iter() {
    let (_, provenance) = entry
    if provenance.kind != ImportedSourceSymbol ||
      !provenance.local_spelling ||
      provenance.source_symbol_name != source_name ||
      !provenance.local_spelling_visible_rel_paths.contains(visible_rel_path) {
      continue
    }
    match target {
      Some(existing) if existing != provenance.generated_symbol_name =>
        return source_name
      Some(_) => ()
      None => target = Some(provenance.generated_symbol_name)
    }
  }
  target.unwrap_or(source_name)
}

///|
fn WgslNagaCompatibilityView::root_local_spelling(
  self : WgslNagaCompatibilityView,
  source_name : String,
) -> String {
  let mut target : String? = None
  for entry in self.generated_import_provenance.iter() {
    let (_, provenance) = entry
    if provenance.kind != ImportedSourceSymbol ||
      !provenance.root_local_spelling ||
      provenance.source_symbol_name != source_name {
      continue
    }
    match target {
      Some(existing) if existing != provenance.generated_symbol_name =>
        return source_name
      Some(_) => ()
      None => target = Some(provenance.generated_symbol_name)
    }
  }
  target.unwrap_or(source_name)
}

///|
fn WgslNagaCompatibilityView::spelling_for_mode(
  self : WgslNagaCompatibilityView,
  source_name : String,
  mode : WgslNagaLocalSpellingMode,
) -> String {
  match mode {
    Root => self.root_local_spelling(source_name)
    Visible(rel_path) => self.local_spelling(source_name, rel_path)
  }
}
