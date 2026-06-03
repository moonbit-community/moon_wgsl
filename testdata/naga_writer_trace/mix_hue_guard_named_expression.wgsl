const HUE_GUARD: f32 = 0.001;

fn mix_hue_guard_named_expression(
  a: vec3<f32>,
  b: vec3<f32>,
  t: f32
) -> vec3<f32> {
  var h = a.x;
  var g = b.x;
  if a.y < HUE_GUARD {
    h = g;
  } else if b.y < HUE_GUARD {
    g = h;
  }

  let hue_diff = g - h;
  if abs(hue_diff) > 0.5 {
    if hue_diff > 0.0 {
      h += (hue_diff - 1.0) * t;
    } else {
      h += (hue_diff + 1.0) * t;
    }
  } else {
    h += hue_diff * t;
  }
  return vec3(fract(h), mix(a.y, b.y, t), mix(a.z, b.z, t));
}
