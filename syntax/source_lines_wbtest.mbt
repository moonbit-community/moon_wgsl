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
test "source line spans keep original offsets" {
  let spans = split_source_line_spans("ab\nc")
  debug_inspect(spans.length(), content="2")
  debug_inspect(spans[0].start, content="0")
  debug_inspect(spans[1].start, content="3")
}
