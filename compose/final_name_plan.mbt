///|
priv struct WgslModuleFinalNameApplication {
  origin_index : Int
  identity : WgslIrSymbolIdentity
  reference_path : WgslReferencePath
  final_name : String
}

///|
priv struct WgslModuleFinalNameApplicationPlan {
  entries : Array[WgslModuleFinalNameApplication]
}

///|
fn WgslModuleFinalNameApplicationPlan::WgslModuleFinalNameApplicationPlan() -> WgslModuleFinalNameApplicationPlan {
  WgslModuleFinalNameApplicationPlan::{ entries: [] }
}

///|
fn WgslModuleFinalNameApplicationPlan::is_empty(
  self : WgslModuleFinalNameApplicationPlan,
) -> Bool {
  self.entries.length() == 0
}

///|
fn WgslModuleFinalNameApplicationPlan::push(
  self : WgslModuleFinalNameApplicationPlan,
  origin_index : Int,
  origin : WgslSourceOriginEntry,
  final_name : String,
) -> Unit {
  if final_name == "" || final_name == origin.generated_symbol_name {
    return
  }
  let identity = WgslIrSymbolIdentity(
    origin.rel_path,
    origin.source_symbol_name,
  )
  match WgslReferencePath::from_text(origin.generated_symbol_name) {
    Some(reference_path) =>
      self.entries.push(WgslModuleFinalNameApplication::{
        origin_index,
        identity,
        reference_path,
        final_name,
      })
    None => ()
  }
}

///|
fn WgslModuleFinalNameApplicationPlan::reference_rewrite_plan(
  self : WgslModuleFinalNameApplicationPlan,
) -> WgslReferenceRewritePlan {
  let plan = WgslReferenceRewritePlan()
  for entry in self.entries {
    plan.add_symbol_reference_binding(
      entry.identity,
      entry.reference_path,
      entry.final_name,
    )
  }
  plan
}

///|
fn WgslModuleFinalNameApplicationPlan::apply_to_origins(
  self : WgslModuleFinalNameApplicationPlan,
  origins : Array[WgslSourceOriginEntry],
) -> Unit {
  for entry in self.entries {
    let origin = origins[entry.origin_index]
    origins[entry.origin_index] = WgslSourceOriginEntry(
      entry.final_name,
      origin.rel_path,
      origin.source_symbol_name,
      origin.kind,
      origin.source_start,
      origin.source_end,
    )
  }
}

///|
fn WgslComposeSession::assigned_final_name_for_origin(
  self : WgslComposeSession,
  origin : WgslSourceOriginEntry,
  alias_prefixes : Array[String],
) -> String? {
  if origin.rel_path == "" ||
    origin.source_symbol_name == "" ||
    origin.generated_symbol_name == "" {
    return None
  }
  let identity = WgslIrSymbolIdentity(
    origin.rel_path,
    origin.source_symbol_name,
  )
  if alias_prefixes.length() == 0 {
    self.assigned_canonical_final_name(identity)
  } else {
    self.symbols.assigned_final_names.alias_get(
      WgslIrAliasSymbolIdentity(
        origin.rel_path,
        alias_prefixes.join("__"),
        origin.source_symbol_name,
      ),
    )
  }
}

///|
fn collect_wgsl_module_final_name_application_plan(
  session : WgslComposeSession,
  start_index : Int,
  alias_prefixes : Array[String],
) -> WgslModuleFinalNameApplicationPlan {
  let plan = WgslModuleFinalNameApplicationPlan()
  for i in start_index..<session.symbols.source_origins.length() {
    let origin = session.symbols.source_origins[i]
    match session.assigned_final_name_for_origin(origin, alias_prefixes) {
      Some(final_name) => plan.push(i, origin, final_name)
      None => ()
    }
  }
  plan
}
