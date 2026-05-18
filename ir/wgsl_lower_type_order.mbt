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
priv struct WgslStructPredeclareEntry {
  declaration : @ast.WgslGlobalDecl
  name : String
  source_start : Int
  first_use : Int
  dependencies : Array[String]
}

///|
fn wgsl_ir_struct_predeclare_order(
  declarations : Array[@ast.WgslGlobalDecl],
) -> Array[@ast.WgslGlobalDecl] {
  let struct_names = @set.Set([])
  let entry_names = @set.Set([])
  let first_uses : Map[String, Int] = Map([])
  let entries : Array[WgslStructPredeclareEntry] = []
  for declaration in declarations {
    match declaration.data() {
      Struct(struct_decl) => {
        let name = struct_decl.name().name()
        struct_names.add(name)
        if entry_names.contains(name) {
          continue
        }
        entry_names.add(name)
        first_uses.set(name, declaration.start())
        entries.push(WgslStructPredeclareEntry::{
          declaration,
          name,
          source_start: declaration.start(),
          first_use: declaration.start(),
          dependencies: [],
        })
      }
      _ => ()
    }
  }
  for declaration in declarations {
    wgsl_ir_record_decl_struct_type_first_uses(
      declaration, struct_names, first_uses,
    )
  }
  let ordered : Array[WgslStructPredeclareEntry] = []
  for entry in entries {
    ordered.push(WgslStructPredeclareEntry::{
      declaration: entry.declaration,
      name: entry.name,
      source_start: entry.source_start,
      first_use: first_uses.get(entry.name).unwrap_or(entry.source_start),
      dependencies: wgsl_ir_collect_decl_struct_type_dependencies(
        entry.declaration,
        entry.name,
        struct_names,
      ),
    })
  }
  ordered.sort_by(wgsl_ir_compare_struct_predeclare_entries)
  let dependency_ordered = wgsl_ir_order_struct_predeclare_entries_by_dependencies(
    ordered,
  )
  let declarations_out : Array[@ast.WgslGlobalDecl] = []
  for entry in dependency_ordered {
    declarations_out.push(entry.declaration)
  }
  declarations_out
}

///|
fn wgsl_ir_compare_struct_predeclare_entries(
  lhs : WgslStructPredeclareEntry,
  rhs : WgslStructPredeclareEntry,
) -> Int {
  let first_use_compare = lhs.first_use - rhs.first_use
  if first_use_compare != 0 {
    return first_use_compare
  }
  let source_compare = lhs.source_start - rhs.source_start
  if source_compare != 0 {
    return source_compare
  }
  String::compare(lhs.name, rhs.name)
}

///|
fn wgsl_ir_order_struct_predeclare_entries_by_dependencies(
  entries : Array[WgslStructPredeclareEntry],
) -> Array[WgslStructPredeclareEntry] {
  let index_by_name : Map[String, Int] = Map([])
  for i in 0..<entries.length() {
    index_by_name.set(entries[i].name, i)
  }
  let ordered : Array[WgslStructPredeclareEntry] = []
  let visiting : @set.Set[Int] = @set.Set([])
  let emitted : @set.Set[Int] = @set.Set([])
  for i in 0..<entries.length() {
    wgsl_ir_push_struct_predeclare_entry_with_dependencies(
      entries, index_by_name, i, visiting, emitted, ordered,
    )
  }
  ordered
}

///|
fn wgsl_ir_push_struct_predeclare_entry_with_dependencies(
  entries : Array[WgslStructPredeclareEntry],
  index_by_name : Map[String, Int],
  index : Int,
  visiting : @set.Set[Int],
  emitted : @set.Set[Int],
  ordered : Array[WgslStructPredeclareEntry],
) -> Unit {
  if emitted.contains(index) || visiting.contains(index) {
    return
  }
  visiting.add(index)
  for dependency in entries[index].dependencies {
    match index_by_name.get(dependency) {
      Some(dependency_index) if dependency_index != index =>
        wgsl_ir_push_struct_predeclare_entry_with_dependencies(
          entries, index_by_name, dependency_index, visiting, emitted, ordered,
        )
      _ => ()
    }
  }
  ignore(visiting.remove(index))
  if !emitted.contains(index) {
    emitted.add(index)
    ordered.push(entries[index])
  }
}

///|
fn wgsl_ir_collect_decl_struct_type_dependencies(
  declaration : @ast.WgslGlobalDecl,
  owner_name : String,
  struct_names : @set.Set[String],
) -> Array[String] {
  let dependencies : Array[String] = []
  match declaration.data() {
    Struct(struct_decl) =>
      for field in struct_decl.members() {
        match field.ty_ref() {
          Some(ty_ref) =>
            wgsl_ir_collect_struct_type_ref_dependency(
              ty_ref, owner_name, struct_names, dependencies,
            )
          None => ()
        }
      }
    _ => ()
  }
  dependencies
}

///|
fn wgsl_ir_push_unique_struct_dependency(
  dependencies : Array[String],
  dependency : String,
) -> Unit {
  if !dependencies.contains(dependency) {
    dependencies.push(dependency)
  }
}

///|
fn wgsl_ir_collect_struct_type_ref_dependency(
  ty_ref : @ast.WgslTypeRef,
  owner_name : String,
  struct_names : @set.Set[String],
  dependencies : Array[String],
) -> Unit {
  let name = ty_ref.name()
  if name != owner_name && struct_names.contains(name) {
    wgsl_ir_push_unique_struct_dependency(dependencies, name)
  }
  for argument in ty_ref.template_arguments() {
    match argument {
      Type(inner) =>
        wgsl_ir_collect_struct_type_ref_dependency(
          inner, owner_name, struct_names, dependencies,
        )
      Expression(_) => ()
    }
  }
}

///|
fn wgsl_ir_record_decl_struct_type_first_uses(
  declaration : @ast.WgslGlobalDecl,
  struct_names : @set.Set[String],
  first_uses : Map[String, Int],
) -> Unit {
  match declaration.data() {
    Function(function) => {
      for argument in function.arguments() {
        match argument.ty_ref() {
          Some(ty_ref) =>
            wgsl_ir_record_struct_type_ref_first_use(
              ty_ref, struct_names, first_uses,
            )
          None => ()
        }
      }
      match function.result() {
        Some(result) =>
          match result.ty_ref() {
            Some(ty_ref) =>
              wgsl_ir_record_struct_type_ref_first_use(
                ty_ref, struct_names, first_uses,
              )
            None => ()
          }
        None => ()
      }
    }
    GlobalVariable(global) => {
      for ty_ref in global.template_list() {
        wgsl_ir_record_struct_type_ref_first_use(
          ty_ref, struct_names, first_uses,
        )
      }
      match global.ty_ref() {
        Some(ty_ref) =>
          wgsl_ir_record_struct_type_ref_first_use(
            ty_ref, struct_names, first_uses,
          )
        None => ()
      }
    }
    Const(value) =>
      match value.ty_ref() {
        Some(ty_ref) =>
          wgsl_ir_record_struct_type_ref_first_use(
            ty_ref, struct_names, first_uses,
          )
        None => ()
      }
    Override(value) =>
      match value.ty_ref() {
        Some(ty_ref) =>
          wgsl_ir_record_struct_type_ref_first_use(
            ty_ref, struct_names, first_uses,
          )
        None => ()
      }
    TypeAlias(alias_decl) =>
      match alias_decl.ty_ref() {
        Some(ty_ref) =>
          wgsl_ir_record_struct_type_ref_first_use(
            ty_ref, struct_names, first_uses,
          )
        None => ()
      }
    Struct(struct_decl) =>
      for field in struct_decl.members() {
        match field.ty_ref() {
          Some(ty_ref) =>
            wgsl_ir_record_struct_type_ref_first_use(
              ty_ref, struct_names, first_uses,
            )
          None => ()
        }
      }
    Directive(_) | Import(_) | ConstAssert(_) | Raw => ()
  }
}

///|
fn wgsl_ir_record_struct_type_ref_first_use(
  ty_ref : @ast.WgslTypeRef,
  struct_names : @set.Set[String],
  first_uses : Map[String, Int],
) -> Unit {
  let name = ty_ref.name()
  if struct_names.contains(name) {
    let position = ty_ref.atom().start()
    match first_uses.get(name) {
      Some(existing) =>
        if position < existing {
          first_uses.set(name, position)
        }
      None => first_uses.set(name, position)
    }
  }
  for argument in ty_ref.template_arguments() {
    match argument {
      Type(inner) =>
        wgsl_ir_record_struct_type_ref_first_use(
          inner, struct_names, first_uses,
        )
      Expression(_) => ()
    }
  }
}
