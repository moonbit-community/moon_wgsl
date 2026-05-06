#import ir_corpus::inc::helper

@group(0) @binding(0)
var<storage, read_write> buffer: u32;

@compute @workgroup_size(1, 1, 1)
fn main() {
  var result: u32 = helper(1u);
  buffer = result;
}
