///|
test "define import path ignores comments" {
  let path = wgsl_source_define_import_path(
    "// #define_import_path wrong::module\n#define_import_path right::module\n",
  )
  inspect(path == Some("right::module"), content="true")
}

///|
test "define import path keeps semicolon like upstream capture" {
  let path = wgsl_source_define_import_path(
    "#define_import_path bevy::render;\n",
  )
  inspect(path == Some("bevy::render;"), content="true")
}

///|
