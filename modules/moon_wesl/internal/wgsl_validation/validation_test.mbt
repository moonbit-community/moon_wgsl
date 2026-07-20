///|
test "WGSL validation rejects a user-function arity mismatch" {
  let source =
    #|fn takes_one(value: i32) -> i32 { return value; }
    #|fn main() { let value = takes_one(1i, 2i); }
    #|
  try @wgsl_validation.validate_source(source) catch {
    error => inspect(error.message().contains("takes_one"), content="true")
  } noraise {
    _ => fail("expected WGSL validation to fail")
  }
}

///|
test "WGSL validation rejects a local non-callable" {
  let source = "fn main() { let value = 1i; let out = value(); }\n"
  try @wgsl_validation.validate_source(source) catch {
    _ => ()
  } noraise {
    _ => fail("expected WGSL validation to fail")
  }
}

///|
test "WGSL validation accepts builtin calls and storage formats" {
  let source =
    #|@group(0) @binding(0)
    #|var input: texture_storage_2d<r32float, read>;
    #|fn main() {
    #|  let value = sin(0.0);
    #|  let position = vec4<f32>(value);
    #|}
    #|
  @wgsl_validation.validate_source(source)
}
