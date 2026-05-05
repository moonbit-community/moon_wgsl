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
priv struct WgslCanonicalTokenEdit {
  start : Int
  end : Int
  replacement : String
}

///|
fn WgslCanonicalTokenEdit::new(
  start : Int,
  end : Int,
  replacement : String,
) -> WgslCanonicalTokenEdit {
  WgslCanonicalTokenEdit::{ start, end, replacement }
}

///|
pub struct WgslCanonicalTokenRewriter {
  priv edits : Array[WgslCanonicalTokenEdit]
}

///|
pub fn WgslCanonicalTokenRewriter::default() -> WgslCanonicalTokenRewriter {
  WgslCanonicalTokenRewriter::{ edits: [] }
}

///|
pub fn WgslCanonicalTokenRewriter::replace(
  self : WgslCanonicalTokenRewriter,
  start : Int,
  end : Int,
  replacement : String,
) -> Unit {
  self.edits.push(WgslCanonicalTokenEdit::new(start, end, replacement))
}

///|
pub fn WgslCanonicalTokenRewriter::is_empty(
  self : WgslCanonicalTokenRewriter,
) -> Bool {
  self.edits.length() == 0
}

///|
priv enum WgslEmitTokenClass {
  Word
  Number
  Other
}

///|
priv struct WgslEmittedToken {
  text : String
  start : Int
  end : Int
  kind : WgslEmitTokenClass
}

///|
fn wgsl_ascii_code_text(code : Int) -> String {
  match code {
    9 => "\t"
    10 => "\n"
    13 => "\r"
    32 => " "
    33 => "!"
    34 => "\""
    35 => "#"
    36 => "$"
    37 => "%"
    38 => "&"
    39 => "'"
    40 => "("
    41 => ")"
    42 => "*"
    43 => "+"
    44 => ","
    45 => "-"
    46 => "."
    47 => "/"
    48 => "0"
    49 => "1"
    50 => "2"
    51 => "3"
    52 => "4"
    53 => "5"
    54 => "6"
    55 => "7"
    56 => "8"
    57 => "9"
    58 => ":"
    59 => ";"
    60 => "<"
    61 => "="
    62 => ">"
    63 => "?"
    64 => "@"
    65 => "A"
    66 => "B"
    67 => "C"
    68 => "D"
    69 => "E"
    70 => "F"
    71 => "G"
    72 => "H"
    73 => "I"
    74 => "J"
    75 => "K"
    76 => "L"
    77 => "M"
    78 => "N"
    79 => "O"
    80 => "P"
    81 => "Q"
    82 => "R"
    83 => "S"
    84 => "T"
    85 => "U"
    86 => "V"
    87 => "W"
    88 => "X"
    89 => "Y"
    90 => "Z"
    91 => "["
    92 => "\\"
    93 => "]"
    94 => "^"
    95 => "_"
    96 => "`"
    97 => "a"
    98 => "b"
    99 => "c"
    100 => "d"
    101 => "e"
    102 => "f"
    103 => "g"
    104 => "h"
    105 => "i"
    106 => "j"
    107 => "k"
    108 => "l"
    109 => "m"
    110 => "n"
    111 => "o"
    112 => "p"
    113 => "q"
    114 => "r"
    115 => "s"
    116 => "t"
    117 => "u"
    118 => "v"
    119 => "w"
    120 => "x"
    121 => "y"
    122 => "z"
    123 => "{"
    124 => "|"
    125 => "}"
    126 => "~"
    _ => ""
  }
}

///|
fn wgsl_emit_token_text(
  token : WgslToken,
  replacements : @hashmap.HashMap[String, String],
  source_start : Int,
) -> String {
  match token {
    WgslToken::Identifier(text, pos) => {
      let absolute_pos = source_start + pos
      let key = "\{absolute_pos}:\{absolute_pos + text.length()}"
      match replacements.get(key) {
        Some(replacement) => replacement
        None => text
      }
    }
    WgslToken::Number(text, _) => text
    WgslToken::Operator(text, _) => text
    WgslToken::Punctuation(code, _) => wgsl_ascii_code_text(code)
    WgslToken::Whitespace(text, _) => text
  }
}

///|
fn wgsl_emit_token_class(token : WgslToken) -> WgslEmitTokenClass {
  match token {
    WgslToken::Identifier(_, _) => Word
    WgslToken::Number(_, _) => Number
    _ => Other
  }
}

///|
fn wgsl_emit_token_at(
  tokens : Array[WgslToken],
  index : Int,
  replacements : @hashmap.HashMap[String, String],
  source_start : Int,
) -> (WgslEmittedToken, Int)? {
  guard index >= 0 && index < tokens.length() else { return None }
  let token = tokens[index]
  Some(
    (
      WgslEmittedToken::{
        text: wgsl_emit_token_text(token, replacements, source_start),
        start: token.pos(),
        end: token.end(),
        kind: wgsl_emit_token_class(token),
      },
      1,
    ),
  )
}

///|
fn wgsl_emit_tokens_need_space(
  previous : WgslEmittedToken,
  current : WgslEmittedToken,
  previous_text : String,
  current_text : String,
) -> Bool {
  if previous_text == "if" ||
    previous_text == "for" ||
    previous_text == "while" ||
    previous_text == "switch" ||
    previous_text == "return" ||
    previous_text == "break" ||
    previous_text == "case" ||
    previous_text == "fn" ||
    previous_text == "struct" ||
    previous_text == "alias" ||
    previous_text == "let" ||
    previous_text == "const" ||
    previous_text == "override" ||
    previous_text == "virtual" {
    return true
  }
  if previous_text == ":" ||
    previous_text == "," ||
    previous_text == "=" ||
    previous_text == "+" ||
    previous_text == "-" ||
    previous_text == "*" ||
    previous_text == "/" ||
    previous_text == "%" ||
    previous_text == "&" ||
    previous_text == "|" ||
    previous_text == "==" ||
    previous_text == "!=" ||
    previous_text == "<=" ||
    previous_text == ">=" ||
    previous_text == "&&" ||
    previous_text == "||" ||
    previous_text == "+=" ||
    previous_text == "-=" ||
    previous_text == "*=" ||
    previous_text == "/=" ||
    previous_text == "%=" ||
    previous_text == "->" {
    return true
  }
  if current_text == "{" || current_text == "=" || current_text == "->" {
    return true
  }
  if previous_text == ">" && current.kind is Word {
    return true
  }
  if current_text == "+" ||
    current_text == "-" ||
    current_text == "*" ||
    current_text == "/" ||
    current_text == "%" ||
    current_text == "&" ||
    current_text == "|" ||
    current_text == "==" ||
    current_text == "!=" ||
    current_text == "<=" ||
    current_text == ">=" ||
    current_text == "&&" ||
    current_text == "||" ||
    current_text == "+=" ||
    current_text == "-=" ||
    current_text == "*=" ||
    current_text == "/=" ||
    current_text == "%=" {
    return true
  }
  if previous.end == current.start {
    return false
  }
  match (previous.kind, current.kind) {
    (Word, Word) | (Word, Number) | (Number, Word) => true
    _ => false
  }
}

///|
fn emit_wgsl_canonical_tokens_with_edits(
  text : String,
  edits : Array[WgslCanonicalTokenEdit],
  source_start : Int,
) -> String {
  let replacements : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for edit in edits {
    replacements.set("\{edit.start}:\{edit.end}", edit.replacement)
  }
  let tokens = tokenize_wgsl(replace_comments(text), false)
  let mut out = ""
  let mut previous : WgslEmittedToken? = None
  let mut previous_text = ""
  let mut i = 0
  while i < tokens.length() {
    guard wgsl_emit_token_at(tokens, i, replacements, source_start)
      is Some((token, consumed)) else {
      break
    }
    i = i + consumed
    let token_text = token.text
    if token_text == "" {
      continue
    }
    match previous {
      Some(previous_token) =>
        if wgsl_emit_tokens_need_space(
            previous_token, token, previous_text, token_text,
          ) {
          out = out + " "
        }
      None => ()
    }
    out = out + token_text
    previous = Some(token)
    previous_text = token_text
  }
  out
}

///|
pub fn WgslCanonicalTokenRewriter::emit(
  self : WgslCanonicalTokenRewriter,
  text : String,
  source_start : Int,
) -> String {
  emit_wgsl_canonical_tokens_with_edits(text, self.edits, source_start)
}
