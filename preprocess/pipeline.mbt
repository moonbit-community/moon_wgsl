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
fn preprocess_emit_pipeline_item(
  item : WgslDirectiveScanItem,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  declared_imports : Array[DeclaredImportBinding],
  used_imports : Array[ImportDefWithOffset],
  scope : Scope,
) -> String raise PreprocessError {
  let offset = item.start
  match item.kind {
    WgslDirectiveScanItemKind::GlslVersion(version) => {
      if version != "440" && version != "450" {
        raise PreprocessError::GlslInvalidVersion(offset)
      }
      preprocess_emit_scanned_item(
        BlankTrivia,
        item,
        shader_defs,
        declared_imports,
        used_imports,
      )
    }
    WgslDirectiveScanItemKind::Directive(directive) => {
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
        return preprocess_emit_scanned_item(
          BlankTrivia,
          item,
          shader_defs,
          declared_imports,
          used_imports,
        )
      }
      if scope.active() &&
        item.required_tail_space &&
        directive.kind == WgslDirectiveKind::Import {
        parse_imports(item.cleaned_text, declared_imports) catch {
          Parse(message, item_offset) =>
            raise PreprocessError::ImportParseError(
              message,
              offset + item_offset,
            )
        }
        return preprocess_emit_scanned_item(
          BlankTrivia,
          item,
          shader_defs,
          declared_imports,
          used_imports,
        )
      }
      if scope.active() {
        preprocess_emit_scanned_item(
          RewriteActiveSource,
          item,
          shader_defs,
          declared_imports,
          used_imports,
        )
      } else {
        preprocess_emit_scanned_item(
          BlankTrivia,
          item,
          shader_defs,
          declared_imports,
          used_imports,
        )
      }
    }
    WgslDirectiveScanItemKind::Source =>
      if scope.active() {
        preprocess_emit_scanned_item(
          RewriteActiveSource,
          item,
          shader_defs,
          declared_imports,
          used_imports,
        )
      } else {
        preprocess_emit_scanned_item(
          BlankTrivia,
          item,
          shader_defs,
          declared_imports,
          used_imports,
        )
      }
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
  for item in parse_wgsl_directive_scan_items(source) {
    final_string = final_string +
      preprocess_emit_pipeline_item(
        item, shader_defs, declared_imports, used_imports, scope,
      )
  }

  scope.finish(utf8_byte_length(source))
  PreprocessOutput::{ preprocessed_source: final_string, imports: used_imports }
}
