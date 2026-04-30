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
test "naga_oil upstream WGSL fixture mirror parses without raw top-level declarations" {
  let files = @resolver.scan_wgsl_source_files(
    "testdata/naga_oil_upstream/compose_tests",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected naga_oil upstream fixture scan success")
  }
  let unknowns : Array[String] = []
  for file in files {
    if file.rel_path.has_prefix("error_test/") {
      continue
    }
    let unit = @parser.parse_wgsl_translation_unit(file.source)
    let mut count = 0
    for decl in unit.declarations {
      if decl.kind == @ast.WgslGlobalDeclKind::Unknown {
        count = count + 1
      }
    }
    if count > 0 {
      unknowns.push("\{file.rel_path}:\{count}")
    }
  }
  debug_inspect(
    unknowns,
    content=(
      #|[]
    ),
  )
}

///|
test "Bevy WGSL fixture mirror parses without raw top-level declarations" {
  let files = @resolver.scan_wgsl_source_files(
    "testdata/bevy_wgsl",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture scan success")
  }
  let unknowns : Array[String] = []
  for file in files {
    let unit = @parser.parse_wgsl_translation_unit(file.source)
    let mut count = 0
    for decl in unit.declarations {
      if decl.kind == @ast.WgslGlobalDeclKind::Unknown {
        count = count + 1
      }
    }
    if count > 0 {
      unknowns.push("\{file.rel_path}:\{count}")
    }
  }
  debug_inspect(
    unknowns,
    content=(
      #|[]
    ),
  )
}
