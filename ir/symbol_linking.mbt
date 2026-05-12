///|
pub struct WgslIrSymbolIdentity {
  priv rel_path : String
  priv original_name : String
} derive(Eq, Debug)

///|
pub struct WgslIrAliasSymbolIdentity {
  priv alias_name : String
  priv symbol : WgslIrSymbolIdentity
} derive(Eq, Debug)

///|
pub struct WgslIrCanonicalFinalNameEntry {
  priv identity : WgslIrSymbolIdentity
  priv final_name : String
} derive(Eq, Debug)

///|
pub struct WgslIrAliasFinalNameEntry {
  priv identity : WgslIrAliasSymbolIdentity
  priv final_name : String
} derive(Eq, Debug)

///|
pub struct WgslIrFinalNameTable {
  priv canonical : Map[String, String]
  priv alias_scoped : Map[String, String]
  priv canonical_entries : Array[WgslIrCanonicalFinalNameEntry]
  priv alias_entries : Array[WgslIrAliasFinalNameEntry]
}

///|
pub(all) enum WgslIrImportEdgeKind {
  FullModule
  AliasModule
  ItemBinding
} derive(Eq, Debug)

///|
pub struct WgslIrImportEdge {
  priv importer_rel_path : String
  priv target_rel_path : String
  priv module_path : String
  priv alias_name : String
  priv item_name : String
  priv kind : WgslIrImportEdgeKind
} derive(Eq, Debug)

///|
pub struct WgslIrSymbolNode {
  priv identity : WgslIrSymbolIdentity
} derive(Eq, Debug)

///|
pub struct WgslIrLinkGraph {
  priv symbol_keys : @set.Set[String]
  priv symbol_nodes : Array[WgslIrSymbolNode]
  priv import_edge_keys : @set.Set[String]
  priv import_edges : Array[WgslIrImportEdge]
  priv reachable_symbol_keys : @set.Set[String]
}

///|
pub fn WgslIrSymbolIdentity::WgslIrSymbolIdentity(
  rel_path : String,
  original_name : String,
) -> WgslIrSymbolIdentity {
  WgslIrSymbolIdentity::{ rel_path, original_name }
}

///|
pub fn WgslIrSymbolIdentity::key(self : WgslIrSymbolIdentity) -> String {
  "\{self.rel_path}|\{self.original_name}"
}

///|
pub fn WgslIrSymbolIdentity::rel_path(self : WgslIrSymbolIdentity) -> String {
  self.rel_path
}

///|
pub fn WgslIrSymbolIdentity::original_name(
  self : WgslIrSymbolIdentity,
) -> String {
  self.original_name
}

///|
pub fn WgslIrAliasSymbolIdentity::WgslIrAliasSymbolIdentity(
  rel_path : String,
  alias_name : String,
  original_name : String,
) -> WgslIrAliasSymbolIdentity {
  WgslIrAliasSymbolIdentity::{
    alias_name,
    symbol: WgslIrSymbolIdentity(rel_path, original_name),
  }
}

///|
pub fn WgslIrAliasSymbolIdentity::key(
  self : WgslIrAliasSymbolIdentity,
) -> String {
  "\{self.alias_name}|\{self.symbol.key()}"
}

///|
pub fn WgslIrAliasSymbolIdentity::alias_name(
  self : WgslIrAliasSymbolIdentity,
) -> String {
  self.alias_name
}

///|
pub fn WgslIrAliasSymbolIdentity::symbol(
  self : WgslIrAliasSymbolIdentity,
) -> WgslIrSymbolIdentity {
  self.symbol
}

///|
pub fn WgslIrCanonicalFinalNameEntry::identity(
  self : WgslIrCanonicalFinalNameEntry,
) -> WgslIrSymbolIdentity {
  self.identity
}

///|
pub fn WgslIrCanonicalFinalNameEntry::final_name(
  self : WgslIrCanonicalFinalNameEntry,
) -> String {
  self.final_name
}

///|
pub fn WgslIrAliasFinalNameEntry::identity(
  self : WgslIrAliasFinalNameEntry,
) -> WgslIrAliasSymbolIdentity {
  self.identity
}

///|
pub fn WgslIrAliasFinalNameEntry::final_name(
  self : WgslIrAliasFinalNameEntry,
) -> String {
  self.final_name
}

///|
pub fn WgslIrFinalNameTable::WgslIrFinalNameTable() -> WgslIrFinalNameTable {
  WgslIrFinalNameTable::{
    canonical: Map([]),
    alias_scoped: Map([]),
    canonical_entries: [],
    alias_entries: [],
  }
}

///|
pub fn WgslIrFinalNameTable::canonical_set(
  self : WgslIrFinalNameTable,
  identity : WgslIrSymbolIdentity,
  final_name : String,
) -> Unit {
  let key = identity.key()
  if self.canonical.contains(key) {
    return
  }
  self.canonical.set(key, final_name)
  self.canonical_entries.push(WgslIrCanonicalFinalNameEntry::{
    identity,
    final_name,
  })
}

///|
pub fn WgslIrFinalNameTable::canonical_get(
  self : WgslIrFinalNameTable,
  identity : WgslIrSymbolIdentity,
) -> String? {
  self.canonical.get(identity.key())
}

///|
pub fn WgslIrFinalNameTable::canonical_entries_for_rel_path(
  self : WgslIrFinalNameTable,
  rel_path : String,
) -> Array[WgslIrCanonicalFinalNameEntry] {
  let entries : Array[WgslIrCanonicalFinalNameEntry] = []
  for entry in self.canonical_entries {
    if entry.identity.rel_path == rel_path {
      entries.push(entry)
    }
  }
  entries
}

///|
pub fn WgslIrFinalNameTable::canonical_entry_count(
  self : WgslIrFinalNameTable,
) -> Int {
  self.canonical_entries.length()
}

///|
pub fn WgslIrFinalNameTable::alias_set(
  self : WgslIrFinalNameTable,
  identity : WgslIrAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  let key = identity.key()
  if self.alias_scoped.contains(key) {
    return
  }
  self.alias_scoped.set(key, final_name)
  self.alias_entries.push(WgslIrAliasFinalNameEntry::{ identity, final_name })
}

///|
pub fn WgslIrFinalNameTable::alias_get(
  self : WgslIrFinalNameTable,
  identity : WgslIrAliasSymbolIdentity,
) -> String? {
  self.alias_scoped.get(identity.key())
}

///|
pub fn WgslIrFinalNameTable::alias_entries_for_scope(
  self : WgslIrFinalNameTable,
  rel_path : String,
  alias_name : String,
) -> Array[WgslIrAliasFinalNameEntry] {
  let entries : Array[WgslIrAliasFinalNameEntry] = []
  for entry in self.alias_entries {
    if entry.identity.alias_name == alias_name &&
      entry.identity.symbol.rel_path == rel_path {
      entries.push(entry)
    }
  }
  entries
}

///|
pub fn WgslIrFinalNameTable::alias_entries(
  self : WgslIrFinalNameTable,
) -> Array[WgslIrAliasFinalNameEntry] {
  self.alias_entries.copy()
}

///|
pub fn WgslIrSymbolNode::identity(
  self : WgslIrSymbolNode,
) -> WgslIrSymbolIdentity {
  self.identity
}

///|
pub fn WgslIrImportEdge::WgslIrImportEdge(
  importer_rel_path : String,
  target_rel_path : String,
  module_path : String,
  alias_name : String,
  item_name : String,
  kind : WgslIrImportEdgeKind,
) -> WgslIrImportEdge {
  WgslIrImportEdge::{
    importer_rel_path,
    target_rel_path,
    module_path,
    alias_name,
    item_name,
    kind,
  }
}

///|
pub fn WgslIrImportEdge::key(self : WgslIrImportEdge) -> String {
  "\{self.importer_rel_path}|\{self.target_rel_path}|\{self.module_path}|\{self.alias_name}|\{self.item_name}|\{self.kind.key()}"
}

///|
pub fn WgslIrImportEdgeKind::key(self : WgslIrImportEdgeKind) -> String {
  match self {
    FullModule => "full"
    AliasModule => "alias"
    ItemBinding => "item"
  }
}

///|
pub fn WgslIrLinkGraph::WgslIrLinkGraph() -> WgslIrLinkGraph {
  WgslIrLinkGraph::{
    symbol_keys: @set.Set([]),
    symbol_nodes: [],
    import_edge_keys: @set.Set([]),
    import_edges: [],
    reachable_symbol_keys: @set.Set([]),
  }
}

///|
pub fn WgslIrLinkGraph::record_symbol(
  self : WgslIrLinkGraph,
  identity : WgslIrSymbolIdentity,
) -> Unit {
  let key = identity.key()
  if self.symbol_keys.contains(key) {
    return
  }
  self.symbol_keys.add(key)
  self.symbol_nodes.push(WgslIrSymbolNode::{ identity, })
}

///|
pub fn WgslIrLinkGraph::mark_reachable(
  self : WgslIrLinkGraph,
  identity : WgslIrSymbolIdentity,
) -> Unit {
  self.reachable_symbol_keys.add(identity.key())
}

///|
pub fn WgslIrLinkGraph::record_reachable_symbol(
  self : WgslIrLinkGraph,
  identity : WgslIrSymbolIdentity,
) -> Unit {
  self.record_symbol(identity)
  self.mark_reachable(identity)
}

///|
pub fn WgslIrLinkGraph::record_import_edge(
  self : WgslIrLinkGraph,
  edge : WgslIrImportEdge,
) -> Unit {
  let key = edge.key()
  if self.import_edge_keys.contains(key) {
    return
  }
  self.import_edge_keys.add(key)
  self.import_edges.push(edge)
}

///|
pub fn WgslIrLinkGraph::record_import(
  self : WgslIrLinkGraph,
  importer_rel_path : String,
  target_rel_path : String,
  module_path : String,
  alias_name : String,
  item_name : String,
  kind : WgslIrImportEdgeKind,
) -> Unit {
  self.record_import_edge(
    WgslIrImportEdge(
      importer_rel_path, target_rel_path, module_path, alias_name, item_name, kind,
    ),
  )
}

///|
pub fn WgslIrLinkGraph::import_edge_count(self : WgslIrLinkGraph) -> Int {
  self.import_edges.length()
}

///|
pub fn WgslIrLinkGraph::contains_reachable_symbol(
  self : WgslIrLinkGraph,
  identity : WgslIrSymbolIdentity,
) -> Bool {
  self.reachable_symbol_keys.contains(identity.key())
}
