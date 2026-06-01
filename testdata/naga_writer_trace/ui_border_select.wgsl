fn sd_rounded_box(point: vec2<f32>, size: vec2<f32>, radius: vec4<f32>) -> f32 {
    return dot(point, size) + radius.x;
}

fn sd_inset_rounded_box(point: vec2<f32>, size: vec2<f32>, radius: vec4<f32>, border: vec4<f32>) -> f32 {
    return dot(point, size) + radius.y + border.x;
}

fn nearest_border_active(point: vec2<f32>, size: vec2<f32>, border: vec4<f32>, flags: u32) -> bool {
    return dot(point, size) > border.x && flags != 0u;
}

fn draw_uinode_border(
    color: vec4<f32>,
    point: vec2<f32>,
    size: vec2<f32>,
    radius: vec4<f32>,
    border: vec4<f32>,
    flags: u32,
) -> vec4<f32> {
    let external_distance = sd_rounded_box(point, size, radius);
    let internal_distance = sd_inset_rounded_box(point, size, radius, border);
    let border_distance = max(external_distance, -internal_distance);
    let nearest_border = select(0.0, 1.0, nearest_border_active(point, size, border, flags));
    let t = 1.0 - step(0.0, border_distance);
    return vec4(color.rgb, saturate(color.a * t * nearest_border));
}
