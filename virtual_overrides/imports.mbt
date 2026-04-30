///|
using @analysis {
  type WgslGraphBlock,
  type WgslRenamePlan,
  build_wgsl_declaration_graph,
  rewrite_wgsl_declarations_with_rename_plan,
}

///|
using @syntax {
  type WgslFunction,
  type WgslGlobalDeclData,
  split_last_identifier,
}
