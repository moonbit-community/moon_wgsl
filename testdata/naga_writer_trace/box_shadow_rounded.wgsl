const SAMPLES: i32 = 4;

fn gaussian(x: f32, sigma: f32) -> f32 {
    return exp(-(x * x) / (2.0 * sigma * sigma)) / (sqrt(2.0 * 3.141592653589793) * sigma);
}

fn erf(p: vec2<f32>) -> vec2<f32> {
    let s = sign(p);
    let a = abs(p);
    var result = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
    result = result * result;
    return s - s / (result * result);
}

fn selectCorner(p: vec2<f32>, c: vec4<f32>) -> f32 {
    return mix(mix(c.x, c.y, step(0.0, p.x)), mix(c.w, c.z, step(0.0, p.x)), step(0.0, p.y));
}

fn horizontalRoundedBoxShadow(x: f32, y: f32, blur: f32, corner: f32, half_size: vec2<f32>) -> f32 {
    let d = min(half_size.y - corner - abs(y), 0.);
    let c = half_size.x - corner + sqrt(max(0., corner * corner - d * d));
    let integral = 0.5 + 0.5 * erf((x + vec2(-c, c)) * (sqrt(0.5) / blur));
    return integral.y - integral.x;
}

fn roundedBoxShadow(
    lower: vec2<f32>,
    upper: vec2<f32>,
    point: vec2<f32>,
    blur: f32,
    corners: vec4<f32>,
) -> f32 {
    let center = (lower + upper) * 0.5;
    let half_size = (upper - lower) * 0.5;
    let p = point - center;
    let low = p.y - half_size.y;
    let high = p.y + half_size.y;
    let start = clamp(-3. * blur, low, high);
    let end = clamp(3. * blur, low, high);
    let step = (end - start) / f32(SAMPLES);
    var y = start + step * 0.5;
    var value: f32 = 0.0;
    for (var i = 0; i < SAMPLES; i++) {
        let corner = selectCorner(p, corners);
        value += horizontalRoundedBoxShadow(p.x, p.y - y, blur, corner, half_size) * gaussian(y, blur) * step;
        y += step;
    }
    return value;
}
