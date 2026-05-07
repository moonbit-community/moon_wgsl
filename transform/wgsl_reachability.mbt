///|
priv struct WgslReachableDeclarations {
  included_names : Array[String]
  missing_root_items : Array[String]
}

///|
fn wgsl_analysis_string_list_push_unique(
  items : Array[String],
  item : String,
) -> Unit {
  if item == "" {
    return
  }
  for existing in items {
    if existing == item {
      return
    }
  }
  items.push(item)
}

///|
fn wgsl_analysis_declaration_name_map(
  declarations : Array[WgslGlobalDecl],
) -> (@hashmap.HashMap[String, Bool], @hashmap.HashMap[String, Int]) {
  let declaration_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap([])
  let declaration_indexes : @hashmap.HashMap[String, Int] = @hashmap.HashMap([])
  for i in 0..<declarations.length() {
    let decl = declarations[i]
    if decl.name() != "" {
      declaration_names.set(decl.name(), true)
      declaration_indexes.set(decl.name(), i)
    }
  }
  (declaration_names, declaration_indexes)
}

///|
fn wgsl_analysis_collect_identifier_dependencies(
  identifiers : Array[WgslIdent],
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  for identifier in identifiers {
    let dependency_name = identifier.name()
    if dependency_name != self_name &&
      declaration_names.contains(dependency_name) {
      wgsl_analysis_string_list_push_unique(dependencies, dependency_name)
    }
  }
}

///|
fn wgsl_analysis_collect_declaration_dependencies(
  declaration_data : WgslGlobalDeclData,
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  match declaration_data {
    WgslGlobalDeclData::Raw => ()
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) => ()
    _ => {
      let identifiers : Array[WgslIdent] = []
      collect_wgsl_decl_identifier_nodes(declaration_data, identifiers)
      wgsl_analysis_collect_identifier_dependencies(
        identifiers, self_name, declaration_names, dependencies,
      )
    }
  }
}

///|
fn collect_wgsl_reachable_declaration_names(
  declarations : Array[WgslGlobalDecl],
  root_items : Array[String],
) -> WgslReachableDeclarations {
  let included_names : Array[String] = []
  if root_items.length() == 0 {
    for decl in declarations {
      wgsl_analysis_string_list_push_unique(included_names, decl.name())
    }
    return WgslReachableDeclarations::{ included_names, missing_root_items: [] }
  }
  let (declaration_names, declaration_indexes) = wgsl_analysis_declaration_name_map(
    declarations,
  )
  let worklist : Array[String] = []
  let missing_root_items : Array[String] = []
  for root_item in root_items {
    if declaration_names.contains(root_item) {
      worklist.push(root_item)
    } else {
      wgsl_analysis_string_list_push_unique(missing_root_items, root_item)
    }
  }
  if worklist.length() == 0 {
    for decl in declarations {
      wgsl_analysis_string_list_push_unique(included_names, decl.name())
    }
    return WgslReachableDeclarations::{ included_names, missing_root_items }
  }
  while worklist.length() > 0 {
    let name = worklist.pop().unwrap()
    if included_names.contains(name) {
      continue
    }
    included_names.push(name)
    guard declaration_indexes.get(name) is Some(index) else { continue }
    let decl = declarations[index]
    let dependencies : Array[String] = []
    wgsl_analysis_collect_declaration_dependencies(
      decl.data(),
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
  WgslReachableDeclarations::{ included_names, missing_root_items }
}
