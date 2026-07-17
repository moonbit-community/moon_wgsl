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

///|
test "selected import extraction visits requested roots by Naga arena category" {
  let source =
    #|struct FunctionDep {
    #|  value: u32,
    #|}
    #|
    #|fn imported_fn(value: FunctionDep) -> u32 {
    #|  return value.value;
    #|}
    #|
    #|struct DirectType {
    #|  value: u32,
    #|}
    #|
    #|struct GlobalType {
    #|  value: u32,
    #|}
    #|
    #|var<private> imported_global: GlobalType;
    #|
  let extracted = extract_wgsl_module_item_origins_strict(source, [
    "imported_fn", "DirectType", "imported_global",
  ]) catch {
    error => abort(error.message())
  }
  let direct_type_pos = extracted.source().find("struct DirectType")
  let global_type_pos = extracted.source().find("struct GlobalType")
  let global_pos = extracted.source().find("var<private> imported_global")
  let function_dep_pos = extracted.source().find("struct FunctionDep")
  let function_pos = extracted.source().find("fn imported_fn")
  debug_inspect(
    match
      (
        direct_type_pos, global_type_pos, global_pos, function_dep_pos, function_pos,
      ) {
      (
        Some(direct_type),
        Some(global_type),
        Some(global),
        Some(function_dep),
        Some(function),
      ) =>
        direct_type < global_type &&
        global_type < global &&
        global < function_dep &&
        function_dep < function
      _ => false
    },
    content="true",
  )
}
