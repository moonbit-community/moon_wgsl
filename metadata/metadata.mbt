///|
fn try_get_preprocessor_metadata(
  source : String,
  allow_defines : Bool,
) -> PreprocessorMetaData raise MetadataError {
  let (cleaned_for_directives, wgsl_directives) = extract_wgsl_directives(
    source,
  )
  let stripped = replace_comments(cleaned_for_directives)

  let declared_imports : Array[DeclaredImportBinding] = []
  let used_imports : Array[ImportDefWithOffset] = []
  let defines : @hashmap.HashMap[String, ShaderDefValue] = @hashmap.HashMap::new()
  let effective_defs : @hashset.HashSet[String] = @hashset.HashSet::new()
  let lines : Array[String] = []
  let mut name : String? = None
  let mut offset = 0

  for line_item in source_lines(stripped) {
    lines.push(line_item)
  }

  let mut line_index = 0
  while line_index < lines.length() {
    let line = lines[line_index]
    let trimmed = line.trim().to_owned()
    let (is_scope, def) = metadata_scope_def(line)

    if is_scope {
      if def is Some(def_name) {
        effective_defs.add(def_name)
      }
    } else if wgsl_directive_tail(trimmed, WgslDirectiveKind::Import) is Some(_) {
      let mut import_lines = "\{line}\n"
      let mut open_count = wgsl_token_brace_balance(line)
      let initial_offset = offset

      while open_count > 0 && line_index + 1 < lines.length() {
        line_index = line_index + 1
        let next_line = lines[line_index]
        import_lines = "\{import_lines}\{next_line}\n"
        open_count = open_count + wgsl_token_brace_balance(next_line)
        offset = offset + next_line.length() + 1
      }

      parse_imports(import_lines, declared_imports) catch {
        Parse(message, line_offset) =>
          raise MetadataError::ImportParseError(
            message,
            initial_offset + line_offset,
          )
      }
    } else if wgsl_directive_tail(trimmed, WgslDirectiveKind::DefineImportPath)
      is Some(raw_name) {
      let import_path = trim_trailing_semicolons(
        wgsl_metadata_first_space_separated_token(raw_name),
      )
      if import_path != "" {
        name = Some(import_path)
      }
    } else if wgsl_directive_tail(trimmed, WgslDirectiveKind::Define)
      is Some(raw_define) {
      if allow_defines {
        let (define_name, define_value) = split_define_name_and_value(
          raw_define,
        )
        if define_name != "" {
          defines.set(define_name, parse_define_value(define_value))
        }
      } else {
        raise MetadataError::DefineInModule(offset)
      }
    } else {
      collect_effective_def_names(line, effective_defs)
      ignore(
        substitute_identifiers(
          line, offset, declared_imports, used_imports, true,
        ) catch {
          AmbiguousImport(position) =>
            raise MetadataError::ImportParseError(
              "Ambiguous import path for item", position,
            )
        },
      )
    }

    offset = offset + line.length() + 1
    line_index = line_index + 1
  }

  PreprocessorMetaData::{
    name,
    imports: used_imports,
    defines,
    effective_defs,
    wgsl_directives,
    cleaned_source: cleaned_for_directives,
  }
}

///|
pub fn get_preprocessor_metadata(source : String) -> PreprocessorMetaData {
  try_get_preprocessor_metadata(source, true) catch {
    _ =>
      PreprocessorMetaData::{
        name: None,
        imports: [],
        defines: @hashmap.HashMap::new(),
        effective_defs: @hashset.HashSet::new(),
        wgsl_directives: WgslDirectives::default(),
        cleaned_source: source,
      }
  }
}

///|
pub fn get_preprocessor_data(
  source : String,
) -> (
  String?,
  Array[ImportDefinition],
  @hashmap.HashMap[String, ShaderDefValue],
) {
  let metadata = get_preprocessor_metadata(source)
  let imports : Array[ImportDefinition] = []
  for import_with_offset in metadata.imports {
    imports.push(import_with_offset.definition)
  }
  (metadata.name, imports, metadata.defines)
}

///|
