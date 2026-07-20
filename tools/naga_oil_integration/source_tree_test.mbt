///|
test "wgsl io: scans a filtered WGSL tree" {
  let files = @wgsl_io.scan_wgsl_source_files(
    moon_wgsl_testdata_path("wgsl_scan"),
    { recursive: true, extensions: [".wgsl"], exclude_prefixes: ["ignored"] },
  ) catch {
    _ => abort("expected WGSL source scan success")
  }
  let rel_paths : Array[String] = []
  for file in files {
    rel_paths.push(file.rel_path)
  }
  rel_paths.sort()
  debug_inspect(
    rel_paths.join(","),
    content="\"effects/main.wgsl,shared/common.wgsl\"",
  )
}

///|
test "wgsl io: checked scan allows duplicate module candidates" {
  let (files, diagnostics) = @wgsl_io.scan_wgsl_source_files_checked(
    moon_wgsl_testdata_path("wgsl_scan_dups"),
    @wgsl_io.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected checked WGSL source scan success")
  }
  debug_inspect(files.length(), content="2")
  debug_inspect(diagnostics.length(), content="0")
}

///|
test "wgsl io: registers a source tree into a composer" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  @wgsl_io.register_source_tree(
    composer,
    moon_wgsl_testdata_path("wgsl_scan"),
    @wgsl_io.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected WGSL source tree registration success")
  }
  let output = composer.compose_wgsl(
    "effects/main.wgsl",
    @contract.WgslComposeOptions::default(),
  ) catch {
    err =>
      abort("expected source-tree-backed compose success: \{err.message()}")
  }
  debug_inspect(
    composer.registered_source("effects/main.wgsl") is Some(_),
    content="true",
  )
  debug_inspect(output.contains("struct SharedValue"), content="true")
  debug_inspect(output.contains("fn build_color"), content="true")
  debug_inspect(output.contains("fn shade"), content="true")
}

///|
test "wgsl io: checked registration preserves existing conflicts" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source(
    "shared/common.wgsl", "#define_import_path demo::shared\nfn shared_value() -> f32 {\n  return 1f;\n}\n",
  )
  let diagnostics = @wgsl_io.register_source_tree_checked(
    composer,
    moon_wgsl_testdata_path("wgsl_scan_conflict"),
    @wgsl_io.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected checked WGSL source tree registration success")
  }
  debug_inspect(diagnostics.length(), content="1")
  debug_inspect(diagnostics[0].severity, content="Error")
  debug_inspect(diagnostics[0].rel_path, content="Some(\"shared/common.wgsl\")")
  debug_inspect(
    composer.registered_source("shared/common.wgsl"),
    content="Some(\"#define_import_path demo::shared\\nfn shared_value() -> f32 {\\n  return 1f;\\n}\\n\")",
  )
}
