///|
fn parse_wgsl_declaration_data(text : String) -> WgslGlobalDeclData {
  WgslDeclParser::new(text).parse_decl_data()
}

///|
fn parse_wgsl_declaration_name(text : String) -> String {
  wgsl_decl_data_name(parse_wgsl_declaration_data(text))
}

///|
priv struct WgslAstParser {
  mut item_view : ArrayView[WgslTopLevelItem]
}

///|
fn WgslAstParser::new(source : String) -> WgslAstParser {
  let items = parse_wgsl_top_level_items(source)
  WgslAstParser::{ item_view: items[:] }
}

///|
fn WgslAstParser::view(self : WgslAstParser) -> ArrayView[WgslTopLevelItem] {
  self.item_view
}

///|
fn WgslAstParser::update_view(
  self : WgslAstParser,
  view : ArrayView[WgslTopLevelItem],
) -> Unit {
  self.item_view = view
}

///|
fn WgslAstParser::parse_global_decl(
  _self : WgslAstParser,
  item : WgslTopLevelItem,
) -> WgslGlobalDecl {
  let data = match item.kind {
    WgslTopLevelKind::DefineImportPath | WgslTopLevelKind::Define =>
      match parse_wgsl_directive_line(item.text) {
        Some(directive) => WgslGlobalDeclData::Directive(directive)
        None => WgslGlobalDeclData::Raw
      }
    WgslTopLevelKind::Import =>
      match parse_wgsl_directive_line(item.text) {
        Some(directive) => WgslGlobalDeclData::Import(directive)
        None => WgslGlobalDeclData::Raw
      }
    WgslTopLevelKind::Directive =>
      match parse_wgsl_directive_line(item.text) {
        Some(directive) => WgslGlobalDeclData::Directive(directive)
        None => WgslGlobalDeclData::Raw
      }
    WgslTopLevelKind::Declaration => parse_wgsl_declaration_data(item.text)
    _ => WgslGlobalDeclData::Raw
  }
  let kind = match item.kind {
    WgslTopLevelKind::Trivia => WgslGlobalDeclKind::Trivia
    _ => wgsl_global_decl_kind_from_data(data)
  }
  WgslGlobalDecl::{
    kind,
    data,
    name: if item.name == "" {
      wgsl_decl_data_name(data)
    } else {
      item.name
    },
    text: item.text,
    start: item.start,
    end: item.end,
  }
}

///|
fn WgslAstParser::parse_translation_unit(
  self : WgslAstParser,
) -> WgslTranslationUnit {
  let declarations : Array[WgslGlobalDecl] = []
  while true {
    match self.view() {
      [item, .. rest] => {
        declarations.push(self.parse_global_decl(item))
        self.update_view(rest)
        continue
      }
      [] => break
    }
  }
  WgslTranslationUnit::{ declarations, }
}

///|
pub fn parse_wgsl_translation_unit(source : String) -> WgslTranslationUnit {
  WgslAstParser::new(source).parse_translation_unit()
}
