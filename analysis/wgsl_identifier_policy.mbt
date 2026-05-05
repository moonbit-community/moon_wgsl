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
// Identifier normalization is part of semantic analysis. Compose validates
// unsupported struct members here instead of running a final text-emission pass.
fn wgsl_identifier_is_reserved(ident : String) -> Bool {
  if ident == "" {
    return false
  }
  ident == "array" ||
  ident == "atomic" ||
  ident == "bool" ||
  ident == "f32" ||
  ident == "f16" ||
  ident == "i32" ||
  ident == "i64" ||
  ident == "mat2x2" ||
  ident == "mat2x3" ||
  ident == "mat2x4" ||
  ident == "mat3x2" ||
  ident == "mat3x3" ||
  ident == "mat3x4" ||
  ident == "mat4x2" ||
  ident == "mat4x3" ||
  ident == "mat4x4" ||
  ident == "ptr" ||
  ident == "sampler" ||
  ident == "sampler_comparison" ||
  ident == "texture_1d" ||
  ident == "texture_2d" ||
  ident == "texture_2d_array" ||
  ident == "texture_3d" ||
  ident == "texture_cube" ||
  ident == "texture_cube_array" ||
  ident == "texture_external" ||
  ident == "texture_multisampled_2d" ||
  ident == "texture_storage_1d" ||
  ident == "texture_storage_2d" ||
  ident == "texture_storage_2d_array" ||
  ident == "texture_storage_3d" ||
  ident == "texture_depth_2d" ||
  ident == "texture_depth_2d_array" ||
  ident == "texture_depth_cube" ||
  ident == "texture_depth_cube_array" ||
  ident == "texture_depth_multisampled_2d" ||
  ident == "u32" ||
  ident == "u64" ||
  ident == "vec2" ||
  ident == "vec3" ||
  ident == "vec4" ||
  ident == "alias" ||
  ident == "bitcast" ||
  ident == "break" ||
  ident == "case" ||
  ident == "const" ||
  ident == "const_assert" ||
  ident == "continue" ||
  ident == "continuing" ||
  ident == "default" ||
  ident == "diagnostic" ||
  ident == "discard" ||
  ident == "else" ||
  ident == "enable" ||
  ident == "false" ||
  ident == "fn" ||
  ident == "for" ||
  ident == "if" ||
  ident == "let" ||
  ident == "loop" ||
  ident == "override" ||
  ident == "return" ||
  ident == "static_assert" ||
  ident == "struct" ||
  ident == "switch" ||
  ident == "true" ||
  ident == "type" ||
  ident == "var" ||
  ident == "while" ||
  ident == "CompileShader" ||
  ident == "ComputeShader" ||
  ident == "DomainShader" ||
  ident == "GeometryShader" ||
  ident == "Hullshader" ||
  ident == "NULL" ||
  ident == "Self" ||
  ident == "abstract" ||
  ident == "active" ||
  ident == "alignas" ||
  ident == "alignof" ||
  ident == "as" ||
  ident == "asm" ||
  ident == "asm_fragment" ||
  ident == "async" ||
  ident == "attribute" ||
  ident == "auto" ||
  ident == "await" ||
  ident == "become" ||
  ident == "binding_array" ||
  ident == "cast" ||
  ident == "catch" ||
  ident == "class" ||
  ident == "co_await" ||
  ident == "co_return" ||
  ident == "co_yield" ||
  ident == "coherent" ||
  ident == "column_major" ||
  ident == "common" ||
  ident == "compile" ||
  ident == "compile_fragment" ||
  ident == "concept" ||
  ident == "const_cast" ||
  ident == "consteval" ||
  ident == "constexpr" ||
  ident == "constinit" ||
  ident == "crate" ||
  ident == "debugger" ||
  ident == "decltype" ||
  ident == "delete" ||
  ident == "demote" ||
  ident == "demote_to_helper" ||
  ident == "do" ||
  ident == "dynamic_cast" ||
  ident == "enum" ||
  ident == "explicit" ||
  ident == "export" ||
  ident == "extends" ||
  ident == "extern" ||
  ident == "external" ||
  ident == "fallthrough" ||
  ident == "filter" ||
  ident == "final" ||
  ident == "finally" ||
  ident == "friend" ||
  ident == "from" ||
  ident == "fxgroup" ||
  ident == "get" ||
  ident == "goto" ||
  ident == "groupshared" ||
  ident == "handle" ||
  ident == "highp" ||
  ident == "impl" ||
  ident == "implements" ||
  ident == "import" ||
  ident == "inline" ||
  ident == "in" ||
  ident == "inout" ||
  ident == "instanceof" ||
  ident == "interface" ||
  ident == "layout" ||
  ident == "lowp" ||
  ident == "macro" ||
  ident == "macro_rules" ||
  ident == "match" ||
  ident == "mediump" ||
  ident == "meta" ||
  ident == "mod" ||
  ident == "module" ||
  ident == "move" ||
  ident == "mut" ||
  ident == "mutable" ||
  ident == "namespace" ||
  ident == "new" ||
  ident == "nil" ||
  ident == "noexcept" ||
  ident == "noinline" ||
  ident == "nointerpolation" ||
  ident == "noperspective" ||
  ident == "null" ||
  ident == "nullptr" ||
  ident == "of" ||
  ident == "operator" ||
  ident == "package" ||
  ident == "packoffset" ||
  ident == "partition" ||
  ident == "pass" ||
  ident == "patch" ||
  ident == "pixelfragment" ||
  ident == "precise" ||
  ident == "precision" ||
  ident == "premerge" ||
  ident == "priv" ||
  ident == "protected" ||
  ident == "pub" ||
  ident == "public" ||
  ident == "readonly" ||
  ident == "ref" ||
  ident == "regardless" ||
  ident == "register" ||
  ident == "reinterpret_cast" ||
  ident == "requires" ||
  ident == "resource" ||
  ident == "restrict" ||
  ident == "self" ||
  ident == "set" ||
  ident == "shared" ||
  ident == "signed" ||
  ident == "sizeof" ||
  ident == "smooth" ||
  ident == "snorm" ||
  ident == "static" ||
  ident == "static_cast" ||
  ident == "std" ||
  ident == "subroutine" ||
  ident == "super" ||
  ident == "target" ||
  ident == "template" ||
  ident == "this" ||
  ident == "thread_local" ||
  ident == "throw" ||
  ident == "trait" ||
  ident == "try" ||
  ident == "typedef" ||
  ident == "typeid" ||
  ident == "typename" ||
  ident == "typeof" ||
  ident == "union" ||
  ident == "unless" ||
  ident == "unorm" ||
  ident == "unsafe" ||
  ident == "unsized" ||
  ident == "use" ||
  ident == "using" ||
  ident == "varying" ||
  ident == "virtual" ||
  ident == "volatile" ||
  ident == "wgsl" ||
  ident == "where" ||
  ident == "with" ||
  ident == "writeonly" ||
  ident == "yield"
}

///|
fn wgsl_identifier_ends_with_digit(ident : String) -> Bool {
  if ident == "" {
    return false
  }
  ident.has_suffix("0") ||
  ident.has_suffix("1") ||
  ident.has_suffix("2") ||
  ident.has_suffix("3") ||
  ident.has_suffix("4") ||
  ident.has_suffix("5") ||
  ident.has_suffix("6") ||
  ident.has_suffix("7") ||
  ident.has_suffix("8") ||
  ident.has_suffix("9")
}

///|
fn sanitize_wgsl_identifier(ident : String) -> String {
  let had_trailing_separator = ident.has_suffix("_")
  let mut out = ident
  while out.has_suffix("_") {
    out = out[:out.length() - 1].to_owned()
  }
  while out.has_prefix("__") {
    out = out[1:out.length()].to_owned()
  }
  if out == "" {
    out = "unnamed"
  }
  if out.has_prefix("_naga") {
    out = "gen_\{out}"
  }
  if wgsl_identifier_is_reserved(out) {
    out = "\{out}_wgsl"
  } else if had_trailing_separator && wgsl_identifier_ends_with_digit(out) {
    out = "\{out}_"
  }
  out
}

///|
fn wgsl_identifier_requires_substitution(ident : String) -> Bool {
  ident != "" && sanitize_wgsl_identifier(ident) != ident
}

///|
fn collect_wgsl_function_local_name_sanitizer(
  name : String,
  plan : WgslRenamePlan,
) -> Unit {
  if wgsl_identifier_requires_substitution(name) {
    plan.add(name, sanitize_wgsl_identifier(name), FunctionLocal)
  }
}

///|
fn collect_wgsl_statement_local_sanitizers(
  statement : WgslStatement,
  plan : WgslRenamePlan,
) -> Unit {
  for binding in statement.local_bindings() {
    collect_wgsl_function_local_name_sanitizer(binding.name().name, plan)
  }
  for block in statement.blocks() {
    collect_wgsl_block_local_sanitizers(block, plan)
  }
}

///|
fn collect_wgsl_block_local_sanitizers(
  block : WgslBlock,
  plan : WgslRenamePlan,
) -> Unit {
  for statement in block.statements() {
    collect_wgsl_statement_local_sanitizers(statement, plan)
  }
}

///|
fn collect_wgsl_function_local_sanitizers(
  data : WgslGlobalDeclData,
  plan : WgslRenamePlan,
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => {
      for argument in function.arguments {
        collect_wgsl_function_local_name_sanitizer(argument.name, plan)
      }
      collect_wgsl_block_local_sanitizers(function.body, plan)
    }
    _ => ()
  }
}

///|
pub fn normalize_wgsl_output_identifiers(
  source : String,
) -> String raise WgslParseError {
  let graph = build_wgsl_declaration_graph(source)
  let plan = WgslRenamePlan::empty()
  for block in graph.declaration_blocks {
    if wgsl_identifier_requires_substitution(block.name) {
      plan.add(
        block.name,
        sanitize_wgsl_identifier(block.name),
        GlobalDeclarationAndReferences,
      )
    }
    collect_wgsl_function_local_sanitizers(block.data, plan)
  }
  if plan.is_empty() {
    source
  } else {
    rewrite_wgsl_declarations_with_rename_plan(source, plan)
  }
}

///|
pub fn invalid_wgsl_struct_member_identifier(
  source : String,
) -> String? raise WgslParseError {
  let graph = build_wgsl_declaration_graph(source)
  for block in graph.declaration_blocks {
    match block.data {
      WgslGlobalDeclData::Struct(struct_decl) =>
        for struct_member in struct_decl.members {
          let mut allows_identifier_substitution = false
          for attr in struct_member.attributes {
            if attr.name() == "blend_src" {
              allows_identifier_substitution = true
              break
            }
          }
          if !allows_identifier_substitution &&
            struct_member.name != "" &&
            wgsl_identifier_requires_substitution(struct_member.name) {
            return Some(struct_member.name)
          }
        }
      _ => ()
    }
  }
  None
}
