///|
test "semantic import reference order follows source spans instead of AST walk order" {
  let source =
    #|fn entry() -> u32 {
    #|  work(first(), second());
    #|  return third();
    #|}
    #|
  let nodes : Array[@ast.WgslIdent] = []
  let unit = parse_wgsl_translation_unit_strict(source) catch {
    error => abort(error.message())
  }
  collect_wgsl_semantic_reference_identifier_nodes_from_unit(unit, nodes)
  let names = nodes.map(fn(node) { node.name() })
  debug_inspect(names.join(","), content="\"u32,work,first,second,third\"")
}

///|
test "naga-oil import-use scanner preserves substitution-position semantics" {
  let source =
    #|@group(0) @binding(0)
    #|var<uniform> material: Material;
    #|// commented::path should not count
    #|fn fragment(input: VertexOutput) -> FragmentOutput {
    #|  let color = material.value + bindings::light.intensity + 1u;
    #|  let text = "ignored::path";
    #|  return FragmentOutput();
    #|}
    #|
  let nodes : Array[@ast.WgslIdent] = []
  collect_wgsl_naga_oil_import_use_identifier_nodes(source, nodes)
  let names = nodes.map(fn(node) { node.name() })
  debug_inspect(names.contains("group"), content="false")
  debug_inspect(names.contains("binding"), content="false")
  debug_inspect(names.contains("material"), content="true")
  debug_inspect(names.contains("value"), content="false")
  debug_inspect(names.contains("bindings::light"), content="true")
  debug_inspect(names.contains("intensity"), content="false")
  debug_inspect(names.contains("commented::path"), content="false")
  debug_inspect(names.contains("ignored::path"), content="false")
  debug_inspect(names.contains("u"), content="true")
}

///|
test "naga-oil import-use scanner drops import directives before scanning" {
  let source =
    #|#import test::util::value
    #|
    #|fn root() -> u32 {
    #|  return value();
    #|}
    #|
  let nodes : Array[@ast.WgslIdent] = []
  collect_wgsl_naga_oil_import_use_identifier_nodes(source, nodes)
  let names = nodes.map(fn(node) { node.name() })
  debug_inspect(names.contains("import"), content="false")
  debug_inspect(names.contains("test::util::value"), content="false")
  debug_inspect(names.contains("root"), content="true")
  debug_inspect(names.contains("value"), content="true")
}
