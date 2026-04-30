///|
pub fn Preprocessor::extract_wgsl_directives(
  _self : Preprocessor,
  source : String,
) -> (String, WgslDirectives) raise PreprocessError {
  let directives = WgslDirectives::default()
  let cleaned_lines : Array[String] = []
  let mut in_directive_section = true
  let mut line_index = 0
  for line in source_lines(source) {
    let trimmed = line.trim().to_owned()

    if trimmed == "" || replace_comments(trimmed).trim().to_owned() == "" {
      cleaned_lines.push(line)
      line_index = line_index + 1
      continue
    }

    if in_directive_section {
      if semicolon_directive_body(trimmed, "enable") is Some(body) {
        let extensions = split_extensions(body)
        if extensions.is_empty() {
          raise PreprocessError::InvalidWgslDirective(
            trimmed, line_index, "No extensions specified",
          )
        }
        cleaned_lines.push("")
        directives.enables.push(EnableDirective::{
          extensions,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if semicolon_directive_body(trimmed, "requires") is Some(body) {
        let extensions = split_extensions(body)
        if extensions.is_empty() {
          raise PreprocessError::InvalidWgslDirective(
            trimmed, line_index, "No extensions specified",
          )
        }
        cleaned_lines.push("")
        directives.requires.push(RequiresDirective::{
          extensions,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if parse_diagnostic_directive_body(trimmed) is Some((severity, rule)) {
        if severity != "off" &&
          severity != "info" &&
          severity != "warn" &&
          severity != "error" {
          raise PreprocessError::InvalidWgslDirective(
            trimmed,
            line_index,
            "Invalid severity '\{severity}'. Must be one of: off, info, warn, error",
          )
        }
        cleaned_lines.push("")
        directives.diagnostics.push(DiagnosticDirective::{
          severity,
          rule,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      match wgsl_source_directive_keyword(trimmed) {
        Some("enable") | Some("requires") | Some("diagnostic") => ()
        _ => in_directive_section = false
      }
    }

    cleaned_lines.push(line)
    line_index = line_index + 1
  }

  let mut cleaned_source = ""
  for i in 0..<cleaned_lines.length() {
    if i > 0 {
      cleaned_source = "\{cleaned_source}\n"
    }
    cleaned_source = cleaned_source + cleaned_lines[i]
  }

  (cleaned_source, directives)
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
  for line_item in source_lines(replace_comments(source)) {
    decommented_lines.push(line_item)
  }

  let mut final_string = ""
  let mut offset = 0
  let mut line_index = 0
  while line_index < decommented_lines.length() {
    let mut line = decommented_lines[line_index]
    let original_line = original_lines[line_index]
    let mut output = false
    let trimmed = line.trim().to_owned()

    if parse_glsl_version_directive(trimmed) is Some(version) {
      if version != "440" && version != "450" {
        raise PreprocessError::GlslInvalidVersion(offset)
      }
    } else {
      let (is_scope, _) = check_scope(shader_defs, line, Some(scope), offset)
      if is_scope ||
        wgsl_directive_tail(trimmed, WgslDirectiveKind::DefineImportPath)
        is Some(_) ||
        wgsl_directive_tail(trimmed, WgslDirectiveKind::Define) is Some(_) {
        ()
      } else if scope.active() {
        if wgsl_directive_tail(trimmed, WgslDirectiveKind::Import) is Some(_) {
          let mut import_lines = ""
          let mut open_count = 0
          let initial_offset = offset
          while true {
            final_string = final_string + spaces(line.length())
            offset = offset + line.length() + 1
            open_count = open_count + import_brace_balance(line)
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
          let diff = line.length() - item_replaced_line.length()
          if diff > 0 {
            final_string = "\{final_string}\{spaces(diff)}"
          }
          offset = offset + original_line.length() + 1
          output = true
        }
      }
    }

    if !output {
      final_string = "\{final_string}\{spaces(line.length())}"
      offset = offset + line.length() + 1
    }
    final_string = "\{final_string}\n"
    line_index = line_index + 1
  }

  scope.finish(offset)
  PreprocessOutput::{ preprocessed_source: final_string, imports: used_imports }
}
