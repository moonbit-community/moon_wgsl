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
pub(all) struct WgslGraphBlock {
  name : String
  text : String
  start : Int
  end : Int
  data : WgslGlobalDeclData
}

///|
pub(all) struct WgslDeclarationGraph {
  import_blocks : Array[WgslGraphBlock]
  declaration_blocks : Array[WgslGraphBlock]
}

///|
pub fn wgsl_identifier_char(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
pub fn wgsl_string_list_push_unique(
  items : Array[String],
  item : String,
) -> Unit {
  for existing in items {
    if existing == item {
      return
    }
  }
  items.push(item)
}

///|
pub fn build_wgsl_declaration_graph(source : String) -> WgslDeclarationGraph {
  let import_blocks : Array[WgslGraphBlock] = []
  let declaration_blocks : Array[WgslGraphBlock] = []
  for decl in parse_wgsl_translation_unit(source).declarations {
    match decl.kind {
      WgslGlobalDeclKind::Import =>
        import_blocks.push(WgslGraphBlock::{
          name: decl.name,
          text: decl.text,
          start: decl.start,
          end: decl.end,
          data: decl.data,
        })
      WgslGlobalDeclKind::Function
      | WgslGlobalDeclKind::GlobalVariable
      | WgslGlobalDeclKind::Const
      | WgslGlobalDeclKind::Override
      | WgslGlobalDeclKind::Struct
      | WgslGlobalDeclKind::TypeAlias
      | WgslGlobalDeclKind::ConstAssert
      | WgslGlobalDeclKind::Unknown =>
        declaration_blocks.push(WgslGraphBlock::{
          name: decl.name,
          text: decl.text,
          start: decl.start,
          end: decl.end,
          data: decl.data,
        })
      _ => ()
    }
  }

  WgslDeclarationGraph::{ import_blocks, declaration_blocks }
}

///|
pub fn build_wgsl_declaration_indexes(
  declaration_blocks : Array[WgslGraphBlock],
) -> (@hashmap.HashMap[String, Bool], @hashmap.HashMap[String, Int]) {
  let declaration_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let declaration_indexes : @hashmap.HashMap[String, Int] = @hashmap.HashMap::new()
  for i in 0..<declaration_blocks.length() {
    let block = declaration_blocks[i]
    if block.name != "" {
      declaration_names.set(block.name, true)
      declaration_indexes.set(block.name, i)
    }
  }
  (declaration_names, declaration_indexes)
}

///|
fn collect_wgsl_dependency_text_fragment(
  text : String,
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  for token in tokenize(text, false) {
    match token {
      Token::Identifier(ident, _) => {
        if ident.contains("\"") {
          continue
        }
        let dependency_name = match split_last_identifier(ident) {
          Some((_, suffix)) => suffix
          None => ident
        }
        if dependency_name != self_name &&
          declaration_names.contains(dependency_name) {
          wgsl_string_list_push_unique(dependencies, dependency_name)
        }
      }
      _ => ()
    }
  }
}

///|
fn collect_wgsl_attribute_dependencies(
  attributes : Array[WgslAttribute],
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  for attr in attributes {
    match attr.arguments_ref {
      Some(expr) =>
        collect_wgsl_identifier_dependencies(
          expr.identifiers,
          self_name,
          declaration_names,
          dependencies,
        )
      None => ()
    }
  }
}

///|
fn collect_wgsl_optional_expr_ref_or_text_dependencies(
  expr_ref : WgslExprRef?,
  _text : String?,
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  match expr_ref {
    Some(expr) =>
      collect_wgsl_identifier_dependencies(
        expr.identifiers,
        self_name,
        declaration_names,
        dependencies,
      )
    None => ()
  }
}

///|
fn collect_wgsl_identifier_dependencies(
  identifiers : Array[WgslIdent],
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  for identifier in identifiers {
    let dependency_name = match split_last_identifier(identifier.name) {
      Some((_, suffix)) => suffix
      None => identifier.name
    }
    if dependency_name != self_name &&
      declaration_names.contains(dependency_name) {
      wgsl_string_list_push_unique(dependencies, dependency_name)
    }
  }
}

///|
fn collect_wgsl_type_ref_dependencies(
  ty_ref : WgslTypeRef?,
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  match ty_ref {
    Some(value) => {
      if value.name != self_name && declaration_names.contains(value.name) {
        wgsl_string_list_push_unique(dependencies, value.name)
      }
      for argument in value.arguments {
        collect_wgsl_type_ref_dependencies(
          Some(argument),
          self_name,
          declaration_names,
          dependencies,
        )
      }
    }
    None => ()
  }
}

///|
fn collect_wgsl_type_ref_or_text_dependencies(
  ty_ref : WgslTypeRef?,
  _ty_text : String,
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  match ty_ref {
    Some(_) =>
      collect_wgsl_type_ref_dependencies(
        ty_ref, self_name, declaration_names, dependencies,
      )
    None => ()
  }
}

///|
fn collect_wgsl_optional_type_ref_or_text_dependencies(
  ty_ref : WgslTypeRef?,
  ty_text : String?,
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  match ty_text {
    Some(text) =>
      collect_wgsl_type_ref_or_text_dependencies(
        ty_ref, text, self_name, declaration_names, dependencies,
      )
    None => ()
  }
}

///|
fn collect_wgsl_declaration_dependencies(
  declaration_data : WgslGlobalDeclData,
  declaration_text : String,
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  match declaration_data {
    WgslGlobalDeclData::Function(function) => {
      collect_wgsl_attribute_dependencies(
        function.attributes,
        self_name,
        declaration_names,
        dependencies,
      )
      for argument in function.arguments {
        collect_wgsl_attribute_dependencies(
          argument.attributes,
          self_name,
          declaration_names,
          dependencies,
        )
        collect_wgsl_type_ref_or_text_dependencies(
          argument.ty_ref,
          argument.ty,
          self_name,
          declaration_names,
          dependencies,
        )
      }
      match function.result {
        Some(result) => {
          collect_wgsl_attribute_dependencies(
            result.attributes,
            self_name,
            declaration_names,
            dependencies,
          )
          collect_wgsl_type_ref_or_text_dependencies(
            result.ty_ref,
            result.ty,
            self_name,
            declaration_names,
            dependencies,
          )
        }
        None => ()
      }
      for statement in function.body.statements {
        collect_wgsl_identifier_dependencies(
          statement.identifiers,
          self_name,
          declaration_names,
          dependencies,
        )
      }
    }
    WgslGlobalDeclData::Struct(struct_decl) => {
      collect_wgsl_attribute_dependencies(
        struct_decl.attributes,
        self_name,
        declaration_names,
        dependencies,
      )
      for struct_member in struct_decl.members {
        collect_wgsl_attribute_dependencies(
          struct_member.attributes,
          self_name,
          declaration_names,
          dependencies,
        )
        collect_wgsl_type_ref_or_text_dependencies(
          struct_member.ty_ref,
          struct_member.ty,
          self_name,
          declaration_names,
          dependencies,
        )
      }
    }
    WgslGlobalDeclData::GlobalVariable(global) => {
      collect_wgsl_attribute_dependencies(
        global.attributes,
        self_name,
        declaration_names,
        dependencies,
      )
      collect_wgsl_optional_type_ref_or_text_dependencies(
        global.ty_ref,
        global.ty,
        self_name,
        declaration_names,
        dependencies,
      )
      collect_wgsl_optional_expr_ref_or_text_dependencies(
        global.initializer_ref,
        global.initializer,
        self_name,
        declaration_names,
        dependencies,
      )
    }
    WgslGlobalDeclData::Const(const_decl) => {
      collect_wgsl_optional_type_ref_or_text_dependencies(
        const_decl.ty_ref,
        const_decl.ty,
        self_name,
        declaration_names,
        dependencies,
      )
      collect_wgsl_optional_expr_ref_or_text_dependencies(
        const_decl.initializer_ref,
        const_decl.initializer,
        self_name,
        declaration_names,
        dependencies,
      )
    }
    WgslGlobalDeclData::Override(override_decl) => {
      collect_wgsl_attribute_dependencies(
        override_decl.attributes,
        self_name,
        declaration_names,
        dependencies,
      )
      collect_wgsl_optional_type_ref_or_text_dependencies(
        override_decl.ty_ref,
        override_decl.ty,
        self_name,
        declaration_names,
        dependencies,
      )
      collect_wgsl_optional_expr_ref_or_text_dependencies(
        override_decl.initializer_ref,
        override_decl.initializer,
        self_name,
        declaration_names,
        dependencies,
      )
    }
    WgslGlobalDeclData::TypeAlias(alias_decl) =>
      collect_wgsl_type_ref_or_text_dependencies(
        alias_decl.ty_ref,
        alias_decl.ty,
        self_name,
        declaration_names,
        dependencies,
      )
    WgslGlobalDeclData::ConstAssert(expr) =>
      collect_wgsl_identifier_dependencies(
        expr.identifiers,
        self_name,
        declaration_names,
        dependencies,
      )
    WgslGlobalDeclData::Raw =>
      collect_wgsl_dependency_text_fragment(
        declaration_text, self_name, declaration_names, dependencies,
      )
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) => ()
  }
}

///|
pub fn collect_wgsl_reachable_declaration_names(
  declaration_blocks : Array[WgslGraphBlock],
  root_items : Array[String],
) -> (@hashmap.HashMap[String, Bool], Array[String]) {
  let included_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  if root_items.length() == 0 {
    for block in declaration_blocks {
      if block.name != "" {
        included_names.set(block.name, true)
      }
    }
    return (included_names, [])
  }

  let (declaration_names, declaration_indexes) = build_wgsl_declaration_indexes(
    declaration_blocks,
  )
  let worklist : Array[String] = []
  let missing_root_items : Array[String] = []
  for root_item in root_items {
    if declaration_names.contains(root_item) {
      worklist.push(root_item)
    } else {
      missing_root_items.push(root_item)
    }
  }
  if worklist.length() == 0 {
    for block in declaration_blocks {
      if block.name != "" {
        included_names.set(block.name, true)
      }
    }
    return (included_names, missing_root_items)
  }

  while worklist.length() > 0 {
    let name = worklist.pop().unwrap()
    if included_names.contains(name) {
      continue
    }
    included_names.set(name, true)
    guard declaration_indexes.get(name) is Some(index) else { continue }
    let block = declaration_blocks[index]
    let dependencies : Array[String] = []
    collect_wgsl_declaration_dependencies(
      block.data,
      block.text,
      name,
      declaration_names,
      dependencies,
    )
    for dependency in dependencies {
      if !included_names.contains(dependency) {
        worklist.push(dependency)
      }
    }
  }
  (included_names, missing_root_items)
}

///|
pub fn wgsl_source_declares_entry_point(
  source : String,
  item_name : String,
) -> Bool {
  if item_name == "" {
    return false
  }
  for decl in parse_wgsl_translation_unit(source).declarations {
    match decl.data {
      WgslGlobalDeclData::Function(function) =>
        if function.name.name == item_name {
          for attr in function.attributes {
            if attr.name == "vertex" ||
              attr.name == "fragment" ||
              attr.name == "compute" {
              return true
            }
          }
        }
      _ => ()
    }
  }
  false
}

///|
pub fn strip_wgsl_import_declarations(source : String) -> String {
  let mut out = ""
  for decl in parse_wgsl_translation_unit(source).declarations {
    match decl.data {
      WgslGlobalDeclData::Directive(directive) =>
        if directive.kind == WgslDirectiveKind::DefineImportPath {
          ()
        } else {
          out = out + decl.text
        }
      WgslGlobalDeclData::Import(_) => ()
      _ => out = out + decl.text
    }
  }
  out
}

///|
pub fn extract_wgsl_module_items(
  source : String,
  requested_items : Array[String],
) -> String {
  if requested_items.length() == 0 {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let (included_names, _) = collect_wgsl_reachable_declaration_names(
    graph.declaration_blocks,
    requested_items,
  )
  let mut matched_requested = 0
  for item in requested_items {
    if included_names.contains(item) {
      matched_requested = matched_requested + 1
    }
  }
  if matched_requested == 0 {
    return source
  }
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + import_block.text
  }
  for block in graph.declaration_blocks {
    if block.name == "" || included_names.contains(block.name) {
      out = out + block.text
    }
  }
  out
}
