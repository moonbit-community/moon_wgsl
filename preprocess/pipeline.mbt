///|
pub fn Preprocessor::extract_wgsl_directives(
  _self : Preprocessor,
  source : String,
) -> (String, WgslDirectives) raise PreprocessError {
  extract_wgsl_directives(source) catch {
    InvalidWgslDirective(line, line_index, message) =>
      raise PreprocessError::InvalidWgslDirective(line, line_index, message)
    ImportParseError(message, offset) =>
      raise PreprocessError::ImportParseError(message, offset)
    DefineInModule(offset) => raise PreprocessError::DefineInModule(offset)
  }
}

///|
pub fn Preprocessor::preprocess(
  _self : Preprocessor,
  source : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> PreprocessOutput raise PreprocessError {
  let declared_imports : Array[DeclaredImportBinding] = []
  let used_imports : Array[ImportDefWithOffset] = []
  let scope = Scope::new()
  let original_lines : Array[String] = []
  let decommented_lines : Array[String] = []
  for line_item in source_lines(source) {
    original_lines.push(line_item)
  }
  for line_item in source_lines(replace_comments_naga_oil(source)) {
    decommented_lines.push(line_item)
  }

  let mut final_string = ""
  let mut offset = 0
  let mut line_index = 0
  while line_index < decommented_lines.length() {
    let mut line = decommented_lines[line_index]
    let original_line = original_lines[line_index]
    let mut output = false
    let trimmed = wgsl_regex_trim_whitespace(line)

    if check_glsl_version_directive(trimmed, offset) {
      ()
    } else {
      let (is_scope, _) = check_scope(shader_defs, line, Some(scope), offset)
      if is_scope ||
        required_space_directive_tail(trimmed, "define_import_path") is Some(_) ||
        required_space_directive_tail(trimmed, "define") is Some(_) {
        ()
      } else if scope.active() {
        if required_space_directive_tail(trimmed, "import") is Some(_) {
          let mut import_lines = ""
          let mut open_count = 0
          let initial_offset = offset
          while true {
            final_string = final_string + spaces(utf8_byte_length(line))
            offset = offset + utf8_byte_length(line) + 1
            open_count = naga_oil_raw_import_brace_balance_next(
              open_count, line,
            )
            import_lines = "\{import_lines}\{line}\n"
            if open_count == 0 || line_index + 1 >= decommented_lines.length() {
              break
            }
            final_string = "\{final_string}\n"
            line_index = line_index + 1
            line = decommented_lines[line_index]
          }
          parse_imports(import_lines, declared_imports) catch {
            Parse(message, line_offset) =>
              raise PreprocessError::ImportParseError(
                message,
                initial_offset + line_offset,
              )
          }
          output = true
        } else {
          let replaced_original = replace_shader_defs_in_line(
            original_line, shader_defs,
          )
          let replaced_decommented = replace_shader_defs_in_line(
            line, shader_defs,
          )
          let ignored_imports : Array[ImportDefWithOffset] = []
          let item_replaced_line = substitute_identifiers(
            replaced_original, offset, declared_imports, ignored_imports, true,
          ) catch {
            AmbiguousImport(position) =>
              raise PreprocessError::ImportParseError(
                "Ambiguous import path for item", position,
              )
          }
          ignore(
            substitute_identifiers(
              replaced_decommented, offset, declared_imports, used_imports, false,
            ) catch {
              AmbiguousImport(position) =>
                raise PreprocessError::ImportParseError(
                  "Ambiguous import path for item", position,
                )
            },
          )
          final_string = "\{final_string}\{item_replaced_line}"
          let diff = utf8_byte_length(line) -
            utf8_byte_length(item_replaced_line)
          if diff > 0 {
            final_string = "\{final_string}\{spaces(diff)}"
          }
          offset = offset + utf8_byte_length(original_line) + 1
          output = true
        }
      }
    }

    if !output {
      final_string = "\{final_string}\{spaces(utf8_byte_length(line))}"
      offset = offset + utf8_byte_length(line) + 1
    }
    final_string = "\{final_string}\n"
    line_index = line_index + 1
  }

  scope.finish(offset)
  PreprocessOutput::{ preprocessed_source: final_string, imports: used_imports }
}
