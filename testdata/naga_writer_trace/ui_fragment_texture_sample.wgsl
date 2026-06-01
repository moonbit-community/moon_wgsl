struct VertexOutput {
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) flags: u32,
    @location(3) point: vec2<f32>,
    @location(4) size: vec2<f32>,
    @location(5) radius: vec4<f32>,
    @location(6) border: vec4<f32>,
}

@group(0) @binding(0) var sprite_texture: texture_2d<f32>;
@group(0) @binding(1) var sprite_sampler: sampler;

const TEXTURED: u32 = 1u;

fn enabled(flags: u32, flag: u32) -> bool {
    return (flags & flag) != 0u;
}

@fragment
fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    let texture_color = textureSample(sprite_texture, sprite_sampler, in.uv);
    let color = select(in.color, in.color * texture_color, enabled(in.flags, TEXTURED));
    return color;
}
