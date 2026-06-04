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
priv enum WgslIrGeneratedImportConstantSemanticPolicy {
  InlineGeneratedImportConstants
  EmitGeneratedImportConstants
}

///|
priv enum WgslIrNumericConstantExpressionSemanticPolicy {
  FoldNumericConstantExpressions
  PreserveNumericConstantExpressions
}

///|
priv enum WgslIrMatrixScalarConstructorSemanticPolicy {
  ExpandMatrixScalarConstructors
  PreserveMatrixScalarConstructors
}

///|
priv enum WgslIrNumericLiteralContextSemanticPolicy {
  ContextualizeNumericLiterals
  PreserveNumericLiteralKinds
}

///|
priv struct WgslIrWriterSemanticPlan {
  generated_import_constants : WgslIrGeneratedImportConstantSemanticPolicy
  numeric_constant_expressions : WgslIrNumericConstantExpressionSemanticPolicy
  matrix_scalar_constructors : WgslIrMatrixScalarConstructorSemanticPolicy
  numeric_literal_context : WgslIrNumericLiteralContextSemanticPolicy
}

///|
fn WgslIrWriterSemanticPlan::runtime_writer() -> WgslIrWriterSemanticPlan {
  {
    generated_import_constants: EmitGeneratedImportConstants,
    numeric_constant_expressions: PreserveNumericConstantExpressions,
    matrix_scalar_constructors: PreserveMatrixScalarConstructors,
    numeric_literal_context: PreserveNumericLiteralKinds,
  }
}

///|
fn WgslIrWriterSemanticPlan::naga_oil_writer() -> WgslIrWriterSemanticPlan {
  {
    generated_import_constants: InlineGeneratedImportConstants,
    numeric_constant_expressions: FoldNumericConstantExpressions,
    matrix_scalar_constructors: ExpandMatrixScalarConstructors,
    numeric_literal_context: ContextualizeNumericLiterals,
  }
}

///|
fn WgslIrWriterSemanticPlan::should_inline_generated_import_constants(
  self : WgslIrWriterSemanticPlan,
) -> Bool {
  match self.generated_import_constants {
    InlineGeneratedImportConstants => true
    EmitGeneratedImportConstants => false
  }
}

///|
fn WgslIrWriterSemanticPlan::should_fold_numeric_constant_expressions(
  self : WgslIrWriterSemanticPlan,
) -> Bool {
  match self.numeric_constant_expressions {
    FoldNumericConstantExpressions => true
    PreserveNumericConstantExpressions => false
  }
}

///|
fn WgslIrWriterSemanticPlan::should_expand_matrix_scalar_constructors(
  self : WgslIrWriterSemanticPlan,
) -> Bool {
  match self.matrix_scalar_constructors {
    ExpandMatrixScalarConstructors => true
    PreserveMatrixScalarConstructors => false
  }
}

///|
fn WgslIrWriterSemanticPlan::should_contextualize_numeric_literals(
  self : WgslIrWriterSemanticPlan,
) -> Bool {
  match self.numeric_literal_context {
    ContextualizeNumericLiterals => true
    PreserveNumericLiteralKinds => false
  }
}
