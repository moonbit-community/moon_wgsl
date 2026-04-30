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
    let trimmed = wgsl_regex_trim_whitespace(line)
    let (is_scope, def) = metadata_scope_def(line)

    if is_scope {
      if def is Some(def_name) {
        effective_defs.add(def_name)
      }
    } else if metadata_required_space_directive_tail(trimmed, "import")
      is Some(_) {
      let mut import_lines = "\{line}\n"
      let mut open_count = naga_oil_raw_import_brace_balance_next(0, line)
      let initial_offset = offset

      while open_count > 0 && line_index + 1 < lines.length() {
        line_index = line_index + 1
        let next_line = lines[line_index]
        import_lines = "\{import_lines}\{next_line}\n"
        open_count = naga_oil_raw_import_brace_balance_next(
          open_count, next_line,
        )
        offset = offset + next_line.length() + 1
      }

      parse_imports(import_lines, declared_imports) catch {
        Parse(message, line_offset) =>
          raise MetadataError::ImportParseError(
            message,
            initial_offset + line_offset,
          )
      }
    } else if metadata_required_space_directive_tail(
        trimmed, "define_import_path",
      )
      is Some(raw_name) {
      let import_path = wgsl_metadata_first_space_separated_token(raw_name)
      if import_path != "" {
        name = Some(import_path)
      }
    } else if metadata_required_space_directive_tail(trimmed, "define")
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
pub fn get_preprocessor_metadata(
  source : String,
  allow_defines? : Bool = true,
) -> PreprocessorMetaData raise MetadataError {
  try_get_preprocessor_metadata(source, allow_defines)
}
