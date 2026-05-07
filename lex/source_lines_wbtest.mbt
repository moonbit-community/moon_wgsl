///|
test "source line helpers preserve explicit semantics" {
  let source = "a\r\nb\n"
  let split = split_source_lines(source)
  debug_inspect(split.length(), content="3")
  debug_inspect(split[0], content="\"a\\r\"")
  debug_inspect(split[2], content="\"\"")
  let rust_like = source_lines(source)
  debug_inspect(rust_like.length(), content="2")
  debug_inspect(rust_like[0], content="\"a\"")
  debug_inspect(rust_like[1], content="\"b\"")
  debug_inspect(source_lines("").length(), content="0")
  debug_inspect(source_lines("a\r").join("|"), content="\"a\\r\"")
  debug_inspect(source_lines("a\r\nb\r").join("|"), content="\"a|b\\r\"")
}

///|
test "split source lines keeps trailing fragment without newline" {
  let lines = split_source_lines("ab\nc")
  debug_inspect(lines.length(), content="2")
  debug_inspect(lines[0], content="\"ab\"")
  debug_inspect(lines[1], content="\"c\"")
}

///|
test "WGSL line break helpers cover official line terminators" {
  let source = "a\r\nb\u{85}c\u{2028}d\u{2029}e"
  debug_inspect(wgsl_line_start(source, 3), content="3")
  debug_inspect(wgsl_line_text_end(source, 3), content="4")
  debug_inspect(wgsl_line_end(source, 3), content="5")
  debug_inspect(wgsl_line_text_end(source, 5), content="6")
  debug_inspect(wgsl_line_end(source, 5), content="7")
  debug_inspect(wgsl_line_text_end(source, 7), content="8")
  debug_inspect(wgsl_line_end(source, 7), content="9")
}
