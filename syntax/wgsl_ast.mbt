///|
pub(all) enum WgslGlobalDeclKind {
  Directive
  Import
  Function
  GlobalVariable
  Const
  Override
  Struct
  TypeAlias
  ConstAssert
  Trivia
  Unknown
} derive(Eq, Debug)

///|
pub(all) struct WgslGlobalDecl {
  kind : WgslGlobalDeclKind
  name : String
  text : String
  start : Int
  end : Int
}

///|
pub(all) struct WgslTranslationUnit {
  declarations : Array[WgslGlobalDecl]
}

///|
fn wgsl_decl_text_after_attributes(trimmed : String) -> String {
  let mut i = 0
  while i < trimmed.length() {
    while i < trimmed.length() {
      let code = trimmed.code_unit_at(i).to_int()
      if code == 32 || code == 9 {
        i = i + 1
      } else {
        break
      }
    }
    if i >= trimmed.length() || trimmed.code_unit_at(i).to_int() != 64 {
      break
    }
    i = i + 1
    while i < trimmed.length() &&
          top_level_identifier_char(trimmed.code_unit_at(i).to_int()) {
      i = i + 1
    }
    while i < trimmed.length() {
      let code = trimmed.code_unit_at(i).to_int()
      if code == 32 || code == 9 {
        i = i + 1
      } else {
        break
      }
    }
    if i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 40 {
      let mut depth = 1
      i = i + 1
      while i < trimmed.length() && depth > 0 {
        let code = trimmed.code_unit_at(i).to_int()
        if code == 40 {
          depth = depth + 1
        } else if code == 41 {
          depth = depth - 1
        }
        i = i + 1
      }
    }
  }
  if i >= trimmed.length() {
    ""
  } else {
    trimmed[i:trimmed.length()].to_owned()
  }
}

///|
fn wgsl_global_decl_kind_from_declaration_text(
  text : String,
) -> WgslGlobalDeclKind {
  let trimmed = replace_comments(text).trim().to_owned()
  if starts_with_text(trimmed, "@") {
    return wgsl_global_decl_kind_from_declaration_text(
      wgsl_decl_text_after_attributes(trimmed),
    )
  }
  if starts_with_text(trimmed, "fn ") ||
    starts_with_text(trimmed, "virtual fn ") ||
    starts_with_text(trimmed, "override fn ") {
    return WgslGlobalDeclKind::Function
  }
  if starts_with_text(trimmed, "var") {
    return WgslGlobalDeclKind::GlobalVariable
  }
  if starts_with_text(trimmed, "const_assert ") ||
    starts_with_text(trimmed, "const_assert(") {
    return WgslGlobalDeclKind::ConstAssert
  }
  if starts_with_text(trimmed, "const ") {
    return WgslGlobalDeclKind::Const
  }
  if starts_with_text(trimmed, "override ") {
    return WgslGlobalDeclKind::Override
  }
  if starts_with_text(trimmed, "struct ") {
    return WgslGlobalDeclKind::Struct
  }
  if starts_with_text(trimmed, "alias ") || starts_with_text(trimmed, "type ") {
    return WgslGlobalDeclKind::TypeAlias
  }
  WgslGlobalDeclKind::Unknown
}

///|
fn wgsl_global_decl_kind_from_top_level_item(
  item : WgslTopLevelItem,
) -> WgslGlobalDeclKind {
  match item.kind {
    WgslTopLevelKind::Trivia => WgslGlobalDeclKind::Trivia
    WgslTopLevelKind::Import => WgslGlobalDeclKind::Import
    WgslTopLevelKind::DefineImportPath | WgslTopLevelKind::Define =>
      WgslGlobalDeclKind::Directive
    WgslTopLevelKind::Declaration =>
      wgsl_global_decl_kind_from_declaration_text(item.text)
  }
}

///|
pub fn parse_wgsl_translation_unit(source : String) -> WgslTranslationUnit {
  let declarations : Array[WgslGlobalDecl] = []
  for item in parse_wgsl_top_level_items(source) {
    declarations.push(WgslGlobalDecl::{
      kind: wgsl_global_decl_kind_from_top_level_item(item),
      name: item.name,
      text: item.text,
      start: item.start,
      end: item.end,
    })
  }
  WgslTranslationUnit::{ declarations, }
}
