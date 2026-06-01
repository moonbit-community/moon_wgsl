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
  raise WgslIrPipelineError::Emit(
    "Naga writer trace function not found: \{function_name_prefix}",
  )
}

///|
fn wgsl_ir_trace_name_matches(name : String?, prefix : String) -> Bool {
  match name {
    Some(value) => value.has_prefix(prefix)
    None => false
  }
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
    slot.body_plan,
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
    slot.body_plan,
  )
}

///|
fn wgsl_ir_naga_writer_body_plan_trace(
  view : WgslIrNagaWriterModule,
  label : String,
  origin : WgslIrEmitFunctionOrigin,
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "function\t\{label}\targuments=\{function.arguments.length()}\tlocals=\{function.local_variables.items.length()}\texpressions=\{function.expressions.items.length()}\n",
  )
  for index in 0..<function.expressions.items.length() {
    let handle = Handle::Handle(index)
    let trace = wgsl_ir_emit_expression_temporary_index_trace(
      function, body_plan, handle,
    )
    let temp_name = match
      view.names.get(wgsl_ir_emit_expression_temporary_name_key(origin, handle)) {
      Some(value) => value
      None => "-"
    }
    out.write_string(
      "expression\t\{label}\t\{index}\t\{wgsl_ir_trace_expression_kind(function.expressions.items[index])}\tmaterialized=\{body_plan.contains_materialized_expression(handle)}\ttemp=\{temp_name}\tfinal_index=\{trace.final_index}\tskipped=\{trace.skipped}\tbase=\{trace.base_index}\tadjusted=\{trace.adjusted_base_index}\timplicit_before=\{trace.implicit_expression_slots_before}\tprior_call_projection=\{trace.prior_call_projection_argument_slots}\timplicit_load=\{trace.implicit_naga_load_slots}\treused_resource=\{trace.reused_resource_operand_slots}\tprojected_temp=\{trace.projected_temporary_slots}\n",
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
  }
  let statements = body_plan.statement_plan(function, function.body)
  for index in 0..<statements.length() {
    let item = statements[index]
    out.write_string(
      "statement\t\{label}\t\{index}\t\{wgsl_ir_trace_statement_kind(item.statement)}\tskip=\{item.skip}\tblank_before=\{item.blank_before}\n",
    )
  }
  out.to_string()
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
    ImplicitReturn => "ImplicitReturn"
    Kill => "Kill"
    ConstAssert(_) => "ConstAssert"
    ControlBarrier(_) => "ControlBarrier"
    MemoryBarrier(_) => "MemoryBarrier"
    Store(_, _) => "Store"
    ImageStore(_, _, _, _) => "ImageStore"
    Atomic(_, _, _, _) => "Atomic"
    ImageAtomic(_, _, _, _, _) => "ImageAtomic"
    WorkGroupUniformLoad(_, _) => "WorkGroupUniformLoad"
    Call(_, _, result) =>
      match result {
        Some(handle) => "Call(result=\{handle.index()})"
        None => "Call"
      }
    RayQuery(_, _) => "RayQuery"
    RayPipelineFunction(_) => "RayPipelineFunction"
    SubgroupBallot(_, _) => "SubgroupBallot"
    SubgroupGather(_, _, _) => "SubgroupGather"
    SubgroupCollectiveOperation(_, _, _, _) => "SubgroupCollectiveOperation"
    CooperativeStore(_, _) => "CooperativeStore"
  }
}
