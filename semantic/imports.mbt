///|
using @ast {
  type WgslGlobalDecl,
  type WgslGlobalDeclData,
  type WgslIdent,
  collect_wgsl_decl_identifier_nodes,
}

///|
using @common {
  type WgslImportTarget,
  type WgslResolvedImportModule,
  type WgslSymbolRedirect,
}

///|
using @lex {split_last_identifier}

///|
using @metadata {wgsl_source_define_import_path}

///|
using @parser {
  type WgslParseError,
  parse_wgsl_import_alias_prefix,
  parse_wgsl_translation_unit_strict,
}

///|
using @resolver {
  type WgslSourceRegistry,
  resolve_wgsl_import_file_path_from_registry,
  resolve_wgsl_import_module_in_registry,
}
