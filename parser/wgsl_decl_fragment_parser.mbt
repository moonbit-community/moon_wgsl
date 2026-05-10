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
  mut source_template_pending_hash : Bool
  mut source_template_brace : Int
}

///|
fn WgslTokenDepth::WgslTokenDepth() -> WgslTokenDepth {
  WgslTokenDepth::{
    paren: 0,
    angle: 0,
    bracket: 0,
    brace: 0,
    source_template_pending_hash: false,
    source_template_brace: 0,
  }
}

///|
fn WgslTokenDepth::at_top(self : WgslTokenDepth) -> Bool {
  self.paren == 0 &&
  self.angle == 0 &&
  self.bracket == 0 &&
  self.brace == 0 &&
  self.source_template_brace == 0
}

///|
fn WgslTokenDepth::observe_source_template(
  self : WgslTokenDepth,
  token : WgslToken,
) -> Bool {
  if self.source_template_brace > 0 {
    match token.punctuation_code() {
      Some(123) => self.source_template_brace = self.source_template_brace + 1
      Some(125) => self.source_template_brace = self.source_template_brace - 1
      _ => ()
    }
    self.source_template_pending_hash = false
    return true
  }
  if self.source_template_pending_hash && token.is_punctuation(123) {
    self.source_template_brace = 1
    self.source_template_pending_hash = false
    return true
  }
  if token.is_punctuation(35) {
    self.source_template_pending_hash = true
  } else if !token.is_whitespace() {
    self.source_template_pending_hash = false
  }
  false
}

///|
fn WgslTokenDepth::observe(self : WgslTokenDepth, token : WgslToken) -> Unit {
  if self.observe_source_template(token) {
    return
  }
  match token.operator_text() {
    Some(">>") => {
      if self.angle >= 2 {
        self.angle = self.angle - 2
      } else {
        self.angle = 0
      }
      return
    }
    _ => ()
  }
  match token.punctuation_code() {
    Some(40) => self.paren = self.paren + 1
    Some(41) => self.paren = self.paren - 1
    Some(60) => self.angle = self.angle + 1
    Some(62) => self.angle = self.angle - 1
    Some(91) => self.bracket = self.bracket + 1
    Some(93) => self.bracket = self.bracket - 1
    Some(123) => self.brace = self.brace + 1
    Some(125) => self.brace = self.brace - 1
    _ => ()
  }
}

///|
fn WgslTokenDepth::observe_statement_token(
  self : WgslTokenDepth,
  token : WgslToken,
) -> Unit {
  if self.observe_source_template(token) {
    return
  }
  match token.punctuation_code() {
    Some(40) => self.paren = self.paren + 1
    Some(41) => self.paren = self.paren - 1
    Some(91) => self.bracket = self.bracket + 1
    Some(93) => self.bracket = self.bracket - 1
    Some(123) => self.brace = self.brace + 1
    Some(125) => self.brace = self.brace - 1
    _ => ()
  }
}

///|
fn wgsl_shift_token(token : WgslToken, offset : Int) -> WgslToken {
  token.shift(offset)
}

///|
fn tokenize_at(
  source : String,
  emit_whitespace : Bool,
  source_start : Int,
) -> Array[WgslToken] {
  let tokens : Array[WgslToken] = []
  for token in tokenize_wgsl(source, emit_whitespace) {
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
fn WgslDeclParser::directive_line_end_at_hash(
  self : WgslDeclParser,
  absolute_hash_pos : Int,
) -> Int? {
  let local_hash_pos = absolute_hash_pos - self.source_start
  if local_hash_pos < 0 || local_hash_pos >= self.source_text.length() {
    return None
  }
  let cleaned = replace_comments(self.source_text)
  let line_start = top_level_line_start(cleaned, local_hash_pos)
  guard wgsl_regex_trim_whitespace(
      cleaned[line_start:local_hash_pos].to_owned(),
    ) ==
    "" else {
    return None
  }
  let line_end = top_level_line_end(cleaned, local_hash_pos)
  if parse_wgsl_directive_line(cleaned[local_hash_pos:line_end].to_owned())
    is Some(_) {
    Some(self.source_start + line_end)
  } else {
    None
  }
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
    [token, .. rest] if token.is_punctuation(code) => {
      self.update_view(rest)
      true
    }
    _ => false
  }
}

///|
fn WgslDeclParser::consume_ident_node(self : WgslDeclParser) -> WgslIdent? {
  match self.view() {
    [token, .. rest] if token.identifier_text() is Some(name) => {
      let pos = token.pos()
      self.update_view(rest)
      Some(WgslIdent(name, pos, pos + name.length()))
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
    [token, ..] if token.is_punctuation(open_code) => token.pos()
    _ => return None
  }
  let mut depth = 0
  for i in 0..<view.length() {
    if view[i].is_punctuation(open_code) {
      depth = depth + 1
    } else if view[i].is_punctuation(close_code) {
      let pos = view[i].pos()
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
  }
  None
}

///|
fn WgslDeclParser::consume_path_ident_node(self : WgslDeclParser) -> WgslIdent? {
  let first = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let mut name = first.name()
  let mut end = first.end()
  while true {
    match self.view() {
      [colon_a, colon_b, segment_token, .. rest] if colon_a.is_punctuation(58) &&
        colon_b.is_punctuation(58) &&
        segment_token.identifier_text() is Some(segment) => {
        let segment_pos = segment_token.pos()
        name = name + "::" + segment
        end = segment_pos + segment.length()
        self.update_view(rest)
      }
      _ => break
    }
  }
  Some(WgslIdent(name, first.start(), end))
}

///|
fn WgslDeclParser::push_attribute_tokens(
  self : WgslDeclParser,
  tokens : Array[(Token, Int, Int)],
) -> Unit {
  while true {
    match self.view() {
      [at_token, name_token, .. rest] if at_token.is_punctuation(64) &&
        name_token.identifier_text() is Some(name) => {
        let at_pos = at_token.pos()
        let name_pos = name_token.pos()
        self.update_view(rest)
        tokens.push((Token::AT(at_pos), at_pos, at_pos + 1))
        tokens.push(
          (
            Token::ATTR_NAME(
              WgslIdent(name, name_pos, name_pos + name.length()),
            ),
            name_pos,
            name_pos + name.length(),
          ),
        )
        match self.collect_delimited_token_view(40, 41) {
          Some(arguments_fragment) => {
            let argument_start = arguments_fragment.open_start + 1
            let argument_end = arguments_fragment.close_start
            if argument_end >= argument_start {
              tokens.push(
                (
                  Token::ATTR_ARGS(
                    (
                      parse_wgsl_expr_ref_text(
                        self.slice(argument_start, argument_end),
                        argument_start,
                      ),
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
  self.collect_until_top_level_fragment_with_mode(stops, false)
}

///|
fn WgslDeclParser::collect_until_top_level_type_fragment(
  self : WgslDeclParser,
  stops : Array[Int],
) -> WgslTextFragment {
  self.collect_until_top_level_fragment_with_mode(stops, true)
}

///|
fn WgslDeclParser::collect_until_top_level_fragment_with_mode(
  self : WgslDeclParser,
  stops : Array[Int],
  track_angle : Bool,
) -> WgslTextFragment {
  let mut start_pos = -1
  let mut end_pos = -1
  fn record_token(token : WgslToken) -> Unit {
    if start_pos < 0 {
      start_pos = token.pos()
    }
    end_pos = token.end()
  }
  let depth = WgslTokenDepth()
  while true {
    match self.view() {
      [token, ..] if depth.at_top() &&
        token.is_punctuation(35) &&
        self.directive_line_end_at_hash(token.pos()) is Some(_) => break
      [token, ..] if depth.at_top() &&
        token.punctuation_code() is Some(code) &&
        stops.contains(code) => break
      [token, .. rest] => {
        if track_angle {
          depth.observe(token)
        } else {
          depth.observe_statement_token(token)
        }
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
    wgsl_trim_blankspace(self.slice(start_pos, end_pos))
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
    if wgsl_blankspace_code_point(code) {
      left = left + 1
      continue
    }
    break
  }
  while right > left {
    let code = text.code_unit_at(right - 1).to_int()
    if wgsl_blankspace_code_point(code) {
      right = right - 1
      continue
    }
    break
  }
  (text[left:right].to_owned(), left, right)
}
