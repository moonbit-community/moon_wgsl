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
pub fn trace_naga_oil_writer_function_plan_for_source(
  source : String,
  function_name_prefix : String,
) -> String raise WgslIrPipelineError {
  trace_naga_oil_writer_function_plan_for_source_with_generated_imports_and_import_arena_events(
    source,
    [],
    [],
    function_name_prefix,
  )
}

///|
pub fn trace_naga_oil_writer_function_plan_for_source_with_generated_imports_and_import_arena_events(
  source : String,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
  import_arena_events : Array[WgslIrImportArenaEvent],
  function_name_prefix : String,
  root_visible_rel_path? : String = "",
) -> String raise WgslIrPipelineError {
  let module_ = lower_validated_wgsl_source_to_ir_with_generated_imports_and_import_arena_events(
    source,
    generated_import_provenance,
    import_arena_events,
    root_visible_rel_path~,
  )
  let view = build_wgsl_ir_naga_writer_module(module_, None)
  for slot in view.entry_point_slots() {
    let final_name = view.names.get(
      wgsl_ir_emit_name_key("ep", slot.source_index),
    )
    if wgsl_ir_trace_name_matches_exact(final_name, function_name_prefix) ||
      slot.item.name == function_name_prefix {
      return wgsl_ir_naga_writer_entry_point_slot_trace(view, slot)
    }
  }
  for slot in view.function_slots() {
    let final_name = view.names.get(
      wgsl_ir_emit_name_key("fn", slot.source_index),
    )
    if wgsl_ir_trace_name_matches(final_name, function_name_prefix) {
      return wgsl_ir_naga_writer_function_slot_trace(view, slot)
    }
  }
  for slot in view.entry_point_slots() {
    let final_name = view.names.get(
      wgsl_ir_emit_name_key("ep", slot.source_index),
    )
    if wgsl_ir_trace_name_matches(final_name, function_name_prefix) {
      return wgsl_ir_naga_writer_entry_point_slot_trace(view, slot)
    }
  }
  raise Emit("Naga writer trace function not found: \{function_name_prefix}")
}

///|
pub fn trace_naga_oil_writer_module_plan_for_source_with_generated_imports_and_import_arena_events(
  source : String,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
  import_arena_events : Array[WgslIrImportArenaEvent],
  root_visible_rel_path? : String = "",
) -> String raise WgslIrPipelineError {
  let module_ = lower_validated_wgsl_source_to_ir_with_generated_imports_and_import_arena_events(
    source,
    generated_import_provenance,
    import_arena_events,
    root_visible_rel_path~,
  )
  let view = build_wgsl_ir_naga_writer_module(module_, None)
  wgsl_ir_naga_writer_module_plan_trace(view)
}

///|
fn wgsl_ir_trace_name_matches_exact(name : String?, expected : String) -> Bool {
  match name {
    Some(value) => value == expected
    None => false
  }
}

///|
fn wgsl_ir_trace_name_matches(name : String?, prefix : String) -> Bool {
  match name {
    Some(value) => value.has_prefix(prefix)
    None => false
  }
}

///|
fn wgsl_ir_trace_text(value : String?) -> String {
  match value {
    Some(text) =>
      text
      .replace(old="\t", new="\\t")
      .replace(old="\n", new="\\n")
      .replace(old="\r", new="\\r")
    None => "-"
  }
}

///|
fn wgsl_ir_trace_final_name(
  view : WgslIrNagaWriterModule,
  key : String,
) -> String {
  wgsl_ir_trace_text(view.names.get(key))
}

///|
fn wgsl_ir_naga_writer_module_plan_trace(
  view : WgslIrNagaWriterModule,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "module\tdirectives=\{view.source_directives().length()}\ttypes=\{view.type_slots().length()}\tconstants=\{view.constant_slots().length()}\toverrides=\{view.override_slots().length()}\tglobals=\{view.global_variable_slots().length()}\tfunctions=\{view.function_slots().length()}\tentry_points=\{view.entry_point_slots().length()}\tconst_asserts=\{view.const_assert_slots().length()}\n",
  )
  for index in 0..<view.source_directives().length() {
    out.write_string(
      "slot\tdirective\t\{index}\tsource=-\tname=\{wgsl_ir_trace_text(Some(view.source_directives()[index]))}\tfinal=-\troot=emit\n",
    )
  }
  for slot_index in 0..<view.type_slots().length() {
    let slot = view.type_slots()[slot_index]
    out.write_string(
      "slot\ttype\t\{slot_index}\tsource=\{slot.source_index}\tname=\{wgsl_ir_trace_text(slot.item.name)}\tfinal=\{wgsl_ir_trace_final_name(view, wgsl_ir_emit_name_key("type", slot.source_index))}\troot=emit\n",
    )
  }
  for slot_index in 0..<view.constant_slots().length() {
    let slot = view.constant_slots()[slot_index]
    let root = if wgsl_ir_trace_constant_is_inline_only(view, slot.item) {
      "inline"
    } else {
      "emit"
    }
    out.write_string(
      "slot\tconstant\t\{slot_index}\tsource=\{slot.source_index}\tname=\{wgsl_ir_trace_text(slot.item.name)}\tfinal=\{wgsl_ir_trace_final_name(view, wgsl_ir_emit_name_key("const", slot.source_index))}\troot=\{root}\n",
    )
  }
  for slot_index in 0..<view.override_slots().length() {
    let slot = view.override_slots()[slot_index]
    out.write_string(
      "slot\toverride\t\{slot_index}\tsource=\{slot.source_index}\tname=\{wgsl_ir_trace_text(slot.item.name)}\tfinal=\{wgsl_ir_trace_final_name(view, wgsl_ir_emit_name_key("override", slot.source_index))}\troot=emit\n",
    )
  }
  for slot_index in 0..<view.global_variable_slots().length() {
    let slot = view.global_variable_slots()[slot_index]
    out.write_string(
      "slot\tglobal\t\{slot_index}\tsource=\{slot.source_index}\tname=\{wgsl_ir_trace_text(slot.item.name)}\tfinal=\{wgsl_ir_trace_final_name(view, wgsl_ir_emit_name_key("global", slot.source_index))}\troot=emit\n",
    )
  }
  for slot_index in 0..<view.function_slots().length() {
    let slot = view.function_slots()[slot_index]
    out.write_string(
      "slot\tfunction\t\{slot_index}\tsource=\{slot.source_index}\tname=\{wgsl_ir_trace_text(slot.item.name)}\tfinal=\{wgsl_ir_trace_final_name(view, wgsl_ir_emit_name_key("fn", slot.source_index))}\troot=emit\n",
    )
  }
  for slot_index in 0..<view.entry_point_slots().length() {
    let slot = view.entry_point_slots()[slot_index]
    out.write_string(
      "slot\tentry_point\t\{slot_index}\tsource=\{slot.source_index}\tname=\{wgsl_ir_trace_text(Some(slot.item.name))}\tfinal=\{wgsl_ir_trace_final_name(view, wgsl_ir_emit_name_key("ep", slot.source_index))}\troot=emit\n",
    )
  }
  for slot_index in 0..<view.const_assert_slots().length() {
    let slot = view.const_assert_slots()[slot_index]
    out.write_string(
      "slot\tconst_assert\t\{slot_index}\tsource=-\tname=-\tfinal=-\troot=emit\tcondition=\{slot.condition.index()}\n",
    )
  }
  out.to_string()
}

///|
fn wgsl_ir_trace_constant_is_inline_only(
  view : WgslIrNagaWriterModule,
  constant : Constant,
) -> Bool {
  if wgsl_ir_trace_type_contains_abstract_scalar(view, constant.ty) {
    return true
  }
  constant.inline_value ||
  (
    constant.generated_import &&
    wgsl_ir_trace_constant_has_naga_inline_only_type(view, constant)
  )
}

///|
fn wgsl_ir_trace_constant_has_naga_inline_only_type(
  view : WgslIrNagaWriterModule,
  constant : Constant,
) -> Bool {
  match wgsl_ir_trace_type_inner(view, constant.ty) {
    Some(Array(_, _, _)) => true
    _ => false
  }
}

///|
fn wgsl_ir_trace_type_contains_abstract_scalar(
  view : WgslIrNagaWriterModule,
  handle : Handle,
) -> Bool {
  match wgsl_ir_trace_type_inner(view, handle) {
    Some(inner) =>
      wgsl_ir_trace_type_inner_contains_abstract_scalar(view, inner)
    None => false
  }
}

///|
fn wgsl_ir_trace_type_inner_contains_abstract_scalar(
  view : WgslIrNagaWriterModule,
  inner : TypeInner,
) -> Bool {
  match inner {
    Scalar(scalar)
    | Vector(_, scalar)
    | Matrix(_, _, scalar)
    | CooperativeMatrix(_, _, scalar, _)
    | Atomic(scalar)
    | ValuePointer(_, scalar, _) =>
      scalar.kind == AbstractInt || scalar.kind == AbstractFloat
    Pointer(base, _) | Array(base, _, _) | BindingArray(base, _) =>
      wgsl_ir_trace_type_contains_abstract_scalar(view, base)
    Struct(members, _) | PredeclaredStruct(members, _) => {
      for field in members {
        if wgsl_ir_trace_type_contains_abstract_scalar(view, field.ty) {
          return true
        }
      }
      false
    }
    Image(_, _, _) | Sampler(_) | AccelerationStructure(_) | RayQuery(_) =>
      false
  }
}

///|
fn wgsl_ir_trace_type_inner(
  view : WgslIrNagaWriterModule,
  handle : Handle,
) -> TypeInner? {
  for slot in view.type_slots() {
    if slot.source_index == handle.index() {
      return Some(slot.item.inner)
    }
  }
  None
}

///|
fn wgsl_ir_naga_writer_function_slot_trace(
  view : WgslIrNagaWriterModule,
  slot : WgslIrNagaWriterFunctionSlot,
) -> String {
  let name = match
    view.names.get(wgsl_ir_emit_name_key("fn", slot.source_index)) {
    Some(value) => value
    None => "<missing>"
  }
  wgsl_ir_naga_writer_body_plan_trace(
    view,
    "fn:\{name}",
    UserFunction(slot.source_index),
    slot.item,
    slot.function_plan,
  )
}

///|
fn wgsl_ir_naga_writer_entry_point_slot_trace(
  view : WgslIrNagaWriterModule,
  slot : WgslIrNagaWriterEntryPointSlot,
) -> String {
  let name = match
    view.names.get(wgsl_ir_emit_name_key("ep", slot.source_index)) {
    Some(value) => value
    None => "<missing>"
  }
  wgsl_ir_naga_writer_body_plan_trace(
    view,
    "entry:\{name}",
    EntryPointFunction(slot.source_index),
    slot.item.function,
    slot.function_plan,
  )
}

///|
fn wgsl_ir_naga_writer_body_plan_trace(
  view : WgslIrNagaWriterModule,
  label : String,
  origin : WgslIrEmitFunctionOrigin,
  function : Function,
  function_plan : NagaCompatFunctionPlan,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "function\t\{label}\targuments=\{function.arguments.length()}\tlocals=\{function.local_variables.items.length()}\texpressions=\{function.expressions.items.length()}\n",
  )
  out.write_string(function_plan.trace_summary(label))
  out.write_string(function_plan.trace_sections(label))
  for local_index in 0..<function.local_variables.items.length() {
    let local_variable = function.local_variables.items[local_index]
    let init = match local_variable.init {
      Some(handle) => "\{handle.index()}"
      None => "-"
    }
    let name = match local_variable.name {
      Some(value) => value
      None => "-"
    }
    out.write_string(
      "local\t\{label}\t\{local_index}\tname=\{name}\tinit=\{init}\tgenerated=\{local_variable.generated_temporary}\n",
    )
  }
  for expression_index in 0..<function.expressions.items.length() {
    match function.expressions.items[expression_index] {
      FunctionArgument(argument_index) => {
        let final_name = match origin {
          UserFunction(function_index) =>
            view.names.get(
              wgsl_ir_emit_name_key2("fn_arg", function_index, argument_index),
            )
          EntryPointFunction(entry_point_index) =>
            view.names.get(
              wgsl_ir_emit_name_key2(
                "ep_arg", entry_point_index, argument_index,
              ),
            )
        }
        let final_name = match final_name {
          Some(value) => value
          None => "-"
        }
        out.write_string(
          "binding\t\{label}\targument\t\{expression_index}\t\{final_name}\n",
        )
      }
      _ => ()
    }
  }
  for index in 0..<function.expressions.items.length() {
    let handle = Handle::Handle(index)
    let trace = wgsl_ir_emit_expression_temporary_index_trace(
      function, function_plan, handle,
    )
    let temp_name = match
      view.names.get(wgsl_ir_emit_expression_temporary_name_key(origin, handle)) {
      Some(value) => value
      None => "-"
    }
    let materialized = function_plan.contains_materialized_expression(handle)
    let materialized_reason = wgsl_ir_trace_expression_materialization_reason(
      function.expressions.items[index],
      function_plan,
      handle,
    )
    out.write_string(
      "expression\t\{label}\t\{index}\t\{wgsl_ir_trace_expression_kind(function.expressions.items[index])}\tdetail=\{wgsl_ir_trace_expression_detail(function.expressions.items[index])}\tmaterialized=\{materialized}\treason=\{materialized_reason}\tinput=\{index}\ttemp=\{temp_name}\tfinal_index=\{trace.final_index}\tskipped=\{trace.skipped}\tbase=\{trace.base_index}\tadjusted=\{trace.adjusted_base_index}\timplicit_before=\{trace.implicit_expression_slots_before}\tprior_call_projection=\{trace.prior_call_projection_argument_slots}\timplicit_load=\{trace.implicit_naga_load_slots}\treused_resource=\{trace.reused_resource_operand_slots}\tprojected_temp=\{trace.projected_temporary_slots}\n",
    )
  }
  for named in function.named_expressions {
    let final_name = match
      view.names.get(
        wgsl_ir_emit_named_expression_name_key(origin, named.handle),
      ) {
      Some(value) => value
      None => "-"
    }
    out.write_string(
      "named-expression\t\{label}\t\{named.handle.index()}\t\{named.name}\tfinal=\{final_name}\n",
    )
    out.write_string(
      "binding\t\{label}\tnamed\t\{named.handle.index()}\t\{final_name}\n",
    )
  }
  let mut raw_statement_index = 0
  for index in 0..<function.body.statements.length() {
    let statement = function.body.statements[index]
    if wgsl_ir_trace_statement_is_not_naga_raw_body_row(function, statement) {
      continue
    }
    for kind in wgsl_ir_trace_raw_statement_kinds(function, statement) {
      out.write_string(
        "raw-statement\t\{label}\t\{raw_statement_index}\t\{kind}\n",
      )
      raw_statement_index = raw_statement_index + 1
    }
  }
  let local_declaration_order = function_plan.local_declaration_order()
  for order_index in 0..<local_declaration_order.length() {
    let local_index = local_declaration_order[order_index]
    let local_handle = Handle::Handle(local_index)
    let final_name = match
      view.names.get(wgsl_ir_emit_local_name_key(origin, local_handle)) {
      Some(value) => value
      None => "-"
    }
    out.write_string(
      "writer-local-declare\t\{label}\t\{order_index}\tlocal=\{order_index}\tsource_local=\{local_index}\tfinal=\{final_name}\n",
    )
  }
  let statements = function_plan.statement_plan(function, function.body)
  for index in 0..<statements.length() {
    let item = statements[index]
    out.write_string(
      "writer-statement\t\{label}\t\{index}\t\{wgsl_ir_trace_statement_kind(item.statement)}\tskip=\{item.skip}\tblank_before=\{item.blank_before}\n",
    )
  }
  out.to_string()
}

///|
fn wgsl_ir_trace_expression_materialization_reason(
  expression : Expression,
  function_plan : NagaCompatFunctionPlan,
  handle : Handle,
) -> String {
  if !function_plan.contains_materialized_expression(handle) {
    return "-"
  }
  match expression {
    CallResult(_) => "call-result"
    AtomicResult(_, _) => "atomic-result"
    Load(_) => "load"
    _ => "expression"
  }
}

///|
fn wgsl_ir_trace_expression_detail(expression : Expression) -> String {
  match expression {
    Literal(literal) => "literal:\{wgsl_ir_trace_literal(literal)}"
    ZeroValue(ty) => "ty:\{ty.index()}"
    Compose(ty, components) =>
      "ty:\{ty.index()}:components:\{wgsl_ir_trace_handle_list(components)}"
    Splat(_, inner) => "inner:\{inner.index()}"
    Swizzle(_, base, components) =>
      "base:\{base.index()}:components:\{wgsl_ir_trace_swizzle_list(components)}"
    FunctionArgument(index) => "arg:\{index}"
    LocalVariable(handle) => "local:\{handle.index()}"
    GlobalVariable(handle) => "global:\{handle.index()}"
    Constant(handle) => "const:\{handle.index()}"
    Override(handle) => "override:\{handle.index()}"
    CallResult(handle) | FunctionCall(handle, _) => "function:\{handle.index()}"
    Load(pointer) => "pointer:\{pointer.index()}"
    AccessIndex(base, index) => "base:\{base.index()}:index:\{index}"
    Binary(_, left, right) => "left:\{left.index()}:right:\{right.index()}"
    _ => "-"
  }
}

///|
fn wgsl_ir_trace_handle_list(handles : Array[Handle]) -> String {
  let mut out = ""
  for index, handle in handles {
    if index > 0 {
      out = out + ","
    }
    out = out + "\{handle.index()}"
  }
  out
}

///|
fn wgsl_ir_trace_swizzle_list(components : Array[SwizzleComponent]) -> String {
  let mut out = ""
  for index, component in components {
    if index > 0 {
      out = out + ","
    }
    out = out + wgsl_ir_trace_swizzle_component(component)
  }
  out
}

///|
fn wgsl_ir_trace_literal(literal : Literal) -> String {
  match literal {
    F64(value) => "f64:\{value}"
    F32(value) | F32Exact(value) => "f32:\{value.to_double()}"
    F16(value) => "f16:\{value}"
    U16(value) => "u16:\{value}"
    I16(value) => "i16:\{value}"
    U32(value) => "u32:\{value}"
    I32(value) => "i32:\{value}"
    U64(value) => "u64:\{value}"
    I64(value) => "i64:\{value}"
    Bool(value) => "bool:\{value}"
    AbstractInt(value) => "abstract-int:\{value}"
    AbstractFloat(value) => "abstract-float:\{value}"
  }
}

///|
fn wgsl_ir_trace_swizzle_component(component : SwizzleComponent) -> String {
  match component {
    X => "x"
    Y => "y"
    Z => "z"
    W => "w"
  }
}

///|
fn wgsl_ir_trace_expression_kind(expression : Expression) -> String {
  match expression {
    Literal(_) => "Literal"
    Constant(_) => "Constant"
    Override(_) => "Override"
    ZeroValue(_) => "ZeroValue"
    Compose(_, _) => "Compose"
    Access(_, _) => "Access"
    AccessIndex(_, _) => "AccessIndex"
    Component(_, _) => "Component"
    Splat(_, _) => "Splat"
    Swizzle(_, _, _) => "Swizzle"
    FunctionArgument(_) => "FunctionArgument"
    GlobalVariable(_) => "GlobalVariable"
    LocalVariable(_) => "LocalVariable"
    Load(_) => "Load"
    AddressOf(_, _) => "AddressOf"
    AtomicCall(_, _) => "AtomicCall"
    ImageSample(_, _, _, _, _, _, _, _, _) => "ImageSample"
    ImageLoad(_, _, _, _, _) => "ImageLoad"
    ImageQuery(_, _) => "ImageQuery"
    Unary(_, _) => "Unary"
    Binary(_, _, _) => "Binary"
    FunctionCall(_, _) => "FunctionCall"
    Select(_, _, _) => "Select"
    Bitcast(_, _) => "Bitcast"
    Derivative(_, _, _) => "Derivative"
    Relational(_, _) => "Relational"
    Math(_, _, _, _, _) => "Math"
    As(_, _, _) => "As"
    CallResult(_) => "CallResult"
    AtomicResult(_, _) => "AtomicResult"
    WorkGroupUniformLoadResult(_) => "WorkGroupUniformLoadResult"
    WorkGroupUniformLoad(_) => "WorkGroupUniformLoad"
    ArrayLength(_) => "ArrayLength"
    RayQueryInitialize(_, _, _) => "RayQueryInitialize"
    RayQueryProceed(_) => "RayQueryProceed"
    RayQueryGenerateIntersection(_, _) => "RayQueryGenerateIntersection"
    RayQueryConfirmIntersection(_) => "RayQueryConfirmIntersection"
    RayQueryTerminate(_) => "RayQueryTerminate"
    RayQueryVertexPositions(_, _) => "RayQueryVertexPositions"
    RayQueryProceedResult => "RayQueryProceedResult"
    RayQueryGetIntersection(_, _) => "RayQueryGetIntersection"
    SubgroupCall(_, _) => "SubgroupCall"
    SubgroupBallotResult => "SubgroupBallotResult"
    SubgroupOperationResult(_) => "SubgroupOperationResult"
    CooperativeLoad(_, _, _, _) => "CooperativeLoad"
    CooperativeMultiplyAdd(_, _, _) => "CooperativeMultiplyAdd"
  }
}

///|
fn wgsl_ir_trace_raw_statement_kinds(
  function : Function,
  statement : Statement,
) -> Array[String] {
  if wgsl_ir_body_statement_is_hoisted_local_var_initializer_emit(
      function, statement,
    ) {
    return []
  }
  match statement {
    Declare(handle) =>
      if wgsl_ir_trace_declare_is_short_circuit_result_load(function, handle) {
        match function.local_variables.items.get(handle.index()) {
          Some({ init: Some(init), .. }) =>
            ["Emit(\{init.index()}..\{init.index()})"]
          _ => [wgsl_ir_trace_statement_kind(statement)]
        }
      } else {
        [wgsl_ir_trace_statement_kind(statement)]
      }
    Emit(range) => wgsl_ir_trace_emit_range_statement_kinds(function, range)
    _ => [wgsl_ir_trace_statement_kind(statement)]
  }
}

///|
fn wgsl_ir_trace_emit_range_statement_kinds(
  function : Function,
  range : HandleRange,
) -> Array[String] {
  let rows : Array[String] = []
  let mut start : Int? = None
  let mut end : Int? = None
  for index in range.start.index()..<=range.end.index() {
    if wgsl_ir_trace_expression_has_raw_short_circuit_temporary_owner(
        function,
        Handle(index),
      ) {
      wgsl_ir_trace_flush_emit_statement_range(rows, start, end)
      start = None
      end = None
    } else {
      if start == None {
        start = Some(index)
      }
      end = Some(index)
    }
  }
  wgsl_ir_trace_flush_emit_statement_range(rows, start, end)
  rows
}

///|
fn wgsl_ir_trace_expression_has_raw_short_circuit_temporary_owner(
  function : Function,
  handle : Handle,
) -> Bool {
  for local_index in 0..<function.local_variables.items.length() {
    let local_handle = Handle::Handle(local_index)
    match function.local_variables.items.get(local_index) {
      Some({ generated_temporary: true, init: Some(init), .. }) =>
        if init == handle &&
          wgsl_ir_trace_declare_is_short_circuit_result_load(
            function, local_handle,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn wgsl_ir_trace_flush_emit_statement_range(
  rows : Array[String],
  start : Int?,
  end : Int?,
) -> Unit {
  match (start, end) {
    (Some(first), Some(last)) => rows.push("Emit(\{first}..\{last})")
    _ => ()
  }
}

///|
fn wgsl_ir_trace_declare_is_short_circuit_result_load(
  function : Function,
  handle : Handle,
) -> Bool {
  guard function.local_variables.items.get(handle.index())
    is Some({ generated_temporary: true, init: Some(init), .. }) else {
    return false
  }
  guard function.expressions.items.get(init.index()) is Some(Load(pointer)) else {
    return false
  }
  guard function.expressions.items.get(pointer.index())
    is Some(LocalVariable(local_handle)) else {
    return false
  }
  match function.local_variables.items.get(local_handle.index()) {
    Some(local_var) =>
      local_var.kind == Var &&
      !local_var.generated_temporary &&
      local_var.short_circuit_result
    None => false
  }
}

///|
fn wgsl_ir_trace_statement_kind(statement : Statement) -> String {
  match statement {
    Declare(handle) => "Declare(\{handle.index()})"
    Emit(range) => "Emit(\{range.start.index()}..\{range.end.index()})"
    Phony(handle) => "Phony(\{handle.index()})"
    Block(_) => "Block"
    If(_, _, _) => "If"
    Switch(_, _) => "Switch"
    Loop(_, _, _) => "Loop"
    Break => "Break"
    Continue => "Continue"
    Return(_) => "Return"
    ImplicitReturn => "Return"
    Kill => "Kill"
    ConstAssert(_) => "ConstAssert"
    ControlBarrier(_) => "ControlBarrier"
    MemoryBarrier(_) => "MemoryBarrier"
    Store(_, _) => "Store"
    ImageStore(_, _, _, _) => "ImageStore"
    Atomic(_, _, _, _, result) =>
      match result {
        Some(handle) => "Atomic(result=\{handle.index()})"
        None => "Atomic"
      }
    ImageAtomic(_, _, _, _, _) => "ImageAtomic"
    WorkGroupUniformLoad(_, _) => "WorkGroupUniformLoad"
    Call(_, _, result) =>
      match result {
        Some(handle) => "Call(result=\{handle.index()})"
        None => "Call(result=-)"
      }
    RayQuery(_, _) => "RayQuery"
    RayPipelineFunction(_) => "RayPipelineFunction"
    SubgroupBallot(_, _) => "SubgroupBallot"
    SubgroupGather(_, _, _) => "SubgroupGather"
    SubgroupCollectiveOperation(_, _, _, _) => "SubgroupCollectiveOperation"
    CooperativeStore(_, _) => "CooperativeStore"
  }
}

///|
fn wgsl_ir_trace_statement_is_not_naga_raw_body_row(
  function : Function,
  statement : Statement,
) -> Bool {
  match statement {
    Declare(handle) =>
      !wgsl_ir_trace_declare_is_short_circuit_result_load(function, handle)
    _ => false
  }
}
