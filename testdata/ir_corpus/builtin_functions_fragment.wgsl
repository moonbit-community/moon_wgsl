@fragment
fn main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let dx: vec2f = dpdx(uv);
  let dy: vec2f = dpdyFine(uv);
  let fw: vec2f = fwidthCoarse(uv);
  let packed_a: u32 = pack4x8unorm(vec4f(0.1, 0.2, 0.3, 0.4));
  let packed_b: u32 = pack2x16unorm(vec2f(0.5, 0.25));
  let unpacked_a: vec4f = unpack4x8unorm(packed_a);
  let unpacked_b: vec2f = unpack2x16unorm(packed_b);
  let c: f32 = cosh(uv.x) + sinh(uv.y) + tanh(uv.x) + acosh(2.0) + asinh(uv.x) + atanh(0.5) + radians(90.0) + degrees(1.0);
  return vec4f(unpacked_a.xy + unpacked_b + dx + dy + fw, c, 1.0);
}
