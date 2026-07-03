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
  let composed = composer.compose_wgsl(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    err => abort("expected facade compose success: \{err.message()}")
  }
  assert_true(composed.contains("fn value"))
  assert_true(composed.contains("fn root"))
}
