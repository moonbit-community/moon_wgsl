///|
fn WgslDeclParser::parse_function(
  self : WgslDeclParser,
  attributes : Array[WgslAttribute],
  qualifier : String,
  qualifier_start : Int?,
  qualifier_end : Int?,
  fn_keyword : WgslIdent,
) -> WgslFunction? {
  let name = if qualifier == "override" {
    match self.consume_path_ident_node() {
      Some(value) => value
      None => return None
    }
  } else {
    match self.consume_ident_node() {
      Some(value) => value
      None => return None
    }
  }
  let arguments = self.parse_function_arguments()
  let result = self.parse_function_result()
  let body = self.parse_block()
  Some(WgslFunction::{
    attributes,
    qualifier,
    qualifier_start,
    qualifier_end,
    fn_start: fn_keyword.start,
    fn_end: fn_keyword.end,
    name,
    arguments,
    result,
    body,
  })
}

///|
fn WgslDeclParser::parse_struct_members(
  self : WgslDeclParser,
) -> Array[WgslStructMember] {
  let members : Array[WgslStructMember] = []
  if !self.consume_if_other(123) {
    return members
  }
  while true {
    if self.consume_if_other(125) {
      break
    }
    let attributes = self.parse_attributes()
    match self.consume_ident_node() {
      Some(name_node) => {
        self.consume_if_other(58) |> ignore
        let ty_fragment = self.collect_until_top_level_fragment([44, 59, 125])
        let ty = ty_fragment.text
        members.push(WgslStructMember::{
          attributes,
          name: name_node.name,
          name_start: name_node.start,
          name_end: name_node.end,
          ty,
          ty_ref: parse_wgsl_type_ref_fragment(ty_fragment),
        })
      }
      None => ()
    }
    if self.consume_if_other(44) || self.consume_if_other(59) {
      continue
    }
    self.consume_if_other(125) |> ignore
    break
  }
  members
}

///|
fn WgslDeclParser::parse_struct(
  self : WgslDeclParser,
  attributes : Array[WgslAttribute],
) -> WgslStruct? {
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  Some(WgslStruct::{ attributes, name, members: self.parse_struct_members() })
}

///|
fn WgslDeclParser::parse_global_variable(
  self : WgslDeclParser,
  attributes : Array[WgslAttribute],
) -> WgslGlobalVariable? {
  let template_list = self.parse_template_list()
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let mut ty_ref : WgslTypeRef? = None
  let ty : String? = if self.consume_if_other(58) {
    let parsed = self.collect_until_top_level_fragment([61, 59])
    if parsed.text == "" {
      None
    } else {
      ty_ref = parse_wgsl_type_ref_fragment(parsed)
      Some(parsed.text)
    }
  } else {
    None
  }
  let (initializer, initializer_ref) = self.parse_optional_initializer()
  Some(WgslGlobalVariable::{
    attributes,
    name,
    template_list,
    ty,
    ty_ref,
    initializer,
    initializer_ref,
  })
}

///|
fn WgslDeclParser::parse_optional_initializer(
  self : WgslDeclParser,
) -> (String?, WgslExprRef?) {
  if !self.consume_if_other(61) {
    return (None, None)
  }
  let parsed = self.collect_until_top_level_fragment([59])
  if parsed.text == "" {
    (None, None)
  } else {
    (Some(parsed.text), parse_wgsl_expr_ref_fragment(parsed))
  }
}

///|
fn WgslDeclParser::parse_const(self : WgslDeclParser) -> WgslConst? {
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let mut ty_ref : WgslTypeRef? = None
  let ty : String? = if self.consume_if_other(58) {
    let parsed = self.collect_until_top_level_fragment([61, 59])
    if parsed.text == "" {
      None
    } else {
      ty_ref = parse_wgsl_type_ref_fragment(parsed)
      Some(parsed.text)
    }
  } else {
    None
  }
  let (initializer, initializer_ref) = self.parse_optional_initializer()
  Some(WgslConst::{ name, ty, ty_ref, initializer, initializer_ref })
}

///|
fn WgslDeclParser::parse_override(
  self : WgslDeclParser,
  attributes : Array[WgslAttribute],
) -> WgslOverride? {
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let mut ty_ref : WgslTypeRef? = None
  let ty : String? = if self.consume_if_other(58) {
    let parsed = self.collect_until_top_level_fragment([61, 59])
    if parsed.text == "" {
      None
    } else {
      ty_ref = parse_wgsl_type_ref_fragment(parsed)
      Some(parsed.text)
    }
  } else {
    None
  }
  let (initializer, initializer_ref) = self.parse_optional_initializer()
  Some(WgslOverride::{
    attributes,
    name,
    ty,
    ty_ref,
    initializer,
    initializer_ref,
  })
}

///|
fn WgslDeclParser::parse_type_alias(self : WgslDeclParser) -> WgslTypeAlias? {
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  self.consume_if_other(61) |> ignore
  let ty_fragment = self.collect_until_top_level_fragment([59])
  let ty = ty_fragment.text
  Some(WgslTypeAlias::{
    name,
    ty,
    ty_ref: parse_wgsl_type_ref_fragment(ty_fragment),
  })
}

///|
fn wgsl_source_directive_kind_from_keyword(name : String) -> WgslDirectiveKind? {
  match name {
    "enable" => Some(WgslDirectiveKind::Enable)
    "requires" => Some(WgslDirectiveKind::Requires)
    "diagnostic" => Some(WgslDirectiveKind::Diagnostic)
    _ => None
  }
}

///|
fn WgslDeclParser::parse_source_directive(
  self : WgslDeclParser,
  keyword : WgslIdent,
  kind : WgslDirectiveKind,
) -> WgslDirective {
  let tail = self.collect_until_top_level_fragment([59]).text
  WgslDirective::{
    kind,
    name: keyword.name,
    tail,
    text: self.source_text.trim().to_owned(),
  }
}

///|
fn WgslDeclParser::parse_decl_data(self : WgslDeclParser) -> WgslGlobalDeclData {
  let attributes = self.parse_attributes()
  match self.consume_ident_node() {
    Some(keyword) if keyword.name == "virtual" =>
      match self.consume_ident_node() {
        Some(fn_keyword) if fn_keyword.name == "fn" =>
          match
            self.parse_function(
              attributes,
              "virtual",
              Some(keyword.start),
              Some(keyword.end),
              fn_keyword,
            ) {
            Some(function) => WgslGlobalDeclData::Function(function)
            None => WgslGlobalDeclData::Raw
          }
        _ => WgslGlobalDeclData::Raw
      }
    Some(keyword) if keyword.name == "override" =>
      match self.view() {
        [Token::Identifier("fn", fn_pos), .. rest] => {
          self.update_view(rest)
          match
            self.parse_function(
              attributes,
              "override",
              Some(keyword.start),
              Some(keyword.end),
              WgslIdent::{ name: "fn", start: fn_pos, end: fn_pos + 2 },
            ) {
            Some(function) => WgslGlobalDeclData::Function(function)
            None => WgslGlobalDeclData::Raw
          }
        }
        _ =>
          match self.parse_override(attributes) {
            Some(value) => WgslGlobalDeclData::Override(value)
            None => WgslGlobalDeclData::Raw
          }
      }
    Some(keyword) if keyword.name == "fn" =>
      match self.parse_function(attributes, "", None, None, keyword) {
        Some(function) => WgslGlobalDeclData::Function(function)
        None => WgslGlobalDeclData::Raw
      }
    Some(keyword) if keyword.name == "var" =>
      match self.parse_global_variable(attributes) {
        Some(value) => WgslGlobalDeclData::GlobalVariable(value)
        None => WgslGlobalDeclData::Raw
      }
    Some(keyword) if keyword.name == "struct" =>
      match self.parse_struct(attributes) {
        Some(value) => WgslGlobalDeclData::Struct(value)
        None => WgslGlobalDeclData::Raw
      }
    Some(keyword) if keyword.name == "const" =>
      match self.parse_const() {
        Some(value) => WgslGlobalDeclData::Const(value)
        None => WgslGlobalDeclData::Raw
      }
    Some(keyword) if keyword.name == "const_assert" =>
      WgslGlobalDeclData::ConstAssert(
        parse_required_wgsl_expr_ref_fragment(
          self.collect_until_top_level_fragment([59]),
        ),
      )
    Some(keyword) if keyword.name == "alias" || keyword.name == "type" =>
      match self.parse_type_alias() {
        Some(value) => WgslGlobalDeclData::TypeAlias(value)
        None => WgslGlobalDeclData::Raw
      }
    Some(keyword) =>
      match wgsl_source_directive_kind_from_keyword(keyword.name) {
        Some(kind) =>
          WgslGlobalDeclData::Directive(
            self.parse_source_directive(keyword, kind),
          )
        None => WgslGlobalDeclData::Raw
      }
    _ => WgslGlobalDeclData::Raw
  }
}

///|
fn wgsl_global_decl_kind_from_data(
  data : WgslGlobalDeclData,
) -> WgslGlobalDeclKind {
  match data {
    Function(_) => WgslGlobalDeclKind::Function
    GlobalVariable(_) => WgslGlobalDeclKind::GlobalVariable
    Const(_) => WgslGlobalDeclKind::Const
    Override(_) => WgslGlobalDeclKind::Override
    Struct(_) => WgslGlobalDeclKind::Struct
    TypeAlias(_) => WgslGlobalDeclKind::TypeAlias
    ConstAssert(_) => WgslGlobalDeclKind::ConstAssert
    Directive(_) => WgslGlobalDeclKind::Directive
    Import(_) => WgslGlobalDeclKind::Import
    Raw => WgslGlobalDeclKind::Unknown
  }
}

///|
