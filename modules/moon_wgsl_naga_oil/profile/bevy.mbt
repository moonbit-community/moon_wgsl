///|
pub fn bevy_wgsl_value_defines() -> Map[String, @contract.ShaderDefValue] {
  let defines : Map[String, @contract.ShaderDefValue] = Map([])
  defines.set("AVAILABLE_STORAGE_BUFFER_BINDINGS", Int(8))
  defines.set("MAX_DIRECTIONAL_LIGHTS", Int(10))
  defines.set("MAX_CASCADES_PER_LIGHT", Int(4))
  defines.set("MAX_RECT_LIGHTS", Int(4))
  defines.set("MATERIAL_BIND_GROUP", Int(3))
  defines.set("SORTED_FRAGMENT_MAX_COUNT", Int(8))
  defines.set("WORLD_CACHE_SIZE", Int(1048576))
  defines.set("PER_OBJECT_BUFFER_BATCH_SIZE", Int(1))
  defines.set("SCREEN_SPACE_SPECULAR_TRANSMISSION_BLUR_TAPS", Int(8))
  defines
}
