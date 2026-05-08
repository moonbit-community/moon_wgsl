pub const WGSL_CAPABILITY_NAMES: &str = "ray-query|dual-source-blending|texture-external|texture-atomic|texture-int64-atomic|f16|shader-int64|subgroups|immediates|binding-arrays|primitive-index|shader-barycentrics|per-vertex|multiview|cooperative-matrix|mesh-shader|mesh-shader-point-topology";

pub fn add_wgsl_capability(capabilities: &mut naga::valid::Capabilities, value: &str) -> bool {
    match value {
        "ray-query" => *capabilities |= naga::valid::Capabilities::RAY_QUERY,
        "dual-source-blending" => *capabilities |= naga::valid::Capabilities::DUAL_SOURCE_BLENDING,
        "texture-external" => *capabilities |= naga::valid::Capabilities::TEXTURE_EXTERNAL,
        "texture-atomic" => *capabilities |= naga::valid::Capabilities::TEXTURE_ATOMIC,
        "texture-int64-atomic" => {
            *capabilities |= naga::valid::Capabilities::TEXTURE_ATOMIC;
            *capabilities |= naga::valid::Capabilities::TEXTURE_INT64_ATOMIC;
        }
        "f16" => *capabilities |= naga::valid::Capabilities::SHADER_FLOAT16,
        "shader-int64" => *capabilities |= naga::valid::Capabilities::SHADER_INT64,
        "subgroups" => *capabilities |= naga::valid::Capabilities::SUBGROUP,
        "immediates" => *capabilities |= naga::valid::Capabilities::IMMEDIATES,
        "binding-arrays" => {
            *capabilities |= naga::valid::Capabilities::TEXTURE_AND_SAMPLER_BINDING_ARRAY;
            *capabilities |=
                naga::valid::Capabilities::TEXTURE_AND_SAMPLER_BINDING_ARRAY_NON_UNIFORM_INDEXING;
            *capabilities |= naga::valid::Capabilities::BUFFER_BINDING_ARRAY;
            *capabilities |= naga::valid::Capabilities::BUFFER_BINDING_ARRAY_NON_UNIFORM_INDEXING;
            *capabilities |= naga::valid::Capabilities::STORAGE_TEXTURE_BINDING_ARRAY;
            *capabilities |=
                naga::valid::Capabilities::STORAGE_TEXTURE_BINDING_ARRAY_NON_UNIFORM_INDEXING;
            *capabilities |= naga::valid::Capabilities::STORAGE_BUFFER_BINDING_ARRAY;
            *capabilities |=
                naga::valid::Capabilities::STORAGE_BUFFER_BINDING_ARRAY_NON_UNIFORM_INDEXING;
        }
        "primitive-index" => *capabilities |= naga::valid::Capabilities::PRIMITIVE_INDEX,
        "shader-barycentrics" => *capabilities |= naga::valid::Capabilities::SHADER_BARYCENTRICS,
        "per-vertex" => *capabilities |= naga::valid::Capabilities::PER_VERTEX,
        "multiview" => *capabilities |= naga::valid::Capabilities::MULTIVIEW,
        "cooperative-matrix" => *capabilities |= naga::valid::Capabilities::COOPERATIVE_MATRIX,
        "mesh-shader" => *capabilities |= naga::valid::Capabilities::MESH_SHADER,
        "mesh-shader-point-topology" => {
            *capabilities |= naga::valid::Capabilities::MESH_SHADER_POINT_TOPOLOGY
        }
        _ => return false,
    }
    true
}
