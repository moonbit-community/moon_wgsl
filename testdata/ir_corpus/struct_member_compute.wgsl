struct Item {
  weight: u32,
  count: u32,
}

@compute
fn main() {
  var item: Item = Item(1u, 2u);
  var weight: u32 = item.weight;
  item.count = weight;
}
