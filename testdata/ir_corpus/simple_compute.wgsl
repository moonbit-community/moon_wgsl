@group(0) @binding(0)
var<storage, read_write> buffer: u32;

fn helper(value: u32) -> u32 {
  return value + 1u;
}

@compute @workgroup_size(1, 1, 1)
fn main() {
  var result: u32 = helper(1u);
  result = min(result, 9u);
  buffer = result;
}
