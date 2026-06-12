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
priv enum WgslIrNumericLiteralBytePolicy {
  CompatNumericLiteralSpelling
  RuntimeNumericLiteralSpelling
}

///|
priv enum WgslIrEntryPointAttributeLineBytePolicy {
  EmitTrailingSpaceAfterEntryPointAttributes
  SuppressTrailingSpaceAfterEntryPointAttributes
}

///|
priv enum WgslIrStoragePointerAccessBytePolicy {
  EmitStoragePointerReadAccess
  ElideStoragePointerReadAccess
}

///|
priv enum WgslIrPointerDereferenceBytePolicy {
  PrefixPointerDereference
  ParenthesizedPointerDereference
}

///|
priv enum WgslIrAddressOfBytePolicy {
  PrefixAddressOf
  ParenthesizedAddressOf
}

///|
priv struct WgslIrWriterBytePlan {
  source_directives : WgslIrSourceDirectiveBytePolicy
  trailing_blank : WgslIrTrailingBlankBytePolicy
  implicit_flat_interpolation : WgslIrImplicitFlatInterpolationBytePolicy
  storage_texture_type_arguments : WgslIrStorageTextureTypeBytePolicy
  local_type_annotations : WgslIrLocalTypeAnnotationBytePolicy
  numeric_literals : WgslIrNumericLiteralBytePolicy
  entry_point_attribute_line : WgslIrEntryPointAttributeLineBytePolicy
  storage_pointer_access : WgslIrStoragePointerAccessBytePolicy
  pointer_dereference : WgslIrPointerDereferenceBytePolicy
  address_of : WgslIrAddressOfBytePolicy
}

///|
fn WgslIrWriterBytePlan::runtime_writer() -> WgslIrWriterBytePlan {
  {
    source_directives: EmitSourceDirectives,
    trailing_blank: SuppressTrailingBlankAfterEntryPoint,
    implicit_flat_interpolation: SuppressImplicitFlatInterpolation,
    storage_texture_type_arguments: SpacedStorageTextureTypeArguments,
    local_type_annotations: ElideInferredConcreteLocalTypes,
    numeric_literals: RuntimeNumericLiteralSpelling,
    entry_point_attribute_line: SuppressTrailingSpaceAfterEntryPointAttributes,
    storage_pointer_access: EmitStoragePointerReadAccess,
    pointer_dereference: PrefixPointerDereference,
    address_of: PrefixAddressOf,
  }
}

///|
fn WgslIrWriterBytePlan::compat_writer() -> WgslIrWriterBytePlan {
  {
    source_directives: SuppressSourceDirectives,
    trailing_blank: SuppressTrailingBlankAfterEntryPoint,
    implicit_flat_interpolation: EmitImplicitFlatInterpolation,
    storage_texture_type_arguments: CompactStorageTextureTypeArguments,
    local_type_annotations: AnnotateConcreteLocalTypes,
    numeric_literals: CompatNumericLiteralSpelling,
    entry_point_attribute_line: EmitTrailingSpaceAfterEntryPointAttributes,
    storage_pointer_access: ElideStoragePointerReadAccess,
    pointer_dereference: ParenthesizedPointerDereference,
    address_of: ParenthesizedAddressOf,
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
fn WgslIrWriterBytePlan::numeric_literal_policy(
  self : WgslIrWriterBytePlan,
) -> WgslIrNumericLiteralBytePolicy {
  self.numeric_literals
}

///|
fn WgslIrWriterBytePlan::should_emit_trailing_space_after_entry_point_attributes(
  self : WgslIrWriterBytePlan,
) -> Bool {
  match self.entry_point_attribute_line {
    EmitTrailingSpaceAfterEntryPointAttributes => true
    SuppressTrailingSpaceAfterEntryPointAttributes => false
  }
}

///|
fn WgslIrWriterBytePlan::should_elide_storage_pointer_read_access(
  self : WgslIrWriterBytePlan,
) -> Bool {
  match self.storage_pointer_access {
    EmitStoragePointerReadAccess => false
    ElideStoragePointerReadAccess => true
  }
}

///|
fn WgslIrWriterBytePlan::pointer_dereference_text(
  self : WgslIrWriterBytePlan,
  expression : String,
) -> String {
  match self.pointer_dereference {
    PrefixPointerDereference => "*(\{expression})"
    ParenthesizedPointerDereference => "(*\{expression})"
  }
}

///|
fn WgslIrWriterBytePlan::address_of_text(
  self : WgslIrWriterBytePlan,
  expression : String,
) -> String {
  match self.address_of {
    PrefixAddressOf => "&\{expression}"
    ParenthesizedAddressOf => "(&\{expression})"
  }
}
