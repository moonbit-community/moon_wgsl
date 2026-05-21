///|
test "semantic import reference order follows source spans instead of AST walk order" {
  let source =
    #|fn entry() -> u32 {
    #|  work(first(), second());
    #|  return third();
    #|}
    #|
  let nodes : Array[@ast.WgslIdent] = []
  collect_wgsl_semantic_reference_identifier_nodes(source, nodes) catch {
    error => abort(error.message())
  }
  let names = nodes.map(fn(node) { node.name() })
  debug_inspect(names.join(","), content="\"u32,work,first,second,third\"")
}
