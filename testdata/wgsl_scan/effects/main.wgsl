#import "../shared/common.wgsl" SharedValue, build_color

fn shade(value: SharedValue) -> vec4<f32> {
  return build_color(value);
}
