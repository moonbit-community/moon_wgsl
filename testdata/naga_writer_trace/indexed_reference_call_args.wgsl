struct Mesh {
    local_from_world_transpose_a: mat2x4<f32>,
    local_from_world_transpose_b: vec4<f32>,
}

@group(0) @binding(0)
var<storage, read> mesh: array<Mesh>;

fn unpack(a: mat2x4<f32>, b: vec4<f32>) -> mat3x3<f32> {
    return mat3x3<f32>(a[0].xyz, a[1].xyz, b.xyz);
}

fn dynamic_indexed_reference_call(instance_index: u32) -> mat3x3<f32> {
    return unpack(
        mesh[instance_index].local_from_world_transpose_a,
        mesh[instance_index].local_from_world_transpose_b,
    );
}
