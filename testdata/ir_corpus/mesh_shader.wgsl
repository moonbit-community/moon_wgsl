enable wgpu_mesh_shader;

struct TaskPayload {
    colorMask: vec4<f32>,
    visible: bool,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
}

struct PrimitiveOutput {
    @builtin(triangle_indices) indices: vec3<u32>,
    @builtin(cull_primitive) cull: bool,
    @per_primitive @location(1) colorMask: vec4<f32>,
}

struct PrimitiveInput {
    @per_primitive @location(1) colorMask: vec4<f32>,
}

struct MeshOutput {
    @builtin(vertices) vertices: array<VertexOutput, 3>,
    @builtin(primitives) primitives: array<PrimitiveOutput, 1>,
    @builtin(vertex_count) vertex_count: u32,
    @builtin(primitive_count) primitive_count: u32,
}

const positions = array(
    vec4(0.0, 1.0, 0.0, 1.0),
    vec4(-1.0, -1.0, 0.0, 1.0),
    vec4(1.0, -1.0, 0.0, 1.0),
);

var<task_payload> payload_data: TaskPayload;
var<workgroup> mesh_output: MeshOutput;

@task
@payload(payload_data)
@workgroup_size(1)
fn task_main() -> @builtin(mesh_task_size) vec3<u32> {
    payload_data.colorMask = vec4(1.0, 1.0, 0.0, 1.0);
    payload_data.visible = true;
    return vec3(1, 1, 1);
}

@mesh(mesh_output)
@payload(payload_data)
@workgroup_size(1)
fn mesh_main() {
    mesh_output.vertex_count = 3;
    mesh_output.primitive_count = 1;
    mesh_output.primitives[0].indices = vec3<u32>(0, 1, 2);
    mesh_output.primitives[0].cull = !payload_data.visible;
    mesh_output.primitives[0].colorMask = payload_data.colorMask;
    mesh_output.vertices[0].position = positions[0];
    mesh_output.vertices[0].color = vec4(1.0, 0.0, 0.0, 1.0);
}

@fragment
fn fragment_main(vertex: VertexOutput, primitive: PrimitiveInput) -> @location(0) vec4<f32> {
    return vertex.color * primitive.colorMask;
}
