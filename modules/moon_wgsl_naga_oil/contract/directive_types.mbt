///|
pub struct EnableDirective {
  extensions : Array[String]
} derive(Eq, Debug)

///|
pub fn EnableDirective::EnableDirective(
  extensions : Array[String],
) -> EnableDirective {
  { extensions, }
}

///|
pub struct RequiresDirective {
  extensions : Array[String]
} derive(Eq, Debug)

///|
pub fn RequiresDirective::RequiresDirective(
  extensions : Array[String],
) -> RequiresDirective {
  { extensions, }
}

///|
pub struct DiagnosticDirective {
  severity : String
  rule : String
} derive(Eq, Debug)

///|
pub fn DiagnosticDirective::DiagnosticDirective(
  severity : String,
  rule : String,
) -> DiagnosticDirective {
  { severity, rule, }
}

///|
pub struct WgslDirectives {
  enables : Array[EnableDirective]
  requires : Array[RequiresDirective]
  diagnostics : Array[DiagnosticDirective]
} derive(Eq, Debug)

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
