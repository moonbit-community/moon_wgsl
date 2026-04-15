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
fn spaces(count : Int) -> String {
  if count <= 0 {
    return ""
  }
  String::make(count, ' ')
}

///|
fn replace_comments_line(
  line_in : String,
  state : CommentState,
) -> (String, CommentState) {
  let mut output = ""
  let mut section_start = 0
  let mut current_state = state

  let mut i = 0
  while i < line_in.length() {
    let marker_index = match current_state {
      CommentState::None => find_first_comment_or_quote_marker(line_in, i)
      CommentState::Block(_) => find_first_block_marker(line_in, i)
      CommentState::Quote => find_first_quote_marker(line_in, i)
    }

    guard marker_index is Some(marker) else {
      let section_end = line_in.length()
      match current_state {
        CommentState::Block(_) =>
          output = output + spaces(section_end - section_start)
        _ => output = output + line_in[section_start:section_end].to_string()
      }
      return (output, current_state)
    }

    let (marker_start, marker_text) = marker
    match current_state {
      CommentState::Block(_) =>
        output = output + spaces(marker_start - section_start)
      _ => output = output + line_in[section_start:marker_start].to_string()
    }

    match marker_text {
      "//" => {
        output = output + spaces(line_in.length() - marker_start)
        return (output, current_state)
      }
      "/*" => {
        current_state = match current_state {
          CommentState::None => CommentState::Block(1)
          CommentState::Block(level) => CommentState::Block(level + 1)
          CommentState::Quote => current_state
        }
        output = "\{output}  "
      }
      "*/" => {
        current_state = match current_state {
          CommentState::Block(1) => CommentState::None
          CommentState::Block(level) => CommentState::Block(level - 1)
          _ => current_state
        }
        output = "\{output}  "
      }
      "\"" => {
        current_state = match current_state {
          CommentState::None => CommentState::Quote
          CommentState::Quote => CommentState::None
          _ => current_state
        }
        output = "\{output}\""
      }
      _ => abort("unreachable comment marker")
    }

    section_start = marker_start + marker_text.length()
    i = section_start
  }

  (output, current_state)
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
fn replace_comments(source : String) -> String {
  let output_lines : Array[String] = []
  let mut state = CommentState::None
  for line_item in source.split("\n") {
    let (output_line, next_state) = replace_comments_line(
      line_item.to_string(),
      state,
    )
    output_lines.push(output_line)
    state = next_state
  }
  let mut output = ""
  for i in 0..<output_lines.length() {
    if i > 0 {
      output = "\{output}\n"
    }
    output = output + output_lines[i]
  }
  output
}
