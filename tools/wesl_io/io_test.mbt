///|
test "wesl io: file resolver reads wesl and falls back to wgsl" {
  let resolver = FileResolver::new(
    "../modules/moon_wesl/testdata/upstream/bevy",
  )
  let wesl_source = resolver.resolve_source(
    @moon_wesl.ModulePath::from_path("/custom_material"),
  )
  inspect(wesl_source.contains("make_polka_dots"), content="true")
  let wgsl_source = resolver.resolve_source(
    @moon_wesl.ModulePath::from_path("/custom_material_import"),
  )
  inspect(wgsl_source.contains("COLOR_MULTIPLIER"), content="true")
}

///|
test "wesl io: file resolver compiles local imports" {
  let resolver = FileResolver::new(
    "../modules/moon_wesl/testdata/upstream/bevy",
  )
  let compiled = @moon_wesl.compile(
    @moon_wesl.ModulePath::from_path("/custom_material"),
    resolver,
    @moon_wesl.EscapeMangler::default(),
    { ..@moon_wesl.CompileOptions::default(), keep_root: true },
  )
  inspect(
    compiled.to_string().contains("fn package_util__2make_polka_dots"),
    content="true",
  )
}

///|
fn ensure_dir(path : String) -> Unit {
  if !@fs.path_exists(path) {
    try! @fs.create_dir(path)
  }
}

///|
test "wesl io: scans packages and writes generated artifacts" {
  let base = "_build/wesl_io_fixture"
  let root = base + "/shaders"
  ensure_dir("_build")
  ensure_dir(base)
  ensure_dir(root)
  try! @fs.write_string_to_file(
    root + ".wesl",
    "fn root_value() -> f32 { return 1.0; }\n",
  )
  try! @fs.write_string_to_file(
    root + "/util.wesl",
    "fn make_value() -> f32 { return 2.0; }\n",
  )
  let pkg = scan_package(@moon_wesl.PkgBuilder::new("demo-crate"), root).validate()
  let artifact_path = base + "/demo_artifact.mbt.txt"
  write_package_artifact(pkg, artifact_path)
  let artifact = try! @fs.read_file_to_string(artifact_path)
  inspect(artifact.contains("demo_crate"), content="true")
  let resolver = @moon_wesl.PkgResolver::new()
  resolver.add_package(pkg.to_codegen_pkg())
  inspect(
    resolver
    .resolve_source(try! @moon_wesl.parse_module_path("demo_crate::util"))
    .contains("fn make_value()"),
    content="true",
  )
}
