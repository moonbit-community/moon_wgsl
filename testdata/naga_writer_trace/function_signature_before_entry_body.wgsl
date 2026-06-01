fn draw_a(color: vec4<f32>) -> vec4<f32> {
    return color;
}

fn draw_b(color: vec4<f32>) -> vec4<f32> {
    return color;
}

@fragment
fn fragment() -> @location(0) vec4<f32> {
    let color = vec4(1.0);
    return draw_b(draw_a(color));
}
