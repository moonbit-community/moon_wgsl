@fragment
fn main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let a: f32 = uv.x + 0.25;
  let b: f32 = uv.y + 0.5;
  let v2: vec2f = uv + vec2f(0.25, 0.5);
  let v3: vec3f = vec3f(a, b, 1.0);
  let v4: vec4f = vec4f(a, b, 0.25, 1.0);
  let m2: mat2x2f = mat2x2f(1.0, 0.0, 0.0, 1.0);

  let s0: f32 = abs(-a) + min(a, b) + max(a, b) + clamp(a, 0.0, 1.0) + saturate(a);
  let s1: f32 = cos(a) + cosh(a) + sin(a) + sinh(a) + tan(a) + tanh(a);
  let s2: f32 = acos(0.5) + acosh(2.0) + asin(0.5) + asinh(a) + atan(a) + atanh(0.5) + atan2(a, b);
  let s3: f32 = radians(90.0) + degrees(1.0) + ceil(a) + floor(a) + round(a) + fract(a) + trunc(a);

  let mf = modf(a);
  let fx = frexp(a);
  let s4: f32 = mf.fract + mf.whole + fx.fract + f32(fx.exp) + ldexp(a, 2i) + exp(a) + exp2(a) + log(2.0) + log2(2.0) + pow(a, 2.0);
  let s5: f32 = dot(v3, v3) + cross(v3, v3).x + distance(v3, v3) + length(v3) + faceForward(v3, v3, -v3).x + reflect(v3, v3).x + refract(v3, v3, 0.5).x;

  let n: vec3f = normalize(v3);
  let s6: f32 = sign(a) + fma(a, b, 1.0) + mix(a, b, 0.5) + step(a, b) + smoothstep(0.0, 1.0, a) + sqrt(a) + inverseSqrt(a);
  let tm: mat2x2f = transpose(m2);
  let s7: f32 = determinant(m2) + tm[0][0];

  let dx: vec2f = dpdx(v2) + dpdxCoarse(v2) + dpdxFine(v2);
  let dy: vec2f = dpdy(v2) + dpdyCoarse(v2) + dpdyFine(v2);
  let fw: vec2f = fwidth(v2) + fwidthCoarse(v2) + fwidthFine(v2);
  let rel: bool = all(vec2<bool>((a < b), (b > a))) && any(vec2<bool>((a == a), (b == a)));

  let r: f32 = s0 + s1 + s2 + s3 + s4 + s5 + n.x + s6 + s7 + dx.x + dy.y + fw.x + select(0.0, 1.0, rel);
  return vec4f(v4.xyz + vec3f(r), 1.0);
}
