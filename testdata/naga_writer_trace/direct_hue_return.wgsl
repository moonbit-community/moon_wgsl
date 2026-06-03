const HUE_GUARD: f32 = 0.0001;

fn direct_hue_return(a: vec3<f32>, b: vec3<f32>, t: f32) -> vec3<f32> {
  var h = a.x;
  var g = b.x;
  if a.y < HUE_GUARD {
    h = g;
  } else if b.y < HUE_GUARD {
    g = h;
  }

  return vec3(
    fract(h + (fract(g - h + 0.5) - 0.5) * t),
    mix(a.y, b.y, t),
    mix(a.z, b.z, t),
  );
}
