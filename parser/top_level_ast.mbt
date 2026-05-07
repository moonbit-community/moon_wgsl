// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn top_level_span_has_text(source : String, start : Int, end_ : Int) -> Bool {
  start >= 0 &&
  end_ > start &&
  wgsl_regex_trim_whitespace(source[start:end_].to_owned()) != ""
}

///|
fn top_level_line_start(source : String, pos : Int) -> Int {
  let mut i = pos
  while i > 0 {
    if source.code_unit_at(i - 1).to_int() == 10 {
      return i
    }
    i = i - 1
  }
  0
}

///|
fn top_level_line_end(source : String, pos : Int) -> Int {
  let mut i = pos
  while i < source.length() {
    if source.code_unit_at(i).to_int() == 10 {
      return i + 1
    }
    i = i + 1
  }
  source.length()
}

///|
fn top_level_hash_starts_directive(cleaned : String, pos : Int) -> Bool {
  let line_start = top_level_line_start(cleaned, pos)
  guard wgsl_regex_trim_whitespace(cleaned[line_start:pos].to_owned()) == "" else {
    return false
  }
  let line_end = top_level_line_end(cleaned, pos)
  parse_wgsl_directive_line(cleaned[pos:line_end].to_owned()) is Some(_)
}

///|
fn top_level_non_whitespace_index(
  tokens : Array[WgslToken],
  start : Int,
) -> Int {
  let mut i = start
  while i < tokens.length() {
    if tokens[i].is_whitespace() {
      i = i + 1
    } else {
      return i
    }
  }
  i
}

///|
fn top_level_index_starts_semicolon(
  tokens : Array[WgslToken],
  start : Int,
) -> Bool {
  let next = top_level_non_whitespace_index(tokens, start)
  next < tokens.length() && tokens[next].is_punctuation(59)
}

///|
fn top_level_previous_token_is_hash(previous : WgslToken?) -> Bool {
  match previous {
    Some(token) if token.is_punctuation(35) => true
    _ => false
  }
}

///|
fn top_level_directive_item_kind(
  kind : WgslDirectiveKind,
) -> WgslRawTopLevelKind {
  match kind {
    WgslDirectiveKind::DefineImportPath => WgslRawTopLevelKind::DefineImportPath
    WgslDirectiveKind::Define => WgslRawTopLevelKind::Define
    WgslDirectiveKind::Import => WgslRawTopLevelKind::Import
    WgslDirectiveKind::Ifdef
    | WgslDirectiveKind::Ifndef
    | WgslDirectiveKind::If
    | WgslDirectiveKind::Else
    | WgslDirectiveKind::Endif
    | WgslDirectiveKind::Enable
    | WgslDirectiveKind::Requires
    | WgslDirectiveKind::Diagnostic
    | WgslDirectiveKind::Other => WgslRawTopLevelKind::Directive
  }
}

///|
fn top_level_push_span_item(
  items : Array[WgslRawTopLevelItem],
  source : String,
  kind : WgslRawTopLevelKind,
  start : Int,
  end_ : Int,
) -> Unit {
  let text = source[start:end_].to_owned()
  items.push(WgslRawTopLevelItem::{ kind, text, start, end: end_ })
}

///|
priv struct WgslTopLevelParser {
  source : String
  cleaned : String
  tokens : Array[WgslToken]
  mut index : Int
  mut pending_start : Int
}

///|
fn WgslTopLevelParser::WgslTopLevelParser(
  source : String,
) -> WgslTopLevelParser {
  let cleaned = replace_comments(source)
  WgslTopLevelParser::{
    source,
    cleaned,
    tokens: tokenize_wgsl(cleaned, false),
    index: 0,
    pending_start: 0,
  }
}

///|
fn WgslTopLevelParser::skip_to_span_end(
  self : WgslTopLevelParser,
  end_ : Int,
) -> Unit {
  while self.index < self.tokens.length() &&
        self.tokens[self.index].pos() < end_ {
    self.index = self.index + 1
  }
}

///|
fn WgslTopLevelParser::flush_trivia_until(
  self : WgslTopLevelParser,
  items : Array[WgslRawTopLevelItem],
  end_ : Int,
) -> Unit {
  if top_level_span_has_text(self.source, self.pending_start, end_) {
    top_level_push_span_item(
      items,
      self.source,
      WgslRawTopLevelKind::Trivia,
      self.pending_start,
      end_,
    )
  }
  self.pending_start = end_
}

///|
fn WgslTopLevelParser::parse_directive_item(
  self : WgslTopLevelParser,
  items : Array[WgslRawTopLevelItem],
  directive : WgslDirective,
) -> Unit {
  let token_pos = self.tokens[self.index].pos()
  let physical_line_start = top_level_line_start(self.source, token_pos)
  let item_start = if physical_line_start < self.pending_start {
    self.pending_start
  } else {
    physical_line_start
  }
  self.flush_trivia_until(items, item_start)
  let first_line_end = top_level_line_end(self.source, token_pos)
  let mut item_end = first_line_end
  if directive.kind() == WgslDirectiveKind::Import {
    let mut balance = naga_oil_raw_import_brace_balance_next(
      0,
      replace_comments(self.source[token_pos:first_line_end].to_owned()),
    )
    while balance > 0 && item_end < self.source.length() {
      let next_line_end = top_level_line_end(self.source, item_end)
      balance = naga_oil_raw_import_brace_balance_next(
        balance,
        replace_comments(self.source[item_end:next_line_end].to_owned()),
      )
      item_end = next_line_end
    }
  }
  top_level_push_span_item(
    items,
    self.source,
    top_level_directive_item_kind(directive.kind()),
    item_start,
    item_end,
  )
  self.skip_to_span_end(item_end)
  self.pending_start = item_end
}

///|
fn WgslTopLevelParser::parse_declaration_item(
  self : WgslTopLevelParser,
  items : Array[WgslRawTopLevelItem],
) -> Unit {
  let first_token_pos = self.tokens[self.index].pos()
  let item_start = if top_level_span_has_text(
      self.source,
      self.pending_start,
      first_token_pos,
    ) {
    self.pending_start
  } else {
    first_token_pos
  }
  let depth = WgslTokenDepth()
  let mut saw_brace = false
  let mut item_end = first_token_pos
  let mut previous_significant : WgslToken? = None
  while self.index < self.tokens.length() {
    let token = self.tokens[self.index]
    if depth.at_top() &&
      token.pos() > first_token_pos &&
      token.is_punctuation(35) &&
      top_level_hash_starts_directive(self.cleaned, token.pos()) {
      item_end = token.pos()
      break
    }
    if !saw_brace && depth.at_top() && token.is_punctuation(59) {
      item_end = token.end()
      self.index = self.index + 1
      break
    }
    let starts_top_level_brace = depth.at_top() &&
      token.is_punctuation(123) &&
      !top_level_previous_token_is_hash(previous_significant)
    depth.observe_statement_token(token)
    if starts_top_level_brace {
      saw_brace = true
    }
    item_end = token.end()
    self.index = self.index + 1
    if saw_brace && depth.at_top() {
      while top_level_index_starts_semicolon(self.tokens, self.index) {
        while self.index < self.tokens.length() &&
              self.tokens[self.index].is_whitespace() {
          item_end = self.tokens[self.index].end()
          self.index = self.index + 1
        }
        if self.index < self.tokens.length() &&
          self.tokens[self.index].is_punctuation(59) {
          item_end = self.tokens[self.index].end()
          self.index = self.index + 1
        }
      }
      break
    }
    if !token.is_whitespace() {
      previous_significant = Some(token)
    }
  }
  if top_level_span_has_text(self.source, item_start, item_end) {
    top_level_push_span_item(
      items,
      self.source,
      WgslRawTopLevelKind::Declaration,
      item_start,
      item_end,
    )
  }
  self.pending_start = item_end
}

///|
fn WgslTopLevelParser::parse_items(
  self : WgslTopLevelParser,
) -> Array[WgslRawTopLevelItem] {
  let items : Array[WgslRawTopLevelItem] = []
  while true {
    self.index = top_level_non_whitespace_index(self.tokens, self.index)
    if self.index >= self.tokens.length() {
      break
    }
    let token = self.tokens[self.index]
    let token_pos = token.pos()
    if token.is_punctuation(59) {
      self.flush_trivia_until(items, token_pos)
      top_level_push_span_item(
        items,
        self.source,
        WgslRawTopLevelKind::Trivia,
        token_pos,
        token.end(),
      )
      self.index = self.index + 1
      self.pending_start = token.end()
      continue
    }
    if token.is_punctuation(35) {
      let line_end = top_level_line_end(self.source, token_pos)
      let cleaned_line = self.cleaned[token_pos:line_end].to_owned()
      match parse_wgsl_directive_line(cleaned_line) {
        Some(directive) => {
          self.parse_directive_item(items, directive)
          continue
        }
        None => ()
      }
    }
    self.parse_declaration_item(items)
  }
  self.flush_trivia_until(items, self.source.length())
  items
}

///|
fn parse_wgsl_top_level_items(source : String) -> Array[WgslRawTopLevelItem] {
  WgslTopLevelParser(source).parse_items()
}
