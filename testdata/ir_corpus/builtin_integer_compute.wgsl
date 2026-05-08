@compute @workgroup_size(1)
fn main() {
  let a: u32 = 0x12345678u;
  let b: u32 = 3u;
  let i: i32 = -17i;
  let v: vec4u = vec4u(1u, 2u, 3u, 4u);
  let vi: vec4i = vec4i(1i, 2i, 3i, 4i);

  let bit_sum: u32 = countTrailingZeros(a) + countLeadingZeros(a) + countOneBits(a) + reverseBits(a) + extractBits(a, 4u, 8u) + insertBits(a, b, 4u, 2u) + u32(firstTrailingBit(a)) + u32(firstLeadingBit(i));
  let dot_i: i32 = dot4I8Packed(0u, 1u);
  let dot_u: u32 = dot4U8Packed(0u, 1u);

  let p0: u32 = pack4x8snorm(vec4f(0.0, 0.25, -0.25, 1.0));
  let p1: u32 = pack4x8unorm(vec4f(0.0, 0.25, 0.5, 1.0));
  let p2: u32 = pack2x16snorm(vec2f(0.0, -0.5));
  let p3: u32 = pack2x16unorm(vec2f(0.25, 0.5));
  let p5: u32 = pack4xI8(vi);
  let p6: u32 = pack4xU8(v);
  let p7: u32 = pack4xI8Clamp(vi);
  let p8: u32 = pack4xU8Clamp(v);

  let u0: vec4f = unpack4x8snorm(p0);
  let u1: vec4f = unpack4x8unorm(p1);
  let u2: vec2f = unpack2x16snorm(p2);
  let u3: vec2f = unpack2x16unorm(p3);
  let u5: vec4i = unpack4xI8(p5);
  let u6: vec4u = unpack4xU8(p6);
  let sum: u32 = bit_sum + dot_u + u32(dot_i) + p7 + p8 + u6.x + u32(u5.x) + u32(u0.x + u1.x + u2.x + u3.x);
}
