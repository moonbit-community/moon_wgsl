///|
pub struct WgslIrSymbolIdentity {
  priv rel_path : String
  priv original_name : String
} derive(Eq, Debug)

///|
pub struct WgslIrAliasSymbolIdentity {
  priv alias_name : String
  priv symbol : WgslIrSymbolIdentity
} derive(Eq, Debug)

///|
pub struct WgslIrCanonicalFinalNameEntry {
  priv identity : WgslIrSymbolIdentity
  priv final_name : String
} derive(Eq, Debug)

///|
pub struct WgslIrAliasFinalNameEntry {
  priv identity : WgslIrAliasSymbolIdentity
  priv final_name : String
} derive(Eq, Debug)

///|
pub struct WgslIrFinalNameTable {
  priv canonical : @hashmap.HashMap[String, String]
  priv alias_scoped : @hashmap.HashMap[String, String]
  priv canonical_entries : Array[WgslIrCanonicalFinalNameEntry]
  priv alias_entries : Array[WgslIrAliasFinalNameEntry]
}

///|
pub fn WgslIrSymbolIdentity::new(
  rel_path : String,
  original_name : String,
) -> WgslIrSymbolIdentity {
  WgslIrSymbolIdentity::{ rel_path, original_name }
}

///|
pub fn WgslIrSymbolIdentity::key(self : WgslIrSymbolIdentity) -> String {
  "\{self.rel_path}|\{self.original_name}"
}

///|
pub fn WgslIrSymbolIdentity::rel_path(self : WgslIrSymbolIdentity) -> String {
  self.rel_path
}

///|
pub fn WgslIrSymbolIdentity::original_name(
  self : WgslIrSymbolIdentity,
) -> String {
  self.original_name
}

///|
pub fn WgslIrAliasSymbolIdentity::new(
  rel_path : String,
  alias_name : String,
  original_name : String,
) -> WgslIrAliasSymbolIdentity {
  WgslIrAliasSymbolIdentity::{
    alias_name,
    symbol: WgslIrSymbolIdentity::new(rel_path, original_name),
  }
}

///|
pub fn WgslIrAliasSymbolIdentity::key(
  self : WgslIrAliasSymbolIdentity,
) -> String {
  "\{self.alias_name}|\{self.symbol.key()}"
}

///|
pub fn WgslIrAliasSymbolIdentity::alias_name(
  self : WgslIrAliasSymbolIdentity,
) -> String {
  self.alias_name
}

///|
pub fn WgslIrAliasSymbolIdentity::symbol(
  self : WgslIrAliasSymbolIdentity,
) -> WgslIrSymbolIdentity {
  self.symbol
}

///|
pub fn WgslIrCanonicalFinalNameEntry::identity(
  self : WgslIrCanonicalFinalNameEntry,
) -> WgslIrSymbolIdentity {
  self.identity
}

///|
pub fn WgslIrCanonicalFinalNameEntry::final_name(
  self : WgslIrCanonicalFinalNameEntry,
) -> String {
  self.final_name
}

///|
pub fn WgslIrAliasFinalNameEntry::identity(
  self : WgslIrAliasFinalNameEntry,
) -> WgslIrAliasSymbolIdentity {
  self.identity
}

///|
pub fn WgslIrAliasFinalNameEntry::final_name(
  self : WgslIrAliasFinalNameEntry,
) -> String {
  self.final_name
}

///|
pub fn WgslIrFinalNameTable::new() -> WgslIrFinalNameTable {
  WgslIrFinalNameTable::{
    canonical: @hashmap.HashMap::new(),
    alias_scoped: @hashmap.HashMap::new(),
    canonical_entries: [],
    alias_entries: [],
  }
}

///|
pub fn WgslIrFinalNameTable::canonical_set(
  self : WgslIrFinalNameTable,
  identity : WgslIrSymbolIdentity,
  final_name : String,
) -> Unit {
  let key = identity.key()
  if self.canonical.contains(key) {
    return
  }
  self.canonical.set(key, final_name)
  self.canonical_entries.push(WgslIrCanonicalFinalNameEntry::{
    identity,
    final_name,
  })
}

///|
pub fn WgslIrFinalNameTable::canonical_get(
  self : WgslIrFinalNameTable,
  identity : WgslIrSymbolIdentity,
) -> String? {
  self.canonical.get(identity.key())
}

///|
pub fn WgslIrFinalNameTable::canonical_entries_for_rel_path(
  self : WgslIrFinalNameTable,
  rel_path : String,
) -> Array[WgslIrCanonicalFinalNameEntry] {
  let entries : Array[WgslIrCanonicalFinalNameEntry] = []
  for entry in self.canonical_entries {
    if entry.identity.rel_path == rel_path {
      entries.push(entry)
    }
  }
  entries
}

///|
pub fn WgslIrFinalNameTable::canonical_entry_count(
  self : WgslIrFinalNameTable,
) -> Int {
  self.canonical_entries.length()
}

///|
pub fn WgslIrFinalNameTable::alias_set(
  self : WgslIrFinalNameTable,
  identity : WgslIrAliasSymbolIdentity,
  final_name : String,
) -> Unit {
  let key = identity.key()
  if self.alias_scoped.contains(key) {
    return
  }
  self.alias_scoped.set(key, final_name)
  self.alias_entries.push(WgslIrAliasFinalNameEntry::{ identity, final_name })
}

///|
pub fn WgslIrFinalNameTable::alias_get(
  self : WgslIrFinalNameTable,
  identity : WgslIrAliasSymbolIdentity,
) -> String? {
  self.alias_scoped.get(identity.key())
}

///|
pub fn WgslIrFinalNameTable::alias_entries_for_scope(
  self : WgslIrFinalNameTable,
  rel_path : String,
  alias_name : String,
) -> Array[WgslIrAliasFinalNameEntry] {
  let entries : Array[WgslIrAliasFinalNameEntry] = []
  for entry in self.alias_entries {
    if entry.identity.alias_name == alias_name &&
      entry.identity.symbol.rel_path == rel_path {
      entries.push(entry)
    }
  }
  entries
}
