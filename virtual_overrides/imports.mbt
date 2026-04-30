///|
using @analysis {
  type WgslGraphBlock,
  type WgslRenamePlan,
  build_wgsl_declaration_graph,
  build_wgsl_decl_local_name_map,
  rewrite_wgsl_declarations_with_rename_plan,
}

///|
using @syntax {
  type WgslFunction,
  type WgslGlobalDeclData,
  split_last_identifier,
}
