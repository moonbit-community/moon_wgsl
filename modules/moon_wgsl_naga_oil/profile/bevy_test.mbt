///|
test "naga-oil profile: Bevy values are selected explicitly" {
  let defines = bevy_wgsl_value_defines()
  assert_eq(defines.get("MATERIAL_BIND_GROUP"), Some(Int(3)))
  assert_eq(defines.get("MAX_DIRECTIONAL_LIGHTS"), Some(Int(10)))
}
