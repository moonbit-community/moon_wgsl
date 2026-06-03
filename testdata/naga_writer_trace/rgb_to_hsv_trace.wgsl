const FRAC_PI_3: f32 = 1.0471976;

fn rgb_to_hsv_trace(rgb: vec3<f32>) -> vec3<f32> {
  let x_max = max(rgb.r, max(rgb.g, rgb.b));
  let x_min = min(rgb.r, min(rgb.g, rgb.b));
  let c = x_max - x_min;

  var swizzle = vec3<f32>(0.0);
  if x_max == rgb.r {
    swizzle = vec3(rgb.gb, 0.0);
  } else if x_max == rgb.g {
    swizzle = vec3(rgb.br, 2.0);
  } else {
    swizzle = vec3(rgb.rg, 4.0);
  }

  let h = FRAC_PI_3 * (((swizzle.x - swizzle.y) / c + swizzle.z) % 6.0);

  var s = 0.0;
  if x_max > 0.0 {
    s = c / x_max;
  }

  return vec3(h, s, x_max);
}
