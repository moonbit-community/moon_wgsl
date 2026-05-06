@compute
fn main() {
  var sum: u32 = 0u;
  for (var i = 0u; i < 4u; i++) {
    sum += i;
  }
  for (sum = 0u; sum < 8u; sum += 1u) {
    sum += 2u;
  }
}
