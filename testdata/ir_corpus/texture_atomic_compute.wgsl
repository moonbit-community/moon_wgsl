@group(0) @binding(0)
var image: texture_storage_2d<r32uint, atomic>;

@compute @workgroup_size(1)
fn main(@builtin(global_invocation_id) id: vec3<u32>) {
  let pixel = id.xy;
  textureAtomicMax(image, pixel, 9u);
  textureAtomicMin(image, pixel, 1u);
  textureAtomicAdd(image, pixel, 2u);
  textureAtomicAnd(image, pixel, 0xffu);
  textureAtomicOr(image, pixel, 0x10u);
  textureAtomicXor(image, pixel, 0x03u);
}
