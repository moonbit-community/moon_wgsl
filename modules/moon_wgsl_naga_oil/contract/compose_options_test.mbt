///|
test "naga-oil contract: default compose options are project-neutral" {
  let options = WgslComposeOptions::default()
  assert_eq(options.defines.length(), 0)
  assert_eq(options.value_defines.length(), 0)
  assert_eq(options.redirects.length(), 0)
  assert_eq(options.additional_imports.length(), 0)
}
