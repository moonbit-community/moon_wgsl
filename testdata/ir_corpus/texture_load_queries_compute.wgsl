@group(0) @binding(0)
var ms_tex: texture_multisampled_2d<f32>;
@group(0) @binding(1)
var arr_tex: texture_2d_array<f32>;
@group(0) @binding(2)
var storage_arr: texture_storage_2d_array<rgba8unorm, read>;

@compute
fn main() {
  let coords: vec2u = vec2u(0u, 0u);
  let ms_color = textureLoad(ms_tex, coords, 0u);
  let arr_color = textureLoad(arr_tex, coords, 0u, 0u);
  let storage_color = textureLoad(storage_arr, coords, 0u);
  let count: u32 = textureNumSamples(ms_tex) + textureNumLayers(arr_tex) + textureNumLayers(storage_arr);
}
