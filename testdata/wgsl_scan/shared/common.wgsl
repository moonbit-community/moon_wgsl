#define_import_path demo::shared
struct SharedValue {
  tint: vec4<f32>,
}

fn build_color(value: SharedValue) -> vec4<f32> {
  return value.tint;
}
