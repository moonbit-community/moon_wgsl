@compute @workgroup_size(1)
fn main() {
  let dot_i: i32 = dot4I8Packed(0u, 1u);
  let dot_u: u32 = dot4U8Packed(0u, 1u);
  let packed_u: u32 = pack4xU8(vec4u(1u, 2u, 3u, 4u));
  let packed_i: u32 = pack4xI8(vec4i(1i, 2i, 3i, 4i));
  let unpacked_u: vec4u = unpack4xU8(packed_u);
  let unpacked_i: vec4i = unpack4xI8(packed_i);
  let sum: u32 = dot_u + unpacked_u.x + u32(unpacked_i.x) + u32(dot_i);
}
