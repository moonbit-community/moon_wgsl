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
priv struct WgslImportRequest {
  module_path : String
  rel_path : String
  mut import_full_module : Bool
  mut keep_requested_items : Bool
  requested_items : Array[String]
  alias_name : String
}

///|
fn find_wgsl_import_request_index(
  requests : Array[WgslImportRequest],
  module_path : String,
  rel_path : String,
  alias_name : String,
) -> Int? {
  for i in 0..<requests.length() {
    let request = requests[i]
    if request.module_path == module_path &&
      request.rel_path == rel_path &&
      request.alias_name == alias_name {
      return Some(i)
    }
  }
  None
}

///|
fn wgsl_import_request_visit_key(
  importer_rel_path : String,
  request : WgslImportRequest,
) -> String {
  let mut key = "\{importer_rel_path}=>\{request.rel_path}|\{request.alias_name}"
  if request.import_full_module {
    key = "\{key}|*"
  } else {
    if request.keep_requested_items {
      key = "\{key}|explicit"
    }
    let sorted_items : Array[String] = []
    for item in request.requested_items {
      sorted_items.push(item)
    }
    sorted_items.sort()
    for item in sorted_items {
      key = "\{key}|\{item}"
    }
  }
  key
}

///|
fn wgsl_full_module_visit_key(rel_path : String, alias_name : String) -> String {
  "\{rel_path}|\{alias_name}|*"
}

///|
fn wgsl_symbol_identity_key(rel_path : String, item_name : String) -> String {
  "\{rel_path}|\{item_name}"
}

///|
fn wgsl_alias_symbol_identity_key(
  rel_path : String,
  alias_name : String,
  item_name : String,
) -> String {
  "\{alias_name}|\{wgsl_symbol_identity_key(rel_path, item_name)}"
}

///|
fn wgsl_path_stack_contains(paths : Array[String], rel_path : String) -> Bool {
  paths.contains(rel_path)
}

///|
fn wgsl_import_cycle_string(
  active_rel_paths : Array[String],
  repeated_rel_path : String,
) -> String {
  let cycle_paths : Array[String] = []
  let mut found_cycle_start = false
  for rel_path in active_rel_paths {
    if rel_path == repeated_rel_path {
      found_cycle_start = true
    }
    if found_cycle_start {
      cycle_paths.push(rel_path)
    }
  }
  cycle_paths.push(repeated_rel_path)
  cycle_paths.join(" -> ")
}
