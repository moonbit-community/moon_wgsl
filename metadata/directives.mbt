///|
fn split_extensions(raw : String) -> Array[String] {
  let extensions : Array[String] = []
  for part in raw.split(",") {
    let extension = wgsl_regex_trim_whitespace(part.to_owned())
    if extension != "" {
      extensions.push(extension)
    }
  }
  extensions
}

///|
fn collect_effective_def_names(
  line : String,
  effective_defs : @hashset.HashSet[String],
) -> Unit {
  for reference in parse_wgsl_shader_def_references(line) {
    effective_defs.add(reference.name())
  }
}

///|
fn parse_define_value(raw_value : String) -> ShaderDefValue {
  let value = trim_trailing_semicolons(raw_value)
  if value == "" {
    return ShaderDefValue::Bool(true)
  }
  if value == "true" {
    return ShaderDefValue::Bool(true)
  }
  if value == "false" {
    return ShaderDefValue::Bool(false)
  }
  let parsed_unsigned = @string.parse_uint(value[:], base=10) catch {
    _ => {
      let parsed = @string.parse_int(value[:], base=10) catch {
        _ => return ShaderDefValue::Bool(false)
      }
      return ShaderDefValue::Int(parsed)
    }
  }
  ShaderDefValue::UInt(parsed_unsigned)
}

///|
fn split_define_name_and_value(text : String) -> (String, String) {
  let trimmed = wgsl_regex_trim_whitespace(text)
  if trimmed == "" {
    return ("", "")
  }
  let mut i = 0
  while i < trimmed.length() {
    let width = wgsl_regex_word_width(trimmed, i)
    guard width > 0 else { break }
    i = i + width
  }
  if i == 0 {
    return ("", "")
  }
  let name = trimmed[0:i].to_owned()
  while i < trimmed.length() {
    if wgsl_regex_whitespace_code_point(trimmed.code_unit_at(i).to_int()) {
      i = i + 1
      continue
    }
    break
  }
  let value_start = i
  while i < trimmed.length() {
    let code = trimmed.code_unit_at(i).to_int()
    if code == 45 {
      i = i + 1
      continue
    }
    let width = wgsl_regex_word_width(trimmed, i)
    guard width > 0 else { break }
    i = i + width
  }
  (name, trimmed[value_start:i].to_owned())
}

///|
pub fn extract_wgsl_directives(
  source : String,
) -> (String, WgslDirectives) raise MetadataError {
  let directives = WgslDirectives::default()
  let cleaned_lines : Array[String] = []
  let mut in_directive_section = true
  let mut line_index = 0
  for item in parse_wgsl_source_directive_items(source) {
    let line = item.line
    let trimmed = wgsl_regex_trim_whitespace(line)

    match item.kind {
      WgslSourceDirectiveItemKind::Trivia => {
        cleaned_lines.push(line)
        line_index = line_index + 1
        continue
      }
      _ => ()
    }

    if in_directive_section {
      match item.kind {
        WgslSourceDirectiveItemKind::Enable(body) => {
          let extensions = split_extensions(body)
          if extensions.is_empty() {
            raise MetadataError::InvalidWgslDirective(
              trimmed, line_index, "No extensions specified",
            )
          }
          cleaned_lines.push("")
          directives.enables.push(EnableDirective::new(extensions))
          line_index = line_index + 1
          continue
        }
        WgslSourceDirectiveItemKind::Requires(body) => {
          let extensions = split_extensions(body)
          if extensions.is_empty() {
            raise MetadataError::InvalidWgslDirective(
              trimmed, line_index, "No extensions specified",
            )
          }
          cleaned_lines.push("")
          directives.requires.push(RequiresDirective::new(extensions))
          line_index = line_index + 1
          continue
        }
        WgslSourceDirectiveItemKind::Diagnostic(severity, rule) => {
          if severity != "off" &&
            severity != "info" &&
            severity != "warn" &&
            severity != "error" {
            raise MetadataError::InvalidWgslDirective(
              trimmed,
              line_index,
              "Invalid severity '\{severity}'. Must be one of: off, info, warn, error",
            )
          }
          cleaned_lines.push("")
          directives.diagnostics.push(DiagnosticDirective::new(severity, rule))
          line_index = line_index + 1
          continue
        }
        WgslSourceDirectiveItemKind::PrefixCandidate => ()
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
