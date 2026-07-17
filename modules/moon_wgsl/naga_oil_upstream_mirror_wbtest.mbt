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
fn mirror_source_needs_conditional_evaluation(source : String) -> Bool {
  source.contains("#if") ||
  source.contains("#else") ||
  source.contains("#endif")
}

///|
fn mirror_preprocess_source(source : String) -> String {
  @preprocess.Preprocessor::default().preprocess(source, Map([])).source() catch {
    _ => abort("expected fixture preprocessing success")
  }
}

///|
test "non-conditional naga_oil fixtures mask into official WGSL" {
  let files = @resolver.scan_wgsl_source_files(
    moon_wgsl_testdata_path("naga_oil_upstream/compose_tests"),
    @contract.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected naga_oil upstream fixture scan success")
  }
  let failures : Array[String] = []
  let mut checked = 0
  for file in files {
    if file.rel_path.has_prefix("error_test/") ||
      mirror_source_needs_conditional_evaluation(file.source) {
      continue
    }
    checked = checked + 1
    ignore(
      @parser.parse_wgsl_translation_unit_strict(
        mirror_preprocess_source(file.source),
      ),
    ) catch {
      err => failures.push("\{file.rel_path}:\{err.message()}")
    }
  }
  debug_inspect(
    failures,
    content=(
      #|[]
    ),
  )
  debug_inspect(checked > 0, content="true")
}

///|
test "non-conditional Bevy fixtures mask into official WGSL" {
  let files = @resolver.scan_wgsl_source_files(
    moon_wgsl_testdata_path("bevy_wgsl"),
    @contract.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture scan success")
  }
  let failures : Array[String] = []
  let mut checked = 0
  for file in files {
    if mirror_source_needs_conditional_evaluation(file.source) {
      continue
    }
    checked = checked + 1
    ignore(
      @parser.parse_wgsl_translation_unit_strict(
        mirror_preprocess_source(file.source),
      ),
    ) catch {
      err => failures.push("\{file.rel_path}:\{err.message()}")
    }
  }
  debug_inspect(
    failures,
    content=(
      #|[]
    ),
  )
  debug_inspect(checked > 0, content="true")
}
