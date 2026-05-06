@group(0) @binding(0)
var tex: texture_2d<f32>;
@group(0) @binding(1)
var samp: sampler;
@group(0) @binding(2)
var out_tex: texture_storage_2d<rgba8unorm, write>;

@compute
fn main() {
  var uv: vec2f = vec2f(0.5, 0.25);
  var color = textureSampleLevel(tex, samp, uv, 0.0);
  var dims: u32 = textureDimensions(tex).x;
  textureStore(out_tex, vec2u(0u, 0u), color);
}
