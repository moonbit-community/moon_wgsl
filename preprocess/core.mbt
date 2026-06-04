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
pub struct Preprocessor {} derive(Default)

///|
pub fn Preprocessor::default() -> Preprocessor {
  Default::default()
}

///|
pub suberror PreprocessError {
  GlslInvalidVersion(Int)
  ElseWithoutCondition(Int)
  TooManyEndIfs(Int)
  NotEnoughEndIfs(Int)
  UnknownShaderDef(String, Int)
  UnknownShaderDefOperator(String, Int)
  InvalidShaderDefComparisonValue(String, String, String, Int)
  ImportParseError(String, Int)
}

///|
priv enum ScopeLevel {
  Active
  PreviouslyActive
  NotActive
} derive(Eq)

///|
priv struct Scope {
  levels : Array[ScopeLevel]
}

///|
fn Scope::Scope() -> Scope {
  { levels: [Active] }
}

///|
fn Scope::branch(
  self : Scope,
  is_else : Bool,
  condition : Bool,
  offset : Int,
) -> Unit raise PreprocessError {
  if is_else {
    let previous_scope = self.levels.pop()
    guard previous_scope is Some(previous) else {
      raise ElseWithoutCondition(offset)
    }
    guard self.levels.length() > 0 else { raise ElseWithoutCondition(offset) }
    let parent_scope = self.levels[self.levels.length() - 1]
    let new_scope = if parent_scope != Active {
      ScopeLevel::NotActive
    } else if previous != NotActive {
      PreviouslyActive
    } else if condition {
      Active
    } else {
      NotActive
    }
    self.levels.push(new_scope)
    return ()
  }
  let parent_scope = if self.levels.is_empty() {
    ScopeLevel::Active
  } else {
    self.levels[self.levels.length() - 1]
  }
  let new_scope = if parent_scope == Active && condition {
    ScopeLevel::Active
  } else {
    NotActive
  }
  self.levels.push(new_scope)
  ()
}

///|
fn Scope::pop(self : Scope, offset : Int) -> Unit raise PreprocessError {
  self.levels.pop() |> ignore
  if self.levels.is_empty() {
    raise TooManyEndIfs(offset)
  } else {
    ()
  }
}

///|
fn Scope::active(self : Scope) -> Bool {
  self.levels[self.levels.length() - 1] == Active
}

///|
fn Scope::finish(self : Scope, offset : Int) -> Unit raise PreprocessError {
  if self.levels.length() != 1 {
    raise NotEnoughEndIfs(offset)
  } else {
    ()
  }
}
