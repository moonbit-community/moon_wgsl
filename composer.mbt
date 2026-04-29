///|
pub type Composer = @compose.Composer

///|
pub type ComposerError = @compose.ComposerError

///|
pub type WgslComposeSession = @compose.WgslComposeSession

///|
pub fn registered_wgsl_source_required(
  rel_path : String,
) -> String raise ComposerError {
  @compose.registered_wgsl_source_required(rel_path)
}
