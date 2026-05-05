///|
using @analysis {
  type WgslGraphBlock,
  type WgslRenamePlan,
  type WgslTokenRewrite,
  build_wgsl_declaration_graph,
  emit_wgsl_text_with_token_rewrites,
  rewrite_wgsl_declarations_with_rename_plan,
}

///|
using @ast {
  type WgslFunction,
  type WgslGlobalDeclData,
  type WgslIdent,
  collect_wgsl_function_body_identifier_nodes,
}

///|
using @lex {split_last_identifier}

///|
using @parser {type WgslParseError}
