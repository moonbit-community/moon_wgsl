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
  let mut final_string = ""
  for item in parse_wgsl_preprocess_items(source) {
    let offset = item.start
    match item.kind {
      WgslPreprocessItemKind::GlslVersion(version) => {
        if version != "440" && version != "450" {
          raise PreprocessError::GlslInvalidVersion(offset)
        }
        final_string = final_string + preprocess_blank_text(item.original_text)
      }
      WgslPreprocessItemKind::Directive(directive) => {
        let (is_scope, _) = preprocess_check_scope_directive(
          shader_defs,
          directive,
          item.required_tail_space,
          Some(scope),
          offset,
        )
        if is_scope ||
          (
            item.required_tail_space &&
            (
              directive.kind == WgslDirectiveKind::DefineImportPath ||
              directive.kind == WgslDirectiveKind::Define
            )
          ) {
          final_string = final_string +
            preprocess_blank_text(item.original_text)
        } else if scope.active() &&
          item.required_tail_space &&
          directive.kind == WgslDirectiveKind::Import {
          parse_imports(item.cleaned_text, declared_imports) catch {
            Parse(message, item_offset) =>
              raise PreprocessError::ImportParseError(
                message,
                offset + item_offset,
              )
          }
          final_string = final_string +
            preprocess_blank_text(item.original_text)
        } else if scope.active() {
          final_string = final_string +
            preprocess_rewrite_source_item(
              item, shader_defs, declared_imports, used_imports,
            )
        } else {
          final_string = final_string +
            preprocess_blank_text(item.original_text)
        }
      }
      WgslPreprocessItemKind::Source =>
        if scope.active() {
          final_string = final_string +
            preprocess_rewrite_source_item(
              item, shader_defs, declared_imports, used_imports,
            )
        } else {
          final_string = final_string +
            preprocess_blank_text(item.original_text)
        }
    }
  }

  scope.finish(utf8_byte_length(source))
  PreprocessOutput::{ preprocessed_source: final_string, imports: used_imports }
}
