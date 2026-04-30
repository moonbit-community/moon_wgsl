///|
using @syntax {
  type Token,
  type WgslGlobalDeclData,
  type WgslGlobalDeclKind,
  type WgslIdent,
  type WgslDirectiveKind,
  collect_wgsl_decl_declared_identifier_nodes,
  collect_wgsl_decl_identifier_nodes,
  parse_wgsl_translation_unit,
  split_last_identifier,
  tokenize,
}

///|
using @common {type WgslSymbolRedirect}
