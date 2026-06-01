fn erf(p: vec2<f32>) -> vec2<f32> {
    let s = sign(p);
    let a = abs(p);
    var result = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
    result = result * result;
    return s - s / (result * result);
}

fn horizontalRoundedBoxShadow(x: f32, y: f32, blur: f32, corner: f32, half_size: vec2<f32>) -> f32 {
    let d = min(half_size.y - corner - abs(y), 0.);
    let c = half_size.x - corner + sqrt(max(0., corner * corner - d * d));
    let integral = 0.5 + 0.5 * erf((x + vec2(-c, c)) * (sqrt(0.5) / blur));
    return integral.y - integral.x;
}
