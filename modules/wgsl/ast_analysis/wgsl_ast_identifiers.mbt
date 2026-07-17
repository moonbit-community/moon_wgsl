///|
pub fn wgsl_decl_data_name(data : WgslGlobalDeclData) -> String {
  match data {
    Function(function) => function.name().name()
    GlobalVariable(global) => global.name().name()
    Const(value) => value.name().name()
    Override(value) => value.name().name()
    Struct(value) => value.name().name()
    TypeAlias(value) => value.name().name()
    Directive(_) | ConstAssert(_) | Raw => ""
  }
}

///|
fn collect_wgsl_expr_ref_identifier_nodes(
  expr_ref : WgslExprRef?,
  nodes : Array[WgslIdent],
) -> Unit {
  match expr_ref {
    Some(expr) =>
      match expr.root() {
        Some(root) => collect_wgsl_expr_node_identifier_nodes(root, [], nodes)
        None =>
          for ident in expr.identifiers() {
            nodes.push(ident)
          }
      }
    None => ()
  }
}

///|
fn collect_wgsl_expr_node_identifier_nodes(
  node : WgslExprNode,
  active_local_names : Array[String],
  nodes : Array[WgslIdent],
) -> Unit {
  match node.kind() {
    Identifier(ident) =>
      if !wgsl_name_list_contains(active_local_names, ident.name()) {
        nodes.push(ident)
      }
    Literal(_) | ShaderDefTemplate(_) => ()
    Unary(_, expr) =>
      collect_wgsl_expr_node_identifier_nodes(expr, active_local_names, nodes)
    PostfixUpdate(_, expr) =>
      collect_wgsl_expr_node_identifier_nodes(expr, active_local_names, nodes)
    Assignment(_, lhs, rhs) => {
      collect_wgsl_expr_node_identifier_nodes(lhs, active_local_names, nodes)
      collect_wgsl_expr_node_identifier_nodes(rhs, active_local_names, nodes)
    }
    Binary(_, lhs, rhs) => {
      collect_wgsl_expr_node_identifier_nodes(lhs, active_local_names, nodes)
      collect_wgsl_expr_node_identifier_nodes(rhs, active_local_names, nodes)
    }
    Call(callee, args) => {
      collect_wgsl_expr_node_identifier_nodes(callee, active_local_names, nodes)
      for arg in args {
        collect_wgsl_expr_node_identifier_nodes(arg, active_local_names, nodes)
      }
    }
    Template(callee, args) => {
      collect_wgsl_expr_node_identifier_nodes(callee, active_local_names, nodes)
      for arg in args {
        match arg {
          Type(ty) => collect_wgsl_type_ref_identifier_nodes(Some(ty), nodes)
          Expression(expr) =>
            collect_wgsl_expr_ref_identifier_nodes_with_scope(
              Some(expr),
              active_local_names,
              nodes,
            )
        }
      }
    }
    PathAccess(base, segment) => {
      let base_path = wgsl_expr_node_path_name(base)
      let full_name = if base_path == "" {
        segment.name()
      } else {
        "\{base_path}::\{segment.name()}"
      }
      if !wgsl_name_list_contains(active_local_names, full_name) {
        nodes.push(WgslIdent(full_name, base.start(), segment.end()))
      }
    }
    Member(base, _) =>
      collect_wgsl_expr_node_identifier_nodes(base, active_local_names, nodes)
    Index(base, index) => {
      collect_wgsl_expr_node_identifier_nodes(base, active_local_names, nodes)
      collect_wgsl_expr_node_identifier_nodes(index, active_local_names, nodes)
    }
    Group(expr) =>
      collect_wgsl_expr_node_identifier_nodes(expr, active_local_names, nodes)
    Sequence(items) =>
      for item in items {
        collect_wgsl_expr_node_identifier_nodes(item, active_local_names, nodes)
      }
  }
}

///|
fn wgsl_expr_node_path_name(node : WgslExprNode) -> String {
  match node.kind() {
    Identifier(ident) => ident.name()
    PathAccess(base, segment) => {
      let base_path = wgsl_expr_node_path_name(base)
      if base_path == "" {
        segment.name()
      } else {
        "\{base_path}::\{segment.name()}"
      }
    }
    _ => ""
  }
}

///|
fn collect_wgsl_expr_ref_identifier_nodes_with_scope(
  expr_ref : WgslExprRef?,
  active_local_names : Array[String],
  nodes : Array[WgslIdent],
) -> Unit {
  match expr_ref {
    Some(expr) =>
      match expr.root() {
        Some(root) =>
          collect_wgsl_expr_node_identifier_nodes(
            root, active_local_names, nodes,
          )
        None =>
          for ident in expr.identifiers() {
            if !wgsl_name_list_contains(active_local_names, ident.name()) {
              nodes.push(ident)
            }
          }
      }
    None => ()
  }
}

///|
fn collect_wgsl_type_ref_identifier_nodes(
  ty_ref : WgslTypeRef?,
  nodes : Array[WgslIdent],
) -> Unit {
  match ty_ref {
    Some(ty) => {
      match ty.atom().identifier() {
        Some(identifier) => nodes.push(identifier)
        None => ()
      }
      for argument in ty.template_arguments() {
        match argument {
          Type(ty) => collect_wgsl_type_ref_identifier_nodes(Some(ty), nodes)
          Expression(expr) =>
            collect_wgsl_expr_ref_identifier_nodes(Some(expr), nodes)
        }
      }
    }
    None => ()
  }
}

///|
fn collect_wgsl_attribute_identifier_nodes(
  attributes : Array[WgslAttribute],
  nodes : Array[WgslIdent],
) -> Unit {
  for attr in attributes {
    collect_wgsl_expr_ref_identifier_nodes(attr.arguments_ref(), nodes)
  }
}

///|
fn wgsl_name_list_contains(names : Array[String], name : String) -> Bool {
  for existing in names {
    if existing == name {
      return true
    }
  }
  false
}

///|
fn wgsl_name_list_push_unique(names : Array[String], name : String) -> Unit {
  if name == "" || wgsl_name_list_contains(names, name) {
    return
  }
  names.push(name)
}

///|
fn wgsl_name_list_copy(names : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  for name in names {
    copied.push(name)
  }
  copied
}

///|
fn collect_wgsl_local_binding_identifier_nodes_with_scope(
  binding : WgslLocalDeclaration,
  active_local_names : Array[String],
  nodes : Array[WgslIdent],
) -> Unit {
  for argument in binding.template_list() {
    collect_wgsl_type_ref_identifier_nodes(Some(argument), nodes)
  }
  collect_wgsl_type_ref_identifier_nodes(binding.ty_ref(), nodes)
  collect_wgsl_expr_ref_identifier_nodes_with_scope(
    binding.initializer_ref(),
    active_local_names,
    nodes,
  )
}

///|
fn collect_wgsl_statement_identifier_nodes_with_scope(
  statement : WgslStatement,
  active_local_names : Array[String],
  nodes : Array[WgslIdent],
) -> Unit {
  for binding in statement.local_bindings() {
    collect_wgsl_local_binding_identifier_nodes_with_scope(
      binding, active_local_names, nodes,
    )
  }
  let block_local_names = wgsl_name_list_copy(active_local_names)
  for binding in statement.local_bindings() {
    wgsl_name_list_push_unique(block_local_names, binding.name().name())
  }
  for expr_ref in statement.expression_refs() {
    collect_wgsl_expr_ref_identifier_nodes_with_scope(
      Some(expr_ref),
      block_local_names,
      nodes,
    )
  }
  for block in statement.blocks() {
    collect_wgsl_block_identifier_nodes_with_scope(
      block, block_local_names, nodes,
    )
  }
}

///|
fn collect_wgsl_block_identifier_nodes_with_scope(
  block : WgslBlock,
  inherited_local_names : Array[String],
  nodes : Array[WgslIdent],
) -> Unit {
  let active_local_names = wgsl_name_list_copy(inherited_local_names)
  for statement in block.statements() {
    collect_wgsl_statement_identifier_nodes_with_scope(
      statement, active_local_names, nodes,
    )
    for binding in statement.exported_local_bindings() {
      wgsl_name_list_push_unique(active_local_names, binding.name().name())
    }
  }
}

///|
pub fn collect_wgsl_function_body_identifier_nodes(
  function : WgslFunction,
  nodes : Array[WgslIdent],
) -> Unit {
  let active_local_names : Array[String] = []
  for argument in function.arguments() {
    wgsl_name_list_push_unique(active_local_names, argument.name().name())
  }
  collect_wgsl_block_identifier_nodes_with_scope(
    function.body(),
    active_local_names,
    nodes,
  )
}

///|
pub fn collect_wgsl_decl_identifier_nodes(
  data : WgslGlobalDeclData,
  nodes : Array[WgslIdent],
) -> Unit {
  match data {
    Function(function) => {
      collect_wgsl_attribute_identifier_nodes(function.attributes(), nodes)
      if function.qualifier() == Some(Override) {
        nodes.push(function.name())
      }
      let active_local_names : Array[String] = []
      for argument in function.arguments() {
        wgsl_name_list_push_unique(active_local_names, argument.name().name())
        collect_wgsl_attribute_identifier_nodes(argument.attributes(), nodes)
        collect_wgsl_type_ref_identifier_nodes(argument.ty_ref(), nodes)
      }
      match function.result() {
        Some(result) => {
          collect_wgsl_attribute_identifier_nodes(result.attributes(), nodes)
          collect_wgsl_type_ref_identifier_nodes(result.ty_ref(), nodes)
        }
        None => ()
      }
      collect_wgsl_block_identifier_nodes_with_scope(
        function.body(),
        active_local_names,
        nodes,
      )
    }
    Struct(struct_decl) => {
      collect_wgsl_attribute_identifier_nodes(struct_decl.attributes(), nodes)
      for struct_member in struct_decl.members() {
        collect_wgsl_attribute_identifier_nodes(
          struct_member.attributes(),
          nodes,
        )
        collect_wgsl_type_ref_identifier_nodes(struct_member.ty_ref(), nodes)
      }
    }
    GlobalVariable(global) => {
      collect_wgsl_attribute_identifier_nodes(global.attributes(), nodes)
      for argument in global.template_list() {
        collect_wgsl_type_ref_identifier_nodes(Some(argument), nodes)
      }
      collect_wgsl_type_ref_identifier_nodes(global.ty_ref(), nodes)
      collect_wgsl_expr_ref_identifier_nodes(global.initializer_ref(), nodes)
    }
    Const(const_decl) => {
      collect_wgsl_type_ref_identifier_nodes(const_decl.ty_ref(), nodes)
      collect_wgsl_expr_ref_identifier_nodes(
        const_decl.initializer_ref(),
        nodes,
      )
    }
    Override(override_decl) => {
      collect_wgsl_attribute_identifier_nodes(override_decl.attributes(), nodes)
      collect_wgsl_type_ref_identifier_nodes(override_decl.ty_ref(), nodes)
      collect_wgsl_expr_ref_identifier_nodes(
        override_decl.initializer_ref(),
        nodes,
      )
    }
    TypeAlias(alias_decl) =>
      collect_wgsl_type_ref_identifier_nodes(alias_decl.ty_ref(), nodes)
    ConstAssert(expr) =>
      collect_wgsl_expr_ref_identifier_nodes(Some(expr), nodes)
    Directive(_) | Raw => ()
  }
}

///|
pub fn collect_wgsl_decl_global_declared_identifier_nodes(
  data : WgslGlobalDeclData,
  nodes : Array[WgslIdent],
) -> Unit {
  match data {
    Function(function) => nodes.push(function.name())
    Struct(struct_decl) => nodes.push(struct_decl.name())
    GlobalVariable(global) => nodes.push(global.name())
    Const(const_decl) => nodes.push(const_decl.name())
    Override(override_decl) => nodes.push(override_decl.name())
    TypeAlias(alias_decl) => nodes.push(alias_decl.name())
    Directive(_) | ConstAssert(_) | Raw => ()
  }
}

///|
