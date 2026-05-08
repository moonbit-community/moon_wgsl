@fragment
fn main(@location(0) input: vec4<f64>) -> @location(0) vec4<f64> {
  let doubled = input + vec4<f64>(1.0);
  return -doubled;
}
