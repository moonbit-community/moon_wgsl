pub const WGSL_CAPABILITY_NAMES: &str = "ray-query|ray-hit-vertex-position|dual-source-blending|texture-external|texture-atomic|texture-int64-atomic|f16|float64|shader-int64|shader-float16-in-float32|subgroups|immediates|binding-arrays|primitive-index|shader-barycentrics|per-vertex|multiview|cooperative-matrix|mesh-shader|mesh-shader-point-topology";

pub fn add_wgsl_capability(capabilities: &mut naga::valid::Capabilities, value: &str) -> bool {
    match value {
        "ray-query" => *capabilities |= naga::valid::Capabilities::RAY_QUERY,
        "ray-hit-vertex-position" => {
            *capabilities |= naga::valid::Capabilities::RAY_QUERY;
            *capabilities |= naga::valid::Capabilities::RAY_HIT_VERTEX_POSITION;
        }
        "dual-source-blending" => *capabilities |= naga::valid::Capabilities::DUAL_SOURCE_BLENDING,
        "texture-external" => *capabilities |= naga::valid::Capabilities::TEXTURE_EXTERNAL,
        "texture-atomic" => *capabilities |= naga::valid::Capabilities::TEXTURE_ATOMIC,
        "texture-int64-atomic" => {
            *capabilities |= naga::valid::Capabilities::TEXTURE_ATOMIC;
            *capabilities |= naga::valid::Capabilities::TEXTURE_INT64_ATOMIC;
        }
        "f16" => *capabilities |= naga::valid::Capabilities::SHADER_FLOAT16,
        "float64" => *capabilities |= naga::valid::Capabilities::FLOAT64,
        "shader-int64" => *capabilities |= naga::valid::Capabilities::SHADER_INT64,
        "shader-float16-in-float32" => {
            *capabilities |= naga::valid::Capabilities::SHADER_FLOAT16_IN_FLOAT32
        }
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

pub fn normalize_wgsl_for_naga_parser(
    source: &str,
    capabilities: naga::valid::Capabilities,
) -> String {
    let mut normalized = String::with_capacity(source.len());
    for line in source.split_inclusive('\n') {
        if parser_unsupported_enable_is_enabled(line.trim(), capabilities) {
            if line.ends_with('\n') {
                normalized.push('\n');
            }
        } else {
            normalized.push_str(line);
        }
    }
    normalized
}

fn parser_unsupported_enable_is_enabled(
    trimmed_line: &str,
    capabilities: naga::valid::Capabilities,
) -> bool {
    let Some(extension) = trimmed_line
        .strip_prefix("enable ")
        .and_then(|rest| rest.strip_suffix(';'))
        .map(str::trim)
    else {
        return false;
    };
    match extension {
        "wgpu_binding_array" => {
            capabilities.contains(naga::valid::Capabilities::BUFFER_BINDING_ARRAY)
                || capabilities
                    .contains(naga::valid::Capabilities::TEXTURE_AND_SAMPLER_BINDING_ARRAY)
                || capabilities.contains(naga::valid::Capabilities::STORAGE_TEXTURE_BINDING_ARRAY)
                || capabilities.contains(naga::valid::Capabilities::STORAGE_BUFFER_BINDING_ARRAY)
        }
        "wgpu_per_vertex" => capabilities.contains(naga::valid::Capabilities::PER_VERTEX),
        _ => false,
    }
}
