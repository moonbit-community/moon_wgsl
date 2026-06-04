// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn WgslIrLowerer::lower_templated_builtin_function_call(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  match callee.kind() {
    Template(base, template_arguments) =>
      match base.kind() {
        Identifier(name) =>
          match name.name() {
            "coopLoad" | "coopLoadT" =>
              Some(
                self.lower_function_cooperative_load_call(
                  name.name(),
                  template_arguments,
                  arguments,
                  function,
                  scope,
                ),
              )
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_function_cooperative_load_call(
  self : WgslIrLowerer,
  name : String,
  template_arguments : Array[@ast.WgslTypeArgument],
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  guard template_arguments is [Type(ty_ref)] else {
    raise UnsupportedExpression(
      "\{name} expects exactly one cooperative matrix type template argument",
    )
  }
  let matrix_ty = self.lower_function_type_ref(ty_ref, function, scope)
  let (columns, rows, _, role) = self.cooperative_matrix_spec_from_type_handle(
    matrix_ty, name,
  )
  let data = self.lower_cooperative_data(
    name,
    arguments,
    0,
    function,
    scope,
    columns,
    rows,
    name == "coopLoadT",
  )
  function.expressions.append(CooperativeLoad(columns, rows, role, data))
}

///|
fn WgslIrLowerer::lower_function_cooperative_multiply_add_call(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [a, b, c] else {
    raise UnsupportedExpression("coopMultiplyAdd expects 3 arguments")
  }
  let a = self.lower_function_expression_node(a, function, scope)
  let b = self.lower_function_expression_node(b, function, scope)
  let c = self.lower_function_expression_node(c, function, scope)
  function.expressions.append(CooperativeMultiplyAdd(a, b, c))
}

///|
fn WgslIrLowerer::lower_cooperative_statement_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool raise WgslIrLowerError {
  match name {
    "coopStore" | "coopStoreT" => {
      let arguments = wgsl_ir_flatten_expression_arguments(arguments)
      guard arguments.length() == 2 || arguments.length() == 3 else {
        raise UnsupportedExpression("\{name} expects 2 or 3 arguments")
      }
      let target = self.lower_function_expression_node(
        arguments[0],
        function,
        scope,
      )
      guard self.function_expression_type(function, target) is Some(ty) else {
        raise MissingType(name)
      }
      let (columns, rows, _, _) = self.cooperative_matrix_spec_from_type_handle(
        ty, name,
      )
      let data = self.lower_cooperative_data(
        name,
        arguments,
        1,
        function,
        scope,
        columns,
        rows,
        name == "coopStoreT",
      )
      block.push(CooperativeStore(target, data))
      true
    }
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_cooperative_data(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  pointer_index : Int,
  function : Function,
  scope : WgslIrFunctionScope,
  columns : CooperativeSize,
  rows : CooperativeSize,
  row_major : Bool,
) -> CooperativeData raise WgslIrLowerError {
  guard arguments.length() == pointer_index + 1 ||
    arguments.length() == pointer_index + 2 else {
    raise UnsupportedExpression("\{name} expects a pointer and optional stride")
  }
  let pointer = self.lower_atomic_pointer_argument(
    arguments[pointer_index],
    function,
    scope,
  )
  let stride = if arguments.length() == pointer_index + 2 {
    self.lower_function_expression_node(
      arguments[pointer_index + 1],
      function,
      scope,
    )
  } else {
    let default_stride = if row_major {
      wgsl_ir_cooperative_size_width(columns)
    } else {
      wgsl_ir_cooperative_size_width(rows)
    }
    function.expressions.append(
      Literal(U32(wgsl_ir_non_negative_int_to_uint(default_stride))),
    )
  }
  { pointer, stride, row_major }
}

///|
fn WgslIrLowerer::cooperative_matrix_spec_from_type_handle(
  self : WgslIrLowerer,
  ty : Handle,
  name : String,
) -> (CooperativeSize, CooperativeSize, Scalar, CooperativeRole) raise WgslIrLowerError {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        CooperativeMatrix(columns, rows, scalar, role) =>
          (columns, rows, scalar, role)
        _ => raise UnsupportedType("\{name} requires a cooperative matrix type")
      }
    None => raise UnsupportedType("\{name} references a missing type")
  }
}

///|
fn WgslIrLowerer::cooperative_data_scalar(
  self : WgslIrLowerer,
  function : Function,
  data : CooperativeData,
) -> Scalar? {
  match self.function_expression_type(function, data.pointer) {
    Some(ty) => self.cooperative_pointer_scalar(ty)
    None => None
  }
}

///|
fn WgslIrLowerer::cooperative_pointer_scalar(
  self : WgslIrLowerer,
  ty : Handle,
) -> Scalar? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(base, _) => self.cooperative_pointer_scalar(base)
        ValuePointer(_, scalar, _) => Some(scalar)
        Scalar(scalar) => Some(scalar)
        _ => None
      }
    None => None
  }
}
