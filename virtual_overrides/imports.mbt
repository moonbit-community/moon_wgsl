///|
using @analysis {
  type WgslGraphBlock,
  type WgslRenamePlan,
  build_wgsl_declaration_graph,
  rewrite_wgsl_declarations_with_rename_plan,
}

///|
using @ast {type WgslFunction, type WgslGlobalDeclData}

///|
using @lex {split_last_identifier}
