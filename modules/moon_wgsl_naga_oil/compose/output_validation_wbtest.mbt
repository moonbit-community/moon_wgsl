///|
test "compose output deduplicates identical generated declarations" {
  let source =
    #|struct Shared {
    #|  value: f32,
    #|}
    #|
    #|fn first() -> Shared {
    #|  return Shared(1.0);
    #|}
    #|
    #|struct Shared {
    #|  value: f32,
    #|}
    #|
    #|fn second() -> Shared {
    #|  return Shared(2.0);
    #|}
    #|
  let output = deduplicate_identical_wgsl_declarations(source) catch {
    error => abort(error.message())
  }
  inspect(
    output,
    content=(
      #|struct Shared {
      #|  value: f32,
      #|}
      #|
      #|fn first() -> Shared {
      #|  return Shared(1.0);
      #|}
      #|
      #|
      #|
      #|fn second() -> Shared {
      #|  return Shared(2.0);
      #|}
      #|
    ),
  )
}

///|
test "compose output rejects conflicting declarations" {
  let source =
    #|struct Shared {
    #|  value: f32,
    #|}
    #|
    #|struct Shared {
    #|  value: u32,
    #|}
    #|
  let message = try {
    ignore(deduplicate_identical_wgsl_declarations(source))
    "accepted"
  } catch {
    error => error.message()
  }
  inspect(
    message,
    content=(
      #|invalid WGSL syntax at 33: conflicting declarations for `Shared` after shader import composition
    ),
  )
}
