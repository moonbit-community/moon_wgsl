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
pub(all) enum Feature {
  Enable
  Disable
  Keep
  Error
} derive(Eq, Debug)

///|
pub fn Feature::default() -> Feature {
  Disable
}

///|
pub fn Feature::from_bool(value : Bool) -> Feature {
  if value {
    Enable
  } else {
    Disable
  }
}

///|
priv enum CondValue {
  Known(Bool)
  Unknown
}

///|
fn CondValue::not(self : CondValue) -> CondValue {
  match self {
    Known(value) => Known(!value)
    Unknown => Unknown
  }
}

///|
fn CondValue::and_value(self : CondValue, other : CondValue) -> CondValue {
  match (self, other) {
    (Known(false), _) => Known(false)
    (_, Known(false)) => Known(false)
    (Known(true), value) => value
    (value, Known(true)) => value
    (Unknown, Unknown) => Unknown
  }
}

///|
fn CondValue::or_value(self : CondValue, other : CondValue) -> CondValue {
  match (self, other) {
    (Known(true), _) => Known(true)
    (_, Known(true)) => Known(true)
    (Known(false), value) => value
    (value, Known(false)) => value
    (Unknown, Unknown) => Unknown
  }
}

///|
pub struct Features {
  default : Feature
  flags : @hashmap.HashMap[String, Feature]
}

///|
pub fn Features::default() -> Features {
  { default: Feature::default(), flags: HashMap([]) }
}

///|
pub fn Features::with_feature(
  self : Features,
  name : String,
  value : Feature,
) -> Features {
  self.flags.set(name, value)
  self
}

///|
fn Features::eval_cond(
  self : Features,
  name : String,
) -> CondValue raise WeslCompileError {
  match self.flags.get(name).unwrap_or(self.default) {
    Enable => Known(true)
    Disable => Known(false)
    Keep => Unknown
    Error => raise InvalidExpression("unexpected feature flag: `\{name}`")
  }
}

///|
pub struct CompileOptions {
  imports : Bool
  condcomp : Bool
  generics : Bool
  strip : Bool
  lower : Bool
  validate : Bool
  lazy_resolution : Bool
  mangle_root : Bool
  keep : Array[String]?
  keep_root : Bool
  features : Features
}

///|
pub fn CompileOptions::default() -> CompileOptions {
  {
    imports: true,
    condcomp: true,
    generics: false,
    strip: true,
    lower: false,
    validate: true,
    lazy_resolution: true,
    mangle_root: false,
    keep: None,
    keep_root: false,
    features: Features::default(),
  }
}

///|
pub fn CompileOptions::with_imports(
  self : CompileOptions,
  imports : Bool,
) -> CompileOptions {
  { ..self, imports, }
}

///|
pub fn CompileOptions::with_condcomp(
  self : CompileOptions,
  condcomp : Bool,
) -> CompileOptions {
  { ..self, condcomp, }
}

///|
pub fn CompileOptions::with_lower(
  self : CompileOptions,
  lower : Bool,
) -> CompileOptions {
  { ..self, lower, }
}

///|
pub fn CompileOptions::with_generics(
  self : CompileOptions,
  generics : Bool,
) -> CompileOptions {
  { ..self, generics, }
}

///|
pub fn CompileOptions::with_strip(
  self : CompileOptions,
  strip : Bool,
) -> CompileOptions {
  { ..self, strip, }
}

///|
pub fn CompileOptions::with_lazy(
  self : CompileOptions,
  enabled : Bool,
) -> CompileOptions {
  { ..self, lazy_resolution: enabled }
}

///|
pub fn CompileOptions::with_validate(
  self : CompileOptions,
  validate : Bool,
) -> CompileOptions {
  { ..self, validate, }
}

///|
pub fn CompileOptions::with_mangle_root(
  self : CompileOptions,
  mangle_root : Bool,
) -> CompileOptions {
  { ..self, mangle_root, }
}

///|
pub fn CompileOptions::with_keep_root(
  self : CompileOptions,
  keep_root : Bool,
) -> CompileOptions {
  { ..self, keep_root, }
}

///|
pub fn CompileOptions::keep_declarations(
  self : CompileOptions,
  keep : Array[String],
) -> CompileOptions {
  { ..self, keep: Some(keep) }
}

///|
pub fn CompileOptions::with_feature(
  self : CompileOptions,
  name : String,
  value : Bool,
) -> CompileOptions {
  self.set_feature(name, Feature::from_bool(value))
}

///|
pub fn CompileOptions::set_feature(
  self : CompileOptions,
  name : String,
  value : Feature,
) -> CompileOptions {
  { ..self, features: self.features.with_feature(name, value) }
}

///|
pub fn CompileOptions::set_missing_feature_behavior(
  self : CompileOptions,
  value : Feature,
) -> CompileOptions {
  { ..self, features: { ..self.features, default: value } }
}

///|
pub struct BasicSourceMap {
  root : ModulePath
  mappings : @hashmap.HashMap[String, (ModulePath, String)]
  sources : @hashmap.HashMap[ModulePath, (String?, String)]
  mut default_source : String?
} derive(Debug)

///|
pub(open) trait SourceMap {
  fn get_decl(Self, String) -> (ModulePath, String)?
  fn get_source(Self, ModulePath) -> String?
  fn get_display_name(Self, ModulePath) -> String?
  fn get_default_source(Self) -> String? = _
  fn unmangle_text(Self, String) -> String = _
}

///|
impl SourceMap with fn get_default_source(_self) {
  None
}

///|
impl SourceMap with fn unmangle_text(_self, text) {
  text
}

///|
pub fn BasicSourceMap::default() -> BasicSourceMap {
  {
    root: ModulePath::new_root(),
    mappings: HashMap([]),
    sources: HashMap([]),
    default_source: None,
  }
}

///|
pub fn BasicSourceMap::new() -> BasicSourceMap {
  BasicSourceMap::default()
}

///|
pub fn BasicSourceMap::add_decl(
  self : BasicSourceMap,
  decl : String,
  path : ModulePath,
  item : String,
) -> Unit {
  self.mappings.set(decl, (path, item))
}

///|
pub fn BasicSourceMap::add_source(
  self : BasicSourceMap,
  file : ModulePath,
  name : String?,
  source : String,
) -> Unit {
  self.sources.set(file, (name, source))
}

///|
pub fn BasicSourceMap::set_default_source(
  self : BasicSourceMap,
  source : String,
) -> Unit {
  self.default_source = Some(source)
}

///|
pub fn BasicSourceMap::get_decl(
  self : BasicSourceMap,
  decl : String,
) -> (ModulePath, String)? {
  self.mappings.get(decl)
}

///|
pub fn BasicSourceMap::get_source(
  self : BasicSourceMap,
  path : ModulePath,
) -> String? {
  match self.sources.get(path) {
    Some((_, source)) => Some(source)
    None => None
  }
}

///|
pub fn BasicSourceMap::get_display_name(
  self : BasicSourceMap,
  path : ModulePath,
) -> String? {
  match self.sources.get(path) {
    Some((name, _)) => name
    None => None
  }
}

///|
pub fn BasicSourceMap::get_default_source(self : BasicSourceMap) -> String? {
  self.default_source
}

///|
pub fn BasicSourceMap::unmangle_identifier(
  self : BasicSourceMap,
  mangled : String,
) -> String? {
  match self.get_decl(mangled) {
    Some((path, item)) => Some("\{path.to_string()}::\{item}")
    None => None
  }
}

///|
pub fn BasicSourceMap::unmangle_text(
  self : BasicSourceMap,
  text : String,
) -> String {
  let parts : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < text.length() {
    let code = text.code_unit_at(index).to_int()
    if wesl_is_identifier_char(code) {
      if start < index {
        parts.push(text[start:index].to_owned())
      }
      let ident_start = index
      index = index + 1
      while index < text.length() &&
            wesl_is_identifier_char(text.code_unit_at(index).to_int()) {
        index = index + 1
      }
      let ident = text[ident_start:index].to_owned()
      match self.unmangle_identifier(ident) {
        Some(unmangled) => parts.push(unmangled)
        None => parts.push(ident)
      }
      start = index
    } else {
      index = index + 1
    }
  }
  if start < text.length() {
    parts.push(text[start:text.length()].to_owned())
  }
  parts.join("")
}

///|
pub impl SourceMap for BasicSourceMap with fn get_decl(self, decl) {
  self.mappings.get(decl)
}

///|
pub impl SourceMap for BasicSourceMap with fn get_source(self, path) {
  match self.sources.get(path) {
    Some((_, source)) => Some(source)
    None => None
  }
}

///|
pub impl SourceMap for BasicSourceMap with fn get_display_name(self, path) {
  match self.sources.get(path) {
    Some((name, _)) => name
    None => None
  }
}

///|
pub impl SourceMap for BasicSourceMap with fn get_default_source(self) {
  self.default_source
}

///|
pub impl SourceMap for BasicSourceMap with fn unmangle_text(self, text) {
  self.unmangle_text(text)
}

///|
pub struct NoSourceMap {}

///|
#warnings("-unnecessary_annotation")
pub fn NoSourceMap::new() -> NoSourceMap {
  NoSourceMap::{  }
}

///|
pub fn NoSourceMap::default() -> NoSourceMap {
  NoSourceMap::new()
}

///|
pub impl SourceMap for NoSourceMap with fn get_decl(_self, _decl) {
  None
}

///|
pub impl SourceMap for NoSourceMap with fn get_source(_self, _path) {
  None
}

///|
pub impl SourceMap for NoSourceMap with fn get_display_name(_self, _path) {
  None
}

///|
pub impl SourceMap for NoSourceMap with fn get_default_source(_self) {
  None
}

///|
pub struct SourceMapper[R] {
  root : ModulePath
  resolver : R
  mangler : ManglerKind
  sourcemap : BasicSourceMap
}

///|
pub fn[R] SourceMapper::new(
  root : ModulePath,
  resolver : R,
  mangler : ManglerKind,
) -> SourceMapper[R] {
  { root, resolver, mangler, sourcemap: { ..BasicSourceMap::default(), root, } }
}

///|
pub fn[R] SourceMapper::sourcemap(self : SourceMapper[R]) -> BasicSourceMap {
  self.sourcemap
}

///|
pub fn[R] SourceMapper::mangler(self : SourceMapper[R]) -> ManglerKind {
  self.mangler
}

///|
pub fn[R] SourceMapper::mangle(
  self : SourceMapper[R],
  path : ModulePath,
  item : String,
) -> String {
  let mangled = ManglerKind::mangle(self.mangler, path, item)
  self.sourcemap.add_decl(mangled, path, item)
  mangled
}

///|
pub fn[R] SourceMapper::unmangle(
  self : SourceMapper[R],
  mangled : String,
) -> (ModulePath, String)? {
  match self.sourcemap.get_decl(mangled) {
    Some((path, item)) => Some((path, item))
    None => ManglerKind::unmangle(self.mangler, mangled)
  }
}

///|
pub fn[R] SourceMapper::finish(self : SourceMapper[R]) -> BasicSourceMap {
  match self.sourcemap.get_source(self.root) {
    Some(source) => self.sourcemap.set_default_source(source)
    None => ()
  }
  self.sourcemap
}

///|
pub impl[R : Resolver] Resolver for SourceMapper[R] with fn resolve_source(
  self,
  path,
) {
  let source = R::resolve_source(self.resolver, path)
  self.sourcemap.add_source(path, R::display_name(self.resolver, path), source)
  source
}

///|
pub impl[R : Resolver] Resolver for SourceMapper[R] with fn resolve_module(
  self,
  path,
) {
  let source_result = try R::resolve_source(self.resolver, path) catch {
    err => Err(err)
  } noraise {
    source => Ok(source)
  }
  match source_result {
    Ok(source) =>
      self.sourcemap.add_source(
        path,
        R::display_name(self.resolver, path),
        source,
      )
    Err(_) => ()
  }
  R::resolve_module(self.resolver, path)
}

///|
pub impl[R : Resolver] Resolver for SourceMapper[R] with fn display_name(
  self,
  path,
) {
  R::display_name(self.resolver, path)
}

///|
pub impl[R : Resolver] Resolver for SourceMapper[R] with fn fs_path(self, path) {
  R::fs_path(self.resolver, path)
}

///|
pub struct CompileResult {
  syntax : TranslationUnit
  sourcemap : BasicSourceMap?
  modules : Array[ModulePath]
} derive(Debug)

///|
pub fn CompileResult::default() -> CompileResult {
  { syntax: TranslationUnit::default(), sourcemap: None, modules: [] }
}

///|
pub fn CompileResult::to_string(self : CompileResult) -> String {
  self.syntax.to_string()
}

///|
pub fn CompileResult::has_sourcemap(self : CompileResult) -> Bool {
  self.sourcemap is Some(_)
}

///|
pub fn CompileResult::write_to_file(
  self : CompileResult,
  path : String,
) -> Unit raise WeslCompileError {
  @fs.write_string_to_file(path, self.to_string()) catch {
    err =>
      raise Artifact(
        "failed to write output shader `\{path}`: \{@debug.to_string(err)}",
      )
  }
}

///|
fn wesl_artifact_output_path(
  artifact_name : String,
  out_dir : String?,
) -> String raise WeslCompileError {
  if artifact_name == "" {
    raise Artifact("artifact name cannot be empty")
  }
  for i in 0..<artifact_name.length() {
    let code = artifact_name.code_unit_at(i).to_int()
    if code == 47 || code == 92 || code == 46 {
      raise Artifact(
        "`artifact_name` cannot contain path separators or file extension",
      )
    }
  }
  let dirname = match out_dir {
    Some(value) => value
    None =>
      match @env.get_env_var("OUT_DIR") {
        Some(value) => value
        None => raise Artifact("OUT_DIR environment variable is not defined")
      }
  }
  if dirname == "" {
    "\{artifact_name}.wgsl"
  } else {
    "\{dirname}/\{artifact_name}.wgsl"
  }
}

///|
pub fn CompileResult::write_artifact(
  self : CompileResult,
  artifact_name : String,
  out_dir? : String? = None,
) -> Unit raise WeslCompileError {
  self.write_to_file(wesl_artifact_output_path(artifact_name, out_dir))
}

///|
pub fn CompileResult::unmangle_text(
  self : CompileResult,
  text : String,
) -> String {
  match self.sourcemap {
    Some(sourcemap) => sourcemap.unmangle_text(text)
    None => text
  }
}

///|
priv struct ImportItem {
  export_module_path : ModulePath?
  export_name : String?
  namespace_path : ModulePath
  local_name : String
  public : Bool
  start_line : Int
  end_line : Int
}

///|
priv struct ModuleItem {
  name : String?
  kind : ModuleItemKind
  header : GlobalDeclarationHeader
  attributes : Array[Attribute]
  source : String
  span : SyntaxSpan
  entrypoint : Bool
  is_const_assert : Bool
  references : Array[ModuleItemRef]
}

///|
priv enum ModuleItemKind {
  Alias
  Const
  Var
  Other
}

///|
enum ModuleItemRef {
  Local(String)
  Import(String, Int)
  Qualified(String, ModulePath, String)
} derive(Eq, Debug)

///|
priv struct ParsedModule {
  path : ModulePath
  imports : Array[ImportItem]
  import_by_local : @hashmap.HashMap[String, Int]
  items : Array[ModuleItem]
  named_items : @hashmap.HashMap[String, Int]
}

///|
priv enum ExportTarget {
  Local(Int)
  ReExport(ImportItem)
  Private
  Missing
}

///|
fn wesl_has_conditional_compile_attr(attributes : Array[Attribute]) -> Bool {
  for attr in attributes {
    if attr.name == "if" || attr.name == "elif" || attr.name == "else" {
      return true
    }
  }
  false
}

///|
fn wesl_duplicate_error(name : String, context : String) -> WeslCompileError {
  if context == name {
    Validate(Duplicate(name))
  } else {
    DuplicateSymbol(context)
  }
}

///|
fn wesl_parse_loaded_translation_unit(
  path : ModulePath,
  translation_unit : TranslationUnit,
  skip_conditional_duplicates : Bool,
) -> ParsedModule raise WeslCompileError {
  let imports : Array[ImportItem] = []
  let import_conditional : Array[Bool] = []
  let parsed_items : Array[ModuleItem] = []
  let named_items : @hashmap.HashMap[String, Int] = HashMap([])
  let duplicate_names : @hashmap.HashMap[String, Int] = HashMap([])
  for statement in translation_unit.imports {
    let conditional_import = wesl_has_conditional_compile_attr(
      statement.attributes,
    )
    for imported_name in statement.flatten_items(path) {
      imports.push({
        export_module_path: imported_name.export_module_path,
        export_name: imported_name.export_name,
        namespace_path: imported_name.namespace_path,
        local_name: imported_name.local_name,
        public: statement.is_public(),
        start_line: statement.span.start_line,
        end_line: statement.span.end_line,
      })
      import_conditional.push(conditional_import)
    }
  }
  for decl in translation_unit.global_declarations {
    let skip_duplicate = skip_conditional_duplicates &&
      wesl_has_conditional_compile_attr(decl.attributes)
    match decl.ident() {
      Some(name) => {
        if !skip_duplicate {
          if duplicate_names.contains(name) {
            let context = if skip_conditional_duplicates {
              name
            } else {
              decl.span.symbol_context(path, name)
            }
            raise wesl_duplicate_error(name, context)
          } else {
            duplicate_names.set(name, parsed_items.length())
          }
        }
        if !named_items.contains(name) {
          named_items.set(name, parsed_items.length())
        }
      }
      None => ()
    }
    parsed_items.push({
      name: decl.ident(),
      kind: wesl_item_kind(decl.header),
      header: decl.header,
      attributes: decl.attributes,
      source: decl.source,
      span: decl.span,
      entrypoint: decl.is_entrypoint(),
      is_const_assert: decl.is_const_assert(),
      references: [],
    })
  }
  let import_by_local : @hashmap.HashMap[String, Int] = HashMap([])
  for i in 0..<imports.length() {
    let import_item = imports[i]
    let skip_duplicate = skip_conditional_duplicates && import_conditional[i]
    if !skip_duplicate {
      if duplicate_names.contains(import_item.local_name) {
        let context = SyntaxSpan::{
          start_line: import_item.start_line,
          end_line: import_item.end_line,
        }.symbol_context(path, import_item.local_name)
        let duplicate_context = if skip_conditional_duplicates {
          import_item.local_name
        } else {
          context
        }
        raise wesl_duplicate_error(import_item.local_name, duplicate_context)
      } else {
        duplicate_names.set(import_item.local_name, i)
      }
    }
    if !import_by_local.contains(import_item.local_name) {
      import_by_local.set(import_item.local_name, i)
    }
  }
  for i in 0..<parsed_items.length() {
    let parsed = parsed_items[i]
    let references = wesl_collect_module_item_references(
      parsed, named_items, import_by_local, imports, path,
    )
    parsed_items[i] = { ..parsed, references, }
  }
  { path, imports, import_by_local, items: parsed_items, named_items }
}

///|
fn wesl_is_identifier_char(code : Int) -> Bool {
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95
}

///|
fn wesl_is_whitespace(code : Int) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn wesl_skip_whitespace(source : String, start : Int) -> Int {
  let mut i = start
  while i < source.length() &&
        wesl_is_whitespace(source.code_unit_at(i).to_int()) {
    i = i + 1
  }
  i
}

///|
fn wesl_skip_layout(source : String, start : Int) -> Int {
  let mut i = start
  while i < source.length() {
    i = wesl_skip_whitespace(source, i)
    if i + 1 < source.length() &&
      source.code_unit_at(i).to_int() == 47 &&
      source.code_unit_at(i + 1).to_int() == 47 {
      i += 2
      while i < source.length() && source.code_unit_at(i).to_int() != 10 {
        i += 1
      }
      continue
    }
    break
  }
  i
}

///|
fn wesl_starts_with_at(source : String, index : Int, needle : String) -> Bool {
  if index < 0 || index + needle.length() > source.length() {
    return false
  }
  source[index:index + needle.length()].to_owned() == needle
}

///|
fn wesl_find_matching_delim(
  source : String,
  start : Int,
  open_code : Int,
  close_code : Int,
) -> Int raise WeslCompileError {
  let mut depth = 0
  let mut i = start
  while i < source.length() {
    let code = source.code_unit_at(i).to_int()
    if code == open_code {
      depth = depth + 1
    } else if code == close_code {
      depth = depth - 1
      if depth == 0 {
        return i
      }
    }
    i = i + 1
  }
  raise Parse("unclosed delimiter in WESL source")
}

///|
fn wesl_eval_cond_expr_node(
  node : @cond_expr_parse.CondExprNode,
  features : Features,
) -> CondValue raise WeslCompileError {
  match node {
    Literal(value) => Known(value)
    Feature(name) => features.eval_cond(name)
    Not(inner) => wesl_eval_cond_expr_node(inner, features).not()
    And(left, right) =>
      wesl_eval_cond_expr_node(left, features).and_value(
        wesl_eval_cond_expr_node(right, features),
      )
    Or(left, right) =>
      wesl_eval_cond_expr_node(left, features).or_value(
        wesl_eval_cond_expr_node(right, features),
      )
  }
}

///|
fn wesl_eval_cond_expression(
  node : CondExpression,
  features : Features,
) -> CondValue raise WeslCompileError {
  match node {
    Literal(value) => Known(value)
    Feature(name) => features.eval_cond(name)
    Not(inner) => wesl_eval_cond_expression(inner, features).not()
    And(left, right) =>
      wesl_eval_cond_expression(left, features).and_value(
        wesl_eval_cond_expression(right, features),
      )
    Or(left, right) =>
      wesl_eval_cond_expression(left, features).or_value(
        wesl_eval_cond_expression(right, features),
      )
  }
}

///|
fn wesl_parse_if_value(
  expr : String,
  features : Features,
) -> CondValue raise WeslCompileError {
  let source = expr.trim().to_owned()
  match @cond_expr_parse.parse_cond_expr_source(source) {
    Parsed(node) => wesl_eval_cond_expr_node(node, features)
    Failed(_) => raise InvalidExpression(expr)
  }
}

///|
fn wesl_find_condcomp_block(
  source : String,
  start : Int,
) -> (Int, Int) raise WeslCompileError {
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut index = start
  while index < source.length() {
    if index + 1 < source.length() &&
      source.code_unit_at(index).to_int() == 47 &&
      source.code_unit_at(index + 1).to_int() == 47 {
      index += 2
      while index < source.length() && source.code_unit_at(index).to_int() != 10 {
        index += 1
      }
      continue
    }
    let code = source.code_unit_at(index).to_int()
    if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if code == 123 && paren_depth == 0 && bracket_depth == 0 {
      let block_end = wesl_find_matching_delim(source, index, 123, 125)
      return (index, block_end + 1)
    }
    index += 1
  }
  raise Parse("missing block after conditional attribute")
}

///|
fn wesl_find_condcomp_region(
  source : String,
  start : Int,
) -> (Int, Int) raise WeslCompileError {
  let region_start = wesl_skip_layout(source, start)
  if region_start >= source.length() {
    raise Parse("missing declaration after conditional attribute")
  }
  let first_code = source.code_unit_at(region_start).to_int()
  if first_code == 123 {
    let block_end = wesl_find_matching_delim(source, region_start, 123, 125)
    return (region_start, block_end + 1)
  }
  let tokens = parser_lex(source[region_start:source.length()].to_owned())
  let block_like = match tokens.get(0) {
    Some(Ident(keyword, _, _, _)) =>
      keyword == "fn" ||
      keyword == "struct" ||
      keyword == "if" ||
      keyword == "switch" ||
      keyword == "loop" ||
      keyword == "for" ||
      keyword == "while" ||
      keyword == "continuing"
    _ => false
  }
  if block_like {
    let (_, region_end) = wesl_find_condcomp_block(source, region_start)
    return (region_start, region_end)
  }
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  let mut index = region_start
  while index < source.length() {
    if index + 1 < source.length() &&
      source.code_unit_at(index).to_int() == 47 &&
      source.code_unit_at(index + 1).to_int() == 47 {
      index += 2
      while index < source.length() && source.code_unit_at(index).to_int() != 10 {
        index += 1
      }
      continue
    }
    let code = source.code_unit_at(index).to_int()
    if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 {
        return (region_start, index)
      }
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if code == 123 {
      brace_depth += 1
    } else if code == 125 {
      if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 {
        return (region_start, index)
      }
      brace_depth -= 1
    } else if code == 44 &&
      paren_depth == 0 &&
      bracket_depth == 0 &&
      brace_depth == 0 {
      return (region_start, index + 1)
    } else if code == 59 &&
      paren_depth == 0 &&
      bracket_depth == 0 &&
      brace_depth == 0 {
      return (region_start, index + 1)
    }
    index += 1
  }
  (region_start, source.length())
}

///|
fn wesl_apply_condcomp(
  source : String,
  features : Features,
) -> String raise WeslCompileError {
  let mut out = ""
  let mut index = 0
  while index < source.length() {
    if wesl_starts_with_at(source, index, "@if") {
      let expr_start = wesl_skip_layout(source, index + 3)
      if expr_start >= source.length() ||
        source.code_unit_at(expr_start).to_int() != 40 {
        raise InvalidExpression(source[index:source.length()].to_owned())
      }
      let expr_end = wesl_find_matching_delim(source, expr_start, 40, 41)
      let expr = source[expr_start + 1:expr_end].to_owned()
      let (region_start, region_end) = wesl_find_condcomp_region(
        source,
        expr_end + 1,
      )
      let region = wesl_apply_condcomp(
        source[region_start:region_end].to_owned(),
        features,
      )
      let mut prev_true = false
      let mut prev_removed = false
      match wesl_parse_if_value(expr, features) {
        Known(true) => {
          out = out + region
          prev_true = true
          prev_removed = false
        }
        Known(false) => prev_removed = true
        Unknown => {
          out = out + source[index:expr_end + 1].to_owned() + "\n" + region
          prev_removed = false
        }
      }
      let mut next_index = region_end
      while true {
        let attr_start = wesl_skip_layout(source, next_index)
        if wesl_starts_with_at(source, attr_start, "@elif") {
          let elif_expr_start = wesl_skip_layout(source, attr_start + 5)
          if elif_expr_start >= source.length() ||
            source.code_unit_at(elif_expr_start).to_int() != 40 {
            raise InvalidExpression(
              source[attr_start:source.length()].to_owned(),
            )
          }
          let elif_expr_end = wesl_find_matching_delim(
            source, elif_expr_start, 40, 41,
          )
          let elif_expr = source[elif_expr_start + 1:elif_expr_end].to_owned()
          let (elif_region_start, elif_region_end) = wesl_find_condcomp_region(
            source,
            elif_expr_end + 1,
          )
          let elif_region = wesl_apply_condcomp(
            source[elif_region_start:elif_region_end].to_owned(),
            features,
          )
          if prev_true {
            prev_removed = true
          } else {
            match wesl_parse_if_value(elif_expr, features) {
              Known(true) => {
                if prev_removed {
                  out = out + elif_region
                } else {
                  out = out + "@else\n" + elif_region
                }
                prev_true = true
                prev_removed = false
              }
              Known(false) => prev_removed = true
              Unknown => {
                if prev_removed {
                  out = out + "@if(" + elif_expr + ")\n" + elif_region
                } else {
                  out = out +
                    source[attr_start:elif_expr_end + 1].to_owned() +
                    "\n" +
                    elif_region
                }
                prev_removed = false
              }
            }
          }
          next_index = elif_region_end
          continue
        }
        if !wesl_starts_with_at(source, attr_start, "@else") {
          break
        }
        let tail_start = wesl_skip_layout(source, attr_start + 5)
        if wesl_starts_with_at(source, tail_start, "if") {
          let elif_expr_start = wesl_skip_layout(source, tail_start + 2)
          if elif_expr_start >= source.length() ||
            source.code_unit_at(elif_expr_start).to_int() != 40 {
            raise InvalidExpression(
              source[attr_start:source.length()].to_owned(),
            )
          }
          let elif_expr_end = wesl_find_matching_delim(
            source, elif_expr_start, 40, 41,
          )
          let elif_expr = source[elif_expr_start + 1:elif_expr_end].to_owned()
          let (elif_region_start, elif_region_end) = wesl_find_condcomp_region(
            source,
            elif_expr_end + 1,
          )
          let elif_region = wesl_apply_condcomp(
            source[elif_region_start:elif_region_end].to_owned(),
            features,
          )
          if prev_true {
            prev_removed = true
          } else {
            match wesl_parse_if_value(elif_expr, features) {
              Known(true) => {
                if prev_removed {
                  out = out + elif_region
                } else {
                  out = out + "@else\n" + elif_region
                }
                prev_true = true
                prev_removed = false
              }
              Known(false) => prev_removed = true
              Unknown => {
                if prev_removed {
                  out = out + "@if(" + elif_expr + ")\n" + elif_region
                } else {
                  out = out + "@elif(" + elif_expr + ")\n" + elif_region
                }
                prev_removed = false
              }
            }
          }
          next_index = elif_region_end
          continue
        }
        let (else_region_start, else_region_end) = wesl_find_condcomp_region(
          source, tail_start,
        )
        let else_region = wesl_apply_condcomp(
          source[else_region_start:else_region_end].to_owned(),
          features,
        )
        if !prev_true {
          if prev_removed {
            out = out + else_region
          } else {
            out = out + source[attr_start:tail_start].to_owned() + else_region
          }
        }
        next_index = else_region_end
        break
      }
      index = next_index
      continue
    }
    out = out + source[index:index + 1].to_owned()
    index = index + 1
  }
  out
}

///|
priv struct CondCompEvalState {
  mut has_if : Bool
  mut is_true : Bool
  mut removed : Bool
}

///|
fn CondCompEvalState::new() -> CondCompEvalState {
  { has_if: false, is_true: false, removed: false }
}

///|
fn wesl_is_condcomp_attribute(attribute : Attribute) -> Bool {
  attribute.name == "if" || attribute.name == "elif" || attribute.name == "else"
}

///|
fn wesl_single_condcomp_attribute(
  attributes : Array[Attribute],
) -> Attribute? raise WeslCompileError {
  let mut found : Attribute? = None
  for attribute in attributes {
    if wesl_is_condcomp_attribute(attribute) {
      match found {
        Some(_) =>
          raise InvalidExpression(
            "cannot have multiple @if/@elif/@else attributes on the same node",
          )
        None => found = Some(attribute)
      }
    }
  }
  found
}

///|
fn wesl_filter_condcomp_attributes(
  attributes : Array[Attribute],
  replacement : Attribute?,
) -> Array[Attribute] {
  let filtered : Array[Attribute] = []
  let mut inserted = false
  for attribute in attributes {
    if wesl_is_condcomp_attribute(attribute) {
      if !inserted {
        match replacement {
          Some(next) => filtered.push(next)
          None => ()
        }
        inserted = true
      }
    } else {
      filtered.push(attribute)
    }
  }
  filtered
}

///|
fn wesl_condcomp_attr_end(
  source : String,
  at_index : Int,
) -> Int raise WeslCompileError {
  let name_start = at_index + 1
  let mut name_end = name_start
  while name_end < source.length() &&
        wesl_is_identifier_char(source.code_unit_at(name_end).to_int()) {
    name_end += 1
  }
  let name = source[name_start:name_end].to_owned()
  if name == "if" || name == "elif" {
    let expr_start = wesl_skip_layout(source, name_end)
    if expr_start >= source.length() ||
      source.code_unit_at(expr_start).to_int() != 40 {
      raise InvalidExpression(source[at_index:source.length()].to_owned())
    }
    let expr_end = wesl_find_matching_delim(source, expr_start, 40, 41)
    wesl_skip_layout(source, expr_end + 1)
  } else if name == "else" {
    wesl_skip_layout(source, name_end)
  } else {
    name_end
  }
}

///|
fn wesl_remove_leading_condcomp_attr(
  source : String,
) -> String raise WeslCompileError {
  let attr_start = wesl_skip_layout(source, 0)
  if attr_start < source.length() &&
    source.code_unit_at(attr_start).to_int() == 64 {
    let attr_end = wesl_condcomp_attr_end(source, attr_start)
    source[0:attr_start].to_owned() +
    source[attr_end:source.length()].to_owned()
  } else {
    source
  }
}

///|
fn wesl_replace_leading_condcomp_attr(
  source : String,
  replacement : String,
) -> String raise WeslCompileError {
  let attr_start = wesl_skip_layout(source, 0)
  if attr_start < source.length() &&
    source.code_unit_at(attr_start).to_int() == 64 {
    let attr_end = wesl_condcomp_attr_end(source, attr_start)
    source[0:attr_start].to_owned() +
    replacement +
    "\n" +
    source[attr_end:source.length()].to_owned()
  } else {
    source
  }
}

///|
fn wesl_condcomp_attr_value(
  attr : Attribute,
  features : Features,
) -> CondValue raise WeslCompileError {
  match attr.condition_expr {
    Some(expr) => wesl_eval_cond_expression(expr, features)
    None =>
      match attr.arguments {
        Some(expr) => wesl_parse_if_value(expr, features)
        None => raise InvalidExpression("missing @\{attr.name} expression")
      }
  }
}

///|
fn wesl_transform_condcomp_node(
  attr : Attribute?,
  attributes : Array[Attribute],
  source : String,
  features : Features,
  state : CondCompEvalState,
) -> (Bool, Array[Attribute]?, String?) raise WeslCompileError {
  match attr {
    None => {
      state.has_if = false
      let transformed = wesl_apply_condcomp(source, features)
      (true, None, Some(transformed))
    }
    Some(cond_attr) => {
      let mut keep_node = true
      let mut remove_attr = false
      let mut replacement : Attribute? = None
      let mut replacement_source : String? = None
      let mut is_true = false
      match cond_attr.name {
        "if" => {
          state.has_if = true
          state.is_true = false
          match wesl_condcomp_attr_value(cond_attr, features) {
            Known(true) => {
              remove_attr = true
              is_true = true
            }
            Known(false) => keep_node = false
            Unknown => replacement = Some(cond_attr)
          }
        }
        "elif" => {
          if !state.has_if {
            raise InvalidExpression(
              "an @elif or @else attribute must be preceded by a @if or @elif on the previous node",
            )
          }
          state.has_if = true
          match wesl_condcomp_attr_value(cond_attr, features) {
            Known(true) =>
              if state.is_true {
                keep_node = false
              } else {
                is_true = true
                if state.removed {
                  remove_attr = true
                } else {
                  replacement = Some({
                    ..cond_attr,
                    name: "else",
                    arguments: None,
                    argument_exprs: [],
                    condition_expr: None,
                  })
                  replacement_source = Some("@else")
                }
              }
            Known(false) => keep_node = false
            Unknown =>
              if state.removed {
                replacement = Some({ ..cond_attr, name: "if" })
                let expr = cond_attr.arguments.unwrap_or("")
                replacement_source = Some("@if(\{expr})")
              } else {
                replacement = Some(cond_attr)
              }
          }
        }
        "else" => {
          if !state.has_if {
            raise InvalidExpression(
              "an @elif or @else attribute must be preceded by a @if or @elif on the previous node",
            )
          }
          state.has_if = false
          if state.is_true {
            keep_node = false
          } else if state.removed {
            remove_attr = true
          } else {
            replacement = Some(cond_attr)
          }
        }
        _ => ()
      }
      state.is_true = is_true || state.is_true
      state.removed = !keep_node
      if !keep_node {
        (false, None, None)
      } else {
        let next_source = match replacement_source {
          Some(text) => wesl_replace_leading_condcomp_attr(source, text)
          None =>
            if remove_attr {
              wesl_remove_leading_condcomp_attr(source)
            } else {
              source
            }
        }
        let transformed = wesl_apply_condcomp(next_source, features)
        let next_attrs = if remove_attr {
          Some(wesl_filter_condcomp_attributes(attributes, None))
        } else {
          Some(wesl_filter_condcomp_attributes(attributes, replacement))
        }
        (true, next_attrs, Some(transformed))
      }
    }
  }
}

///|
fn wesl_condcomp_imports(
  imports : Array[ImportStatement],
  features : Features,
) -> Array[ImportStatement] raise WeslCompileError {
  let out : Array[ImportStatement] = []
  let state = CondCompEvalState::new()
  for statement in imports {
    let attr = wesl_single_condcomp_attribute(statement.attributes)
    let (keep_node, next_attrs, next_source) = wesl_transform_condcomp_node(
      attr,
      statement.attributes,
      statement.source,
      features,
      state,
    )
    if keep_node {
      out.push({
        ..statement,
        attributes: next_attrs.unwrap_or(statement.attributes),
        source: next_source.unwrap_or(statement.source),
      })
    }
  }
  out
}

///|
fn wesl_condcomp_declarations(
  declarations : Array[GlobalDeclaration],
  features : Features,
) -> Array[GlobalDeclaration] raise WeslCompileError {
  let out : Array[GlobalDeclaration] = []
  let state = CondCompEvalState::new()
  for declaration in declarations {
    let attr = wesl_single_condcomp_attribute(declaration.attributes)
    let (keep_node, next_attrs, next_source) = wesl_transform_condcomp_node(
      attr,
      declaration.attributes,
      declaration.source,
      features,
      state,
    )
    if keep_node {
      let transformed_source = next_source.unwrap_or(declaration.source)
      let transformed_declarations = parse_global_declarations(
        transformed_source,
      )
      guard transformed_declarations.length() == 1 else {
        raise Parse(
          "conditional compilation produced an invalid declaration: \{transformed_source}",
        )
      }
      out.push({
        ..transformed_declarations[0],
        attributes: next_attrs.unwrap_or(transformed_declarations[0].attributes),
        span: declaration.span,
      })
    }
  }
  out
}

///|
pub struct CondCompPreprocessor {
  features : Features
}

///|
pub fn CondCompPreprocessor::new(features : Features) -> CondCompPreprocessor {
  { features, }
}

///|
pub impl ModulePreprocessor for CondCompPreprocessor with fn preprocess_module(
  self,
  _path,
  unit,
) {
  {
    imports: wesl_condcomp_imports(unit.imports, self.features) catch {
      err => raise Error(err.message())
    },
    global_declarations: wesl_condcomp_declarations(
      unit.global_declarations,
      self.features,
    ) catch {
      err => raise Error(err.message())
    },
  }
}

///|
fn wesl_push_unique(items : Array[String], value : String) -> Unit {
  if value == "" {
    return
  }
  for item in items {
    if item == value {
      return
    }
  }
  items.push(value)
}

///|
fn wesl_scopes_contain(
  scopes : Array[Array[String]],
  scope_depth : Int,
  name : String,
) -> Bool {
  let mut depth = scope_depth
  while depth >= 0 {
    for item in scopes[depth] {
      if item == name {
        return true
      }
    }
    depth -= 1
  }
  false
}

///|
fn wesl_bind_scope(
  scopes : Array[Array[String]],
  scope_depth : Int,
  name : String,
) -> Unit {
  wesl_push_unique(scopes[scope_depth], name)
}

///|
fn wesl_push_unique_item_ref(
  items : Array[ModuleItemRef],
  value : ModuleItemRef,
) -> Unit {
  for item in items {
    if item == value {
      return
    }
  }
  items.push(value)
}

///|
fn wesl_resolve_module_path(
  current_path : ModulePath,
  module_path_text : String,
) -> ModulePath raise WeslCompileError {
  let raw_module_path = parse_module_path(module_path_text.trim().to_owned()) catch {
    err => raise Parse(err.message())
  }
  match raw_module_path.origin {
    Package(name) if raw_module_path.components.is_empty() =>
      return ModulePath::new(Absolute, [name])
    _ => ()
  }
  current_path.join_path(raw_module_path)
}

///|
fn wesl_slice_segments(
  segments : Array[String],
  start : Int,
  end_ : Int,
) -> Array[String] {
  let out : Array[String] = []
  for i = start; i < end_; i = i + 1 {
    out.push(segments[i])
  }
  out
}

///|
fn wesl_extend_module_path(
  base_path : ModulePath,
  extra_segments : Array[String],
) -> ModulePath raise WeslCompileError {
  if extra_segments.is_empty() {
    return base_path
  }
  let suffix = extra_segments.join("::")
  let full_path = "\{base_path.to_string()}::\{suffix}"
  parse_module_path(full_path) catch {
    err => raise Parse(err.message())
  }
}

///|
fn wesl_token_text(source : String, token : ParserToken) -> String {
  source[token.start():token.end()].to_owned()
}

///|
fn wesl_is_declaration_keyword(name : String) -> Bool {
  name == "fn" ||
  name == "struct" ||
  name == "alias" ||
  name == "const" ||
  name == "override" ||
  name == "let" ||
  name == "var"
}

///|
fn wesl_binding_keyword_before(
  tokens : Array[ParserToken],
  index : Int,
) -> String? {
  if index <= 0 {
    return None
  }
  match tokens[index - 1] {
    Ident(previous, _, _, _) if wesl_is_declaration_keyword(previous) =>
      return Some(previous)
    Gt(_, _, _) => {
      let mut depth = 1
      let mut i = index - 2
      while i >= 0 {
        match tokens[i] {
          Gt(_, _, _) => depth += 1
          Lt(_, _, _) => {
            depth -= 1
            if depth == 0 {
              break
            }
          }
          _ => ()
        }
        i -= 1
      }
      if i > 0 {
        match tokens[i - 1] {
          Ident(previous, _, _, _) if wesl_is_declaration_keyword(previous) =>
            return Some(previous)
          _ => ()
        }
      }
    }
    _ => ()
  }
  None
}

///|
fn wesl_is_bound_identifier(
  source : String,
  tokens : Array[ParserToken],
  index : Int,
) -> Bool {
  if wesl_binding_keyword_before(tokens, index) is Some(_) {
    return true
  }
  if index + 1 < tokens.length() {
    match tokens[index + 1] {
      Other(_, _, _) => wesl_token_text(source, tokens[index + 1]) == ":"
      _ => false
    }
  } else {
    false
  }
}

///|
fn wesl_collect_qualified_segments(
  source : String,
  tokens : Array[ParserToken],
  start_index : Int,
) -> (Array[String], String, Int) {
  let segments : Array[String] = []
  let start_offset = tokens[start_index].start()
  let mut end_offset = tokens[start_index].end()
  let mut index = start_index
  while index < tokens.length() {
    match tokens[index] {
      Ident(segment, _, end_, _) => {
        segments.push(segment)
        end_offset = end_
        index += 1
      }
      _ => break
    }
    if index + 1 < tokens.length() &&
      tokens[index] is DoubleColon(_, _, _) &&
      tokens[index + 1] is Ident(_, _, _, _) {
      index += 1
      continue
    }
    break
  }
  (segments, source[start_offset:end_offset].to_owned(), index)
}

///|
fn wesl_resolve_qualified_import_target(
  import_item : ImportItem,
  segments : Array[String],
) -> (ModulePath, String) raise WeslCompileError {
  let item_name = segments[segments.length() - 1]
  let module_path = wesl_extend_module_path(
    import_item.namespace_path,
    wesl_slice_segments(segments, 1, segments.length() - 1),
  )
  (module_path, item_name)
}

///|
fn wesl_resolve_direct_qualified_target(
  current_path : ModulePath,
  segments : Array[String],
) -> (ModulePath, String) raise WeslCompileError {
  let item_name = segments[segments.length() - 1]
  let module_path = wesl_resolve_module_path(
    current_path,
    wesl_slice_segments(segments, 0, segments.length() - 1).join("::"),
  )
  (module_path, item_name)
}

///|
fn wesl_import_named_target(import_item : ImportItem) -> (ModulePath, String)? {
  match import_item.export_module_path {
    Some(export_module_path) =>
      match import_item.export_name {
        Some(export_name) => Some((export_module_path, export_name))
        None => None
      }
    None => None
  }
}

///|
fn wesl_collect_legacy_item_references(
  source : String,
  item_name : String?,
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Array[ModuleItemRef] {
  let references : Array[ModuleItemRef] = []
  let tokens = parser_lex(source)
  let scopes : Array[Array[String]] = [[]]
  let mut scope_depth = 0
  let mut consumed_item_decl = item_name is None
  let mut index = 0
  while index < tokens.length() {
    match tokens[index] {
      LBrace(_, _, _) => {
        scope_depth += 1
        if scope_depth < scopes.length() {
          scopes[scope_depth] = []
        } else {
          scopes.push([])
        }
      }
      RBrace(_, _, _) => if scope_depth > 0 { scope_depth -= 1 }
      Ident(name, _, _, _) => {
        let is_binding = wesl_is_bound_identifier(source, tokens, index)
        if is_binding {
          let is_item_decl = match item_name {
            Some(current_item_name) =>
              !consumed_item_decl && name == current_item_name
            None => false
          }
          if is_item_decl {
            consumed_item_decl = true
          } else {
            wesl_bind_scope(scopes, scope_depth, name)
          }
          index += 1
          continue
        }
        if index + 1 < tokens.length() &&
          tokens[index + 1] is DoubleColon(_, _, _) {
          let (segments, raw_text, next_index) = wesl_collect_qualified_segments(
            source, tokens, index,
          )
          if segments.length() >= 2 &&
            !wesl_scopes_contain(scopes, scope_depth, segments[0]) {
            match import_by_local.get(segments[0]) {
              Some(import_index) => {
                let (target_path, target_name) = wesl_resolve_qualified_import_target(
                  imports[import_index],
                  segments,
                ) catch {
                  _ =>
                    (
                      imports[import_index].namespace_path,
                      segments[segments.length() - 1],
                    )
                }
                wesl_push_unique_item_ref(
                  references,
                  Qualified(raw_text, target_path, target_name),
                )
              }
              None =>
                if segments[0] == "package" ||
                  segments[0] == "self" ||
                  segments[0] == "super" {
                  let (target_path, target_name) = wesl_resolve_direct_qualified_target(
                    current_path, segments,
                  ) catch {
                    _ => (current_path, segments[segments.length() - 1])
                  }
                  wesl_push_unique_item_ref(
                    references,
                    Qualified(raw_text, target_path, target_name),
                  )
                }
            }
          }
          index = next_index
          continue
        }
        if wesl_scopes_contain(scopes, scope_depth, name) {
          index += 1
          continue
        }
        if named_items.contains(name) {
          wesl_push_unique_item_ref(references, Local(name))
        } else {
          match import_by_local.get(name) {
            Some(import_index) =>
              if wesl_import_named_target(imports[import_index]) is Some(_) {
                wesl_push_unique_item_ref(
                  references,
                  Import(name, import_index),
                )
              }
            None => ()
          }
        }
      }
      _ => ()
    }
    index += 1
  }
  references
}

///|
fn wesl_ast_raw_path(ty : TypeExpression) -> String {
  let mut raw = ""
  for segment in ty.path {
    if raw == "" {
      raw = segment
    } else {
      raw = raw + "::" + segment
    }
  }
  if raw == "" {
    ty.ident
  } else {
    raw + "::" + ty.ident
  }
}

///|
fn wesl_ast_path_segments(ty : TypeExpression) -> Array[String] {
  let segments : Array[String] = []
  for segment in ty.path {
    segments.push(segment)
  }
  segments.push(ty.ident)
  segments
}

///|
fn wesl_ast_bind_name(scopes : Array[Array[String]], name : String) -> Unit {
  if scopes.length() == 0 {
    return
  }
  wesl_push_unique(scopes[scopes.length() - 1], name)
}

///|
fn wesl_ast_name_is_bound(scopes : Array[Array[String]], name : String) -> Bool {
  if scopes.length() == 0 {
    return false
  }
  wesl_scopes_contain(scopes, scopes.length() - 1, name)
}

///|
fn wesl_ast_collect_type_reference(
  ty : TypeExpression,
  references : Array[ModuleItemRef],
  scopes : Array[Array[String]],
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Unit {
  if ty.path.length() == 0 {
    if !wesl_ast_name_is_bound(scopes, ty.ident) {
      if named_items.contains(ty.ident) {
        wesl_push_unique_item_ref(references, Local(ty.ident))
      } else {
        match import_by_local.get(ty.ident) {
          Some(import_index) =>
            if wesl_import_named_target(imports[import_index]) is Some(_) {
              wesl_push_unique_item_ref(
                references,
                Import(ty.ident, import_index),
              )
            }
          None => ()
        }
      }
    }
  } else if !wesl_ast_name_is_bound(scopes, ty.path[0]) {
    let segments = wesl_ast_path_segments(ty)
    match import_by_local.get(segments[0]) {
      Some(import_index) => {
        let (target_path, target_name) = wesl_resolve_qualified_import_target(
          imports[import_index],
          segments,
        ) catch {
          _ => (imports[import_index].namespace_path, ty.ident)
        }
        wesl_push_unique_item_ref(
          references,
          Qualified(wesl_ast_raw_path(ty), target_path, target_name),
        )
      }
      None =>
        if segments[0] == "package" ||
          segments[0] == "self" ||
          segments[0] == "super" {
          let (target_path, target_name) = wesl_resolve_direct_qualified_target(
            current_path, segments,
          ) catch {
            _ => (current_path, ty.ident)
          }
          wesl_push_unique_item_ref(
            references,
            Qualified(wesl_ast_raw_path(ty), target_path, target_name),
          )
        }
    }
  }
  for arg in ty.template_args {
    match arg {
      Type(template_type) =>
        wesl_ast_collect_type_reference(
          template_type, references, scopes, named_items, import_by_local, imports,
          current_path,
        )
      Literal(_) => ()
    }
  }
}

///|
fn wesl_ast_collect_expression_references(
  expr : Expression,
  references : Array[ModuleItemRef],
  scopes : Array[Array[String]],
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Unit {
  match expr {
    Literal(_) | Bool(_) => ()
    TypeOrIdentifier(ty) =>
      wesl_ast_collect_type_reference(
        ty, references, scopes, named_items, import_by_local, imports, current_path,
      )
    Parenthesized(inner) =>
      wesl_ast_collect_expression_references(
        inner, references, scopes, named_items, import_by_local, imports, current_path,
      )
    NamedComponent(base, _) =>
      wesl_ast_collect_expression_references(
        base, references, scopes, named_items, import_by_local, imports, current_path,
      )
    Indexing(base, index) => {
      wesl_ast_collect_expression_references(
        base, references, scopes, named_items, import_by_local, imports, current_path,
      )
      wesl_ast_collect_expression_references(
        index, references, scopes, named_items, import_by_local, imports, current_path,
      )
    }
    Unary(_, operand) =>
      wesl_ast_collect_expression_references(
        operand, references, scopes, named_items, import_by_local, imports, current_path,
      )
    Binary(_, lhs, rhs) => {
      wesl_ast_collect_expression_references(
        lhs, references, scopes, named_items, import_by_local, imports, current_path,
      )
      wesl_ast_collect_expression_references(
        rhs, references, scopes, named_items, import_by_local, imports, current_path,
      )
    }
    FunctionCall(call) => {
      wesl_ast_collect_type_reference(
        call.callee,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
      for arg in call.arguments {
        wesl_ast_collect_expression_references(
          arg, references, scopes, named_items, import_by_local, imports, current_path,
        )
      }
    }
  }
}

///|
fn wesl_ast_collect_attribute_references(
  attribute : Attribute,
  references : Array[ModuleItemRef],
  scopes : Array[Array[String]],
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Unit {
  for expr in attribute.argument_exprs {
    wesl_ast_collect_expression_references(
      expr, references, scopes, named_items, import_by_local, imports, current_path,
    )
  }
}

///|
fn wesl_ast_collect_attributes_references(
  attributes : Array[Attribute],
  references : Array[ModuleItemRef],
  scopes : Array[Array[String]],
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Unit {
  for attribute in attributes {
    wesl_ast_collect_attribute_references(
      attribute, references, scopes, named_items, import_by_local, imports, current_path,
    )
  }
}

///|
fn wesl_ast_collect_declaration_references(
  declaration : StatementDeclaration,
  references : Array[ModuleItemRef],
  scopes : Array[Array[String]],
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Unit {
  match declaration.type_expr {
    Some(ty) =>
      wesl_ast_collect_type_reference(
        ty, references, scopes, named_items, import_by_local, imports, current_path,
      )
    None => ()
  }
  match declaration.initializer_expr {
    Some(expr) =>
      wesl_ast_collect_expression_references(
        expr, references, scopes, named_items, import_by_local, imports, current_path,
      )
    None => ()
  }
  match declaration.name {
    Some(name) => wesl_ast_bind_name(scopes, name)
    None => ()
  }
}

///|
fn wesl_ast_collect_statement_references(
  statement : Statement,
  references : Array[ModuleItemRef],
  scopes : Array[Array[String]],
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Unit {
  wesl_ast_collect_attributes_references(
    statement.attributes,
    references,
    scopes,
    named_items,
    import_by_local,
    imports,
    current_path,
  )
  match statement.expression {
    Some(expr) =>
      wesl_ast_collect_expression_references(
        expr, references, scopes, named_items, import_by_local, imports, current_path,
      )
    None => ()
  }
  match statement.declaration {
    Some(declaration) =>
      wesl_ast_collect_declaration_references(
        declaration, references, scopes, named_items, import_by_local, imports, current_path,
      )
    None => ()
  }
  match statement.assignment {
    Some(assignment) => {
      wesl_ast_collect_expression_references(
        assignment.lhs,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
      wesl_ast_collect_expression_references(
        assignment.rhs,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
    }
    None => ()
  }
  match statement.update_expression {
    Some(expr) =>
      wesl_ast_collect_expression_references(
        expr, references, scopes, named_items, import_by_local, imports, current_path,
      )
    None => ()
  }
  match statement.control {
    Some(control) =>
      wesl_ast_collect_control_references(
        control, references, scopes, named_items, import_by_local, imports, current_path,
      )
    None => ()
  }
}

///|
fn wesl_ast_collect_body_references(
  body : FunctionBody,
  references : Array[ModuleItemRef],
  scopes : Array[Array[String]],
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Unit {
  scopes.push([])
  for statement in body.statements {
    wesl_ast_collect_statement_references(
      statement, references, scopes, named_items, import_by_local, imports, current_path,
    )
  }
  ignore(scopes.pop())
}

///|
fn wesl_ast_collect_control_references(
  control : ControlStatement,
  references : Array[ModuleItemRef],
  scopes : Array[Array[String]],
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Unit {
  match control {
    Block(block) =>
      wesl_ast_collect_body_references(
        block.body,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
    If(if_) => {
      wesl_ast_collect_expression_references(
        if_.condition,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
      wesl_ast_collect_body_references(
        if_.body,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
      match if_.else_body {
        Some(body) =>
          wesl_ast_collect_body_references(
            body, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
    }
    Switch(switch_) => {
      wesl_ast_collect_expression_references(
        switch_.selector,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
      for case_ in switch_.cases {
        wesl_ast_collect_attributes_references(
          case_.attributes,
          references,
          scopes,
          named_items,
          import_by_local,
          imports,
          current_path,
        )
        for selector in case_.selectors {
          wesl_ast_collect_expression_references(
            selector, references, scopes, named_items, import_by_local, imports,
            current_path,
          )
        }
        wesl_ast_collect_body_references(
          case_.body,
          references,
          scopes,
          named_items,
          import_by_local,
          imports,
          current_path,
        )
      }
    }
    Loop(loop_) =>
      wesl_ast_collect_body_references(
        loop_.body,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
    For(for_) => {
      scopes.push([])
      match for_.initializer {
        Some(Declaration(declaration)) =>
          wesl_ast_collect_declaration_references(
            declaration, references, scopes, named_items, import_by_local, imports,
            current_path,
          )
        Some(Assignment(assignment)) => {
          wesl_ast_collect_expression_references(
            assignment.lhs,
            references,
            scopes,
            named_items,
            import_by_local,
            imports,
            current_path,
          )
          wesl_ast_collect_expression_references(
            assignment.rhs,
            references,
            scopes,
            named_items,
            import_by_local,
            imports,
            current_path,
          )
        }
        Some(Expression(expr)) =>
          wesl_ast_collect_expression_references(
            expr, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
      match for_.condition {
        Some(expr) =>
          wesl_ast_collect_expression_references(
            expr, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
      match for_.update {
        Some(Assignment(assignment)) => {
          wesl_ast_collect_expression_references(
            assignment.lhs,
            references,
            scopes,
            named_items,
            import_by_local,
            imports,
            current_path,
          )
          wesl_ast_collect_expression_references(
            assignment.rhs,
            references,
            scopes,
            named_items,
            import_by_local,
            imports,
            current_path,
          )
        }
        Some(Increment(expr))
        | Some(Decrement(expr))
        | Some(Expression(expr)) =>
          wesl_ast_collect_expression_references(
            expr, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
      wesl_ast_collect_body_references(
        for_.body,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
      ignore(scopes.pop())
    }
    While(while_) => {
      wesl_ast_collect_expression_references(
        while_.condition,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
      wesl_ast_collect_body_references(
        while_.body,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
    }
    Continuing(continuing) =>
      wesl_ast_collect_body_references(
        continuing.body,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
  }
}

///|
fn wesl_collect_ast_item_references(
  header : GlobalDeclarationHeader,
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Array[ModuleItemRef] {
  let references : Array[ModuleItemRef] = []
  let scopes : Array[Array[String]] = [[]]
  match header {
    Alias(alias_decl) =>
      match alias_decl.target_type {
        Some(ty) =>
          wesl_ast_collect_type_reference(
            ty, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
    Const(const_) => {
      match const_.type_expr {
        Some(ty) =>
          wesl_ast_collect_type_reference(
            ty, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
      match const_.initializer_expr {
        Some(expr) =>
          wesl_ast_collect_expression_references(
            expr, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
    }
    Override(override_) => {
      match override_.type_expr {
        Some(ty) =>
          wesl_ast_collect_type_reference(
            ty, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
      match override_.initializer_expr {
        Some(expr) =>
          wesl_ast_collect_expression_references(
            expr, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
    }
    Let(let_) => {
      match let_.type_expr {
        Some(ty) =>
          wesl_ast_collect_type_reference(
            ty, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
      match let_.initializer_expr {
        Some(expr) =>
          wesl_ast_collect_expression_references(
            expr, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
    }
    Var(var_) => {
      match var_.type_expr {
        Some(ty) =>
          wesl_ast_collect_type_reference(
            ty, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
      match var_.initializer_expr {
        Some(expr) =>
          wesl_ast_collect_expression_references(
            expr, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
    }
    Function(function_) => {
      for parameter in function_.parameters {
        wesl_ast_collect_attributes_references(
          parameter.attributes,
          references,
          scopes,
          named_items,
          import_by_local,
          imports,
          current_path,
        )
        wesl_ast_collect_type_reference(
          parameter.type_expr,
          references,
          scopes,
          named_items,
          import_by_local,
          imports,
          current_path,
        )
      }
      match function_.return_type_expr {
        Some(ty) =>
          wesl_ast_collect_type_reference(
            ty, references, scopes, named_items, import_by_local, imports, current_path,
          )
        None => ()
      }
      wesl_ast_collect_attributes_references(
        function_.return_attributes,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
      for parameter in function_.parameters {
        wesl_ast_bind_name(scopes, parameter.name)
      }
      wesl_ast_collect_body_references(
        function_.body,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
    }
    Struct(struct_) =>
      for field in struct_.members {
        wesl_ast_collect_attributes_references(
          field.attributes,
          references,
          scopes,
          named_items,
          import_by_local,
          imports,
          current_path,
        )
        wesl_ast_collect_type_reference(
          field.type_expr,
          references,
          scopes,
          named_items,
          import_by_local,
          imports,
          current_path,
        )
      }
    ConstAssert(assertion) =>
      wesl_ast_collect_expression_references(
        assertion.assertion_expr,
        references,
        scopes,
        named_items,
        import_by_local,
        imports,
        current_path,
      )
    EnableDirective(_)
    | RequiresDirective(_)
    | DiagnosticDirective(_)
    | Other => ()
  }
  references
}

///|
fn wesl_collect_module_item_references(
  item : ModuleItem,
  named_items : @hashmap.HashMap[String, Int],
  import_by_local : @hashmap.HashMap[String, Int],
  imports : Array[ImportItem],
  current_path : ModulePath,
) -> Array[ModuleItemRef] {
  let references : Array[ModuleItemRef] = []
  let scopes : Array[Array[String]] = [[]]
  wesl_ast_collect_attributes_references(
    item.attributes,
    references,
    scopes,
    named_items,
    import_by_local,
    imports,
    current_path,
  )
  for
    reference in wesl_collect_ast_item_references(
      item.header,
      named_items,
      import_by_local,
      imports,
      current_path,
    ) {
    wesl_push_unique_item_ref(references, reference)
  }
  for
    reference in wesl_collect_legacy_item_references(
      item.source,
      item.name,
      named_items,
      import_by_local,
      imports,
      current_path,
    ) {
    wesl_push_unique_item_ref(references, reference)
  }
  references
}

///|
fn wesl_replace_identifier(
  source : String,
  old_name : String,
  new_name : String,
) -> String {
  if old_name == new_name || old_name == "" {
    return source
  }
  let mut out = ""
  let mut index = 0
  while index < source.length() {
    let can_match = index + old_name.length() <= source.length() &&
      source[index:index + old_name.length()].to_owned() == old_name
    if can_match {
      let prev_code = if index == 0 {
        -1
      } else {
        source.code_unit_at(index - 1).to_int()
      }
      let next_code = if index + old_name.length() >= source.length() {
        -1
      } else {
        source.code_unit_at(index + old_name.length()).to_int()
      }
      let prev_ok = prev_code < 0 || !wesl_is_identifier_char(prev_code)
      let next_ok = next_code < 0 || !wesl_is_identifier_char(next_code)
      if prev_ok && next_ok {
        out = out + new_name
        index = index + old_name.length()
        continue
      }
    }
    out = out + source[index:index + 1].to_owned()
    index = index + 1
  }
  out
}

///|
fn wesl_replace_reference_identifier(
  source : String,
  old_name : String,
  new_name : String,
  item_name : String?,
) -> String {
  if old_name == new_name || old_name == "" {
    return source
  }
  let tokens = parser_lex(source)
  let scopes : Array[Array[String]] = [[]]
  let mut scope_depth = 0
  let mut consumed_item_decl = item_name is None
  let mut out = ""
  let mut previous_end = 0
  for i in 0..<tokens.length() {
    let token = tokens[i]
    let start = token.start()
    let end_ = token.end()
    if previous_end < start {
      out = out + source[previous_end:start].to_owned()
    }
    match token {
      LBrace(_, _, _) => {
        scope_depth += 1
        if scope_depth < scopes.length() {
          scopes[scope_depth] = []
        } else {
          scopes.push([])
        }
        out = out + source[start:end_].to_owned()
      }
      RBrace(_, _, _) => {
        if scope_depth > 0 {
          scope_depth -= 1
        }
        out = out + source[start:end_].to_owned()
      }
      Ident(name, _, _, _) => {
        let original = source[start:end_].to_owned()
        if wesl_is_bound_identifier(source, tokens, i) {
          let is_item_decl = match item_name {
            Some(current_item_name) =>
              !consumed_item_decl && name == current_item_name
            None => false
          }
          if is_item_decl {
            consumed_item_decl = true
          } else {
            wesl_bind_scope(scopes, scope_depth, name)
          }
          out = out + original
        } else if name == old_name &&
          !wesl_scopes_contain(scopes, scope_depth, name) {
          out = out + new_name
        } else {
          out = out + original
        }
      }
      _ => out = out + source[start:end_].to_owned()
    }
    previous_end = end_
  }
  if previous_end < source.length() {
    out = out + source[previous_end:source.length()].to_owned()
  }
  out
}

///|
fn wesl_replace_global_identifier(
  source : String,
  old_name : String,
  new_name : String,
  item_name : String?,
) -> String {
  if old_name == new_name || old_name == "" {
    return source
  }
  let tokens = parser_lex(source)
  let scopes : Array[Array[String]] = [[]]
  let mut scope_depth = 0
  let mut consumed_item_decl = item_name is None
  let mut out = ""
  let mut previous_end = 0
  for i in 0..<tokens.length() {
    let token = tokens[i]
    let start = token.start()
    let end_ = token.end()
    if previous_end < start {
      out = out + source[previous_end:start].to_owned()
    }
    match token {
      LBrace(_, _, _) => {
        scope_depth += 1
        if scope_depth < scopes.length() {
          scopes[scope_depth] = []
        } else {
          scopes.push([])
        }
        out = out + source[start:end_].to_owned()
      }
      RBrace(_, _, _) => {
        if scope_depth > 0 {
          scope_depth -= 1
        }
        out = out + source[start:end_].to_owned()
      }
      Ident(name, _, _, _) => {
        let original = source[start:end_].to_owned()
        if wesl_is_bound_identifier(source, tokens, i) {
          let is_item_decl = match item_name {
            Some(current_item_name) =>
              !consumed_item_decl && name == current_item_name
            None => false
          }
          if is_item_decl {
            consumed_item_decl = true
            if name == old_name {
              out = out + new_name
            } else {
              out = out + original
            }
          } else {
            wesl_bind_scope(scopes, scope_depth, name)
            out = out + original
          }
        } else if name == old_name &&
          !wesl_scopes_contain(scopes, scope_depth, name) {
          out = out + new_name
        } else {
          out = out + original
        }
      }
      _ => out = out + source[start:end_].to_owned()
    }
    previous_end = end_
  }
  if previous_end < source.length() {
    out = out + source[previous_end:source.length()].to_owned()
  }
  out
}

///|
fn wesl_decl_key(path : ModulePath, name : String) -> String {
  "\{path.to_string()}::\{name}"
}

///|
fn wesl_is_used_decl(
  used_decls : @hashmap.HashMap[String, Bool],
  path : ModulePath,
  name : String,
) -> Bool {
  used_decls.contains(wesl_decl_key(path, name))
}

///|
fn wesl_item_kind(header : GlobalDeclarationHeader) -> ModuleItemKind {
  match header {
    Alias(_) => Alias
    Const(_) => Const
    Var(_) => Var
    _ => Other
  }
}

///|
fn wesl_item_has_cycle_semantics(item : ModuleItem) -> Bool {
  match item.kind {
    Alias => true
    Const => true
    Var => true
    Other => false
  }
}

///|
fn wesl_module_export_target(
  parsed_module : ParsedModule,
  name : String,
) -> ExportTarget {
  match parsed_module.named_items.get(name) {
    Some(index) => Local(index)
    None =>
      match parsed_module.import_by_local.get(name) {
        Some(index) =>
          if parsed_module.imports[index].public &&
            wesl_import_named_target(parsed_module.imports[index]) is Some(_) {
            ReExport(parsed_module.imports[index])
          } else {
            Private
          }
        None => Missing
      }
  }
}

///|
fn wesl_resolve_export_target(
  path : ModulePath,
  name : String,
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
) -> (ModulePath, String) raise WeslCompileError {
  guard modules.get(path) is Some(parsed_module) else {
    raise MissingDecl(path, name)
  }
  match wesl_module_export_target(parsed_module, name) {
    Local(_) => (path, name)
    ReExport(import_item) =>
      match wesl_import_named_target(import_item) {
        Some((import_path, import_name)) =>
          wesl_resolve_export_target(import_path, import_name, modules)
        None => raise MissingDecl(path, name)
      }
    Private => raise Private(name, path)
    Missing => raise MissingDecl(path, name)
  }
}

///|
fn[R : Resolver] wesl_preload_import_item(
  import_item : ImportItem,
  resolver : R,
  options : CompileOptions,
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
  order : Array[ModulePath],
  sourcemap : BasicSourceMap,
  record_sourcemap : Bool,
  root : ModulePath,
  mangler : ManglerKind,
) -> Unit raise WeslCompileError {
  let mut missing_named_target : (ModulePath, String)? = None
  match wesl_import_named_target(import_item) {
    Some((import_path, import_name)) =>
      try
        wesl_load_module(
          import_path, resolver, options, modules, order, sourcemap, record_sourcemap,
          root, mangler,
        )
      catch {
        _ => ()
      } noraise {
        loaded =>
          match wesl_module_export_target(loaded, import_name) {
            Local(_) => return
            ReExport(_) => return
            Private => raise Private(import_name, loaded.path)
            Missing => missing_named_target = Some((loaded.path, import_name))
          }
      }
    None => ()
  }
  ignore(
    wesl_load_module(
      import_item.namespace_path,
      resolver,
      options,
      modules,
      order,
      sourcemap,
      record_sourcemap,
      root,
      mangler,
    ),
  ) catch {
    err =>
      match missing_named_target {
        Some((missing_path, missing_name)) =>
          raise MissingDecl(missing_path, missing_name)
        None => raise err
      }
  }
}

///|
fn[R : Resolver] wesl_record_sourcemap_source(
  path : ModulePath,
  resolver : R,
  sourcemap : BasicSourceMap,
  record_sourcemap : Bool,
) -> Unit {
  if !record_sourcemap || sourcemap.get_source(path) is Some(_) {
    return
  }
  let source_result = try R::resolve_source(resolver, path) catch {
    err => Err(err)
  } noraise {
    source => Ok(source)
  }
  match source_result {
    Ok(source) =>
      sourcemap.add_source(path, R::display_name(resolver, path), source)
    Err(_) => ()
  }
}

///|
fn wesl_record_sourcemap_decls(
  path : ModulePath,
  root : ModulePath,
  items : Array[ModuleItem],
  options : CompileOptions,
  mangler : ManglerKind,
  sourcemap : BasicSourceMap,
  record_sourcemap : Bool,
) -> Unit {
  if !record_sourcemap {
    return
  }
  for item in items {
    match item.name {
      Some(name) =>
        if path != root || options.mangle_root {
          sourcemap.add_decl(
            ManglerKind::mangle(mangler, path, name),
            path,
            name,
          )
        }
      None => ()
    }
  }
}

///|
fn[R : Resolver] wesl_load_module(
  path : ModulePath,
  resolver : R,
  options : CompileOptions,
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
  order : Array[ModulePath],
  sourcemap : BasicSourceMap,
  record_sourcemap : Bool,
  root : ModulePath,
  mangler : ManglerKind,
) -> ParsedModule raise WeslCompileError {
  match modules.get(path) {
    Some(existing) => existing
    None => {
      wesl_record_sourcemap_source(path, resolver, sourcemap, record_sourcemap)
      let translation_unit = if options.condcomp && options.imports {
        let unit = R::resolve_module(resolver, path) catch {
          Error(message) => raise Parse(message)
          err => raise Resolve(err)
        }
        ModulePreprocessor::preprocess_module(
          CondCompPreprocessor::new(options.features),
          path,
          unit,
        ) catch {
          Error(message) => raise InvalidExpression(message)
          err => raise Resolve(err)
        }
      } else if options.condcomp {
        let raw_source = R::resolve_source(resolver, path) catch {
          err => raise Resolve(err)
        }
        let unit = parse_translation_unit(path, raw_source, options.imports)
        ModulePreprocessor::preprocess_module(
          CondCompPreprocessor::new(options.features),
          path,
          unit,
        ) catch {
          Error(message) => raise InvalidExpression(message)
          err => raise Resolve(err)
        }
      } else if !options.imports {
        let raw_source = R::resolve_source(resolver, path) catch {
          err => raise Resolve(err)
        }
        parse_translation_unit(path, raw_source, options.imports)
      } else {
        R::resolve_module(resolver, path) catch {
          Error(message) => raise Parse(message)
          err => raise Resolve(err)
        }
      }
      let parsed_module = wesl_parse_loaded_translation_unit(
        path, translation_unit, false,
      )
      wesl_record_sourcemap_decls(
        path,
        root,
        parsed_module.items,
        options,
        mangler,
        sourcemap,
        record_sourcemap,
      )
      modules.set(path, parsed_module)
      order.push(path)
      if options.imports && (!options.strip || !options.lazy_resolution) {
        for import_item in parsed_module.imports {
          ignore(
            wesl_preload_import_item(
              import_item, resolver, options, modules, order, sourcemap, record_sourcemap,
              root, mangler,
            ),
          )
        }
      }
      parsed_module
    }
  }
}

///|
fn[R : Resolver] wesl_mark_module_used(
  path : ModulePath,
  resolver : R,
  options : CompileOptions,
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
  order : Array[ModulePath],
  used_modules : @hashmap.HashMap[ModulePath, Bool],
  used_decls : @hashmap.HashMap[String, Bool],
  sourcemap : BasicSourceMap,
  record_sourcemap : Bool,
  root : ModulePath,
  mangler : ManglerKind,
) -> ParsedModule raise WeslCompileError {
  let parsed_module = wesl_load_module(
    path, resolver, options, modules, order, sourcemap, record_sourcemap, root, mangler,
  )
  if used_modules.contains(path) {
    return parsed_module
  }
  used_modules.set(path, true)
  for item in parsed_module.items {
    if !item.is_const_assert {
      continue
    }
    ignore(
      wesl_mark_item_refs(
        path, parsed_module, item, resolver, options, modules, order, used_modules,
        used_decls, sourcemap, record_sourcemap, root, mangler,
      ),
    )
  }
  parsed_module
}

///|
fn[R : Resolver] wesl_mark_named_decl(
  path : ModulePath,
  name : String,
  resolver : R,
  options : CompileOptions,
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
  order : Array[ModulePath],
  used_modules : @hashmap.HashMap[ModulePath, Bool],
  used_decls : @hashmap.HashMap[String, Bool],
  sourcemap : BasicSourceMap,
  record_sourcemap : Bool,
  root : ModulePath,
  mangler : ManglerKind,
) -> Unit raise WeslCompileError {
  let parsed_module = wesl_mark_module_used(
    path, resolver, options, modules, order, used_modules, used_decls, sourcemap,
    record_sourcemap, root, mangler,
  )
  let key = wesl_decl_key(path, name)
  if used_decls.contains(key) {
    return
  }
  match wesl_module_export_target(parsed_module, name) {
    Local(index) => {
      used_decls.set(key, true)
      let item = parsed_module.items[index]
      ignore(
        wesl_mark_item_refs(
          path, parsed_module, item, resolver, options, modules, order, used_modules,
          used_decls, sourcemap, record_sourcemap, root, mangler,
        ),
      )
    }
    ReExport(import_item) => {
      used_decls.set(key, true)
      match wesl_import_named_target(import_item) {
        Some((import_path, import_name)) =>
          ignore(
            wesl_mark_named_decl(
              import_path, import_name, resolver, options, modules, order, used_modules,
              used_decls, sourcemap, record_sourcemap, root, mangler,
            ),
          )
        None => ()
      }
    }
    Private => raise Private(name, path)
    Missing => raise MissingDecl(path, name)
  }
}

///|
fn wesl_root_keep_names(
  root : ParsedModule,
  options : CompileOptions,
) -> Array[String] {
  let keep_names : Array[String] = []
  if !options.strip || options.keep_root {
    for entry in root.named_items.iter() {
      let (name, _) = entry
      keep_names.push(name)
    }
    return keep_names
  }
  match options.keep {
    Some(keep) => {
      for name in keep {
        if root.named_items.contains(name) {
          keep_names.push(name)
        }
      }
      keep_names
    }
    None => {
      for item in root.items {
        if item.entrypoint && item.name is Some(name) {
          keep_names.push(name)
        }
      }
      keep_names
    }
  }
}

///|
fn[R : Resolver] wesl_mark_item_refs(
  path : ModulePath,
  parsed_module : ParsedModule,
  item : ModuleItem,
  resolver : R,
  options : CompileOptions,
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
  order : Array[ModulePath],
  used_modules : @hashmap.HashMap[ModulePath, Bool],
  used_decls : @hashmap.HashMap[String, Bool],
  sourcemap : BasicSourceMap,
  record_sourcemap : Bool,
  root : ModulePath,
  mangler : ManglerKind,
) -> Unit raise WeslCompileError {
  for reference in item.references {
    match reference {
      Local(name) =>
        ignore(
          wesl_mark_named_decl(
            path, name, resolver, options, modules, order, used_modules, used_decls,
            sourcemap, record_sourcemap, root, mangler,
          ),
        )
      Import(_, import_index) => {
        let import_item = parsed_module.imports[import_index]
        match wesl_import_named_target(import_item) {
          Some((import_path, import_name)) =>
            ignore(
              wesl_mark_named_decl(
                import_path, import_name, resolver, options, modules, order, used_modules,
                used_decls, sourcemap, record_sourcemap, root, mangler,
              ),
            )
          None => ()
        }
      }
      Qualified(_, target_path, target_name) =>
        ignore(
          wesl_mark_named_decl(
            target_path, target_name, resolver, options, modules, order, used_modules,
            used_decls, sourcemap, record_sourcemap, root, mangler,
          ),
        )
    }
  }
}

///|
fn wesl_apply_replacements(
  source : String,
  replacements : Array[(String, String)],
) -> String {
  let mut out = source
  for replacement in replacements {
    out = wesl_replace_identifier(out, replacement.0, replacement.1)
  }
  out
}

///|
fn wesl_close_replacements(
  replacements : Array[(String, String)],
) -> Array[(String, String)] {
  let mut current = replacements
  for _ in 0..<replacements.length() {
    let next : Array[(String, String)] = []
    let mut changed = false
    for replacement in current {
      let candidates : Array[(String, String)] = []
      for candidate in current {
        if candidate.0 != replacement.0 {
          candidates.push(candidate)
        }
      }
      let expanded = wesl_apply_replacements(replacement.1, candidates)
      if expanded != replacement.1 {
        changed = true
      }
      next.push((replacement.0, expanded))
    }
    current = next
    if !changed {
      break
    }
  }
  current
}

///|
fn wesl_item_references_local(item : ModuleItem, name : String) -> Bool {
  for reference in item.references {
    match reference {
      Local(reference_name) if reference_name == name => return true
      _ => ()
    }
  }
  false
}

///|
fn wesl_apply_referenced_replacements(
  item : ModuleItem,
  replacements : Array[(String, String)],
) -> String {
  let filtered : Array[(String, String)] = []
  for replacement in replacements {
    if wesl_item_references_local(item, replacement.0) {
      filtered.push(replacement)
    }
  }
  wesl_apply_replacements(item.source, filtered)
}

///|
fn wesl_lower_source(source : String) -> String raise WeslCompileError {
  let path = ModulePath::from_path("/__wesl_lower")
  let parsed_module = wesl_parse_loaded_translation_unit(
    path,
    parse_translation_unit(path, source, true),
    false,
  )
  let alias_replacements : Array[(String, String)] = []
  let const_replacements : Array[(String, String)] = []
  let kept_items : Array[ModuleItem] = []
  for parsed in parsed_module.items {
    match parsed.header {
      Alias(alias_decl) =>
        match alias_decl.target {
          Some(target) => {
            alias_replacements.push(
              (
                alias_decl.name,
                wesl_apply_replacements(
                  wesl_apply_replacements(target, alias_replacements),
                  const_replacements,
                ),
              ),
            )
            continue
          }
          None => kept_items.push(parsed)
        }
      Const(const_decl) =>
        match const_decl.initializer {
          Some(initializer) => {
            const_replacements.push(
              (
                const_decl.name,
                "(\{wesl_apply_replacements(wesl_apply_replacements(initializer, alias_replacements), const_replacements)})",
              ),
            )
            continue
          }
          None => kept_items.push(parsed)
        }
      _ => kept_items.push(parsed)
    }
  }
  let replacements : Array[(String, String)] = []
  for replacement in alias_replacements {
    replacements.push(replacement)
  }
  for replacement in const_replacements {
    replacements.push(replacement)
  }
  let closed_replacements = wesl_close_replacements(replacements)
  let lowered : Array[String] = []
  for item in kept_items {
    let lowered_item = wesl_apply_referenced_replacements(
        item, closed_replacements,
      )
      .trim()
      .to_owned()
    if lowered_item != "" {
      lowered.push(lowered_item)
    }
  }
  lowered.join("\n\n")
}

///|
fn wesl_cycle_reference_target(
  current_path : ModulePath,
  parsed_module : ParsedModule,
  reference : ModuleItemRef,
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
) -> (ModulePath, String)? {
  match reference {
    Local(name) => Some((current_path, name))
    Import(_, import_index) =>
      match wesl_import_named_target(parsed_module.imports[import_index]) {
        Some((import_path, import_name)) => {
          let target = wesl_resolve_export_target(
            import_path, import_name, modules,
          ) catch {
            _ => return None
          }
          Some(target)
        }
        None => None
      }
    Qualified(_, target_path, target_name) => {
      let target = wesl_resolve_export_target(target_path, target_name, modules) catch {
        _ => return None
      }
      Some(target)
    }
  }
}

///|
fn wesl_validate_decl_cycle(
  path : ModulePath,
  name : String,
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
  states : @hashmap.HashMap[String, Int],
) -> Unit raise WeslCompileError {
  let key = wesl_decl_key(path, name)
  match states.get(key) {
    Some(state) =>
      if state == 1 {
        guard modules.get(path) is Some(parsed_module) else { return }
        guard parsed_module.named_items.get(name) is Some(index) else { return }
        let item = parsed_module.items[index]
        raise CircularDecl(item.span.symbol_context(path, name))
      } else {
        return
      }
    None => ()
  }
  guard modules.get(path) is Some(parsed_module) else { return }
  guard parsed_module.named_items.get(name) is Some(index) else { return }
  let item = parsed_module.items[index]
  if !wesl_item_has_cycle_semantics(item) {
    states.set(key, 2)
    return
  }
  states.set(key, 1)
  for reference in item.references {
    match wesl_cycle_reference_target(path, parsed_module, reference, modules) {
      Some((target_path, target_name)) =>
        ignore(
          wesl_validate_decl_cycle(target_path, target_name, modules, states),
        )
      None => ()
    }
  }
  states.set(key, 2)
}

///|
fn wesl_validate_loaded_cycles(
  order : Array[ModulePath],
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
) -> Unit raise WeslCompileError {
  let states : @hashmap.HashMap[String, Int] = HashMap([])
  for path in order {
    guard modules.get(path) is Some(parsed_module) else { continue }
    for item in parsed_module.items {
      guard item.name is Some(name) else { continue }
      if !wesl_item_has_cycle_semantics(item) {
        continue
      }
      ignore(wesl_validate_decl_cycle(path, name, modules, states))
    }
  }
}

///|
pub fn validate_wesl(unit : TranslationUnit) -> Unit raise WeslCompileError {
  let path = ModulePath::from_path("/__validate__")
  let parsed_module = wesl_parse_loaded_translation_unit(path, unit, true)
  let modules : @hashmap.HashMap[ModulePath, ParsedModule] = HashMap([])
  let order : Array[ModulePath] = [path]
  modules.set(path, parsed_module)
  wesl_validate_loaded_cycles(order, modules) catch {
    CircularDecl(symbol) => raise Validate(Cycle(symbol, symbol))
    error => raise error
  }
}

///|
fn wesl_validate_wgsl_source(source : String) -> Unit raise WeslCompileError {
  let module_ = @ir.parse_wgsl_module_to_ir(source) catch {
    error => raise Validation(error.message())
  }
  @ir.validate_wgsl_ir_module(module_) catch {
    error => raise Validation(error.message())
  }
}

///|
fn wesl_emit_item_source(
  parsed_module : ParsedModule,
  item : ModuleItem,
  root : ModulePath,
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
  used_decls : @hashmap.HashMap[String, Bool],
  mangler : ManglerKind,
  options : CompileOptions,
) -> String {
  let mut current = item.source
  for reference in item.references {
    match reference {
      Import(import_ref, import_index) => {
        let import_item = parsed_module.imports[import_index]
        match wesl_import_named_target(import_item) {
          Some((import_path, import_name)) => {
            let (target_path, target_name) = wesl_resolve_export_target(
              import_path, import_name, modules,
            ) catch {
              _ => (import_path, import_name)
            }
            current = wesl_replace_reference_identifier(
              current,
              import_ref,
              ManglerKind::mangle(mangler, target_path, target_name),
              item.name,
            )
          }
          None => ()
        }
      }
      Qualified(qualified_ref, target_path, target_name) =>
        current = wesl_replace_identifier(
          current,
          qualified_ref,
          ManglerKind::mangle(mangler, target_path, target_name),
        )
      Local(_) => ()
    }
  }
  if parsed_module.path != root || options.mangle_root {
    for entry in parsed_module.named_items.iter() {
      let (name, _) = entry
      if !options.strip ||
        wesl_is_used_decl(used_decls, parsed_module.path, name) {
        current = wesl_replace_global_identifier(
          current,
          name,
          ManglerKind::mangle(mangler, parsed_module.path, name),
          item.name,
        )
      }
    }
  }
  current.trim().to_owned()
}

///|
fn wesl_emit_module(
  path : ModulePath,
  root : ModulePath,
  modules : @hashmap.HashMap[ModulePath, ParsedModule],
  used_modules : @hashmap.HashMap[ModulePath, Bool],
  used_decls : @hashmap.HashMap[String, Bool],
  emitted : @hashmap.HashMap[ModulePath, Bool],
  parts : Array[String],
  mangler : ManglerKind,
  options : CompileOptions,
) -> Unit {
  if emitted.contains(path) || !used_modules.contains(path) {
    return
  }
  emitted.set(path, true)
  guard modules.get(path) is Some(parsed_module) else { return }
  if !options.strip || !options.lazy_resolution {
    for import_item in parsed_module.imports {
      match wesl_import_named_target(import_item) {
        Some((import_path, import_name)) =>
          try
            wesl_resolve_export_target(import_path, import_name, modules)
          catch {
            _ => ()
          } noraise {
            (target_path, _) =>
              wesl_emit_module(
                target_path, root, modules, used_modules, used_decls, emitted, parts,
                mangler, options,
              )
          }
        None => ()
      }
      wesl_emit_module(
        import_item.namespace_path,
        root,
        modules,
        used_modules,
        used_decls,
        emitted,
        parts,
        mangler,
        options,
      )
    }
  } else {
    for import_item in parsed_module.imports {
      if import_item.public &&
        wesl_is_used_decl(
          used_decls,
          parsed_module.path,
          import_item.local_name,
        ) {
        match wesl_import_named_target(import_item) {
          Some((import_path, import_name)) =>
            try
              wesl_resolve_export_target(import_path, import_name, modules)
            catch {
              _ => ()
            } noraise {
              (target_path, _) =>
                wesl_emit_module(
                  target_path, root, modules, used_modules, used_decls, emitted,
                  parts, mangler, options,
                )
            }
          None => ()
        }
      }
    }
    for item in parsed_module.items {
      let should_emit = match item.name {
        Some(name) => wesl_is_used_decl(used_decls, parsed_module.path, name)
        None => true
      }
      if !should_emit {
        continue
      }
      for reference in item.references {
        match reference {
          Import(_, import_index) =>
            match
              wesl_import_named_target(parsed_module.imports[import_index]) {
              Some((import_path, import_name)) =>
                try
                  wesl_resolve_export_target(import_path, import_name, modules)
                catch {
                  _ => ()
                } noraise {
                  (target_path, _) =>
                    wesl_emit_module(
                      target_path, root, modules, used_modules, used_decls, emitted,
                      parts, mangler, options,
                    )
                }
              None => ()
            }
          Qualified(_, target_path, _) =>
            wesl_emit_module(
              target_path, root, modules, used_modules, used_decls, emitted, parts,
              mangler, options,
            )
          Local(_) => ()
        }
      }
    }
  }
  for item in parsed_module.items {
    let should_emit = match item.name {
      Some(name) =>
        if options.strip {
          wesl_is_used_decl(used_decls, parsed_module.path, name)
        } else {
          true
        }
      None => true
    }
    if !should_emit {
      continue
    }
    let emitted_item = wesl_emit_item_source(
      parsed_module, item, root, modules, used_decls, mangler, options,
    )
    if emitted_item != "" {
      parts.push(emitted_item)
    }
  }
}

///|
fn[R : Resolver] compile_with_mangler_kind(
  root : ModulePath,
  resolver : R,
  mangler : ManglerKind,
  options : CompileOptions,
  use_sourcemap : Bool,
) -> CompileResult raise WeslCompileError {
  let sourcemap = BasicSourceMap::{ ..BasicSourceMap::default(), root, }
  compile_with_mangler_kind_and_sourcemap(
    root, resolver, mangler, options, use_sourcemap, sourcemap,
  )
}

///|
fn[R : Resolver] compile_with_mangler_kind_and_sourcemap(
  root : ModulePath,
  resolver : R,
  mangler : ManglerKind,
  options : CompileOptions,
  use_sourcemap : Bool,
  sourcemap : BasicSourceMap,
) -> CompileResult raise WeslCompileError {
  let _ = options.lower
  let _ = options.generics
  let modules : @hashmap.HashMap[ModulePath, ParsedModule] = HashMap([])
  let order : Array[ModulePath] = []
  let used_modules : @hashmap.HashMap[ModulePath, Bool] = HashMap([])
  let used_decls : @hashmap.HashMap[String, Bool] = HashMap([])
  let root_module = wesl_mark_module_used(
    root, resolver, options, modules, order, used_modules, used_decls, sourcemap,
    use_sourcemap, root, mangler,
  )
  if options.validate {
    wesl_validate_loaded_cycles(order, modules)
  }
  for keep_name in wesl_root_keep_names(root_module, options) {
    ignore(
      wesl_mark_named_decl(
        root, keep_name, resolver, options, modules, order, used_modules, used_decls,
        sourcemap, use_sourcemap, root, mangler,
      ),
    )
  }
  if !options.strip {
    for module_path in order {
      used_modules.set(module_path, true)
    }
  }
  let emitted : @hashmap.HashMap[ModulePath, Bool] = HashMap([])
  let parts : Array[String] = []
  wesl_emit_module(
    root, root, modules, used_modules, used_decls, emitted, parts, mangler, options,
  )
  let assembled = parts.filter(fn(part) { part != "" }).join("\n\n")
  let source = if options.lower {
    wesl_lower_source(assembled)
  } else {
    assembled
  }
  if options.validate {
    wesl_validate_wgsl_source(source)
  }
  let syntax = parse_translation_unit(root, source, false)
  let output_sourcemap = if use_sourcemap {
    match sourcemap.get_source(root) {
      Some(root_source) => sourcemap.set_default_source(root_source)
      None => ()
    }
    Some(sourcemap)
  } else {
    None
  }
  { syntax, sourcemap: output_sourcemap, modules: order }
}

///|
pub fn[R : Resolver] compile(
  root : ModulePath,
  resolver : R,
  _mangler : EscapeMangler,
  options : CompileOptions,
) -> CompileResult raise WeslCompileError {
  compile_with_mangler_kind(root, resolver, Escape, options, false)
}

///|
pub fn[R : Resolver] compile_sourcemap(
  root : ModulePath,
  resolver : R,
  _mangler : EscapeMangler,
  options : CompileOptions,
) -> CompileResult raise WeslCompileError {
  compile_with_mangler_kind(root, resolver, Escape, options, true)
}

///|
fn[R : Resolver] wesl_diagnostic_from_compile_error(
  root : ModulePath,
  resolver : R,
  mangler : ManglerKind,
  error : WeslCompileError,
  use_sourcemap : Bool,
  sourcemap : BasicSourceMap,
) -> Diagnostic {
  let mut diagnostic = error
    .diagnostic()
    .with_module_path(root, R::display_name(resolver, root))
    .unmangle_with_mangler(mangler)
  if use_sourcemap {
    match sourcemap.get_source(root) {
      Some(root_source) => sourcemap.set_default_source(root_source)
      None => {
        let source_result = try R::resolve_source(resolver, root) catch {
          err => Err(err)
        } noraise {
          source => Ok(source)
        }
        match source_result {
          Ok(source) => {
            sourcemap.add_source(root, R::display_name(resolver, root), source)
            sourcemap.set_default_source(source)
          }
          Err(_) => ()
        }
      }
    }
    diagnostic = diagnostic.with_sourcemap(sourcemap).infer_span_from_message()
  }
  diagnostic
}

///|
fn[R : Resolver] compile_diagnostic_with_mangler_kind(
  root : ModulePath,
  resolver : R,
  mangler : ManglerKind,
  options : CompileOptions,
  use_sourcemap : Bool,
) -> CompileResult raise WeslDiagnosticError {
  let sourcemap = BasicSourceMap::{ ..BasicSourceMap::default(), root, }
  compile_with_mangler_kind_and_sourcemap(
    root, resolver, mangler, options, use_sourcemap, sourcemap,
  ) catch {
    err =>
      raise Diagnostic(
        wesl_diagnostic_from_compile_error(
          root, resolver, mangler, err, use_sourcemap, sourcemap,
        ),
      )
  }
}

///|
pub fn[R : Resolver] compile_diagnostic(
  root : ModulePath,
  resolver : R,
  _mangler : EscapeMangler,
  options : CompileOptions,
) -> CompileResult raise WeslDiagnosticError {
  compile_diagnostic_with_mangler_kind(root, resolver, Escape, options, false)
}

///|
pub fn[R : Resolver] compile_sourcemap_diagnostic(
  root : ModulePath,
  resolver : R,
  _mangler : EscapeMangler,
  options : CompileOptions,
) -> CompileResult raise WeslDiagnosticError {
  compile_diagnostic_with_mangler_kind(root, resolver, Escape, options, true)
}
