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
  PreprocessOutput::{ preprocessed_source, imports }
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
  PreprocessorMetaData::{
    name,
    imports,
    defines,
    effective_defs,
    wgsl_directives,
    cleaned_source,
  }
}
