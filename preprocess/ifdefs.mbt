///|
pub fn apply_wgsl_template_consts(
  source : String,
  value_defines : @hashmap.HashMap[String, Int],
) -> String {
  let mut out = ""
  let mut copy_start = 0
  for reference in parse_wgsl_template_const_references(source, value_defines) {
    if value_defines.get(reference.name) is Some(value) {
      out = out + source[copy_start:reference.start].to_owned()
      out = out + value.to_string()
      copy_start = reference.end
    }
  }
  if copy_start < source.length() {
    out = out + source[copy_start:source.length()].to_owned()
  }
  out
}

///|
pub fn apply_wgsl_ifdefs_strict(
  source : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> String raise PreprocessError {
  let mut out = ""
  let scope = Scope::new()
  let original_lines : Array[String] = []
  let decommented_lines : Array[String] = []
  for line in source_lines(source) {
    original_lines.push(line)
  }
  for line in source_lines(replace_comments(source)) {
    decommented_lines.push(line)
  }
  let mut offset = 0
  let mut line_index = 0
  while line_index < decommented_lines.length() {
    let line = decommented_lines[line_index]
    let original_line = if line_index < original_lines.length() {
      original_lines[line_index]
    } else {
      line
    }
    let (is_scope, _) = check_scope(shader_defs, line, Some(scope), offset)
    if !is_scope && scope.active() {
      out = "\{out}\{original_line}\n"
    }
    offset = offset + original_line.length() + 1
    line_index = line_index + 1
  }
  scope.finish(offset)
  out
}

///|
pub fn active_wgsl_ifdef_line_flags_strict(
  source : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> Array[Bool] raise PreprocessError {
  let scope = Scope::new()
  let flags : Array[Bool] = []
  let mut offset = 0
  for line in source_lines(replace_comments(source)) {
    let (is_scope, _) = check_scope(shader_defs, line, Some(scope), offset)
    flags.push(!is_scope && scope.active())
    offset = offset + line.length() + 1
  }
  scope.finish(offset)
  flags
}
