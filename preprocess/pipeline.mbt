///|
fn preprocess_emit_pipeline_item(
  item : WgslDirectiveScanItem,
  shader_defs : Map[String, ShaderDefValue],
  import_state : WgslImportSubstitutionState,
  used_imports : Array[ImportDefWithOffset],
  scope : Scope,
) -> String raise PreprocessError {
  let offset = item.start()
  match item.kind() {
    GlslVersion(version) => {
      if version != "440" && version != "450" {
        raise GlslInvalidVersion(offset)
      }
      preprocess_emit_scanned_item(
        BlankTrivia,
        item,
        shader_defs,
        import_state,
        used_imports,
      )
    }
    Directive(directive) => {
      let (is_scope, _) = preprocess_check_scope_directive(
        shader_defs,
        directive,
        Some(scope),
        offset,
      )
      if is_scope ||
        (
          directive.has_required_tail_separator() &&
          (directive.kind() == DefineImportPath || directive.kind() == Define)
        ) {
        return preprocess_emit_scanned_item(
          BlankTrivia,
          item,
          shader_defs,
          import_state,
          used_imports,
        )
      }
      if scope.active() &&
        directive.has_required_tail_separator() &&
        directive.kind() == Import {
        import_state.declare_imports(item.source().cleaned_text()) catch {
          Parse(message, item_offset) =>
            raise ImportParseError(message, offset + item_offset)
        }
        return preprocess_emit_scanned_item(
          BlankTrivia,
          item,
          shader_defs,
          import_state,
          used_imports,
        )
      }
      if scope.active() {
        preprocess_emit_scanned_item(
          RewriteActiveSource,
          item,
          shader_defs,
          import_state,
          used_imports,
        )
      } else {
        preprocess_emit_scanned_item(
          BlankTrivia,
          item,
          shader_defs,
          import_state,
          used_imports,
        )
      }
    }
    Source =>
      if scope.active() {
        preprocess_emit_scanned_item(
          RewriteActiveSource,
          item,
          shader_defs,
          import_state,
          used_imports,
        )
      } else {
        preprocess_emit_scanned_item(
          BlankTrivia,
          item,
          shader_defs,
          import_state,
          used_imports,
        )
      }
  }
}

///|
pub fn Preprocessor::preprocess(
  _self : Preprocessor,
  source : String,
  shader_defs : Map[String, ShaderDefValue],
) -> PreprocessOutput raise PreprocessError {
  let import_state = WgslImportSubstitutionState::default()
  let used_imports : Array[ImportDefWithOffset] = []
  let scope = Scope()
  let mut final_string = ""
  for item in parse_wgsl_directive_scan_items(source) {
    final_string = final_string +
      preprocess_emit_pipeline_item(
        item, shader_defs, import_state, used_imports, scope,
      )
  }

  scope.finish(utf8_byte_length(source))
  PreprocessOutput(final_string, used_imports)
}
