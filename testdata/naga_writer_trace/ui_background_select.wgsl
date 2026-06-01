const INVERT: u32 = 4096u;

fn enabled(flags: u32, mask: u32) -> bool {
    return (flags & mask) != 0u;
}

fn sd_inset_rounded_box(point: vec2<f32>, size: vec2<f32>, radius: vec4<f32>, border: vec4<f32>) -> f32 {
    return dot(point, size) + radius.y + border.x;
}

fn draw_uinode_background(
    color: vec4<f32>,
    point: vec2<f32>,
    size: vec2<f32>,
    radius: vec4<f32>,
    border: vec4<f32>,
    flags: u32,
) -> vec4<f32> {
    let internal_distance = sd_inset_rounded_box(point, size, radius, border) * select(1., -1, enabled(flags, INVERT));
    let t = 1.0 - step(0.0, internal_distance);
    return vec4(color.rgb, saturate(color.a * t));
}
