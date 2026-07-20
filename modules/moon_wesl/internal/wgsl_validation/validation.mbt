///|
pub suberror WgslValidationError {
  Lower(String)
  Validate(String)
}

///|
pub fn WgslValidationError::message(self : WgslValidationError) -> String {
  match self {
    Lower(message) | Validate(message) => message
  }
}

///|
pub fn validate_source(source : String) -> Unit raise WgslValidationError {
  let module_ = @ir.parse_wgsl_module_to_ir(source) catch {
    error => raise Lower(error.message())
  }
  @ir.validate_wgsl_ir_module(module_) catch {
    error => raise Validate(error.message())
  }
}
