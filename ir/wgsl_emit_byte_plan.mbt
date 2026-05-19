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
priv struct WgslIrWriterBytePlan {
  source_directives : WgslIrSourceDirectiveBytePolicy
  trailing_blank : WgslIrTrailingBlankBytePolicy
}

///|
fn WgslIrWriterBytePlan::runtime_writer() -> WgslIrWriterBytePlan {
  WgslIrWriterBytePlan::{
    source_directives: EmitSourceDirectives,
    trailing_blank: SuppressTrailingBlankAfterEntryPoint,
  }
}

///|
fn WgslIrWriterBytePlan::naga_oil_writer() -> WgslIrWriterBytePlan {
  WgslIrWriterBytePlan::{
    source_directives: SuppressSourceDirectives,
    trailing_blank: SuppressTrailingBlankAfterEntryPoint,
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
