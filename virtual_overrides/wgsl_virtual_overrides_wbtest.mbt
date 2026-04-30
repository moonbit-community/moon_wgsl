///|
test "virtual override base detection does not collapse namespace suffixes" {
  let source =
    #|virtual fn func() -> f32 {
    #|  return 1.0;
    #|}
    #|override fn func() -> f32 {
    #|  return other::func();
    #|}
    #|
  let redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let output = apply_wgsl_virtual_overrides_raw(source, redirects)
  debug_inspect(output.invalid_override, content="None")
  debug_inspect(output.source.contains("__virtual_base"), content="false")
  debug_inspect(output.source.contains("return other::func();"), content="true")
}
