///|
pub struct WgslIdentifierReference {
  text : String
  start : Int
  end : Int
  substitution_allowed : Bool
} derive(Debug)

///|
fn WgslIdentifierReference::new(
  text : String,
  start : Int,
  end : Int,
  substitution_allowed : Bool,
) -> WgslIdentifierReference {
  WgslIdentifierReference::{ text, start, end, substitution_allowed }
}

///|
pub fn parse_wgsl_identifier_references(
  input : String,
) -> Array[WgslIdentifierReference] {
  let references : Array[WgslIdentifierReference] = []
  let tokens = tokenize(input, true)
  let mut in_substitution_position = true
  for token in tokens {
    match token {
      WgslToken::Identifier(ident, token_pos) =>
        references.push(
          WgslIdentifierReference::new(
            ident,
            token_pos,
            token_pos + ident.length(),
            in_substitution_position,
          ),
        )
      WgslToken::Other(other, _) =>
        if other == 46 || other == 64 {
          in_substitution_position = false
          continue
        }
      WgslToken::Whitespace(_, _) => ()
    }
    in_substitution_position = true
  }
  references
}
