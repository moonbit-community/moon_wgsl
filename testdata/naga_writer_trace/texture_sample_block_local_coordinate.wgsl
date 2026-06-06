@group(0) @binding(0)
var color_texture: texture_2d<f32>;

@group(0) @binding(1)
var color_sampler: sampler;

fn texture_sample_block_local_coordinate(uv: vec2<f32>, enabled: bool) -> vec4<f32> {
    var sample_uv = uv;
    if enabled {
        return textureSampleLevel(color_texture, color_sampler, sample_uv, 0.0);
    }
    return vec4<f32>(0.0);
}
