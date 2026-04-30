///|
pub fn wgsl_decl_data_name(data : WgslGlobalDeclData) -> String {
  match data {
    Function(function) => function.name.name
    GlobalVariable(global) => global.name.name
    Const(value) => value.name.name
    Override(value) => value.name.name
    Struct(value) => value.name.name
    TypeAlias(value) => value.name.name
    Directive(_) | Import(_) | ConstAssert(_) | Raw => ""
  }
}

///|
fn collect_wgsl_expr_ref_identifier_nodes(
  expr_ref : WgslExprRef?,
  nodes : Array[WgslIdent],
) -> Unit {
  match expr_ref {
    Some(expr) =>
      for ident in expr.identifiers {
        nodes.push(ident)
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
      nodes.push(WgslIdent::{
        name: ty.name,
        start: ty.start,
        end: ty.start + ty.name.length(),
      })
      for argument in ty.arguments {
        collect_wgsl_type_ref_identifier_nodes(Some(argument), nodes)
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
    collect_wgsl_expr_ref_identifier_nodes(attr.arguments_ref, nodes)
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
pub fn collect_wgsl_decl_identifier_nodes(
  data : WgslGlobalDeclData,
  nodes : Array[WgslIdent],
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => {
      collect_wgsl_attribute_identifier_nodes(function.attributes, nodes)
      if function.qualifier == "override" {
        nodes.push(function.name)
      }
      let active_local_names : Array[String] = []
      for argument in function.arguments {
        wgsl_name_list_push_unique(active_local_names, argument.name)
        collect_wgsl_attribute_identifier_nodes(argument.attributes, nodes)
        collect_wgsl_type_ref_identifier_nodes(argument.ty_ref, nodes)
      }
      match function.result {
        Some(result) => {
          collect_wgsl_attribute_identifier_nodes(result.attributes, nodes)
          collect_wgsl_type_ref_identifier_nodes(result.ty_ref, nodes)
        }
        None => ()
      }
      for statement in function.body.statements {
        for ident in statement.identifiers {
          if !wgsl_name_list_contains(active_local_names, ident.name) {
            nodes.push(ident)
          }
        }
        for binding in statement.exported_locals {
          wgsl_name_list_push_unique(active_local_names, binding.name)
        }
      }
    }
    WgslGlobalDeclData::Struct(struct_decl) => {
      collect_wgsl_attribute_identifier_nodes(struct_decl.attributes, nodes)
      for struct_member in struct_decl.members {
        collect_wgsl_attribute_identifier_nodes(struct_member.attributes, nodes)
        collect_wgsl_type_ref_identifier_nodes(struct_member.ty_ref, nodes)
      }
    }
    WgslGlobalDeclData::GlobalVariable(global) => {
      collect_wgsl_attribute_identifier_nodes(global.attributes, nodes)
      collect_wgsl_type_ref_identifier_nodes(global.ty_ref, nodes)
      collect_wgsl_expr_ref_identifier_nodes(global.initializer_ref, nodes)
    }
    WgslGlobalDeclData::Const(const_decl) => {
      collect_wgsl_type_ref_identifier_nodes(const_decl.ty_ref, nodes)
      collect_wgsl_expr_ref_identifier_nodes(const_decl.initializer_ref, nodes)
    }
    WgslGlobalDeclData::Override(override_decl) => {
      collect_wgsl_attribute_identifier_nodes(override_decl.attributes, nodes)
      collect_wgsl_type_ref_identifier_nodes(override_decl.ty_ref, nodes)
      collect_wgsl_expr_ref_identifier_nodes(
        override_decl.initializer_ref,
        nodes,
      )
    }
    WgslGlobalDeclData::TypeAlias(alias_decl) =>
      collect_wgsl_type_ref_identifier_nodes(alias_decl.ty_ref, nodes)
    WgslGlobalDeclData::ConstAssert(expr) =>
      for ident in expr.identifiers {
        nodes.push(ident)
      }
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) | Raw => ()
  }
}

///|
pub fn collect_wgsl_decl_global_declared_identifier_nodes(
  data : WgslGlobalDeclData,
  nodes : Array[WgslIdent],
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => nodes.push(function.name)
    WgslGlobalDeclData::Struct(struct_decl) => nodes.push(struct_decl.name)
    WgslGlobalDeclData::GlobalVariable(global) => nodes.push(global.name)
    WgslGlobalDeclData::Const(const_decl) => nodes.push(const_decl.name)
    WgslGlobalDeclData::Override(override_decl) =>
      nodes.push(override_decl.name)
    WgslGlobalDeclData::TypeAlias(alias_decl) => nodes.push(alias_decl.name)
    WgslGlobalDeclData::Directive(_)
    | WgslGlobalDeclData::Import(_)
    | WgslGlobalDeclData::ConstAssert(_)
    | Raw => ()
  }
}

///|
