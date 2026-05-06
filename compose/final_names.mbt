///|
priv struct WgslCanonicalFinalNameEntry {
  identity : WgslSymbolIdentity
  final_name : String
}

///|
priv struct WgslAliasFinalNameEntry {
  identity : WgslAliasSymbolIdentity
  final_name : String
}

///|
priv struct WgslFinalNameTables {
  canonical : @hashmap.HashMap[String, String]
  alias_scoped : @hashmap.HashMap[String, String]
  canonical_entries : Array[WgslCanonicalFinalNameEntry]
  alias_entries : Array[WgslAliasFinalNameEntry]
}

///|
fn WgslFinalNameTables::new() -> WgslFinalNameTables {
  WgslFinalNameTables::{
    canonical: @hashmap.HashMap::new(),
    alias_scoped: @hashmap.HashMap::new(),
    canonical_entries: [],
    alias_entries: [],
  }
}

///|
fn WgslFinalNameTables::canonical_set(
  self : WgslFinalNameTables,
  identity : WgslSymbolIdentity,
  final_name : String,
) -> Unit {
  let key = identity.key()
  if self.canonical.contains(key) {
    return
  }
  self.canonical.set(key, final_name)
  self.canonical_entries.push(WgslCanonicalFinalNameEntry::{
    identity,
    final_name,
  })
}

///|
fn WgslFinalNameTables::canonical_get(
  self : WgslFinalNameTables,
  identity : WgslSymbolIdentity,
) -> String? {
  self.canonical.get(identity.key())
}

///|
fn WgslFinalNameTables::canonical_entries_for_rel_path(
  self : WgslFinalNameTables,
  rel_path : String,
) -> Array[WgslCanonicalFinalNameEntry] {
  let entries : Array[WgslCanonicalFinalNameEntry] = []
  for entry in self.canonical_entries {
    if entry.identity.rel_path == rel_path {
      entries.push(entry)
    }
  }
  entries
}

///|
fn WgslFinalNameTables::alias_set(
  self : WgslFinalNameTables,
  identity : WgslAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  let key = identity.key()
  if self.alias_scoped.contains(key) {
    return
  }
  self.alias_scoped.set(key, final_name)
  self.alias_entries.push(WgslAliasFinalNameEntry::{ identity, final_name })
}

///|
fn WgslFinalNameTables::alias_get(
  self : WgslFinalNameTables,
  identity : WgslAliasSymbolIdentity,
) -> String? {
  self.alias_scoped.get(identity.key())
}

///|
fn WgslFinalNameTables::alias_entries_for_scope(
  self : WgslFinalNameTables,
  rel_path : String,
  alias_name : String,
) -> Array[WgslAliasFinalNameEntry] {
  let entries : Array[WgslAliasFinalNameEntry] = []
  for entry in self.alias_entries {
    if entry.identity.alias_name == alias_name &&
      entry.identity.symbol.rel_path == rel_path {
      entries.push(entry)
    }
  }
  entries
}
