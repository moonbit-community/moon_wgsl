///|
fn blank_wgsl_directive_text_preserving_offsets(text : String) -> String {
  let out = StringBuilder::new(size_hint=utf8_byte_length(text))
  let mut line_start = 0
  let mut index = 0
  while index < text.length() {
    let width = wgsl_line_break_width(text, index)
    if width > 0 {
      out.write_string(
        spaces(utf8_byte_length(text[line_start:index].to_owned())),
      )
      out.write_string(text[index:index + width].to_owned())
      index = index + width
      line_start = index
    } else {
      index = index + 1
    }
  }
  if line_start < text.length() {
    out.write_string(
      spaces(utf8_byte_length(text[line_start:text.length()].to_owned())),
    )
  }
  out.to_string()
}

///|
/// Removes naga-oil preprocessing syntax while preserving every source byte
/// offset and line break expected by the strict WGSL parser.
pub fn mask_naga_oil_directives_for_wgsl(source : String) -> String {
  let out = StringBuilder::new(size_hint=utf8_byte_length(source))
  for item in parse_wgsl_directive_scan_items(source) {
    match item.kind() {
      Source => out.write_string(item.source().original_text())
      Directive(_) | GlslVersion(_) =>
        out.write_string(
          blank_wgsl_directive_text_preserving_offsets(
            item.source().original_text(),
          ),
        )
    }
  }
  out.to_string()
}

///|
test "naga-oil directive masking preserves byte offsets and line endings" {
  let source = "#define FLAG\nlet 名 = 1;\r\n#import x::{y}\n"
  let masked = mask_naga_oil_directives_for_wgsl(source)
  inspect(
    utf8_byte_length(masked),
    content=source |> utf8_byte_length |> Int::to_string,
  )
  debug_inspect(masked.contains("#"), content="false")
  debug_inspect(masked.contains("let 名 = 1;"), content="true")
  debug_inspect(masked.contains("\r\n"), content="true")
}

///|
test "naga-oil masking consumes complete multiline grouped imports" {
  let source =
    #|#define_import_path bevy_pbr::ambient
    #|
    #|#import bevy_pbr::{
    #|    lighting::{EnvBRDFApprox, F_AB},
    #|    mesh_view_bindings::lights,
    #|}
    #|fn ambient_light() {}
    #|
  let masked = mask_naga_oil_directives_for_wgsl(source)
  debug_inspect(masked.contains("#import"), content="false")
  debug_inspect(masked.contains("mesh_view_bindings::lights"), content="false")
  debug_inspect(masked.contains("fn ambient_light() {}"), content="true")
  debug_inspect(
    utf8_byte_length(masked),
    content=source |> utf8_byte_length |> Int::to_string,
  )
}
