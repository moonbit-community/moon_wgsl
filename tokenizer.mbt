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
enum Token {
  Identifier(String, Int)
  Other(Int, Int)
  Whitespace(String, Int)
} derive(Eq, Debug)

///|
fn Token::pos(self : Token) -> Int {
  match self {
    Identifier(_, pos) => pos
    Other(_, pos) => pos
    Whitespace(_, pos) => pos
  }
}

///|
fn Token::identifier(self : Token) -> String? {
  match self {
    Identifier(ident, _) => Some(ident)
    _ => None
  }
}

///|
fn tokenizer_identifier_start(code : Int) -> Bool {
  code == 95 || // '_'
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code > 127
}

///|
fn tokenizer_identifier_continue(code : Int) -> Bool {
  tokenizer_identifier_start(code) || (code >= 48 && code <= 57)
}

///|
fn tokenize(src : String, emit_whitespace : Bool) -> Array[Token] {
  let tokens : Array[Token] = []
  let mut current_token_start = 0
  let mut current_token_kind = -1
  let mut quoted_token = false
  let mut i = 0

  while i < src.length() {
    let code = src.code_unit_at(i).to_int()
    if code == 34 { // '"'
      quoted_token = !quoted_token
      if current_token_kind == -1 {
        current_token_kind = 0
        current_token_start = i
      }
      i = i + 1
      continue
    }

    if current_token_kind == 0 {
      if quoted_token || tokenizer_identifier_continue(code) {
        i = i + 1
        continue
      }
      if code == 58 && // ':'
        i + 1 < src.length() &&
        src.code_unit_at(i + 1).to_int() == 58 {
        i = i + 2
        continue
      }
      tokens.push(
        Token::Identifier(
          src[current_token_start:i].to_owned(),
          current_token_start,
        ),
      )
      current_token_kind = -1
      current_token_start = i
      continue
    }

    if current_token_kind == 1 {
      if code == 32 || code == 9 || code == 10 || code == 13 {
        i = i + 1
        continue
      }
      tokens.push(
        Token::Whitespace(
          src[current_token_start:i].to_owned(),
          current_token_start,
        ),
      )
      current_token_kind = -1
      current_token_start = i
      continue
    }

    if tokenizer_identifier_start(code) {
      current_token_kind = 0
      current_token_start = i
      i = i + 1
      continue
    }

    if code == 32 || code == 9 || code == 10 || code == 13 {
      if emit_whitespace {
        current_token_kind = 1
        current_token_start = i
      }
      i = i + 1
      continue
    }

    tokens.push(Token::Other(code, i))
    i = i + 1
  }

  if current_token_kind == 0 {
    tokens.push(
      Token::Identifier(
        src[current_token_start:src.length()].to_owned(),
        current_token_start,
      ),
    )
  } else if current_token_kind == 1 {
    tokens.push(
      Token::Whitespace(
        src[current_token_start:src.length()].to_owned(),
        current_token_start,
      ),
    )
  }

  tokens
}
