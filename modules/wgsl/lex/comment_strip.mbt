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
priv enum CommentState {
  None
  Block(Int)
  Quote
}

///|
pub fn spaces(count : Int) -> String {
  if count <= 0 {
    return ""
  }
  String::make(count, ' ')
}

///|
fn replace_comments_line(
  line_in : String,
  state : CommentState,
  preserve_byte_width : Bool,
) -> (String, CommentState) {
  let output = StringBuilder::new()
  let mut section_start = 0
  let mut current_state = state

  let mut i = 0
  while i < line_in.length() {
    let marker_index = match current_state {
      None => find_first_comment_or_quote_marker(line_in, i)
      Block(_) => find_first_block_marker(line_in, i)
      Quote => find_first_quote_marker(line_in, i)
    }

    guard marker_index is Some(marker) else {
      let section_end = line_in.length()
      match current_state {
        Block(_) =>
          output.write_string(
            comment_spaces(
              line_in[section_start:section_end].to_owned(),
              preserve_byte_width,
            ),
          )
        _ => output.write_string(line_in[section_start:section_end].to_owned())
      }
      return (output.to_string(), current_state)
    }

    let (marker_start, marker_text) = marker
    match current_state {
      Block(_) =>
        output.write_string(
          comment_spaces(
            line_in[section_start:marker_start].to_owned(),
            preserve_byte_width,
          ),
        )
      _ => output.write_string(line_in[section_start:marker_start].to_owned())
    }

    match marker_text {
      "//" => {
        output.write_string(
          comment_spaces(
            line_in[marker_start:line_in.length()].to_owned(),
            preserve_byte_width,
          ),
        )
        return (output.to_string(), current_state)
      }
      "/*" => {
        current_state = match current_state {
          None => Block(1)
          Block(level) => Block(level + 1)
          Quote => current_state
        }
        output.write_string("  ")
      }
      "*/" => {
        current_state = match current_state {
          Block(1) => None
          Block(level) => Block(level - 1)
          _ => current_state
        }
        output.write_string("  ")
      }
      "\"" => {
        current_state = match current_state {
          None => Quote
          Quote => None
          _ => current_state
        }
        output.write_string("\"")
      }
      _ => abort("unreachable comment marker")
    }

    section_start = marker_start + marker_text.length()
    i = section_start
  }

  (output.to_string(), current_state)
}

///|
fn comment_spaces(text : String, preserve_byte_width : Bool) -> String {
  if preserve_byte_width {
    spaces(utf8_byte_length(text))
  } else {
    spaces(text.length())
  }
}

///|
fn find_first_comment_or_quote_marker(
  line : String,
  start : Int,
) -> (Int, String)? {
  let mut i = start
  while i < line.length() {
    if i + 1 < line.length() &&
      line.code_unit_at(i).to_int() == 47 && // '/'
      line.code_unit_at(i + 1).to_int() == 47 {
      return Some((i, "//"))
    }
    if i + 1 < line.length() &&
      line.code_unit_at(i).to_int() == 47 &&
      line.code_unit_at(i + 1).to_int() == 42 { // '*'
      return Some((i, "/*"))
    }
    if line.code_unit_at(i).to_int() == 34 { // '"'
      return Some((i, "\""))
    }
    i = i + 1
  }
  None
}

///|
fn find_first_block_marker(line : String, start : Int) -> (Int, String)? {
  let mut i = start
  while i + 1 < line.length() {
    if line.code_unit_at(i).to_int() == 47 && // '/'
      line.code_unit_at(i + 1).to_int() == 42 {
      return Some((i, "/*"))
    }
    if line.code_unit_at(i).to_int() == 42 && // '*'
      line.code_unit_at(i + 1).to_int() == 47 { // '/'
      return Some((i, "*/"))
    }
    i = i + 1
  }
  None
}

///|
fn find_first_quote_marker(line : String, start : Int) -> (Int, String)? {
  let mut i = start
  while i < line.length() {
    if line.code_unit_at(i).to_int() == 34 { // '"'
      return Some((i, "\""))
    }
    i = i + 1
  }
  None
}

///|
fn source_contains_comment_marker(source : String) -> Bool {
  let mut i = 0
  while i + 1 < source.length() {
    if source.code_unit_at(i).to_int() == 47 {
      let next = source.code_unit_at(i + 1).to_int()
      if next == 47 || next == 42 {
        return true
      }
    }
    i = i + 1
  }
  false
}

///|
fn replace_comments_preserving_line_endings(source : String) -> String {
  let output = StringBuilder::new(size_hint=utf8_byte_length(source))
  let mut state = CommentState::None
  let mut line_start = 0
  let mut index = 0
  while index < source.length() {
    let break_width = wgsl_line_break_width(source, index)
    if break_width == 0 {
      index = index + 1
      continue
    }
    let (output_line, next_state) = replace_comments_line(
      source[line_start:index].to_owned(),
      state,
      true,
    )
    output.write_string(output_line)
    output.write_string(source[index:index + break_width].to_owned())
    state = next_state
    index = index + break_width
    line_start = index
  }
  if line_start < source.length() {
    let (output_line, _) = replace_comments_line(
      source[line_start:source.length()].to_owned(),
      state,
      true,
    )
    output.write_string(output_line)
  }
  output.to_string()
}

///|
fn replace_comments_with(source : String, preserve_byte_width : Bool) -> String {
  if !source_contains_comment_marker(source) {
    return source
  }
  if preserve_byte_width {
    return replace_comments_preserving_line_endings(source)
  }
  let mut state = CommentState::None
  let lines = split_source_lines(source)
  let output = StringBuilder::new()
  let mut first_line = true
  for line in lines {
    let (output_line, next_state) = replace_comments_line(
      line, state, preserve_byte_width,
    )
    if first_line {
      first_line = false
    } else {
      output.write_string("\n")
    }
    output.write_string(output_line)
    state = next_state
  }
  output.to_string()
}

///|
pub fn replace_comments(source : String) -> String {
  replace_comments_with(source, false)
}

///|
pub fn replace_comments_preserving_byte_width(source : String) -> String {
  replace_comments_with(source, true)
}
