///|
fn wgsl_expr_identifier_has_access_prefix(
  tokens : Array[WgslToken],
  index : Int,
) -> Bool {
  if index == 0 {
    return false
  }
  match tokens[index - 1] {
    WgslToken::Other(46, _) | WgslToken::Other(64, _) => true
    _ => false
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
  let tokens = tokenize(replace_comments(trimmed), false)
  for i in 0..<tokens.length() {
    match tokens[i] {
      WgslToken::Identifier(name, pos) =>
        if !wgsl_expr_identifier_has_access_prefix(tokens, i) {
          identifiers.push(WgslIdent::{
            name,
            start: base + local_start + pos,
            end: base + local_start + pos + name.length(),
          })
        }
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
  source_start : Int
  mut token_view : ArrayView[WgslToken]
}

///|
priv struct WgslTextFragment {
  text : String
  start : Int
  end : Int
}

///|
priv struct WgslDelimitedTokenView {
  inner : ArrayView[WgslToken]
  open_start : Int
  close_start : Int
  consumed : Int
}

///|
priv struct WgslTokenDepth {
  mut paren : Int
  mut angle : Int
  mut bracket : Int
  mut brace : Int
}

///|
fn WgslTokenDepth::new() -> WgslTokenDepth {
  WgslTokenDepth::{ paren: 0, angle: 0, bracket: 0, brace: 0 }
}

///|
fn WgslTokenDepth::at_top(self : WgslTokenDepth) -> Bool {
  self.paren == 0 && self.angle == 0 && self.bracket == 0 && self.brace == 0
}

///|
fn WgslTokenDepth::observe(self : WgslTokenDepth, token : WgslToken) -> Unit {
  match token {
    WgslToken::Other(40, _) => self.paren = self.paren + 1
    WgslToken::Other(41, _) => self.paren = self.paren - 1
    WgslToken::Other(60, _) => self.angle = self.angle + 1
    WgslToken::Other(62, _) => self.angle = self.angle - 1
    WgslToken::Other(91, _) => self.bracket = self.bracket + 1
    WgslToken::Other(93, _) => self.bracket = self.bracket - 1
    WgslToken::Other(123, _) => self.brace = self.brace + 1
    WgslToken::Other(125, _) => self.brace = self.brace - 1
    _ => ()
  }
}

///|
fn WgslTokenDepth::observe_statement_token(
  self : WgslTokenDepth,
  token : WgslToken,
) -> Unit {
  match token {
    WgslToken::Other(40, _) => self.paren = self.paren + 1
    WgslToken::Other(41, _) => self.paren = self.paren - 1
    WgslToken::Other(91, _) => self.bracket = self.bracket + 1
    WgslToken::Other(93, _) => self.bracket = self.bracket - 1
    WgslToken::Other(123, _) => self.brace = self.brace + 1
    WgslToken::Other(125, _) => self.brace = self.brace - 1
    _ => ()
  }
}

///|
fn wgsl_shift_token(token : WgslToken, offset : Int) -> WgslToken {
  match token {
    WgslToken::Identifier(name, pos) =>
      WgslToken::Identifier(name, pos + offset)
    WgslToken::Other(code, pos) => WgslToken::Other(code, pos + offset)
    WgslToken::Whitespace(text, pos) =>
      WgslToken::Whitespace(text, pos + offset)
  }
}

///|
fn tokenize_at(
  source : String,
  emit_whitespace : Bool,
  source_start : Int,
) -> Array[WgslToken] {
  let tokens : Array[WgslToken] = []
  for token in tokenize(source, emit_whitespace) {
    tokens.push(wgsl_shift_token(token, source_start))
  }
  tokens
}

///|
fn WgslDeclParser::new_at(text : String, source_start : Int) -> WgslDeclParser {
  let tokens = tokenize_at(replace_comments(text), false, source_start)
  WgslDeclParser::{ source_text: text, source_start, token_view: tokens[:] }
}

///|
fn WgslDeclParser::new(text : String) -> WgslDeclParser {
  WgslDeclParser::new_at(text, 0)
}

///|
fn WgslDeclParser::slice(
  self : WgslDeclParser,
  start : Int,
  end_ : Int,
) -> String {
  let local_start = start - self.source_start
  let local_end = end_ - self.source_start
  if local_start < 0 ||
    local_end < local_start ||
    local_end > self.source_text.length() {
    return ""
  }
  self.source_text[local_start:local_end].to_owned()
}

///|
fn WgslDeclParser::view(self : WgslDeclParser) -> ArrayView[WgslToken] {
  self.token_view
}

///|
fn WgslDeclParser::update_view(
  self : WgslDeclParser,
  view : ArrayView[WgslToken],
) -> Unit {
  self.token_view = view
}

///|
fn WgslDeclParser::consume_if_other(self : WgslDeclParser, code : Int) -> Bool {
  match self.view() {
    [WgslToken::Other(actual, _), .. rest] if actual == code => {
      self.update_view(rest)
      true
    }
    _ => false
  }
}

///|
fn WgslDeclParser::consume_ident_node(self : WgslDeclParser) -> WgslIdent? {
  match self.view() {
    [WgslToken::Identifier(name, pos), .. rest] => {
      self.update_view(rest)
      Some(WgslIdent::{ name, start: pos, end: pos + name.length() })
    }
    _ => None
  }
}

///|
fn WgslDeclParser::drop_tokens(self : WgslDeclParser, count : Int) -> Unit {
  let mut view = self.view()
  let mut remaining = count
  while remaining > 0 {
    match view {
      [_, .. rest] => {
        view = rest
        remaining = remaining - 1
      }
      [] => break
    }
  }
  self.update_view(view)
}

///|
fn WgslDeclParser::collect_delimited_token_view(
  self : WgslDeclParser,
  open_code : Int,
  close_code : Int,
) -> WgslDelimitedTokenView? {
  let view = self.view()
  let open_start = match view {
    [WgslToken::Other(code, pos), ..] if code == open_code => pos
    _ => return None
  }
  let mut depth = 0
  for i in 0..<view.length() {
    match view[i] {
      WgslToken::Other(code, _) if code == open_code => depth = depth + 1
      WgslToken::Other(code, pos) if code == close_code => {
        depth = depth - 1
        if depth == 0 {
          return Some(WgslDelimitedTokenView::{
            inner: view[1:i],
            open_start,
            close_start: pos,
            consumed: i + 1,
          })
        }
      }
      _ => ()
    }
  }
  None
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
        WgslToken::Other(58, _),
        WgslToken::Other(58, _),
        WgslToken::Identifier(segment, segment_pos),
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
fn WgslDeclParser::push_attribute_tokens(
  self : WgslDeclParser,
  tokens : Array[(Token, Int, Int)],
) -> Unit {
  while true {
    match self.view() {
      [
        WgslToken::Other(64, at_pos),
        WgslToken::Identifier(name, name_pos),
        .. rest,
      ] => {
        self.update_view(rest)
        tokens.push((Token::AT(at_pos), at_pos, at_pos + 1))
        tokens.push(
          (
            Token::ATTR_NAME(WgslIdent::{
              name,
              start: name_pos,
              end: name_pos + name.length(),
            }),
            name_pos,
            name_pos + name.length(),
          ),
        )
        match self.collect_delimited_token_view(40, 41) {
          Some(arguments_fragment) => {
            let argument_start = arguments_fragment.open_start + 1
            let argument_end = arguments_fragment.close_start
            if argument_end >= argument_start {
              let arguments = self.slice(argument_start, argument_end)
              tokens.push(
                (
                  Token::ATTR_ARGS(
                    (
                      arguments,
                      parse_wgsl_expr_ref_text(arguments, argument_start),
                      arguments_fragment.close_start + 1,
                    ),
                  ),
                  arguments_fragment.open_start,
                  arguments_fragment.close_start + 1,
                ),
              )
            }
            self.drop_tokens(arguments_fragment.consumed)
          }
          _ => ()
        }
        continue
      }
      _ => break
    }
  }
}

///|
fn WgslDeclParser::collect_until_top_level_fragment(
  self : WgslDeclParser,
  stops : Array[Int],
) -> WgslTextFragment {
  let mut start_pos = -1
  let mut end_pos = -1
  fn record_token(token : WgslToken) -> Unit {
    if start_pos < 0 {
      start_pos = token.pos()
    }
    end_pos = token.end()
  }
  let depth = WgslTokenDepth::new()
  while true {
    match self.view() {
      [WgslToken::Other(code, _), ..] if depth.at_top() && stops.contains(code) =>
        break
      [token, .. rest] => {
        depth.observe(token)
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
    self.slice(start_pos, end_pos).trim().to_owned()
  }
  WgslTextFragment::{ text, start: start_pos, end: end_pos }
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
  let (trimmed, local_start, _) = wgsl_trim_fragment_bounds(
    text,
    0,
    text.length(),
  )
  if trimmed == "" {
    return None
  }
  let source_start = base + local_start
  Some(
    type_ref(tokenize_wgsl_type_ref(trimmed, source_start)) catch {
      _ => return None
    },
  )
}

///|
fn wgsl_type_ref_space(code : Int) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn wgsl_type_ref_delimiter(code : Int) -> Bool {
  code == 60 || code == 62 || code == 44
}

///|
fn tokenize_wgsl_type_ref(
  source : String,
  source_start : Int,
) -> Array[(Token, Int, Int)] {
  let tokens : Array[(Token, Int, Int)] = []
  let mut i = 0
  while i < source.length() {
    let code = source.code_unit_at(i).to_int()
    if wgsl_type_ref_space(code) {
      i = i + 1
      continue
    }
    let start = i
    let absolute_start = source_start + start
    if code == 60 {
      tokens.push(
        (
          Token::TYPE_LT(source_start + start + 1),
          absolute_start,
          absolute_start + 1,
        ),
      )
      i = i + 1
      continue
    }
    if code == 62 {
      tokens.push(
        (
          Token::TYPE_GT(source_start + start + 1),
          absolute_start,
          absolute_start + 1,
        ),
      )
      i = i + 1
      continue
    }
    if code == 44 {
      tokens.push((Token::COMMA, absolute_start, absolute_start + 1))
      i = i + 1
      continue
    }
    while i < source.length() {
      let next = source.code_unit_at(i).to_int()
      if wgsl_type_ref_space(next) || wgsl_type_ref_delimiter(next) {
        break
      }
      i = i + 1
    }
    let absolute_end = source_start + i
    tokens.push(
      (
        Token::TYPE_ATOM(
          (
            source[start:i].to_owned(),
            source,
            source_start,
            absolute_start,
            absolute_end,
          ),
        ),
        absolute_start,
        absolute_end,
      ),
    )
  }
  tokens.push(
    (Token::EOF, source_start + source.length(), source_start + source.length()),
  )
  tokens
}

///|
fn parse_wgsl_type_ref_fragment(fragment : WgslTextFragment) -> WgslTypeRef? {
  if fragment.start < 0 || fragment.end < fragment.start {
    return None
  }
  parse_wgsl_type_ref_text(fragment.text, fragment.start)
}

///|
priv struct WgslTemplateListFragment {
  text : String
  start : Int
  consumed : Int
}

///|
fn WgslDeclParser::collect_template_list_fragment(
  self : WgslDeclParser,
) -> WgslTemplateListFragment? {
  let view = self.view()
  guard view is [WgslToken::Other(60, open_pos), ..] else { return None }
  let mut depth = 0
  let mut consumed = 0
  let mut end_pos = -1
  while consumed < view.length() {
    match view[consumed] {
      WgslToken::Other(60, _) => depth = depth + 1
      WgslToken::Other(62, pos) => {
        depth = depth - 1
        if depth == 0 {
          end_pos = pos + 1
          consumed = consumed + 1
          break
        }
      }
      _ => ()
    }
    consumed = consumed + 1
  }
  guard end_pos >= open_pos else { return None }
  Some(WgslTemplateListFragment::{
    text: self.slice(open_pos, end_pos),
    start: open_pos,
    consumed,
  })
}

///|
fn WgslDeclParser::parse_template_list(self : WgslDeclParser) -> Array[String] {
  match self.collect_template_list_fragment() {
    Some(fragment) => {
      let parsed = template_list(
        tokenize_wgsl_type_ref(fragment.text, fragment.start),
      ) catch {
        _ => return []
      }
      self.drop_tokens(fragment.consumed)
      parsed
    }
    None => []
  }
}

///|
