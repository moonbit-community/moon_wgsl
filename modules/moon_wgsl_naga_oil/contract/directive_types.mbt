///|
#derive(Eq, Debug)
pub struct EnableDirective {
  extensions : Array[String]
}

///|
pub fn EnableDirective::EnableDirective(
  extensions : Array[String],
) -> EnableDirective {
  { extensions, }
}

///|
#derive(Eq, Debug)
pub struct RequiresDirective {
  extensions : Array[String]
}

///|
pub fn RequiresDirective::RequiresDirective(
  extensions : Array[String],
) -> RequiresDirective {
  { extensions, }
}

///|
#derive(Eq, Debug)
pub struct DiagnosticDirective {
  severity : String
  rule : String
}

///|
pub fn DiagnosticDirective::DiagnosticDirective(
  severity : String,
  rule : String,
) -> DiagnosticDirective {
  { severity, rule, }
}

///|
#derive(Eq, Debug)
pub struct WgslDirectives {
  enables : Array[EnableDirective]
  requires : Array[RequiresDirective]
  diagnostics : Array[DiagnosticDirective]
}

///|
pub fn WgslDirectives::default() -> WgslDirectives {
  { enables: [], requires: [], diagnostics: [], }
}

///|
pub fn WgslDirectives::is_empty(self : WgslDirectives) -> Bool {
  self.enables.is_empty() &&
  self.requires.is_empty() &&
  self.diagnostics.is_empty()
}

///|
pub extend DiagnosticDirective with Debug::{to_repr}

///|
pub extend DiagnosticDirective with Eq::{not_equal, equal}

///|
pub extend EnableDirective with Debug::{to_repr}

///|
pub extend EnableDirective with Eq::{not_equal, equal}

///|
pub extend RequiresDirective with Debug::{to_repr}

///|
pub extend RequiresDirective with Eq::{not_equal, equal}

///|
pub extend WgslDirectives with Debug::{to_repr}

///|
pub extend WgslDirectives with Eq::{not_equal, equal}
