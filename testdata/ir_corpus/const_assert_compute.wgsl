const COUNT: u32 = 4u;
const_assert COUNT == 4u;
const EXACT = 3937509.87755102;
const_assert EXACT != 3937510.0;
const_assert EXACT != 3937509.75;

@compute @workgroup_size(1, 1, 1)
fn main() {
  const_assert COUNT > 0u;
}
