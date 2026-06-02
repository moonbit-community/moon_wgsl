struct Mesh {
    flags: u32,
}

@group(0) @binding(0)
var<storage, read> mesh: array<Mesh>;

fn sign_flags(flags: u32) -> f32 {
    return f32(flags);
}

fn call_member_after_argument_access(
    vertex_tangent: vec4<f32>,
    instance_index: u32,
) -> f32 {
    return vertex_tangent.w * sign_flags(mesh[instance_index].flags);
}
