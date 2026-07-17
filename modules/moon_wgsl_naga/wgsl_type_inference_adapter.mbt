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
fn WgslIrEmitter::type_inference(self : WgslIrEmitter) -> WgslIrTypeInference {
  WgslIrTypeInference::from_module(self.shader_module)
}

///|
fn WgslIrEmitter::expression_type(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Handle? {
  self.type_inference().expression_type(function, handle)
}

///|
fn WgslIrEmitter::as_expression_result_type(
  self : WgslIrEmitter,
  input : Handle?,
  kind : ScalarKind,
  width : Int,
) -> Handle? {
  self.type_inference().as_expression_result_type(input, kind, width)
}

///|
fn WgslIrEmitter::atomic_pointer_scalar_type(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> Scalar? {
  self.type_inference().atomic_pointer_scalar_type(function, pointer)
}
