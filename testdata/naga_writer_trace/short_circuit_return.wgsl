fn enabled(flags: u32, mask: u32) -> bool {
  return (flags & mask) != 0u;
}

fn is_enabled_pair(flags: u32, value: u32) -> bool {
  return (enabled(flags, 1u) && value == 1u) ||
    (enabled(flags, 2u) && value == 2u);
}
