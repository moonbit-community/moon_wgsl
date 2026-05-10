///|
pub(all) struct ImportDefinition {
  import_path : String
  items : Array[String]
} derive(Eq, Debug)

///|
pub struct ImportDefWithOffset {
  definition : ImportDefinition
} derive(Eq, Debug)

///|
pub fn ImportDefWithOffset::ImportDefWithOffset(
  definition : ImportDefinition,
) -> ImportDefWithOffset {
  ImportDefWithOffset::{ definition, }
}

///|
pub(all) struct WgslImportTarget {
  raw_path : String
  alias_name : String
} derive(Eq, Debug)

///|
pub struct WgslReferencePath {
  priv segments : Array[String]
} derive(Eq, Debug)

///|
pub fn WgslReferencePath::from_segments(
  segments : Array[String],
) -> WgslReferencePath? {
  let normalized : Array[String] = []
  for segment in segments {
    let segment = segment.trim().to_owned()
    if segment == "" {
      return None
    }
    normalized.push(segment)
  }
  if normalized.length() == 0 {
    None
  } else {
    Some(WgslReferencePath::{ segments: normalized })
  }
}

///|
pub fn WgslReferencePath::from_text(text : String) -> WgslReferencePath? {
  let segments : Array[String] = []
  for raw_segment in text.trim().split("::") {
    let segment = raw_segment.trim().to_owned()
    if segment == "" {
      return None
    }
    segments.push(segment)
  }
  WgslReferencePath::from_segments(segments)
}

///|
pub fn WgslReferencePath::segments(self : WgslReferencePath) -> Array[String] {
  self.segments.copy()
}

///|
pub fn WgslReferencePath::text(self : WgslReferencePath) -> String {
  self.segments.join("::")
}

///|
pub fn WgslReferencePath::matches(
  self : WgslReferencePath,
  other : WgslReferencePath,
) -> Bool {
  if self.segments.length() != other.segments.length() {
    return false
  }
  for i in 0..<self.segments.length() {
    if self.segments[i] != other.segments[i] {
      return false
    }
  }
  true
}

///|
pub struct WgslResolvedImportModule {
  priv module_path : String
  priv rel_path : String
} derive(Eq, Debug)

///|
pub fn WgslResolvedImportModule::WgslResolvedImportModule(
  module_path : String,
  rel_path : String,
) -> WgslResolvedImportModule {
  WgslResolvedImportModule::{ module_path, rel_path }
}

///|
pub fn WgslResolvedImportModule::module_path(
  self : WgslResolvedImportModule,
) -> String {
  self.module_path
}

///|
pub fn WgslResolvedImportModule::rel_path(
  self : WgslResolvedImportModule,
) -> String {
  self.rel_path
}

///|
pub fn WgslResolvedImportModule::is_empty(
  self : WgslResolvedImportModule,
) -> Bool {
  self.module_path == "" && self.rel_path == ""
}
