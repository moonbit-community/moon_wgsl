///|
test "declaration graph dependency order follows identifier source spans" {
  let source =
    #|fn first() -> u32 {
    #|  return 1u;
    #|}
    #|
    #|fn second() -> u32 {
    #|  return 2u;
    #|}
    #|
    #|fn work(a: u32, b: u32) -> u32 {
    #|  return a + b;
    #|}
    #|
    #|fn entry() -> u32 {
    #|  return work(first(), second());
    #|}
    #|
  let extracted = extract_wgsl_module_item_origins_strict(source, ["entry"]) catch {
    error => abort(error.message())
  }
  let first_pos = extracted.source().find("fn first")
  let second_pos = extracted.source().find("fn second")
  let work_pos = extracted.source().find("fn work")
  debug_inspect(
    match (work_pos, first_pos, second_pos) {
      (Some(work), Some(first), Some(second)) => work < first && first < second
      _ => false
    },
    content="true",
  )
}
