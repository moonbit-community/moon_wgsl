///|
using @ast {
  type WgslAttribute,
  type WgslDirectiveKind,
  type WgslGlobalDeclData,
  type WgslGlobalDeclKind,
  type WgslIdent,
  collect_wgsl_decl_global_declared_identifier_nodes,
  collect_wgsl_decl_identifier_nodes,
}

///|
using @parser {parse_wgsl_translation_unit}

///|
using @lex {split_last_identifier}

///|
using @common {type WgslSymbolRedirect}
