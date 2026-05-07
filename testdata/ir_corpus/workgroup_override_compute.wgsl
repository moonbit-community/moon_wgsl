const WIDTH: u32 = max(1u, 4u - 1u);
@id(0) override HEIGHT: u32 = 8u;

@compute @workgroup_size(WIDTH, HEIGHT, 1)
fn main(@builtin(global_invocation_id) id: vec3u) {
  let value = id.x + HEIGHT;
}
