///|
priv struct WgslComposeIrSymbol {
  identity : WgslSymbolIdentity
  final_name : String
  declared : Bool
}

///|
priv struct WgslComposeIrReferenceBinding {
  binding : WgslComposeBinding
  resolved_to_name : String
}

///|
priv struct WgslComposeSemanticIr {
  declared_names : @hashmap.HashMap[String, Bool]
  symbol_keys : @hashset.HashSet[String]
  symbols : Array[WgslComposeIrSymbol]
  emitted_final_name_by_identity : @hashmap.HashMap[String, String]
  reference_bindings : Array[WgslComposeIrReferenceBinding]
}

///|
fn WgslComposeSemanticIr::new() -> WgslComposeSemanticIr {
  WgslComposeSemanticIr::{
    declared_names: @hashmap.HashMap::new(),
    symbol_keys: @hashset.HashSet::new(),
    symbols: [],
    emitted_final_name_by_identity: @hashmap.HashMap::new(),
    reference_bindings: [],
  }
}

///|
fn WgslComposeSemanticIr::record_declared_name(
  self : WgslComposeSemanticIr,
  name : String,
) -> Unit {
  let name = name.trim().to_owned()
  if name != "" {
    self.declared_names.set(name, true)
  }
}

///|
fn WgslComposeSemanticIr::record_symbol(
  self : WgslComposeSemanticIr,
  identity : WgslSymbolIdentity,
  final_name : String,
  declared : Bool,
) -> Unit {
  let final_name = final_name.trim().to_owned()
  if final_name == "" {
    return
  }
  let symbol_key = "\{identity.key()}|\{final_name}|\{declared}"
  if self.symbol_keys.contains(symbol_key) {
    return
  }
  self.symbol_keys.add(symbol_key)
  self.symbols.push(WgslComposeIrSymbol::{ identity, final_name, declared })
}

///|
fn WgslComposeSemanticIr::record_emitted_symbol_target(
  self : WgslComposeSemanticIr,
  binding : WgslComposeBinding,
) -> Unit {
  let final_name = binding.to_name.trim().to_owned()
  if final_name == "" || !self.declared_names.contains(final_name) {
    return
  }
  match binding.identity {
    Some(identity) => {
      self.record_symbol(identity, final_name, true)
      let identity_key = identity.key()
      if !self.emitted_final_name_by_identity.contains(identity_key) {
        self.emitted_final_name_by_identity.set(identity_key, final_name)
      }
    }
    None => ()
  }
}

///|
fn WgslComposeSemanticIr::resolved_binding_target(
  self : WgslComposeSemanticIr,
  binding : WgslComposeBinding,
) -> String {
  let requested_to_name = binding.to_name.trim().to_owned()
  if requested_to_name == "" || self.declared_names.contains(requested_to_name) {
    return requested_to_name
  }
  match binding.identity {
    Some(identity) =>
      match self.emitted_final_name_by_identity.get(identity.key()) {
        Some(emitted_name) => emitted_name
        None => requested_to_name
      }
    None => requested_to_name
  }
}

///|
fn WgslComposeSemanticIr::record_reference_binding(
  self : WgslComposeSemanticIr,
  binding : WgslComposeBinding,
) -> Unit {
  let resolved_to_name = self.resolved_binding_target(binding)
  match binding.identity {
    Some(identity) =>
      self.record_symbol(
        identity,
        resolved_to_name,
        self.declared_names.contains(resolved_to_name),
      )
    None => ()
  }
  self.reference_bindings.push(WgslComposeIrReferenceBinding::{
    binding,
    resolved_to_name,
  })
}

///|
fn WgslComposeSemanticIr::from_facts_and_bindings(
  facts : WgslComposeSemanticFacts,
  bindings : WgslComposeBindingSet,
) -> WgslComposeSemanticIr {
  let ir = WgslComposeSemanticIr::new()
  for declaration in facts.declarations {
    ir.record_declared_name(declaration.name())
  }
  for binding in bindings.bindings {
    ir.record_emitted_symbol_target(binding)
  }
  for binding in bindings.bindings {
    ir.record_reference_binding(binding)
  }
  ir
}

///|
fn WgslComposeSemanticIr::symbol_target_is_declared(
  self : WgslComposeSemanticIr,
  identity : WgslSymbolIdentity,
  final_name : String,
) -> Bool {
  let final_name = final_name.trim().to_owned()
  if final_name == "" {
    return false
  }
  let identity_key = identity.key()
  for symbol in self.symbols {
    if symbol.identity.key() == identity_key && symbol.final_name == final_name {
      return symbol.declared
    }
  }
  false
}

///|
fn WgslComposeSemanticIr::binding_target_is_declared(
  self : WgslComposeSemanticIr,
  binding : WgslComposeBinding,
  final_name : String,
) -> Bool {
  match binding.identity {
    Some(identity) => self.symbol_target_is_declared(identity, final_name)
    None => self.declared_names.contains(final_name)
  }
}

///|
fn WgslComposeSemanticIr::live_binding_plan(
  self : WgslComposeSemanticIr,
) -> WgslLiveBindingPlan {
  let plan = WgslLiveBindingPlan::new()
  let seen_binding_keys : @hashset.HashSet[String] = @hashset.HashSet::new()
  for ir_binding in self.reference_bindings {
    let resolved_binding = if ir_binding.resolved_to_name ==
      ir_binding.binding.to_name.trim().to_owned() {
      ir_binding.binding
    } else {
      ir_binding.binding.with_to_name(ir_binding.resolved_to_name)
    }
    let binding_key = wgsl_compose_binding_key(resolved_binding)
    if seen_binding_keys.contains(binding_key) {
      continue
    }
    seen_binding_keys.add(binding_key)
    if ir_binding.resolved_to_name != "" &&
      (
        self.binding_target_is_declared(
          resolved_binding,
          ir_binding.resolved_to_name,
        ) ||
        ir_binding.binding.scope == UnqualifiedItemBinding
      ) {
      plan.push(resolved_binding)
    }
  }
  plan
}
