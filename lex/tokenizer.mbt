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
priv enum WgslTokenKind {
  Identifier
  Number
  Operator
  Punctuation
  Whitespace
} derive(Eq, Debug)

///|
pub struct WgslToken {
  priv kind : WgslTokenKind
  priv text : String
  priv code : Int
  priv pos : Int
  priv end : Int
} derive(Eq, Debug)

///|
fn WgslToken::new_text(
  kind : WgslTokenKind,
  text : String,
  pos : Int,
) -> WgslToken {
  WgslToken::{ kind, text, code: -1, pos, end: pos + text.length() }
}

///|
fn WgslToken::new_identifier(text : String, pos : Int) -> WgslToken {
  WgslToken::new_text(Identifier, text, pos)
}

///|
fn WgslToken::new_number(text : String, pos : Int) -> WgslToken {
  WgslToken::new_text(Number, text, pos)
}

///|
fn WgslToken::new_operator(text : String, pos : Int) -> WgslToken {
  WgslToken::new_text(Operator, text, pos)
}

///|
fn WgslToken::new_whitespace(text : String, pos : Int) -> WgslToken {
  WgslToken::new_text(Whitespace, text, pos)
}

///|
fn WgslToken::new_punctuation(code : Int, pos : Int) -> WgslToken {
  WgslToken::{
    kind: Punctuation,
    text: "",
    code,
    pos,
    end: pos + tokenizer_code_point_width(code),
  }
}

///|
pub fn WgslToken::identifier_text(self : WgslToken) -> String? {
  if self.kind == Identifier {
    Some(self.text)
  } else {
    None
  }
}

///|
pub fn WgslToken::number_text(self : WgslToken) -> String? {
  if self.kind == Number {
    Some(self.text)
  } else {
    None
  }
}

///|
pub fn WgslToken::operator_text(self : WgslToken) -> String? {
  if self.kind == Operator {
    Some(self.text)
  } else {
    None
  }
}

///|
pub fn WgslToken::punctuation_code(self : WgslToken) -> Int? {
  if self.kind == Punctuation {
    Some(self.code)
  } else {
    None
  }
}

///|
pub fn WgslToken::is_identifier(self : WgslToken, text : String) -> Bool {
  self.kind == Identifier && self.text == text
}

///|
pub fn WgslToken::is_operator(self : WgslToken, text : String) -> Bool {
  self.kind == Operator && self.text == text
}

///|
pub fn WgslToken::is_punctuation(self : WgslToken, code : Int) -> Bool {
  self.kind == Punctuation && self.code == code
}

///|
pub fn WgslToken::is_whitespace(self : WgslToken) -> Bool {
  self.kind == Whitespace
}

///|
pub fn WgslToken::pos(self : WgslToken) -> Int {
  self.pos
}

///|
pub fn WgslToken::end(self : WgslToken) -> Int {
  self.end
}

///|
pub fn WgslToken::shift(self : WgslToken, offset : Int) -> WgslToken {
  WgslToken::{
    kind: self.kind,
    text: self.text,
    code: self.code,
    pos: self.pos + offset,
    end: self.end + offset,
  }
}

///|
fn tokenizer_whitespace(code : Int, wgsl_blankspace : Bool) -> Bool {
  if wgsl_blankspace {
    wgsl_blankspace_code_point(code)
  } else {
    wgsl_regex_whitespace_code_point(code)
  }
}

///|
fn tokenizer_code_point_width(code : Int) -> Int {
  if code > 0xFFFF {
    2
  } else {
    1
  }
}

///|
fn tokenizer_code_point_at(src : String, index : Int) -> (Int, Int) {
  match wgsl_code_point_at(src, index) {
    Some(point) => point
    None => (src.code_unit_at(index).to_int(), 1)
  }
}

///|
fn tokenizer_operator_pair_text(lhs : Int, rhs : Int) -> String? {
  match (lhs, rhs) {
    (45, 62) => Some("->")
    (61, 61) => Some("==")
    (33, 61) => Some("!=")
    (60, 61) => Some("<=")
    (62, 61) => Some(">=")
    (38, 38) => Some("&&")
    (124, 124) => Some("||")
    (60, 60) => Some("<<")
    (62, 62) => Some(">>")
    (43, 43) => Some("++")
    (45, 45) => Some("--")
    (43, 61) => Some("+=")
    (45, 61) => Some("-=")
    (42, 61) => Some("*=")
    (47, 61) => Some("/=")
    (37, 61) => Some("%=")
    (38, 61) => Some("&=")
    (124, 61) => Some("|=")
    (94, 61) => Some("^=")
    _ => None
  }
}

///|
fn tokenizer_identifier_start(code : Int, wgsl_blankspace : Bool) -> Bool {
  if wgsl_blankspace {
    wgsl_identifier_start_code_point(code)
  } else {
    wgsl_xid_start_code_point(code)
  }
}

///|
fn tokenizer_identifier_continue(code : Int, wgsl_blankspace : Bool) -> Bool {
  if wgsl_blankspace {
    wgsl_identifier_continue_code_point(code)
  } else {
    wgsl_xid_continue_code_point(code)
  }
}

///|
fn tokenizer_number_continue(
  src : String,
  index : Int,
  wgsl_blankspace : Bool,
) -> Bool {
  let (code, _) = tokenizer_code_point_at(src, index)
  if (code >= 48 && code <= 57) ||
    tokenizer_identifier_start(code, wgsl_blankspace) ||
    code == 46 {
    return true
  }
  if (code == 43 || code == 45) && index > 0 {
    let previous = src.code_unit_at(index - 1).to_int()
    return previous == 69 ||
      previous == 80 ||
      previous == 101 ||
      previous == 112
  }
  false
}

///|
fn tokenizer_push_number_as_other(
  tokens : Array[WgslToken],
  src : String,
  start : Int,
  end_ : Int,
  wgsl_blankspace : Bool,
) -> Unit {
  if wgsl_blankspace {
    tokens.push(WgslToken::new_number(src[start:end_].to_owned(), start))
    return
  }
  let mut pos = start
  while pos < end_ {
    let (code, width) = tokenizer_code_point_at(src, pos)
    tokens.push(WgslToken::new_punctuation(code, pos))
    pos = pos + width
  }
}

///|
fn tokenize_with(
  src : String,
  emit_whitespace : Bool,
  wgsl_blankspace : Bool,
) -> Array[WgslToken] {
  let tokens : Array[WgslToken] = []
  let mut current_token_start = 0
  let mut current_token_kind = -1
  let mut quoted_token = false
  let mut i = 0

  while i < src.length() {
    let (code, width) = tokenizer_code_point_at(src, i)
    if code == 34 { // '"'
      quoted_token = !quoted_token
      if current_token_kind == -1 {
        current_token_kind = 0
        current_token_start = i
      }
      i = i + width
      continue
    }

    if current_token_kind == 0 {
      if quoted_token || tokenizer_identifier_continue(code, wgsl_blankspace) {
        i = i + width
        continue
      }
      if code == 58 && // ':'
        i + 1 < src.length() &&
        src.code_unit_at(i + 1).to_int() == 58 {
        i = i + 2
        continue
      }
      tokens.push(
        WgslToken::new_identifier(
          src[current_token_start:i].to_owned(),
          current_token_start,
        ),
      )
      current_token_kind = -1
      current_token_start = i
      continue
    }

    if current_token_kind == 2 {
      if tokenizer_number_continue(src, i, wgsl_blankspace) {
        i = i + width
        continue
      }
      tokenizer_push_number_as_other(
        tokens, src, current_token_start, i, wgsl_blankspace,
      )
      current_token_kind = -1
      current_token_start = i
      continue
    }

    if current_token_kind == 1 {
      if tokenizer_whitespace(code, wgsl_blankspace) {
        i = i + width
        continue
      }
      tokens.push(
        WgslToken::new_whitespace(
          src[current_token_start:i].to_owned(),
          current_token_start,
        ),
      )
      current_token_kind = -1
      current_token_start = i
      continue
    }

    if tokenizer_identifier_start(code, wgsl_blankspace) {
      current_token_kind = 0
      current_token_start = i
      i = i + width
      continue
    }

    if wgsl_blankspace && code >= 48 && code <= 57 {
      current_token_kind = 2
      current_token_start = i
      i = i + width
      continue
    }

    if tokenizer_whitespace(code, wgsl_blankspace) {
      if emit_whitespace {
        current_token_kind = 1
        current_token_start = i
      }
      i = i + width
      continue
    }

    if i + 1 < src.length() {
      let rhs = src.code_unit_at(i + 1).to_int()
      match tokenizer_operator_pair_text(code, rhs) {
        Some(text) => {
          tokens.push(WgslToken::new_operator(text, i))
          i = i + 2
          continue
        }
        None => ()
      }
    }

    tokens.push(WgslToken::new_punctuation(code, i))
    i = i + width
  }

  if current_token_kind == 0 {
    tokens.push(
      WgslToken::new_identifier(
        src[current_token_start:src.length()].to_owned(),
        current_token_start,
      ),
    )
  } else if current_token_kind == 2 {
    tokenizer_push_number_as_other(
      tokens,
      src,
      current_token_start,
      src.length(),
      wgsl_blankspace,
    )
  } else if current_token_kind == 1 {
    tokens.push(
      WgslToken::new_whitespace(
        src[current_token_start:src.length()].to_owned(),
        current_token_start,
      ),
    )
  }

  tokens
}

///|
pub fn tokenize(src : String, emit_whitespace : Bool) -> Array[WgslToken] {
  tokenize_with(src, emit_whitespace, false)
}

///|
pub fn tokenize_wgsl(src : String, emit_whitespace : Bool) -> Array[WgslToken] {
  tokenize_with(src, emit_whitespace, true)
}
