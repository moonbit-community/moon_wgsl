///|
pub type ShaderLanguage = @common.ShaderLanguage

///|
pub type ShaderType = @common.ShaderType

///|
pub type ShaderDefValue = @common.ShaderDefValue

///|
pub type ImportDefinition = @common.ImportDefinition

///|
pub type ImportDefWithOffset = @common.ImportDefWithOffset

///|
pub type EnableDirective = @common.EnableDirective

///|
pub type RequiresDirective = @common.RequiresDirective

///|
pub type DiagnosticDirective = @common.DiagnosticDirective

///|
pub type WgslDirectives = @common.WgslDirectives

///|
pub type PreprocessOutput = @common.PreprocessOutput

///|
pub type PreprocessorMetaData = @common.PreprocessorMetaData

///|
pub type WgslSourceFile = @common.WgslSourceFile

///|
pub type WgslSourceScanOptions = @common.WgslSourceScanOptions

///|
pub type WgslDiagnosticSeverity = @common.WgslDiagnosticSeverity

///|
pub type WgslDiagnostic = @common.WgslDiagnostic

///|
pub type WgslSourceCatalogEntry = @common.WgslSourceCatalogEntry

///|
pub type WgslSymbolRedirect = @common.WgslSymbolRedirect

///|
pub type WgslComposeOptions = @common.WgslComposeOptions

///|
pub type WgslSourceMapEntry = @common.WgslSourceMapEntry

///|
pub type WgslExportOptions = @common.WgslExportOptions

///|
pub type WgslExportOutput = @common.WgslExportOutput

///|
pub type WgslImportTarget = @common.WgslImportTarget

///|
pub type WgslResolvedImportModule = @common.WgslResolvedImportModule

///|
pub fn default_wgsl_value_defines() -> @hashmap.HashMap[String, Int] {
  @common.default_wgsl_value_defines()
}
