///|
priv enum WgslComposeImportEdgeKind {
  FullModule
  AliasModule
  ItemBinding
}

///|
priv struct WgslComposeImportEdge {
  importer_rel_path : String
  target_rel_path : String
  module_path : String
  alias_name : String
  item_name : String
  kind : WgslComposeImportEdgeKind
}

///|
priv struct WgslComposeSymbolNode {
  identity : WgslSymbolIdentity
  generated_name : String
}

///|
priv struct WgslComposeSymbolGraph {
  symbol_keys : @hashset.HashSet[String]
  symbol_nodes : Array[WgslComposeSymbolNode]
  import_edge_keys : @hashset.HashSet[String]
  import_edges : Array[WgslComposeImportEdge]
  reachable_symbol_keys : @hashset.HashSet[String]
}

///|
fn WgslComposeSymbolGraph::new() -> WgslComposeSymbolGraph {
  WgslComposeSymbolGraph::{
    symbol_keys: @hashset.HashSet::new(),
    symbol_nodes: [],
    import_edge_keys: @hashset.HashSet::new(),
    import_edges: [],
    reachable_symbol_keys: @hashset.HashSet::new(),
  }
}

///|
fn wgsl_compose_import_edge_kind_key(
  kind : WgslComposeImportEdgeKind,
) -> String {
  match kind {
    FullModule => "full"
    AliasModule => "alias"
    ItemBinding => "item"
  }
}

///|
fn WgslComposeImportEdge::key(self : WgslComposeImportEdge) -> String {
  "\{self.importer_rel_path}|\{self.target_rel_path}|\{self.module_path}|\{self.alias_name}|\{self.item_name}|\{wgsl_compose_import_edge_kind_key(self.kind)}"
}

///|
fn WgslComposeSymbolGraph::record_symbol(
  self : WgslComposeSymbolGraph,
  identity : WgslSymbolIdentity,
  generated_name : String,
) -> Unit {
  let key = identity.key()
  if self.symbol_keys.contains(key) {
    for node in self.symbol_nodes {
      if node.identity.key() == key && node.generated_name == generated_name {
        return
      }
    }
    return
  }
  self.symbol_keys.add(key)
  self.symbol_nodes.push(WgslComposeSymbolNode::{ identity, generated_name })
}

///|
fn WgslComposeSymbolGraph::record_import_edge(
  self : WgslComposeSymbolGraph,
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
fn WgslComposeSymbolGraph::mark_reachable(
  self : WgslComposeSymbolGraph,
  identity : WgslSymbolIdentity,
) -> Unit {
  self.reachable_symbol_keys.add(identity.key())
}

///|
fn WgslComposeSymbolGraph::record_request_edges(
  self : WgslComposeSymbolGraph,
  importer_rel_path : String,
  request : WgslImportRequest,
) -> Unit {
  if request.import_full_module {
    self.record_import_edge(WgslComposeImportEdge::{
      importer_rel_path,
      target_rel_path: request.rel_path,
      module_path: request.module_path,
      alias_name: request.alias_name,
      item_name: "",
      kind: if request.alias_name == "" {
        FullModule
      } else {
        AliasModule
      },
    })
  }
  for item_name in request.requested_items {
    let identity = WgslSymbolIdentity::new(request.rel_path, item_name)
    self.mark_reachable(identity)
    self.record_import_edge(WgslComposeImportEdge::{
      importer_rel_path,
      target_rel_path: request.rel_path,
      module_path: request.module_path,
      alias_name: request.alias_name,
      item_name,
      kind: ItemBinding,
    })
  }
}
