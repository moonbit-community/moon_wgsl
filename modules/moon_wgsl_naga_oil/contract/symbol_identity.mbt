///|
pub struct WgslComposeSymbolIdentity {
  priv rel_path : String
  priv original_name : String
  priv key : String
} derive(Eq, Debug)

///|
pub struct WgslComposeAliasSymbolIdentity {
  priv alias_name : String
  priv symbol : WgslComposeSymbolIdentity
  priv key : String
} derive(Eq, Debug)

///|
pub fn WgslComposeSymbolIdentity::WgslComposeSymbolIdentity(
  rel_path : String,
  original_name : String,
) -> WgslComposeSymbolIdentity {
  { rel_path, original_name, key: "\{rel_path}|\{original_name}" }
}

///|
pub fn WgslComposeSymbolIdentity::key(
  self : WgslComposeSymbolIdentity,
) -> String {
  self.key
}

///|
pub fn WgslComposeSymbolIdentity::rel_path(
  self : WgslComposeSymbolIdentity,
) -> String {
  self.rel_path
}

///|
pub fn WgslComposeSymbolIdentity::original_name(
  self : WgslComposeSymbolIdentity,
) -> String {
  self.original_name
}

///|
pub fn WgslComposeAliasSymbolIdentity::WgslComposeAliasSymbolIdentity(
  rel_path : String,
  alias_name : String,
  original_name : String,
) -> WgslComposeAliasSymbolIdentity {
  let symbol = WgslComposeSymbolIdentity(rel_path, original_name)
  { alias_name, symbol, key: "\{alias_name}|\{symbol.key()}" }
}

///|
pub fn WgslComposeAliasSymbolIdentity::key(
  self : WgslComposeAliasSymbolIdentity,
) -> String {
  self.key
}

///|
pub fn WgslComposeAliasSymbolIdentity::alias_name(
  self : WgslComposeAliasSymbolIdentity,
) -> String {
  self.alias_name
}

///|
pub fn WgslComposeAliasSymbolIdentity::symbol(
  self : WgslComposeAliasSymbolIdentity,
) -> WgslComposeSymbolIdentity {
  self.symbol
}
