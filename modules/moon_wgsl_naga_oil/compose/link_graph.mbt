///|
fn record_wgsl_import_request_link_edges(
  link_graph : WgslComposeLinkGraph,
  importer_rel_path : String,
  request : WgslImportRequest,
) -> Unit {
  if request.import_full_module {
    link_graph.record_import(
      importer_rel_path,
      request.rel_path,
      request.module_path,
      request.alias_name,
      "",
      if request.alias_name == "" {
        FullModule
      } else {
        AliasModule
      },
    )
  }
  for item_name in request.requested_items {
    let identity = WgslComposeSymbolIdentity(request.rel_path, item_name)
    link_graph.mark_reachable(identity)
    link_graph.record_import(
      importer_rel_path,
      request.rel_path,
      request.module_path,
      request.alias_name,
      item_name,
      ItemBinding,
    )
  }
}

///|
fn record_wgsl_import_request_batch_link_edges(
  link_graph : WgslComposeLinkGraph,
  importer_rel_path : String,
  requests : Array[WgslImportRequest],
) -> Unit {
  for request in requests {
    record_wgsl_import_request_link_edges(
      link_graph, importer_rel_path, request,
    )
  }
}
