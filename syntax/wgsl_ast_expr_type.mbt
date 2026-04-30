///|
fn wgsl_ast_token_end(token : Token) -> Int {
  match token {
    Token::Identifier(text, pos) | Token::Whitespace(text, pos) =>
      pos + text.length()
    Token::Other(_, pos) => pos + 1
  }
}

///|
fn parse_wgsl_expr_ref_text(text : String, base : Int) -> WgslExprRef? {
  let (trimmed, local_start, local_end) = wgsl_trim_fragment_bounds(
    text,
    0,
    text.length(),
  )
  if trimmed == "" {
    return None
  }
  let identifiers : Array[WgslIdent] = []
  for token in tokenize(replace_comments(trimmed), false) {
    match token {
      Token::Identifier(name, pos) =>
        identifiers.push(WgslIdent::{
          name,
          start: base + local_start + pos,
          end: base + local_start + pos + name.length(),
        })
      _ => ()
    }
  }
  Some(WgslExprRef::{
    text: trimmed,
    identifiers,
    start: base + local_start,
    end: base + local_end,
  })
}

///|
fn parse_wgsl_expr_ref_fragment(fragment : WgslTextFragment) -> WgslExprRef? {
  if fragment.start < 0 || fragment.end < fragment.start {
    return None
  }
  parse_wgsl_expr_ref_text(fragment.text, fragment.start)
}

///|
fn parse_required_wgsl_expr_ref_fragment(
  fragment : WgslTextFragment,
) -> WgslExprRef {
  match parse_wgsl_expr_ref_fragment(fragment) {
    Some(expr) => expr
    None =>
      WgslExprRef::{
        text: fragment.text,
        identifiers: [],
        start: fragment.start,
        end: fragment.end,
      }
  }
}

///|
priv struct WgslDeclParser {
  source_text : String
  mut token_view : ArrayView[Token]
}

///|
priv struct WgslTextFragment {
  text : String
  start : Int
  end : Int
}

///|
fn WgslDeclParser::new(text : String) -> WgslDeclParser {
  let tokens = tokenize(replace_comments(text), false)
  WgslDeclParser::{ source_text: text, token_view: tokens[:] }
}

///|
fn WgslDeclParser::view(self : WgslDeclParser) -> ArrayView[Token] {
  self.token_view
}

///|
fn WgslDeclParser::update_view(
  self : WgslDeclParser,
  view : ArrayView[Token],
) -> Unit {
  self.token_view = view
}

///|
fn WgslDeclParser::consume_if_other(self : WgslDeclParser, code : Int) -> Bool {
  match self.view() {
    [Token::Other(actual, _), .. rest] if actual == code => {
      self.update_view(rest)
      true
    }
    _ => false
  }
}

///|
fn WgslDeclParser::consume_ident_node(self : WgslDeclParser) -> WgslIdent? {
  match self.view() {
    [Token::Identifier(name, pos), .. rest] => {
      self.update_view(rest)
      Some(WgslIdent::{ name, start: pos, end: pos + name.length() })
    }
    _ => None
  }
}

///|
fn WgslDeclParser::consume_path_ident_node(self : WgslDeclParser) -> WgslIdent? {
  let first = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let mut name = first.name
  let mut end = first.end
  while true {
    match self.view() {
      [
        Token::Other(58, _),
        Token::Other(58, _),
        Token::Identifier(segment, segment_pos),
        .. rest,
      ] => {
        name = name + "::" + segment
        end = segment_pos + segment.length()
        self.update_view(rest)
      }
      _ => break
    }
  }
  Some(WgslIdent::{ name, start: first.start, end })
}

///|
fn WgslDeclParser::parse_attributes(
  self : WgslDeclParser,
) -> Array[WgslAttribute] {
  let attributes : Array[WgslAttribute] = []
  while true {
    match self.view() {
      [Token::Other(64, _), Token::Identifier(name, _), .. rest] => {
        self.update_view(rest)
        let mut arguments = ""
        let mut arguments_ref : WgslExprRef? = None
        match self.view() {
          [Token::Other(40, open_pos), .. token_rest] => {
            self.update_view(token_rest)
            let arg_start = open_pos + 1
            let mut arg_end = arg_start
            let mut depth = 1
            while depth > 0 {
              match self.view() {
                [Token::Other(40, _), .. nested_rest] => {
                  depth = depth + 1
                  self.update_view(nested_rest)
                  continue
                }
                [Token::Other(41, close_pos), .. nested_rest] => {
                  depth = depth - 1
                  self.update_view(nested_rest)
                  if depth == 0 {
                    arg_end = close_pos
                    break
                  }
                  continue
                }
                [_, .. nested_rest] => {
                  self.update_view(nested_rest)
                  continue
                }
                [] => break
              }
            }
            if arg_end >= arg_start {
              arguments = self.source_text[arg_start:arg_end].to_owned()
              arguments_ref = parse_wgsl_expr_ref_text(arguments, arg_start)
            }
          }
          _ => ()
        }
        attributes.push(WgslAttribute::{ name, arguments, arguments_ref })
        continue
      }
      _ => break
    }
  }
  attributes
}

///|
fn WgslDeclParser::collect_until_top_level_fragment(
  self : WgslDeclParser,
  stops : Array[Int],
) -> WgslTextFragment {
  let mut start_pos = -1
  let mut end_pos = -1
  fn record_token(token : Token) -> Unit {
    if start_pos < 0 {
      start_pos = token.pos()
    }
    end_pos = wgsl_ast_token_end(token)
  }
  let mut paren_depth = 0
  let mut angle_depth = 0
  let mut bracket_depth = 0
  while true {
    match self.view() {
      [Token::Other(code, _), ..] if paren_depth == 0 &&
        angle_depth == 0 &&
        bracket_depth == 0 &&
        stops.contains(code) => break
      [Token::Other(40, pos), .. rest] => {
        paren_depth = paren_depth + 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [Token::Other(41, pos), .. rest] => {
        paren_depth = paren_depth - 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [Token::Other(60, pos), .. rest] => {
        angle_depth = angle_depth + 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [Token::Other(62, pos), .. rest] => {
        angle_depth = angle_depth - 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [Token::Other(91, pos), .. rest] => {
        bracket_depth = bracket_depth + 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [Token::Other(93, pos), .. rest] => {
        bracket_depth = bracket_depth - 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [token, .. rest] => {
        record_token(token)
        self.update_view(rest)
        continue
      }
      [] => break
    }
  }
  let text = if start_pos < 0 || end_pos < start_pos {
    ""
  } else {
    self.source_text[start_pos:end_pos].to_owned().trim().to_owned()
  }
  WgslTextFragment::{ text, start: start_pos, end: end_pos }
}

///|
fn WgslDeclParser::collect_until_top_level(
  self : WgslDeclParser,
  stops : Array[Int],
) -> String {
  self.collect_until_top_level_fragment(stops).text
}

///|
fn wgsl_trim_fragment_bounds(
  text : String,
  start : Int,
  end_ : Int,
) -> (String, Int, Int) {
  let mut left = start
  let mut right = end_
  while left < right {
    let code = text.code_unit_at(left).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      left = left + 1
      continue
    }
    break
  }
  while right > left {
    let code = text.code_unit_at(right - 1).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      right = right - 1
      continue
    }
    break
  }
  (text[left:right].to_owned(), left, right)
}

///|
fn parse_wgsl_type_ref_text(text : String, base : Int) -> WgslTypeRef? {
  let (trimmed, local_start, local_end) = wgsl_trim_fragment_bounds(
    text,
    0,
    text.length(),
  )
  if trimmed == "" {
    return None
  }
  let tokens = tokenize(trimmed, false)
  if tokens.length() == 0 {
    return None
  }
  let name = match tokens[0] {
    Token::Identifier(value, _) => value
    _ => trimmed
  }
  let arguments : Array[WgslTypeRef] = []
  let mut open_index = -1
  for i in 1..<tokens.length() {
    match tokens[i] {
      Token::Other(60, _) => {
        open_index = i
        break
      }
      _ => ()
    }
  }
  if open_index >= 0 {
    let mut depth = 1
    let mut arg_start = tokens[open_index].pos() + 1
    let mut i = open_index + 1
    while i < tokens.length() && depth > 0 {
      match tokens[i] {
        Token::Other(60, _) => depth = depth + 1
        Token::Other(62, pos) => {
          depth = depth - 1
          if depth == 0 {
            let (arg_text, arg_local_start, _) = wgsl_trim_fragment_bounds(
              trimmed, arg_start, pos,
            )
            match
              parse_wgsl_type_ref_text(
                arg_text,
                base + local_start + arg_local_start,
              ) {
              Some(arg) => arguments.push(arg)
              None => ()
            }
            break
          }
        }
        Token::Other(44, pos) if depth == 1 => {
          let (arg_text, arg_local_start, _) = wgsl_trim_fragment_bounds(
            trimmed, arg_start, pos,
          )
          match
            parse_wgsl_type_ref_text(
              arg_text,
              base + local_start + arg_local_start,
            ) {
            Some(arg) => arguments.push(arg)
            None => ()
          }
          arg_start = pos + 1
        }
        _ => ()
      }
      i = i + 1
    }
  }
  Some(WgslTypeRef::{
    name,
    arguments,
    text: trimmed,
    start: base + local_start,
    end: base + local_end,
  })
}

///|
fn parse_wgsl_type_ref_fragment(fragment : WgslTextFragment) -> WgslTypeRef? {
  if fragment.start < 0 || fragment.end < fragment.start {
    return None
  }
  parse_wgsl_type_ref_text(fragment.text, fragment.start)
}

///|
fn WgslDeclParser::parse_template_list(self : WgslDeclParser) -> Array[String] {
  let templates : Array[String] = []
  if !self.consume_if_other(60) {
    return templates
  }
  while true {
    let value = self.collect_until_top_level([44, 62])
    if value != "" {
      templates.push(value)
    }
    if self.consume_if_other(44) {
      continue
    }
    self.consume_if_other(62) |> ignore
    break
  }
  templates
}

///|
