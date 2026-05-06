@compute
fn main() {
  var value: u32 = 0u;
  switch value {
    case 0u, 1u: {
      value = value + 1u;
    }
    default {
      value = 9u;
    }
  }
}
