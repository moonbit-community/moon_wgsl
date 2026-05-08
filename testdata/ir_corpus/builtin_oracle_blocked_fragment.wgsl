@fragment
fn main(@location(0) x: f32) -> @location(0) vec4f {
  let m: mat2x2f = mat2x2f(1.0, 0.0, 0.0, 1.0);
  let im: mat2x2f = inverse(m);
  let q: f32 = quantizeToF16(x);
  let p: u32 = pack2x16float(vec2f(x, 1.0));
  let u: vec2f = unpack2x16float(p);
  let b: bool = isNan(x) || isInf(x);
  subgroupBarrier();
  let r: f32 = im[0][0] + q + u.x + select(0.0, 1.0, b);
  return vec4f(r, r, r, 1.0);
}
