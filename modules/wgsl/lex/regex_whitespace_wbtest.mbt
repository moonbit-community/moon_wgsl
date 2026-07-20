///|
test "naga_oil regex whitespace matches representative Unicode spaces" {
  debug_inspect(wgsl_regex_whitespace_code_point(0x09), content="true")
  debug_inspect(wgsl_regex_whitespace_code_point(0x20), content="true")
  debug_inspect(wgsl_regex_whitespace_code_point(0xA0), content="true")
  debug_inspect(wgsl_regex_whitespace_code_point(0x2003), content="true")
  debug_inspect(wgsl_regex_whitespace_code_point(0x3000), content="true")
  debug_inspect(wgsl_regex_whitespace_code_point(65), content="false")
  debug_inspect(
    wgsl_regex_trim_whitespace("\u{00A0}demo\u{3000}"),
    content="\"demo\"",
  )
  debug_inspect(
    wgsl_regex_skip_whitespace("\u{00A0}\u{2003}demo", 0),
    content="2",
  )
}

///|
test "naga_oil tokenizer accepts Unicode whitespace in imports" {
  let tokens = tokenize("a\u{00A0}b\u{2003}c", false)
  debug_inspect(tokens.length(), content="3")
  debug_inspect(tokens[0].identifier_text(), content="Some(\"a\")")
  debug_inspect(tokens[1].identifier_text(), content="Some(\"b\")")
  debug_inspect(tokens[2].identifier_text(), content="Some(\"c\")")
}
