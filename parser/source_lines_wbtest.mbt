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
}

///|
test "split source lines keeps trailing fragment without newline" {
  let lines = split_source_lines("ab\nc")
  debug_inspect(lines.length(), content="2")
  debug_inspect(lines[0], content="\"ab\"")
  debug_inspect(lines[1], content="\"c\"")
}
