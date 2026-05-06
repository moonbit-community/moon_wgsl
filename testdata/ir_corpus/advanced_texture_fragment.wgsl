@group(0) @binding(0)
var tex: texture_2d<f32>;
@group(0) @binding(1)
var tex_arr: texture_2d_array<f32>;
@group(0) @binding(2)
var depth_tex: texture_depth_2d;
@group(0) @binding(3)
var depth_arr: texture_depth_2d_array;
@group(0) @binding(4)
var samp: sampler;
@group(0) @binding(5)
var cmp_samp: sampler_comparison;

@fragment
fn fragment() -> @location(0) vec4f {
  let uv: vec2f = vec2f(0.5, 0.25);
  let dx: vec2f = vec2f(0.01, 0.0);
  let dy: vec2f = vec2f(0.0, 0.01);
  var color = textureSampleBias(tex, samp, uv, 0.25, vec2i(0i, 0i));
  color = color + textureSampleGrad(tex, samp, uv, dx, dy, vec2i(0i, 0i));
  color = color + textureSampleLevel(tex_arr, samp, uv, 0u, 1.0, vec2i(0i, 0i));
  let count: u32 = textureNumLevels(tex) + textureDimensions(tex).x;
  let cmp: f32 = textureSampleCompare(depth_tex, cmp_samp, uv, 0.5, vec2i(0i, 0i));
  let cmp0: f32 = textureSampleCompareLevel(depth_tex, cmp_samp, uv, 0.5, vec2i(0i, 0i));
  color = color + textureGather(1u, tex, samp, uv, vec2i(0i, 0i));
  color = color + textureGather(depth_tex, samp, uv, vec2i(0i, 0i));
  color = color + textureGatherCompare(depth_arr, cmp_samp, uv, 0u, 0.5, vec2i(0i, 0i));
  return color + vec4f(f32(count) * 0.0 + cmp + cmp0);
}
