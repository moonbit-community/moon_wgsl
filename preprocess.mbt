///|
pub type Preprocessor = @preprocess.Preprocessor

///|
pub type PreprocessError = @preprocess.PreprocessError

///|
pub fn get_preprocessor_metadata(source : String) -> PreprocessorMetaData {
  @preprocess.get_preprocessor_metadata(source)
}

///|
pub fn get_preprocessor_data(
  source : String,
) -> (
  String?,
  Array[ImportDefinition],
  @hashmap.HashMap[String, ShaderDefValue],
) {
  @preprocess.get_preprocessor_data(source)
}
