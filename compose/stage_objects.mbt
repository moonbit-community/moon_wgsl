///|
priv struct WgslImportGraphBuilder {
  composer : Composer
  session : WgslComposeSession
}

///|
fn WgslImportGraphBuilder::WgslImportGraphBuilder(
  composer : Composer,
  session : WgslComposeSession,
) -> WgslImportGraphBuilder {
  WgslImportGraphBuilder::{ composer, session }
}

///|
priv struct WgslReachabilityPlan {
  facts : WgslComposeSemanticFacts
  bindings : WgslComposeBindingSet
}

///|
fn WgslReachabilityPlan::WgslReachabilityPlan(
  facts : WgslComposeSemanticFacts,
  bindings : WgslComposeBindingSet,
) -> WgslReachabilityPlan {
  WgslReachabilityPlan::{ facts, bindings }
}

///|
fn WgslReachabilityPlan::live_binding_plan(
  self : WgslReachabilityPlan,
) -> WgslLiveBindingPlan {
  WgslComposeSemanticIr::from_facts_and_bindings(self.facts, self.bindings).live_binding_plan()
}

///|
priv struct WgslFinalNameAllocator {
  session : WgslComposeSession
  alias_prefixes : Array[String]
}

///|
fn WgslFinalNameAllocator::WgslFinalNameAllocator(
  session : WgslComposeSession,
  alias_prefixes : Array[String],
) -> WgslFinalNameAllocator {
  WgslFinalNameAllocator::{ session, alias_prefixes }
}

///|
fn WgslFinalNameAllocator::application_plan(
  self : WgslFinalNameAllocator,
  start_index : Int,
) -> WgslModuleFinalNameApplicationPlan {
  collect_wgsl_module_final_name_application_plan(
    self.session,
    start_index,
    self.alias_prefixes,
  )
}

///|
priv struct WgslComposeEmitter {
  composer : Composer
  session : WgslComposeSession
}

///|
fn WgslComposeEmitter::WgslComposeEmitter(
  composer : Composer,
  session : WgslComposeSession,
) -> WgslComposeEmitter {
  WgslComposeEmitter::{ composer, session }
}
