///|
pub suberror MetadataError {
  InvalidWgslDirective(String, Int, String)
  ImportParseError(String, Int)
  DefineInModule(Int)
}

///|
