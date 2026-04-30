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
pub fn build_wgsl_symbol_redirect_map(
  redirects : Array[WgslSymbolRedirect],
) -> @hashmap.HashMap[String, String] {
  let redirect_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for redirect in redirects {
    let from_name = redirect.from_name.trim().to_owned()
    let to_name = redirect.to_name.trim().to_owned()
    if from_name == "" || to_name == "" || from_name == to_name {
      continue
    }
    redirect_map.set(from_name, to_name)
  }
  let keys : Array[String] = []
  for entry in redirect_map.iter() {
    let (from_name, _) = entry
    keys.push(from_name)
  }
  for key in keys {
    let seen : Array[String] = []
    let mut target = match redirect_map.get(key) {
      Some(value) => value
      None => continue
    }
    seen.push(key)
    while redirect_map.get(target) is Some(next_target) {
      if seen.contains(target) {
        break
      }
      seen.push(target)
      target = next_target
    }
    redirect_map.set(key, target)
  }
  redirect_map
}

///|
pub fn rewrite_wgsl_symbol_redirects(
  source : String,
  redirects : Array[WgslSymbolRedirect],
) -> String {
  if redirects.length() == 0 {
    return source
  }
  rewrite_wgsl_declarations_with_rename_plan(
    source,
    build_wgsl_rename_plan_from_redirect_map(
      build_wgsl_symbol_redirect_map(redirects),
      ReferencesOnly,
    ),
  )
}
