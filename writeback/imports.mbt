///|
using @analysis {
  type WgslRenamePlan,
  build_wgsl_declaration_graph,
  rewrite_wgsl_declarations_with_rename_plan,
}

///|
using @ast {type WgslBlock, type WgslGlobalDeclData, type WgslStatement}

///|
using @parser {type WgslParseError}
