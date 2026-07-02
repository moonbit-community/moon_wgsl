///|
fn try_get_preprocessor_metadata(
  source : String,
  allow_defines : Bool,
  collect_import_uses : Bool,
) -> PreprocessorMetaData raise MetadataError {
  let (cleaned_for_directives, wgsl_directives) = extract_wgsl_directives(
    source,
  )

  let import_state = WgslImportSubstitutionState::default()
  let used_imports : Array[ImportDefWithOffset] = []
  let defines : Map[String, ShaderDefValue] = Map([])
  let effective_defs : @set.Set[String] = Set([])
  let mut name : String? = None

  for
    item in parse_wgsl_directive_scan_items(
      cleaned_for_directives,
      include_glsl_version=false,
    ) {
    match item.kind() {
      Directive(directive) => {
        let (is_scope, def) = metadata_scope_def_from_directive(directive)
        if is_scope {
          if def is Some(def_name) {
            effective_defs.add(def_name)
          }
        } else if directive.has_required_tail_separator() &&
          directive.kind() == Import {
          import_state.declare_imports(item.source().cleaned_text()) catch {
            Parse(message, item_offset) =>
              raise ImportParseError(message, item.start() + item_offset)
          }
        } else if directive.has_required_tail_separator() &&
          directive.kind() == DefineImportPath {
          let import_path = wgsl_metadata_first_space_separated_token(
            directive.tail(),
          )
          if import_path != "" {
            name = Some(import_path)
          }
        } else if directive.has_required_tail_separator() &&
          directive.kind() == Define {
          if allow_defines {
            let (define_name, define_value) = split_define_name_and_value(
              directive.tail(),
            )
            if define_name != "" {
              defines.set(define_name, parse_define_value(define_value))
            }
          } else {
            raise DefineInModule(item.start())
          }
        } else {
          metadata_collect_source_item(item, effective_defs)
        }
      }
      Source => metadata_collect_source_item(item, effective_defs)
      GlslVersion(_) => ()
    }
  }
  if collect_import_uses {
    metadata_collect_import_uses(
      cleaned_for_directives, import_state, used_imports,
    )
  }

  PreprocessorMetaData(
    name, used_imports, defines, effective_defs, wgsl_directives, cleaned_for_directives,
  )
}

///|
pub fn get_preprocessor_metadata(
  source : String,
  allow_defines? : Bool = true,
  collect_import_uses? : Bool = true,
) -> PreprocessorMetaData raise MetadataError {
  try_get_preprocessor_metadata(source, allow_defines, collect_import_uses)
}

///|
fn wgsl_metadata_skip_whitespace(line : String, start : Int) -> Int {
  let mut index = start
  while index < line.length() {
    let width = wgsl_regex_whitespace_width(line, index)
    guard width > 0 else { break }
    index = index + width
  }
  index
}

///|
fn wgsl_metadata_has_word_at(
  line : String,
  start : Int,
  word : String,
) -> Bool {
  guard start + word.length() <= line.length() else { return false }
  for i in 0..<word.length() {
    if line.code_unit_at(start + i).to_int() != word.code_unit_at(i).to_int() {
      return false
    }
  }
  let end_ = start + word.length()
  end_ >= line.length() || wgsl_regex_word_width(line, end_) == 0
}

///|
fn wgsl_metadata_line_may_define_shader_def(line : String) -> Bool {
  let hash_start = wgsl_metadata_skip_whitespace(line, 0)
  guard hash_start < line.length() &&
    line.code_unit_at(hash_start).to_int() == 35 else {
    return false
  }
  let name_start = wgsl_metadata_skip_whitespace(line, hash_start + 1)
  wgsl_metadata_has_word_at(line, name_start, "define")
}

///|
fn wgsl_metadata_source_may_define_shader_def(source : String) -> Bool {
  for line in source.split("\n") {
    if wgsl_metadata_line_may_define_shader_def(line.to_owned()) {
      return true
    }
  }
  false
}

///|
pub fn collect_wgsl_source_local_shader_defines(
  source : String,
) -> Map[String, ShaderDefValue] {
  let defines : Map[String, ShaderDefValue] = Map([])
  if !wgsl_metadata_source_may_define_shader_def(source) {
    return defines
  }
  for
    item in parse_wgsl_directive_scan_items(source, include_glsl_version=false) {
    match item.kind() {
      Directive(directive) =>
        if directive.has_required_tail_separator() && directive.kind() == Define {
          let (define_name, define_value) = split_define_name_and_value(
            directive.tail(),
          )
          if define_name != "" {
            defines.set(define_name, parse_define_value(define_value))
          }
        }
      _ => ()
    }
  }
  defines
}
