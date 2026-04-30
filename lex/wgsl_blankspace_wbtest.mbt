///|
test "WGSL blankspace matches Pattern_White_Space representatives" {
  debug_inspect(wgsl_blankspace_code_point(0x0B), content="true")
  debug_inspect(wgsl_blankspace_code_point(0x0C), content="true")
  debug_inspect(wgsl_blankspace_code_point(0x85), content="true")
  debug_inspect(wgsl_blankspace_code_point(0x200E), content="true")
  debug_inspect(wgsl_blankspace_code_point(0x2029), content="true")
  debug_inspect(wgsl_blankspace_code_point(0xA0), content="false")
  debug_inspect(
    wgsl_trim_blankspace("\u{200E}demo\u{2029}"),
    content="\"demo\"",
  )
}

///|
test "WGSL tokenizer skips Pattern_White_Space blankspace" {
  let tokens = tokenize("a\u{000C}b\u{200E}c", false)
  debug_inspect(tokens.length(), content="3")
  debug_inspect(tokens[0], content="Identifier(\"a\", 0)")
  debug_inspect(tokens[1], content="Identifier(\"b\", 2)")
  debug_inspect(tokens[2], content="Identifier(\"c\", 4)")
}
