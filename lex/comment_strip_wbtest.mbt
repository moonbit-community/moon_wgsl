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
test "naga_oil wb: comment stripping preserves quoted import URLs" {
  let source = "#import \"embedded://file.wgsl\""
  debug_inspect(
    replace_comments(source),
    content="\"#import \\\"embedded://file.wgsl\\\"\"",
  )
  let commented = "// #import \"embedded://file.wgsl\""
  debug_inspect(
    replace_comments(commented),
    content="\"\{spaces(commented.length())}\"",
  )
}

///|
test "naga_oil wb: comment stripping ignores comment markers inside quotes" {
  let source = "#import \"embedded:/* */ /* /**/* / / /// * / //*/*/ / */*file.wgsl\""
  debug_inspect(
    replace_comments(source),
    content="\"#import \\\"embedded:/* */ /* /**/* / / /// * / //*/*/ / */*file.wgsl\\\"\"",
  )
  debug_inspect(
    replace_comments("/* #import \"embedded:*/file.wgsl\" */"),
    content="\"                       file.wgsl\\\" */\"",
  )
}

///|
test "naga_oil wb: comment stripping preserves line width around block comments" {
  debug_inspect(
    replace_comments(
      "1.0 /* block comment with a partial line comment on the end *// 2.0",
    ),
    content="\"1.0                                                           / 2.0\"",
  )
  debug_inspect(
    replace_comments("1.0 /* block comment 1 *//* block comment 2 */ * 2.0"),
    content="\"1.0                                            * 2.0\"",
  )
  debug_inspect(
    replace_comments(
      "1.0 /* block comment with real line comment after */// line comment",
    ),
    content="\"1.0                                                                \"",
  )
}

///|
test "naga_oil wb: comment stripping handles nested multiline comments" {
  debug_inspect(
    replace_comments("/*\n//*\n*/commented\n*/not commented"),
    content="\"  \\n   \\n           \\n  not commented\"",
  )
}

///|
test "naga_oil wb: comment stripping replaces non-ascii comments by UTF-8 byte width" {
  debug_inspect(replace_comments_naga_oil("a/*中*/b"), content="\"a       b\"")
  debug_inspect(replace_comments_naga_oil("中//评"), content="\"中     \"")
  debug_inspect(
    replace_comments_naga_oil("a/*💡*/b"),
    content="\"a        b\"",
  )
}

///|
test "naga_oil wb: comment stripping uses Rust CRLF line semantics" {
  debug_inspect(
    replace_comments_naga_oil("//x\r\nvalue"),
    content="\"   \\nvalue\"",
  )
  debug_inspect(
    replace_comments_naga_oil("/*x*/\r\nvalue"),
    content="\"     \\nvalue\"",
  )
}

///|
test "WGSL parser comment stripping preserves code-unit source positions" {
  debug_inspect(replace_comments("a/*中*/b"), content="\"a     b\"")
  debug_inspect(replace_comments("a/*💡*/b"), content="\"a      b\"")
}
