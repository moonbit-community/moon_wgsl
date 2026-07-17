///|
test "facade exposes preprocessing and composition runtime API" {
  let preprocessor = Preprocessor::default()
  let conditional_source =
    #|#ifdef USE_COLOR
    #|const value: u32 = 2u;
    #|#else
    #|const value: u32 = 1u;
    #|#endif
    #|
  let defs : Map[String, ShaderDefValue] = { "USE_COLOR": Bool(true) }
  let preprocessed = preprocessor.preprocess(conditional_source, defs) catch {
    _ => abort("expected facade preprocess success")
  }
  assert_true(preprocessed.preprocessed_source.contains("2u"))

  let composer = Composer::default()
  let util_source =
    #|#define_import_path test::util
    #|
    #|fn value() -> u32 {
    #|  return 1u;
    #|}
    #|
  composer.register_source("util.wgsl", util_source)
  let root_source =
    #|#import test::util::value
    #|
    #|fn root() -> u32 {
    #|  return value();
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let composed = composer.compose("root.wgsl", WgslComposeOptions::default()) catch {
    err => abort("expected facade compose success: \{err.message()}")
  }
  assert_true(composed.contains("fn value"))
  assert_true(composed.contains("fn root"))

  let prepared = composer.prepare("root.wgsl", WgslComposeOptions::default()) catch {
    err => abort("expected facade prepare success: \{err.message()}")
  }
  assert_true(prepared.source().contains("fn root"))

  let exported = composer.export_wgsl(
    "root.wgsl",
    WgslComposeOptions::default(),
    { root_items: [] },
  ) catch {
    err => abort("expected facade export success: \{err.message()}")
  }
  assert_true(exported.source().contains("fn root"))
  assert_eq(exported.diagnostics().length(), 0)
}

///|
test "facade maps lower-level failures without exposing implementation errors" {
  let composer = Composer::default()
  let mut error_message = ""
  ignore(
    composer.compose("missing.wgsl", WgslComposeOptions::default()) catch {
      error => {
        error_message = error.message()
        ""
      }
    },
  )
  assert_true(error_message.contains("missing.wgsl"))
}
