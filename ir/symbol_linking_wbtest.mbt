///|
test "IR final-name table is keyed by stable canonical identity" {
  let table = WgslIrFinalNameTable::new()
  let identity = WgslIrSymbolIdentity::new("module.wgsl", "Item")
  table.canonical_set(identity, "module__Item")
  table.canonical_set(identity, "other__Item")
  debug_inspect(table.canonical_entry_count(), content="1")
  debug_inspect(table.canonical_get(identity), content="Some(\"module__Item\")")
}

///|
test "IR final-name table keeps alias scopes separate" {
  let table = WgslIrFinalNameTable::new()
  let first = WgslIrAliasSymbolIdentity::new("module.wgsl", "a", "Item")
  let second = WgslIrAliasSymbolIdentity::new("module.wgsl", "b", "Item")
  table.alias_set(first, "a__Item")
  table.alias_set(second, "b__Item")
  debug_inspect(table.alias_get(first), content="Some(\"a__Item\")")
  debug_inspect(table.alias_get(second), content="Some(\"b__Item\")")
  debug_inspect(
    table.alias_entries_for_scope("module.wgsl", "a").length(),
    content="1",
  )
}

///|
test "IR link graph records import edges and reachable symbols" {
  let graph = WgslIrLinkGraph::new()
  let identity = WgslIrSymbolIdentity::new("dep.wgsl", "dep_fn")
  graph.record_symbol(identity)
  graph.mark_reachable(identity)
  graph.record_import("root.wgsl", "dep.wgsl", "dep", "", "dep_fn", ItemBinding)
  graph.record_import("root.wgsl", "dep.wgsl", "dep", "", "dep_fn", ItemBinding)
  debug_inspect(graph.import_edge_count(), content="1")
  debug_inspect(graph.contains_reachable_symbol(identity), content="true")
}
