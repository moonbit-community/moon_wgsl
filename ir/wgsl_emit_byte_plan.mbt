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
priv enum WgslIrSourceDirectiveBytePolicy {
  EmitSourceDirectives
  SuppressSourceDirectives
}

///|
priv enum WgslIrTrailingBlankBytePolicy {
  KeepTrailingBlankAfterDeclarations
  SuppressTrailingBlankAfterEntryPoint
}

///|
priv enum WgslIrImplicitFlatInterpolationBytePolicy {
  EmitImplicitFlatInterpolation
  SuppressImplicitFlatInterpolation
}

///|
priv enum WgslIrStorageTextureTypeBytePolicy {
  CompactStorageTextureTypeArguments
  SpacedStorageTextureTypeArguments
}

///|
priv enum WgslIrLocalTypeAnnotationBytePolicy {
  AnnotateConcreteLocalTypes
  ElideInferredConcreteLocalTypes
}

///|
priv enum WgslIrAtomicResultLocalAnnotationBytePolicy {
  AnnotateAtomicCompareExchangeResultLocals
  FollowLocalTypeAnnotationPolicy
}

///|
priv enum WgslIrNumericLiteralBytePolicy {
  NagaCompatibleNumericLiteralSpelling
  RuntimeNumericLiteralSpelling
}

///|
priv struct WgslIrWriterBytePlan {
  source_directives : WgslIrSourceDirectiveBytePolicy
  trailing_blank : WgslIrTrailingBlankBytePolicy
  implicit_flat_interpolation : WgslIrImplicitFlatInterpolationBytePolicy
  storage_texture_type_arguments : WgslIrStorageTextureTypeBytePolicy
  local_type_annotations : WgslIrLocalTypeAnnotationBytePolicy
  atomic_result_local_annotations : WgslIrAtomicResultLocalAnnotationBytePolicy
  numeric_literals : WgslIrNumericLiteralBytePolicy
}

///|
fn WgslIrWriterBytePlan::runtime_writer() -> WgslIrWriterBytePlan {
  WgslIrWriterBytePlan::{
    source_directives: EmitSourceDirectives,
    trailing_blank: SuppressTrailingBlankAfterEntryPoint,
    implicit_flat_interpolation: SuppressImplicitFlatInterpolation,
    storage_texture_type_arguments: SpacedStorageTextureTypeArguments,
    local_type_annotations: ElideInferredConcreteLocalTypes,
    atomic_result_local_annotations: FollowLocalTypeAnnotationPolicy,
    numeric_literals: RuntimeNumericLiteralSpelling,
  }
}

///|
fn WgslIrWriterBytePlan::naga_oil_writer() -> WgslIrWriterBytePlan {
  WgslIrWriterBytePlan::{
    source_directives: SuppressSourceDirectives,
    trailing_blank: SuppressTrailingBlankAfterEntryPoint,
    implicit_flat_interpolation: EmitImplicitFlatInterpolation,
    storage_texture_type_arguments: CompactStorageTextureTypeArguments,
    local_type_annotations: AnnotateConcreteLocalTypes,
    atomic_result_local_annotations: AnnotateAtomicCompareExchangeResultLocals,
    numeric_literals: NagaCompatibleNumericLiteralSpelling,
  }
}

///|
fn WgslIrWriterBytePlan::should_emit_source_directives(
  self : WgslIrWriterBytePlan,
) -> Bool {
  match self.source_directives {
    EmitSourceDirectives => true
    SuppressSourceDirectives => false
  }
}

///|
fn WgslIrWriterBytePlan::should_emit_trailing_blank(
  self : WgslIrWriterBytePlan,
  last_item_is_entry_point : Bool,
) -> Bool {
  match self.trailing_blank {
    KeepTrailingBlankAfterDeclarations => true
    SuppressTrailingBlankAfterEntryPoint => !last_item_is_entry_point
  }
}

///|
fn WgslIrWriterBytePlan::should_emit_implicit_flat_interpolation(
  self : WgslIrWriterBytePlan,
) -> Bool {
  match self.implicit_flat_interpolation {
    EmitImplicitFlatInterpolation => true
    SuppressImplicitFlatInterpolation => false
  }
}

///|
fn WgslIrWriterBytePlan::storage_texture_type_separator(
  self : WgslIrWriterBytePlan,
) -> String {
  match self.storage_texture_type_arguments {
    CompactStorageTextureTypeArguments => ","
    SpacedStorageTextureTypeArguments => ", "
  }
}

///|
fn WgslIrWriterBytePlan::should_annotate_all_local_types(
  self : WgslIrWriterBytePlan,
) -> Bool {
  match self.local_type_annotations {
    AnnotateConcreteLocalTypes => true
    ElideInferredConcreteLocalTypes => false
  }
}

///|
fn WgslIrWriterBytePlan::should_annotate_atomic_compare_exchange_result_locals(
  self : WgslIrWriterBytePlan,
) -> Bool {
  match self.atomic_result_local_annotations {
    AnnotateAtomicCompareExchangeResultLocals => true
    FollowLocalTypeAnnotationPolicy => false
  }
}

///|
fn WgslIrWriterBytePlan::numeric_literal_policy(
  self : WgslIrWriterBytePlan,
) -> WgslIrNumericLiteralBytePolicy {
  self.numeric_literals
}
