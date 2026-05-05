///|
fn preprocess_emit_pipeline_item(
  item : WgslDirectiveScanItem,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  import_state : WgslImportSubstitutionState,
  used_imports : Array[ImportDefWithOffset],
  scope : Scope,
) -> String raise PreprocessError {
  let offset = item.start()
  match item.kind() {
    WgslDirectiveScanItemKind::GlslVersion(version) => {
      if version != "440" && version != "450" {
        raise PreprocessError::GlslInvalidVersion(offset)
      }
      preprocess_emit_scanned_item(
        BlankTrivia,
        item,
        shader_defs,
        import_state,
        used_imports,
      )
    }
    WgslDirectiveScanItemKind::Directive(directive) => {
      let (is_scope, _) = preprocess_check_scope_directive(
        shader_defs,
        directive,
        item.requires_tail_space(),
        Some(scope),
        offset,
      )
      if is_scope ||
        (
          item.requires_tail_space() &&
          (
            directive.kind() == WgslDirectiveKind::DefineImportPath ||
            directive.kind() == WgslDirectiveKind::Define
          )
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
        item.requires_tail_space() &&
        directive.kind() == WgslDirectiveKind::Import {
        import_state.declare_imports(item.cleaned_directive_text()) catch {
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
    WgslDirectiveScanItemKind::Source =>
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
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> PreprocessOutput raise PreprocessError {
  let import_state = WgslImportSubstitutionState::default()
  let used_imports : Array[ImportDefWithOffset] = []
  let scope = Scope::new()
  let mut final_string = ""
  for item in parse_wgsl_directive_scan_items(source) {
    final_string = final_string +
      preprocess_emit_pipeline_item(
        item, shader_defs, import_state, used_imports, scope,
      )
  }

  scope.finish(utf8_byte_length(source))
  PreprocessOutput::new(final_string, used_imports)
}
