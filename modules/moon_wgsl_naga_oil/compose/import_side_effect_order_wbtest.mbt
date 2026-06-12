///|
test "selected item full-module side effects follow source import order" {
  let composer = Composer::default()
  let view_source =
    #|#define_import_path test::view
    #|
    #|struct View {
    #|  value: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> view: View;
    #|
  let prepass_source =
    #|#define_import_path test::prepass
    #|
    #|struct PreviousViewUniforms {
    #|  value: f32,
    #|}
    #|
    #|@group(0) @binding(2)
    #|var<uniform> previous_view_uniforms: PreviousViewUniforms;
    #|
  let transforms_source =
    #|#define_import_path test::transforms
    #|#import test::view as view_bindings
    #|#import test::prepass
    #|
    #|fn selected(value: vec3<f32>) -> vec4<f32> {
    #|  return vec4(value, 1.0);
    #|}
    #|
    #|fn view_side_effect(value: vec3<f32>) -> vec4<f32> {
    #|  return vec4(value, view_bindings::view.value);
    #|}
    #|
    #|fn prepass_side_effect(value: vec3<f32>) -> vec4<f32> {
    #|  return vec4(value, prepass::previous_view_uniforms.value);
    #|}
    #|
  let root_source =
    #|#import test::transforms::selected
    #|
    #|fn main() -> vec4<f32> {
    #|  return selected(vec3(1.0));
    #|}
    #|
  composer.register_source("view.wgsl", view_source)
  composer.register_source("prepass.wgsl", prepass_source)
  composer.register_source("transforms.wgsl", transforms_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    compose_test_before(
      emitted, "struct ViewX_naga_oil_mod", "struct PreviousViewUniformsX_naga_oil_mod",
    ),
    content="true",
  )
}

///|
test "root import use order includes naga-oil struct member import uses" {
  let composer = Composer::default()
  let forward_source =
    #|#define_import_path test::forward
    #|
    #|struct VertexOutput {
    #|  value: u32,
    #|}
    #|
    #|struct FragmentOutput {
    #|  color: u32,
    #|}
    #|
  let types_source =
    #|#define_import_path test::types
    #|
    #|struct Material {
    #|  value: u32,
    #|}
    #|
  let bindings_source =
    #|#define_import_path test::bindings
    #|#import test::types::Material
    #|
    #|@group(0) @binding(0)
    #|var<uniform> material: Material;
    #|
  let root_source =
    #|#import test::forward::{FragmentOutput, VertexOutput}
    #|#import test::bindings::material
    #|
    #|struct RootData {
    #|  material: u32,
    #|}
    #|
    #|@fragment
    #|fn fragment(input: VertexOutput) -> FragmentOutput {
    #|  var out: FragmentOutput;
    #|  out.color = material.value + input.value;
    #|  return out;
    #|}
    #|
  composer.register_source("forward.wgsl", forward_source)
  composer.register_source("types.wgsl", types_source)
  composer.register_source("bindings.wgsl", bindings_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_for_naga_oil_writer_parity(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    compose_test_before(
      emitted, "struct MaterialX_naga_oil_mod", "struct VertexOutputX_naga_oil_mod",
    ),
    content="true",
  )
}
