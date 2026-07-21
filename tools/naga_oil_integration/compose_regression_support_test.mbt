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
fn compose_regression_empty_defines() -> Map[String, Bool] {
  Map([])
}

///|
fn compose_regression_bool_defines(names : Array[String]) -> Map[String, Bool] {
  let defines : Map[String, Bool] = Map([])
  for name in names {
    defines.set(name, true)
  }
  defines
}

///|
fn compose_regression_options(
  defines : Map[String, Bool],
) -> @contract.WgslComposeOptions {
  {
    ..@contract.WgslComposeOptions::default(),
    defines,
    value_defines: @profile.bevy_wgsl_value_defines(),
  }
}

///|
fn compose_regression_empty_options() -> @contract.WgslComposeOptions {
  compose_regression_options(compose_regression_empty_defines())
}

///|
fn compose_regression_count_occurrences(text : String, pattern : String) -> Int {
  if pattern == "" {
    return 0
  }
  let mut parts = 0
  for _ in text.split(pattern) {
    parts = parts + 1
  }
  if parts == 0 {
    0
  } else {
    parts - 1
  }
}
