///|
using @ast {type WgslIdent, collect_wgsl_decl_identifier_nodes}

///|
using @common {type WgslResolvedImportModule}

///|
using @lex {split_last_identifier, tokenize}

///|
using @metadata {wgsl_source_define_import_path}

///|
using @resolver {
  resolve_wgsl_import_file_path_from_registry,
  resolve_wgsl_import_module_in_registry,
}
