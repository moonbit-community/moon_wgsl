///|
fn parse_wgsl_declaration_data(text : String) -> WgslGlobalDeclData {
  WgslDeclParser::new(text).parse_decl_data()
}

///|
fn parse_wgsl_declaration_data_at(
  text : String,
  source_start : Int,
) -> WgslGlobalDeclData {
  WgslDeclParser::new_at(text, source_start).parse_decl_data()
}

///|
fn parse_wgsl_declaration_name(text : String) -> String {
  wgsl_decl_data_name(parse_wgsl_declaration_data(text))
}

///|
fn parse_wgsl_raw_global_decl(item : WgslRawTopLevelItem) -> WgslGlobalDecl {
  let data = match item.kind {
    WgslRawTopLevelKind::DefineImportPath | WgslRawTopLevelKind::Define =>
      match parse_wgsl_directive_line_at(item.text, item.start) {
        Some(directive) => WgslGlobalDeclData::Directive(directive)
        None => WgslGlobalDeclData::Raw
      }
    WgslRawTopLevelKind::Import =>
      match parse_wgsl_directive_line_at(item.text, item.start) {
        Some(directive) => WgslGlobalDeclData::Import(directive)
        None => WgslGlobalDeclData::Raw
      }
    WgslRawTopLevelKind::Directive =>
      match parse_wgsl_directive_line_at(item.text, item.start) {
        Some(directive) => WgslGlobalDeclData::Directive(directive)
        None => WgslGlobalDeclData::Raw
      }
    WgslRawTopLevelKind::Declaration =>
      parse_wgsl_declaration_data_at(item.text, item.start)
    WgslRawTopLevelKind::Trivia => WgslGlobalDeclData::Raw
  }
  let kind = match item.kind {
    WgslRawTopLevelKind::Trivia => WgslGlobalDeclKind::Trivia
    _ => wgsl_global_decl_kind_from_data(data)
  }
  WgslGlobalDecl::new(
    kind,
    data,
    if item.name == "" {
      wgsl_decl_data_name(data)
    } else {
      item.name
    },
    item.text,
    item.start,
    item.end,
  )
}

///|
fn parse_wgsl_raw_top_level_items(
  source : String,
) -> Array[WgslRawTopLevelItem] {
  let raw_items = parse_wgsl_top_level_items(source)
  let tokens : Array[(Token, Int, Int)] = []
  for item in raw_items {
    tokens.push((Token::ITEM(item), item.start, item.end))
  }
  tokens.push((Token::EOF, source.length(), source.length()))
  raw_top_level_items(tokens) catch {
    _ => raw_items
  }
}

///|
pub fn parse_wgsl_translation_unit(source : String) -> WgslTranslationUnit {
  let declarations : Array[WgslGlobalDecl] = []
  for item in parse_wgsl_raw_top_level_items(source) {
    declarations.push(parse_wgsl_raw_global_decl(item))
  }
  WgslTranslationUnit::new(declarations)
}
