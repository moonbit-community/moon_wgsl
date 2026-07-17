///|
pub struct PreprocessOutput {
  preprocessed_source : String
  imports : Array[ImportDefWithOffset]
}

///|
pub fn PreprocessOutput::PreprocessOutput(
  preprocessed_source : String,
  imports : Array[ImportDefWithOffset],
) -> PreprocessOutput {
  { preprocessed_source, imports }
}

///|
/// Return the preprocessed WGSL text. Directive and import spans are replaced
/// with width-preserving whitespace where required by the pipeline.
pub fn PreprocessOutput::source(self : PreprocessOutput) -> String {
  self.preprocessed_source
}

///|
/// Return the imports discovered while preprocessing.
pub fn PreprocessOutput::imports(
  self : PreprocessOutput,
) -> Array[ImportDefWithOffset] {
  self.imports.copy()
}

///|
pub struct PreprocessorMetaData {
  name : String?
  imports : Array[ImportDefWithOffset]
  defines : Map[String, ShaderDefValue]
  effective_defs : @set.Set[String]
  wgsl_directives : WgslDirectives
  cleaned_source : String
}

///|
pub fn PreprocessorMetaData::PreprocessorMetaData(
  name : String?,
  imports : Array[ImportDefWithOffset],
  defines : Map[String, ShaderDefValue],
  effective_defs : @set.Set[String],
  wgsl_directives : WgslDirectives,
  cleaned_source : String,
) -> PreprocessorMetaData {
  { name, imports, defines, effective_defs, wgsl_directives, cleaned_source }
}
