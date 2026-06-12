///|
test "naga_oil regex word ranges match representative code points" {
  debug_inspect(wgsl_regex_word_code_point(65), content="true")
  debug_inspect(wgsl_regex_word_width("A", 0), content="1")
  debug_inspect(wgsl_regex_word_width("|", 0), content="1")
  debug_inspect(wgsl_regex_word_width("中", 0), content="1")
  debug_inspect(wgsl_regex_word_width("💡", 0), content="0")
  debug_inspect(wgsl_regex_word_text("abc_123|中"), content="true")
  debug_inspect(wgsl_regex_word_text("abc💡"), content="false")
}
