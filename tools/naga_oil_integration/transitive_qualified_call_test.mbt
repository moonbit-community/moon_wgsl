///|
test "github issue 17: transitive module resolves fully qualified call" {
  let composer = @compose.Composer::default()
  let types_source =
    #|#define_import_path test::types
    #|struct Fog { mode: u32 }
    #|
  composer.register_source("types.wgsl", types_source)
  let fog_source =
    #|#define_import_path test::fog
    #|#import test::types::Fog
    #|fn linear_fog(
    #|  fog_params: Fog,
    #|  input_color: vec4<f32>,
    #|  distance: f32,
    #|  scattering: vec3<f32>,
    #|) -> vec4<f32> {
    #|  return input_color;
    #|}
    #|
  composer.register_source("fog.wgsl", fog_source)
  let pbr_functions_source =
    #|#define_import_path test::pbr_functions
    #|#import test::types
    #|#ifdef DISTANCE_FOG
    #|fn apply_fog(
    #|  fog_params: types::Fog,
    #|  input_color: vec4<f32>,
    #|  distance: f32,
    #|  scattering: vec3<f32>,
    #|) -> vec4<f32> {
    #|  return test::fog::linear_fog(
    #|    fog_params, input_color, distance, scattering,
    #|  );
    #|}
    #|#endif
    #|
  composer.register_source("pbr_functions.wgsl", pbr_functions_source)
  let root_source =
    #|#define_import_path test::root
    #|#import test::pbr_functions
    #|#import test::types
    #|fn fragment(
    #|  fog_params: types::Fog,
    #|  input_color: vec4<f32>,
    #|  distance: f32,
    #|  scattering: vec3<f32>,
    #|) -> vec4<f32> {
    #|  return pbr_functions::apply_fog(
    #|    fog_params, input_color, distance, scattering,
    #|  );
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let source = composer.compose_wgsl_runtime_valid(
    "root.wgsl",
    compose_regression_options(
      compose_regression_bool_defines(["DISTANCE_FOG"]),
    ),
  )
  assert_false(source.contains("test::fog::linear_fog"))
}
