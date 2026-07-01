///|
fn wgsl_ir_expr_ref_is_phony(expr_ref : @ast.WgslExprRef) -> Bool {
  match expr_ref.root() {
    Some(root) =>
      match root.kind() {
        Identifier(name) => name.name() == "_"
        _ => false
      }
    None => false
  }
}

///|
fn wgsl_ir_expr_tokens_are_phony(tokens : Array[@ast.WgslExprToken]) -> Bool {
  match tokens {
    [token] =>
      match token.kind() {
        Identifier => token.text() == "_"
        _ => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_flatten_expression_arguments(
  arguments : Array[@ast.WgslExprNode],
) -> Array[@ast.WgslExprNode] {
  match arguments {
    [single] =>
      match single.kind() {
        Sequence(items) => items
        _ => arguments
      }
    _ => arguments
  }
}

///|
fn wgsl_ir_expr_node_shape(node : @ast.WgslExprNode) -> String {
  match node.kind() {
    Identifier(name) => "identifier \{name.name()}"
    Literal(token) => "literal \{token.text()}"
    ShaderDefTemplate(text) => "shader-def template \{text}"
    Unary(op, inner) => "unary \{op.text()}(\{wgsl_ir_expr_node_shape(inner)})"
    PostfixUpdate(op, inner) =>
      "postfix \{op}(\{wgsl_ir_expr_node_shape(inner)})"
    Assignment(op, left, right) =>
      "assignment \{op}(\{wgsl_ir_expr_node_shape(left)}, \{wgsl_ir_expr_node_shape(right)})"
    Binary(op, left, right) =>
      "binary \{op.text()}(\{wgsl_ir_expr_node_shape(left)}, \{wgsl_ir_expr_node_shape(right)})"
    Call(callee, _) => "call(\{wgsl_ir_expr_node_shape(callee)})"
    Template(base, _) => "template(\{wgsl_ir_expr_node_shape(base)})"
    PathAccess(base, segment) =>
      "path(\{wgsl_ir_expr_node_shape(base)}::\{segment.name()})"
    Member(base, segment) =>
      "member(\{wgsl_ir_expr_node_shape(base)}.\{segment.name()})"
    Index(base, _) => "index(\{wgsl_ir_expr_node_shape(base)})"
    Group(inner) => "group(\{wgsl_ir_expr_node_shape(inner)})"
    Sequence(items) => {
      let parts : Array[String] = []
      let limit = if items.length() < 4 { items.length() } else { 4 }
      for i in 0..<limit {
        parts.push(wgsl_ir_expr_node_shape(items[i]))
      }
      if items.length() > limit {
        parts.push("...")
      }
      let text = parts.join(", ")
      "sequence(\{items.length()}: \{text})"
    }
  }
}
