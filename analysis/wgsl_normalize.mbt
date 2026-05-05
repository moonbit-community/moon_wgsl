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
priv struct WgslGlobalBindingInfo {
  name : String
  group : Int
  binding : Int
}

///|
fn wgsl_string_list_key(items : Array[String]) -> String {
  items.join("|")
}

///|
fn wgsl_type_ref_list_key(items : Array[WgslTypeRef]) -> String {
  let keys : Array[String] = []
  for item in items {
    keys.push(wgsl_type_ref_key(Some(item)))
  }
  keys.join("|")
}

///|
fn wgsl_attribute_key(attribute : WgslAttribute) -> String {
  let argument_key = match attribute.arguments_ref() {
    Some(expr) => wgsl_expr_ref_key(expr)
    None => ""
  }
  "\{attribute.name().name()}(\{argument_key})"
}

///|
fn wgsl_attributes_key(attributes : Array[WgslAttribute]) -> String {
  let keys : Array[String] = []
  for attribute in attributes {
    keys.push(wgsl_attribute_key(attribute))
  }
  wgsl_string_list_key(keys)
}

///|
fn wgsl_expr_token_key(token : WgslExprToken) -> String {
  match token.kind() {
    Identifier => "id:\{token.text()}"
    BoolLiteral(value) => "bool:\{value}"
    UintLiteral(value) => "uint:\{value}"
    IntLiteral(value) => "int:\{value}"
    FloatLiteral => "float:\{token.text()}"
    Operator(text) => "op:\{text}"
    Punctuation(code) => "punct:\{code}"
    Unknown => "unknown:\{token.text()}"
  }
}

///|
fn wgsl_expr_ref_key(expr : WgslExprRef) -> String {
  let keys : Array[String] = []
  for token in expr.tokens() {
    keys.push(wgsl_expr_token_key(token))
  }
  wgsl_string_list_key(keys)
}

///|
fn wgsl_type_ref_key(ty : WgslTypeRef?) -> String {
  match ty {
    Some(type_ref) => {
      let argument_keys : Array[String] = []
      for argument in type_ref.arguments() {
        argument_keys.push(wgsl_type_ref_key(Some(argument)))
      }
      "\{type_ref.name()}<\{wgsl_string_list_key(argument_keys)}>"
    }
    None => ""
  }
}

///|
fn wgsl_statement_kind_key(kind : WgslStatementKind) -> String {
  match kind {
    Empty => "empty"
    LocalDeclaration => "local"
    Return => "return"
    If => "if"
    For => "for"
    While => "while"
    Loop => "loop"
    Switch => "switch"
    Break => "break"
    Continue => "continue"
    Discard => "discard"
    ConstAssert => "const_assert"
    Compound => "compound"
    Expression => "expression"
  }
}

///|
fn wgsl_local_declaration_kind_key(kind : WgslLocalDeclarationKind) -> String {
  match kind {
    Var => "var"
    Let => "let"
    Const => "const"
  }
}

///|
fn wgsl_function_qualifier_key(qualifier : WgslFunctionQualifier?) -> String {
  match qualifier {
    Some(Virtual) => "virtual"
    Some(Override) => "override"
    None => ""
  }
}

///|
fn wgsl_local_binding_key(binding : WgslLocalDeclaration) -> String {
  "\{wgsl_local_declaration_kind_key(binding.kind())}:\{binding.name().name()}<\{wgsl_type_ref_list_key(binding.template_list())}>:\{wgsl_type_ref_key(binding.ty_ref())}=\{wgsl_optional_expr_ref_key(binding.initializer_ref())}"
}

///|
fn wgsl_directive_kind_key(kind : WgslDirectiveKind) -> String {
  match kind {
    Ifdef => "ifdef"
    Ifndef => "ifndef"
    If => "if"
    Else => "else"
    Endif => "endif"
    DefineImportPath => "define_import_path"
    Define => "define"
    Import => "import"
    Enable => "enable"
    Requires => "requires"
    Diagnostic => "diagnostic"
    Other(name) => "other:\{name}"
  }
}

///|
fn wgsl_optional_expr_ref_key(expr : WgslExprRef?) -> String {
  match expr {
    Some(value) => wgsl_expr_ref_key(value)
    None => ""
  }
}

///|
fn wgsl_statement_key(statement : WgslStatement) -> String {
  let locals : Array[String] = []
  for binding in statement.local_bindings() {
    locals.push(wgsl_local_binding_key(binding))
  }
  let exported_local_names : Array[String] = []
  for binding in statement.exported_local_bindings() {
    exported_local_names.push(binding.name().name())
  }
  let expressions : Array[String] = []
  for expr_ref in statement.expression_refs() {
    expressions.push(wgsl_expr_ref_key(expr_ref))
  }
  let blocks : Array[String] = []
  for block in statement.blocks() {
    blocks.push(wgsl_block_key(block))
  }
  "\{wgsl_statement_kind_key(statement.kind())}[expr:\{wgsl_string_list_key(expressions)}][\{wgsl_string_list_key(locals)}][export:\{wgsl_string_list_key(exported_local_names)}]{\{wgsl_string_list_key(blocks)}}"
}

///|
fn wgsl_block_key(block : WgslBlock) -> String {
  let statements : Array[String] = []
  for statement in block.statements() {
    statements.push(wgsl_statement_key(statement))
  }
  wgsl_string_list_key(statements)
}

///|
fn wgsl_declaration_structural_key(data : WgslGlobalDeclData) -> String {
  match data {
    WgslGlobalDeclData::Directive(directive) =>
      "directive:\{wgsl_directive_kind_key(directive.kind())}:\{directive.name().name()}:\{directive.tail()}"
    WgslGlobalDeclData::Import(directive) =>
      "import:\{directive.name().name()}:\{directive.tail()}"
    WgslGlobalDeclData::Function(function) => {
      let args : Array[String] = []
      for argument in function.arguments() {
        args.push(
          "\{wgsl_attributes_key(argument.attributes())}:\{argument.name().name()}:\{wgsl_type_ref_key(argument.ty_ref())}",
        )
      }
      let result = match function.result() {
        Some(value) =>
          "\{wgsl_attributes_key(value.attributes())}:\{wgsl_type_ref_key(value.ty_ref())}"
        None => ""
      }
      "fn:\{wgsl_attributes_key(function.attributes())}:\{wgsl_function_qualifier_key(function.qualifier())}:\{function.name().name()}(\{wgsl_string_list_key(args)})->\{result}{\{wgsl_block_key(function.body())}}"
    }
    WgslGlobalDeclData::GlobalVariable(global) =>
      "global:\{wgsl_attributes_key(global.attributes())}:\{global.name().name()}:\{wgsl_type_ref_list_key(global.template_list())}:\{wgsl_type_ref_key(global.ty_ref())}=\{wgsl_optional_expr_ref_key(global.initializer_ref())}"
    WgslGlobalDeclData::Const(const_decl) =>
      "const:\{const_decl.name().name()}:\{wgsl_type_ref_key(const_decl.ty_ref())}=\{wgsl_optional_expr_ref_key(const_decl.initializer_ref())}"
    WgslGlobalDeclData::Override(override_decl) =>
      "override:\{wgsl_attributes_key(override_decl.attributes())}:\{override_decl.name().name()}:\{wgsl_type_ref_key(override_decl.ty_ref())}=\{wgsl_optional_expr_ref_key(override_decl.initializer_ref())}"
    WgslGlobalDeclData::Struct(struct_decl) => {
      let members : Array[String] = []
      for field in struct_decl.members() {
        members.push(
          "\{wgsl_attributes_key(field.attributes())}:\{field.name().name()}:\{wgsl_type_ref_key(field.ty_ref())}",
        )
      }
      "struct:\{wgsl_attributes_key(struct_decl.attributes())}:\{struct_decl.name().name()}{\{wgsl_string_list_key(members)}}"
    }
    WgslGlobalDeclData::TypeAlias(alias_decl) =>
      "alias:\{alias_decl.name().name()}=\{wgsl_type_ref_key(alias_decl.ty_ref())}"
    WgslGlobalDeclData::ConstAssert(expr) =>
      "const_assert:\{wgsl_expr_ref_key(expr)}"
    Raw => "raw"
  }
}

///|
fn dedupe_wgsl_duplicate_declarations(
  source : String,
) -> String raise WgslParseError {
  let graph = build_wgsl_declaration_graph(source)
  let mut deduped = ""
  let emitted_blocks : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for import_block in graph.import_blocks {
    deduped = deduped + emit_wgsl_graph_block_canonical(import_block)
  }
  for block in graph.declaration_blocks {
    if block.name != "" {
      let declaration_key = wgsl_declaration_structural_key(block.data)
      match emitted_blocks.get(block.name) {
        Some(existing_key) if existing_key == declaration_key => continue
        _ => emitted_blocks.set(block.name, declaration_key)
      }
    }
    deduped = deduped + emit_wgsl_graph_block_canonical(block)
  }
  deduped
}

///|
fn record_wgsl_alias_suffix_redirect_candidate(
  suffix : String,
  lowered_name : String,
  declared_names : @hashmap.HashMap[String, Bool],
  candidate_redirects : @hashmap.HashMap[String, String],
  ambiguous_suffixes : @hashmap.HashMap[String, Bool],
) -> Unit {
  if suffix == "" || declared_names.contains(suffix) {
    return
  }
  match candidate_redirects.get(suffix) {
    Some(existing) if existing != lowered_name =>
      ambiguous_suffixes.set(suffix, true)
    Some(_) => ()
    None => candidate_redirects.set(suffix, lowered_name)
  }
}

///|
fn build_wgsl_unique_alias_suffix_rename_plan(
  source : String,
  alias_redirects : Array[WgslSymbolRedirect],
) -> WgslRenamePlan raise WgslParseError {
  let graph = build_wgsl_declaration_graph(source)
  let declared_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let candidate_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let ambiguous_suffixes : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  for block in graph.declaration_blocks {
    if block.name != "" {
      declared_names.set(block.name, true)
    }
  }
  for redirect in alias_redirects {
    let lowered_name = redirect.to_name.trim().to_owned()
    if lowered_name == "" || !declared_names.contains(lowered_name) {
      continue
    }
    let parts : Array[String] = []
    for part in redirect.from_name.trim().split("::") {
      parts.push(part.to_owned())
    }
    for i in 1..<parts.length() {
      let mut suffix = ""
      for j in i..<parts.length() {
        if suffix != "" {
          suffix = "\{suffix}::"
        }
        suffix = "\{suffix}\{parts[j]}"
      }
      if suffix != "" {
        record_wgsl_alias_suffix_redirect_candidate(
          suffix, lowered_name, declared_names, candidate_redirects, ambiguous_suffixes,
        )
      }
    }
  }
  let plan = WgslRenamePlan::empty()
  for entry in candidate_redirects.iter() {
    let (suffix, lowered_name) = entry
    if !ambiguous_suffixes.contains(suffix) {
      plan.add(suffix, lowered_name, ReferencesOnly)
    }
  }
  plan
}

///|
fn wgsl_expr_ref_single_uint_value(expr_ref : WgslExprRef?) -> Int? {
  match expr_ref {
    Some(expr) => {
      let tokens = expr.tokens()
      if tokens.length() == 1 {
        match tokens[0].kind() {
          UintLiteral(value) | IntLiteral(value) => Some(value)
          _ => None
        }
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn wgsl_attribute_uint_value(
  attributes : Array[WgslAttribute],
  name : String,
) -> Int? {
  for attr in attributes {
    if attr.name().name() == name {
      return wgsl_expr_ref_single_uint_value(attr.arguments_ref())
    }
  }
  None
}

///|
fn wgsl_global_binding_info(block : WgslGraphBlock) -> WgslGlobalBindingInfo? {
  match block.data {
    WgslGlobalDeclData::GlobalVariable(global) => {
      guard wgsl_attribute_uint_value(global.attributes(), "group")
        is Some(group) else {
        return None
      }
      guard wgsl_attribute_uint_value(global.attributes(), "binding")
        is Some(binding) else {
        return None
      }
      Some(WgslGlobalBindingInfo::{ name: global.name().name(), group, binding })
    }
    _ => None
  }
}

///|
fn dedupe_wgsl_duplicate_resource_bindings(
  source : String,
) -> String raise WgslParseError {
  let graph = build_wgsl_declaration_graph(source)
  let binding_owner : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let duplicate_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let redirect_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for block in graph.declaration_blocks {
    guard wgsl_global_binding_info(block) is Some(info) else { continue }
    let key = "\{info.group}:\{info.binding}"
    match binding_owner.get(key) {
      Some(owner) =>
        if info.name != owner {
          duplicate_names.set(info.name, true)
          redirect_map.set(info.name, owner)
        }
      None => binding_owner.set(key, info.name)
    }
  }
  if redirect_map.is_empty() {
    return source
  }
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + emit_wgsl_graph_block_canonical(import_block)
  }
  for block in graph.declaration_blocks {
    if duplicate_names.contains(block.name) {
      continue
    }
    out = out + emit_wgsl_graph_block_canonical(block)
  }
  rewrite_wgsl_declarations_with_rename_plan(
    out,
    build_wgsl_rename_plan_from_redirect_map(redirect_map, ReferencesOnly),
  )
}

///|
pub fn normalize_wgsl_composed_declarations(
  source : String,
  alias_redirects : Array[WgslSymbolRedirect],
) -> String raise WgslParseError {
  let deduped = dedupe_wgsl_duplicate_declarations(source)
  let suffix_plan = build_wgsl_unique_alias_suffix_rename_plan(
    deduped, alias_redirects,
  )
  let suffix_rewritten = if suffix_plan.is_empty() {
    deduped
  } else {
    rewrite_wgsl_declarations_with_rename_plan(deduped, suffix_plan)
  }
  dedupe_wgsl_duplicate_resource_bindings(suffix_rewritten)
}
