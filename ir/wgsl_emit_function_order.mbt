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
fn WgslIrEmitter::function_emission_order(self : WgslIrEmitter) -> Array[Int] {
  match self.naga_writer_module {
    Some(view) => view.function_order()
    None => self.source_ordered_function_indices()
  }
}

///|
fn WgslIrEmitter::source_ordered_function_indices(
  self : WgslIrEmitter,
) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<self.shader_module.functions.items.length() {
    if self.function_order_should_include(index, order) {
      order.push(index)
    }
  }
  order
}

///|
fn WgslIrEmitter::function_order_should_include(
  self : WgslIrEmitter,
  index : Int,
  emitted : Array[Int],
) -> Bool {
  if emitted.contains(index) {
    return false
  }
  if !self.should_emit_function(index) {
    return false
  }
  !self.function_is_entry_point_name(self.shader_module.functions.items[index])
}
