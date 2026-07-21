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
pub suberror WgslImmediateSpecializationError {
  InvalidImmediateSpecialization(String)
}

///|
pub fn WgslImmediateSpecializationError::message(
  self : WgslImmediateSpecializationError,
) -> String {
  match self {
    InvalidImmediateSpecialization(message) => message
  }
}

///|
priv struct WgslImmediateDeclarationReplacement {
  start : Int
  end : Int
  source : String
}

///|
fn wgsl_immediate_literal(
  value : ShaderDefValue,
) -> String raise WgslImmediateSpecializationError {
  match value {
    Bool(flag) => flag.to_string()
    Int(value) => "\{value}i"
    UInt(value) => "\{value}u"
    Raw(value) => {
      let literal = value.trim().to_owned()
      if literal == "" {
        raise InvalidImmediateSpecialization(
          "immediate specialization value must not be empty",
        )
      }
      literal
    }
  }
}

///|
fn wgsl_immediate_global_is_immediate(global : WgslGlobalVariable) -> Bool {
  let template_list = global.template_list()
  template_list.length() == 1 && template_list[0].name() == "immediate"
}

///|
fn wgsl_immediate_structs(
  unit : WgslTranslationUnit,
) -> Map[String, WgslStruct] {
  let structs : Map[String, WgslStruct] = Map([])
  for declaration in unit.declarations() {
    match declaration.data() {
      Struct(struct_decl) => structs.set(struct_decl.name().name(), struct_decl)
      _ => ()
    }
  }
  structs
}

///|
fn wgsl_immediate_specializations_by_global(
  specializations : Array[WgslImmediateSpecialization],
) -> Map[String, WgslImmediateSpecialization] raise WgslImmediateSpecializationError {
  let by_global : Map[String, WgslImmediateSpecialization] = Map([])
  for specialization in specializations {
    let global_name = specialization.global_name.trim().to_owned()
    if global_name == "" {
      raise InvalidImmediateSpecialization(
        "immediate specialization global name must not be empty",
      )
    }
    if by_global.contains(global_name) {
      raise InvalidImmediateSpecialization(
        "duplicate immediate specialization for global `\{global_name}`",
      )
    }
    by_global.set(global_name, specialization)
  }
  by_global
}

///|
fn wgsl_specialized_immediate_declaration(
  global : WgslGlobalVariable,
  struct_decl : WgslStruct,
  specialization : WgslImmediateSpecialization,
) -> String raise WgslImmediateSpecializationError {
  let global_name = global.name().name()
  if global.attributes().length() > 0 {
    raise InvalidImmediateSpecialization(
      "immediate global `\{global_name}` must not have attributes",
    )
  }
  let type_ref = match global.ty_ref() {
    Some(value) => value
    None =>
      raise InvalidImmediateSpecialization(
        "immediate global `\{global_name}` must declare a struct type",
      )
  }
  let members = struct_decl.members()
  let member_names : @set.Set[String] = Set([])
  let values : Array[String] = []
  for struct_member in members {
    let member_name = struct_member.name().name()
    member_names.add(member_name)
    let value = match specialization.field_values.get(member_name) {
      Some(value) => value
      None =>
        raise InvalidImmediateSpecialization(
          "immediate specialization for `\{global_name}` is missing field `\{member_name}`",
        )
    }
    values.push(wgsl_immediate_literal(value))
  }
  for entry in specialization.field_values.iter() {
    let (field_name, _) = entry
    if !member_names.contains(field_name) {
      raise InvalidImmediateSpecialization(
        "immediate specialization for `\{global_name}` has unknown field `\{field_name}`",
      )
    }
  }
  let type_name = type_ref.canonical_text()
  "const \{global_name}: \{type_name} = \{type_name}(\{values.join(", ")});"
}

///|
/// Replace selected `var<immediate>` struct declarations with concrete `const`
/// declarations before import linking.
pub fn specialize_wgsl_immediate_globals(
  source : String,
  specializations : Array[WgslImmediateSpecialization],
) -> String raise WgslImmediateSpecializationError {
  if specializations.length() == 0 {
    return source
  }
  let unit = parse_wgsl_translation_unit_strict(
    mask_naga_oil_directives_for_wgsl(source),
  ) catch {
    error =>
      raise InvalidImmediateSpecialization(
        "cannot parse WGSL for immediate specialization: \{error.message()}",
      )
  }
  let structs = wgsl_immediate_structs(unit)
  let by_global = wgsl_immediate_specializations_by_global(specializations)
  let matched : @set.Set[String] = Set([])
  let replacements : Array[WgslImmediateDeclarationReplacement] = []
  for declaration in unit.declarations() {
    guard declaration.data() is GlobalVariable(global) else { continue }
    let global_name = global.name().name()
    guard by_global.get(global_name) is Some(specialization) else { continue }
    if !wgsl_immediate_global_is_immediate(global) {
      raise InvalidImmediateSpecialization(
        "global `\{global_name}` is not declared as `var<immediate>`",
      )
    }
    let type_name = match global.ty_ref() {
      Some(type_ref) => type_ref.name()
      None => ""
    }
    let struct_decl = match structs.get(type_name) {
      Some(value) => value
      None =>
        raise InvalidImmediateSpecialization(
          "immediate global `\{global_name}` type `\{type_name}` is not a struct declared in the same source",
        )
    }
    replacements.push({
      start: declaration.start(),
      end: declaration.end(),
      source: wgsl_specialized_immediate_declaration(
        global, struct_decl, specialization,
      ),
    })
    matched.add(global_name)
  }
  for entry in by_global.iter() {
    let (global_name, _) = entry
    if !matched.contains(global_name) {
      raise InvalidImmediateSpecialization(
        "immediate global `\{global_name}` was not found",
      )
    }
  }
  let out = StringBuilder::new()
  let mut cursor = 0
  for replacement in replacements {
    out.write_string(source[cursor:replacement.start].to_owned())
    out.write_string(replacement.source)
    cursor = replacement.end
  }
  out.write_string(source[cursor:].to_owned())
  out.to_string()
}
