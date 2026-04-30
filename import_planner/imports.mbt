///|
using @analysis {collect_wgsl_named_declarations}

///|
using @common {
  type WgslImportTarget,
  type WgslResolvedImportModule,
  type WgslSymbolRedirect,
}

///|
using @metadata {wgsl_source_define_import_path}

///|
using @resolver {
  type WgslSourceRegistry,
  resolve_wgsl_import_file_path_from_registry,
  resolve_wgsl_import_module_in_registry,
}

///|
using @ast {type WgslIdent, collect_wgsl_decl_identifier_nodes}

///|
using @parser {parse_wgsl_translation_unit}

///|
using @lex {type WgslToken, split_last_identifier, tokenize}
