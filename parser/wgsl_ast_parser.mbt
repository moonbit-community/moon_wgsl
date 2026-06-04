///|
fn parse_wgsl_declaration_data_at(
  text : String,
  source_start : Int,
) -> WgslGlobalDeclData raise WgslParseError {
  WgslDeclParser::new_at(text, source_start).parse_decl_data_checked() catch {
    _ => raise UnparsedDeclaration(text, source_start)
  }
}

///|
pub suberror WgslParseError {
  UnparsedDeclaration(String, Int)
}

///|
pub fn WgslParseError::message(self : WgslParseError) -> String {
  match self {
    UnparsedDeclaration(text, offset) =>
      "WGSL declaration could not be parsed at \{offset}: \{text}"
  }
}

///|
fn parse_wgsl_raw_global_decl_strict(
  source : String,
  item : WgslRawTopLevelItem,
) -> WgslGlobalDecl raise WgslParseError {
  let item_text = source[item.start:item.end].to_owned()
  let directive_text = replace_comments_naga_oil(item_text)
  let (kind, data) = match item.kind {
    DefineImportPath | Define =>
      match parse_wgsl_directive_line_at(directive_text, item.start) {
        Some(directive) =>
          (
            WgslGlobalDeclKind::Directive,
            WgslGlobalDeclData::Directive(directive),
          )
        None => raise UnparsedDeclaration(item_text, item.start)
      }
    Import =>
      match parse_wgsl_directive_line_at(directive_text, item.start) {
        Some(directive) => (Import, Import(directive))
        None => raise UnparsedDeclaration(item_text, item.start)
      }
    Directive =>
      match parse_wgsl_directive_line_at(directive_text, item.start) {
        Some(directive) => (Directive, Directive(directive))
        None => raise UnparsedDeclaration(item_text, item.start)
      }
    Declaration => {
      let data = parse_wgsl_declaration_data_at(item_text, item.start)
      (wgsl_global_decl_kind_from_data(data), data)
    }
    Trivia => (Trivia, Raw)
  }
  let declaration = WgslGlobalDecl(kind, data, item.start, item.end)
  match data {
    Function(function) =>
      if wgsl_function_has_invalid_statement_expression(function) {
        raise UnparsedDeclaration(item_text, item.start)
      } else {
        declaration
      }
    _ => declaration
  }
}

///|
fn wgsl_function_has_invalid_statement_expression(
  function : WgslFunction,
) -> Bool {
  wgsl_block_has_invalid_statement_expression(function.body())
}

///|
fn wgsl_block_has_invalid_statement_expression(block : WgslBlock) -> Bool {
  for statement in block.statements() {
    if statement.has_invalid_expression() {
      return true
    }
    for child in statement.blocks() {
      if wgsl_block_has_invalid_statement_expression(child) {
        return true
      }
    }
  }
  false
}

///|
pub fn parse_wgsl_translation_unit_strict(
  source : String,
) -> WgslTranslationUnit raise WgslParseError {
  let declarations : Array[WgslGlobalDecl] = []
  for item in parse_wgsl_top_level_items(source) {
    declarations.push(parse_wgsl_raw_global_decl_strict(source, item))
  }
  WgslTranslationUnit(declarations)
}
