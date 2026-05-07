///|
fn parse_wgsl_declaration_data_at(
  text : String,
  source_start : Int,
) -> WgslGlobalDeclData raise WgslParseError {
  WgslDeclParser::new_at(text, source_start).parse_decl_data_checked() catch {
    _ => raise WgslParseError::UnparsedDeclaration(text, source_start)
  }
}

///|
pub suberror WgslParseError {
  Parse(String, Int)
  UnparsedDeclaration(String, Int)
}

///|
pub fn WgslParseError::message(self : WgslParseError) -> String {
  match self {
    Parse(message, offset) => "WGSL parse error at \{offset}: \{message}"
    UnparsedDeclaration(text, offset) =>
      "WGSL declaration could not be parsed at \{offset}: \{text}"
  }
}

///|
fn wgsl_parse_error_from_generated(error : ParseError) -> WgslParseError {
  match error {
    UnexpectedToken(_, (start, _), _) =>
      WgslParseError::Parse("unexpected token", start)
    UnexpectedEndOfInput(pos, _) =>
      WgslParseError::Parse("unexpected end of input", pos)
  }
}

///|
fn parse_wgsl_raw_top_level_items_strict(
  source : String,
) -> Array[WgslRawTopLevelItem] raise WgslParseError {
  let raw_items = parse_wgsl_top_level_items(source)
  let tokens : Array[(Token, Int, Int)] = []
  for item in raw_items {
    tokens.push((Token::ITEM(item), item.start, item.end))
  }
  tokens.push((Token::EOF, source.length(), source.length()))
  raw_top_level_items(tokens) catch {
    error => raise wgsl_parse_error_from_generated(error)
  }
}

///|
fn parse_wgsl_raw_global_decl_strict(
  item : WgslRawTopLevelItem,
) -> WgslGlobalDecl raise WgslParseError {
  let directive_text = replace_comments_naga_oil(item.text)
  let (kind, data) = match item.kind {
    WgslRawTopLevelKind::DefineImportPath | WgslRawTopLevelKind::Define =>
      match parse_wgsl_directive_line_at(directive_text, item.start) {
        Some(directive) =>
          (
            WgslGlobalDeclKind::Directive,
            WgslGlobalDeclData::Directive(directive),
          )
        None => raise WgslParseError::UnparsedDeclaration(item.text, item.start)
      }
    WgslRawTopLevelKind::Import =>
      match parse_wgsl_directive_line_at(directive_text, item.start) {
        Some(directive) =>
          (WgslGlobalDeclKind::Import, WgslGlobalDeclData::Import(directive))
        None => raise WgslParseError::UnparsedDeclaration(item.text, item.start)
      }
    WgslRawTopLevelKind::Directive =>
      match parse_wgsl_directive_line_at(directive_text, item.start) {
        Some(directive) =>
          (
            WgslGlobalDeclKind::Directive,
            WgslGlobalDeclData::Directive(directive),
          )
        None => raise WgslParseError::UnparsedDeclaration(item.text, item.start)
      }
    WgslRawTopLevelKind::Declaration => {
      let data = parse_wgsl_declaration_data_at(item.text, item.start)
      (wgsl_global_decl_kind_from_data(data), data)
    }
    WgslRawTopLevelKind::Trivia =>
      (WgslGlobalDeclKind::Trivia, WgslGlobalDeclData::Raw)
  }
  let declaration = WgslGlobalDecl(kind, data, item.start, item.end)
  match data {
    WgslGlobalDeclData::Function(function) =>
      if wgsl_function_has_invalid_statement_expression(function) {
        raise WgslParseError::UnparsedDeclaration(item.text, item.start)
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
  for item in parse_wgsl_raw_top_level_items_strict(source) {
    declarations.push(parse_wgsl_raw_global_decl_strict(item))
  }
  WgslTranslationUnit(declarations)
}
