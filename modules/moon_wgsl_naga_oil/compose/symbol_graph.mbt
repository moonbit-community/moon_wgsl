///|
pub struct WgslComposeCanonicalFinalNameEntry {
  priv identity : WgslComposeSymbolIdentity
  priv final_name : String
} derive(Eq, Debug)

///|
pub struct WgslComposeAliasFinalNameEntry {
  priv identity : WgslComposeAliasSymbolIdentity
  priv final_name : String
} derive(Eq, Debug)

///|
pub struct WgslComposeFinalNameTable {
  priv canonical : Map[String, String]
  priv alias_scoped : Map[String, String]
  priv canonical_entries : Array[WgslComposeCanonicalFinalNameEntry]
  priv alias_entries : Array[WgslComposeAliasFinalNameEntry]
}

///|
pub(all) enum WgslComposeImportEdgeKind {
  FullModule
  AliasModule
  ItemBinding
} derive(Eq, Debug)

///|
pub(all) enum WgslComposeDeclarationKind {
  Type
  Constant
  Override
  GlobalVariable
  Function
} derive(Eq, Debug)

///|
pub struct WgslComposeImportEdge {
  priv importer_rel_path : String
  priv target_rel_path : String
  priv module_path : String
  priv alias_name : String
  priv item_name : String
  priv kind : WgslComposeImportEdgeKind
} derive(Eq, Debug)

///|
pub struct WgslComposeImportArenaSymbol {
  priv kind : WgslComposeDeclarationKind
  priv source_symbol_name : String
  priv generated_symbol_name : String
  priv source_decl_rank : Int
  priv source_order_rank : Int
} derive(Eq, Debug)

///|
pub struct WgslComposeImportArenaEvent {
  priv sequence : Int
  priv importer_rel_path : String
  priv target_rel_path : String
  priv module_path : String
  priv alias_name : String
  priv item_names : Array[String]
  priv kind : WgslComposeImportEdgeKind
  priv generated_symbols : Array[WgslComposeImportArenaSymbol]
} derive(Eq, Debug)

///|
pub struct WgslComposeSymbolNode {
  priv identity : WgslComposeSymbolIdentity
} derive(Eq, Debug)

///|
pub struct WgslComposeLinkGraph {
  priv symbol_keys : @set.Set[String]
  priv symbol_nodes : Array[WgslComposeSymbolNode]
  priv import_edge_keys : @set.Set[String]
  priv import_edges : Array[WgslComposeImportEdge]
  priv import_arena_events : Array[WgslComposeImportArenaEvent]
  priv reachable_symbol_keys : @set.Set[String]
}

///|
pub fn WgslComposeCanonicalFinalNameEntry::identity(
  self : WgslComposeCanonicalFinalNameEntry,
) -> WgslComposeSymbolIdentity {
  self.identity
}

///|
pub fn WgslComposeCanonicalFinalNameEntry::final_name(
  self : WgslComposeCanonicalFinalNameEntry,
) -> String {
  self.final_name
}

///|
pub fn WgslComposeAliasFinalNameEntry::identity(
  self : WgslComposeAliasFinalNameEntry,
) -> WgslComposeAliasSymbolIdentity {
  self.identity
}

///|
pub fn WgslComposeAliasFinalNameEntry::final_name(
  self : WgslComposeAliasFinalNameEntry,
) -> String {
  self.final_name
}

///|
pub fn WgslComposeFinalNameTable::WgslComposeFinalNameTable() -> WgslComposeFinalNameTable {
  {
    canonical: Map([]),
    alias_scoped: Map([]),
    canonical_entries: [],
    alias_entries: [],
  }
}

///|
pub fn WgslComposeFinalNameTable::canonical_set(
  self : WgslComposeFinalNameTable,
  identity : WgslComposeSymbolIdentity,
  final_name : String,
) -> Unit {
  let key = identity.key()
  if self.canonical.contains(key) {
    return
  }
  self.canonical.set(key, final_name)
  self.canonical_entries.push({ identity, final_name })
}

///|
pub fn WgslComposeFinalNameTable::canonical_get(
  self : WgslComposeFinalNameTable,
  identity : WgslComposeSymbolIdentity,
) -> String? {
  self.canonical.get(identity.key())
}

///|
pub fn WgslComposeFinalNameTable::canonical_entries_for_rel_path(
  self : WgslComposeFinalNameTable,
  rel_path : String,
) -> Array[WgslComposeCanonicalFinalNameEntry] {
  let entries : Array[WgslComposeCanonicalFinalNameEntry] = []
  for entry in self.canonical_entries {
    if entry.identity.rel_path() == rel_path {
      entries.push(entry)
    }
  }
  entries
}

///|
pub fn WgslComposeFinalNameTable::canonical_entry_count(
  self : WgslComposeFinalNameTable,
) -> Int {
  self.canonical_entries.length()
}

///|
pub fn WgslComposeFinalNameTable::alias_set(
  self : WgslComposeFinalNameTable,
  identity : WgslComposeAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  let key = identity.key()
  if self.alias_scoped.contains(key) {
    return
  }
  self.alias_scoped.set(key, final_name)
  self.alias_entries.push({ identity, final_name })
}

///|
pub fn WgslComposeFinalNameTable::alias_get(
  self : WgslComposeFinalNameTable,
  identity : WgslComposeAliasSymbolIdentity,
) -> String? {
  self.alias_scoped.get(identity.key())
}

///|
pub fn WgslComposeFinalNameTable::alias_entries_for_scope(
  self : WgslComposeFinalNameTable,
  rel_path : String,
  alias_name : String,
) -> Array[WgslComposeAliasFinalNameEntry] {
  let entries : Array[WgslComposeAliasFinalNameEntry] = []
  for entry in self.alias_entries {
    if entry.identity.alias_name() == alias_name &&
      entry.identity.symbol().rel_path() == rel_path {
      entries.push(entry)
    }
  }
  entries
}

///|
pub fn WgslComposeFinalNameTable::alias_entries(
  self : WgslComposeFinalNameTable,
) -> Array[WgslComposeAliasFinalNameEntry] {
  self.alias_entries.copy()
}

///|
pub fn WgslComposeSymbolNode::identity(
  self : WgslComposeSymbolNode,
) -> WgslComposeSymbolIdentity {
  self.identity
}

///|
pub fn WgslComposeImportEdge::WgslComposeImportEdge(
  importer_rel_path : String,
  target_rel_path : String,
  module_path : String,
  alias_name : String,
  item_name : String,
  kind : WgslComposeImportEdgeKind,
) -> WgslComposeImportEdge {
  {
    importer_rel_path,
    target_rel_path,
    module_path,
    alias_name,
    item_name,
    kind,
  }
}

///|
pub fn WgslComposeImportEdge::key(self : WgslComposeImportEdge) -> String {
  "\{self.importer_rel_path}|\{self.target_rel_path}|\{self.module_path}|\{self.alias_name}|\{self.item_name}|\{self.kind.key()}"
}

///|
pub fn WgslComposeImportArenaSymbol::WgslComposeImportArenaSymbol(
  kind : WgslComposeDeclarationKind,
  source_symbol_name : String,
  generated_symbol_name : String,
  source_decl_rank? : Int = -1,
  source_order_rank? : Int = -1,
) -> WgslComposeImportArenaSymbol {
  {
    kind,
    source_symbol_name,
    generated_symbol_name,
    source_decl_rank,
    source_order_rank,
  }
}

///|
pub fn WgslComposeImportArenaSymbol::kind(
  self : WgslComposeImportArenaSymbol,
) -> WgslComposeDeclarationKind {
  self.kind
}

///|
pub fn WgslComposeImportArenaSymbol::source_symbol_name(
  self : WgslComposeImportArenaSymbol,
) -> String {
  self.source_symbol_name
}

///|
pub fn WgslComposeImportArenaSymbol::generated_symbol_name(
  self : WgslComposeImportArenaSymbol,
) -> String {
  self.generated_symbol_name
}

///|
pub fn WgslComposeImportArenaSymbol::source_order_rank(
  self : WgslComposeImportArenaSymbol,
) -> Int {
  self.source_order_rank
}

///|
pub fn WgslComposeImportArenaSymbol::source_decl_rank(
  self : WgslComposeImportArenaSymbol,
) -> Int {
  self.source_decl_rank
}

///|
pub fn WgslComposeImportArenaEvent::WgslComposeImportArenaEvent(
  sequence : Int,
  importer_rel_path : String,
  target_rel_path : String,
  module_path : String,
  alias_name : String,
  item_names : Array[String],
  kind : WgslComposeImportEdgeKind,
  generated_symbols : Array[WgslComposeImportArenaSymbol],
) -> WgslComposeImportArenaEvent {
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
pub fn WgslComposeImportArenaEvent::sequence(
  self : WgslComposeImportArenaEvent,
) -> Int {
  self.sequence
}

///|
pub fn WgslComposeImportArenaEvent::importer_rel_path(
  self : WgslComposeImportArenaEvent,
) -> String {
  self.importer_rel_path
}

///|
pub fn WgslComposeImportArenaEvent::target_rel_path(
  self : WgslComposeImportArenaEvent,
) -> String {
  self.target_rel_path
}

///|
pub fn WgslComposeImportArenaEvent::module_path(
  self : WgslComposeImportArenaEvent,
) -> String {
  self.module_path
}

///|
pub fn WgslComposeImportArenaEvent::alias_name(
  self : WgslComposeImportArenaEvent,
) -> String {
  self.alias_name
}

///|
pub fn WgslComposeImportArenaEvent::item_names(
  self : WgslComposeImportArenaEvent,
) -> Array[String] {
  self.item_names.copy()
}

///|
pub fn WgslComposeImportArenaEvent::kind(
  self : WgslComposeImportArenaEvent,
) -> WgslComposeImportEdgeKind {
  self.kind
}

///|
pub fn WgslComposeImportArenaEvent::generated_symbol_names(
  self : WgslComposeImportArenaEvent,
) -> Array[String] {
  let names : Array[String] = []
  for symbol in self.generated_symbols {
    names.push(symbol.generated_symbol_name)
  }
  names
}

///|
pub fn WgslComposeImportArenaEvent::generated_symbols(
  self : WgslComposeImportArenaEvent,
) -> Array[WgslComposeImportArenaSymbol] {
  self.generated_symbols.copy()
}

///|
pub fn WgslComposeImportEdgeKind::key(
  self : WgslComposeImportEdgeKind,
) -> String {
  match self {
    FullModule => "full"
    AliasModule => "alias"
    ItemBinding => "item"
  }
}

///|
pub fn WgslComposeLinkGraph::WgslComposeLinkGraph() -> WgslComposeLinkGraph {
  {
    symbol_keys: Set([]),
    symbol_nodes: [],
    import_edge_keys: Set([]),
    import_edges: [],
    import_arena_events: [],
    reachable_symbol_keys: Set([]),
  }
}

///|
pub fn WgslComposeLinkGraph::record_symbol(
  self : WgslComposeLinkGraph,
  identity : WgslComposeSymbolIdentity,
) -> Unit {
  let key = identity.key()
  if self.symbol_keys.contains(key) {
    return
  }
  self.symbol_keys.add(key)
  self.symbol_nodes.push({ identity, })
}

///|
pub fn WgslComposeLinkGraph::mark_reachable(
  self : WgslComposeLinkGraph,
  identity : WgslComposeSymbolIdentity,
) -> Unit {
  self.reachable_symbol_keys.add(identity.key())
}

///|
pub fn WgslComposeLinkGraph::record_reachable_symbol(
  self : WgslComposeLinkGraph,
  identity : WgslComposeSymbolIdentity,
) -> Unit {
  self.record_symbol(identity)
  self.mark_reachable(identity)
}

///|
pub fn WgslComposeLinkGraph::record_import_edge(
  self : WgslComposeLinkGraph,
  edge : WgslComposeImportEdge,
) -> Unit {
  let key = edge.key()
  if self.import_edge_keys.contains(key) {
    return
  }
  self.import_edge_keys.add(key)
  self.import_edges.push(edge)
}

///|
pub fn WgslComposeLinkGraph::record_import(
  self : WgslComposeLinkGraph,
  importer_rel_path : String,
  target_rel_path : String,
  module_path : String,
  alias_name : String,
  item_name : String,
  kind : WgslComposeImportEdgeKind,
) -> Unit {
  self.record_import_edge(
    WgslComposeImportEdge(
      importer_rel_path, target_rel_path, module_path, alias_name, item_name, kind,
    ),
  )
}

///|
pub fn WgslComposeLinkGraph::import_edge_count(
  self : WgslComposeLinkGraph,
) -> Int {
  self.import_edges.length()
}

///|
pub fn WgslComposeLinkGraph::record_import_arena_event(
  self : WgslComposeLinkGraph,
  importer_rel_path : String,
  target_rel_path : String,
  module_path : String,
  alias_name : String,
  item_names : Array[String],
  kind : WgslComposeImportEdgeKind,
  generated_symbols : Array[WgslComposeImportArenaSymbol],
) -> Unit {
  self.import_arena_events.push(
    WgslComposeImportArenaEvent(
      self.import_arena_events.length(),
      importer_rel_path,
      target_rel_path,
      module_path,
      alias_name,
      item_names.copy(),
      kind,
      generated_symbols.copy(),
    ),
  )
}

///|
pub fn WgslComposeLinkGraph::import_arena_event_count(
  self : WgslComposeLinkGraph,
) -> Int {
  self.import_arena_events.length()
}

///|
pub fn WgslComposeLinkGraph::import_arena_events(
  self : WgslComposeLinkGraph,
) -> Array[WgslComposeImportArenaEvent] {
  self.import_arena_events.copy()
}

///|
pub fn WgslComposeLinkGraph::contains_reachable_symbol(
  self : WgslComposeLinkGraph,
  identity : WgslComposeSymbolIdentity,
) -> Bool {
  self.reachable_symbol_keys.contains(identity.key())
}
