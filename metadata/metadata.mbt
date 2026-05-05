///|
fn try_get_preprocessor_metadata(
  source : String,
  allow_defines : Bool,
) -> PreprocessorMetaData raise MetadataError {
  let (cleaned_for_directives, wgsl_directives) = extract_wgsl_directives(
    source,
  )

  let declared_imports : Array[DeclaredImportBinding] = []
  let used_imports : Array[ImportDefWithOffset] = []
  let defines : @hashmap.HashMap[String, ShaderDefValue] = @hashmap.HashMap::new()
  let effective_defs : @hashset.HashSet[String] = @hashset.HashSet::new()
  let mut name : String? = None

  for
    item in parse_wgsl_directive_scan_items(
      cleaned_for_directives,
      include_glsl_version=false,
    ) {
    match item.kind() {
      WgslDirectiveScanItemKind::Directive(directive) => {
        let (is_scope, def) = metadata_scope_def_from_directive(
          directive,
          item.requires_tail_space(),
        )
        if is_scope {
          if def is Some(def_name) {
            effective_defs.add(def_name)
          }
        } else if item.requires_tail_space() &&
          directive.kind == WgslDirectiveKind::Import {
          parse_imports(item.cleaned_directive_text(), declared_imports) catch {
            Parse(message, item_offset) =>
              raise MetadataError::ImportParseError(
                message,
                item.start() + item_offset,
              )
          }
        } else if item.requires_tail_space() &&
          directive.kind == WgslDirectiveKind::DefineImportPath {
          let import_path = wgsl_metadata_first_space_separated_token(
            directive.tail,
          )
          if import_path != "" {
            name = Some(import_path)
          }
        } else if item.requires_tail_space() &&
          directive.kind == WgslDirectiveKind::Define {
          if allow_defines {
            let (define_name, define_value) = split_define_name_and_value(
              directive.tail,
            )
            if define_name != "" {
              defines.set(define_name, parse_define_value(define_value))
            }
          } else {
            raise MetadataError::DefineInModule(item.start())
          }
        } else {
          metadata_collect_source_item(item, effective_defs)
        }
      }
      WgslDirectiveScanItemKind::Source =>
        metadata_collect_source_item(item, effective_defs)
      WgslDirectiveScanItemKind::GlslVersion(_) => ()
    }
  }
  metadata_collect_import_uses(
    cleaned_for_directives, declared_imports, used_imports,
  )

  PreprocessorMetaData::new(
    name, used_imports, defines, effective_defs, wgsl_directives, cleaned_for_directives,
  )
}

///|
pub fn get_preprocessor_metadata(
  source : String,
  allow_defines? : Bool = true,
) -> PreprocessorMetaData raise MetadataError {
  try_get_preprocessor_metadata(source, allow_defines)
}
