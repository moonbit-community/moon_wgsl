///|
pub(all) enum WgslDiagnosticSeverity {
  Warn
  Error
} derive(Eq, Debug)

///|
pub struct WgslDiagnostic {
  severity : WgslDiagnosticSeverity
  message : String
  rel_path : String?
  symbol_name : String?
} derive(Eq, Debug)

///|
pub fn WgslDiagnostic::WgslDiagnostic(
  severity : WgslDiagnosticSeverity,
  message : String,
  rel_path : String?,
  symbol_name : String?,
) -> WgslDiagnostic {
  { severity, message, rel_path, symbol_name }
}
