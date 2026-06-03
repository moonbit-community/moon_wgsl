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

pub fn push_function_expression_inventory(
    lines: &mut Vec<String>,
    label: &str,
    function: &naga::Function,
) {
    lines.push(format!(
        "function\t{label}\targuments={}\tlocals={}\texpressions={}\tnamed={}",
        function.arguments.len(),
        function.local_variables.len(),
        function.expressions.len(),
        function.named_expressions.len()
    ));
    for (handle, argument) in function.arguments.iter().enumerate() {
        lines.push(format!(
            "argument\t{label}\t{handle}\tname={:?}\tbinding={:?}",
            argument.name, argument.binding
        ));
    }
    for (handle, local) in function.local_variables.iter() {
        lines.push(format!(
            "local\t{label}\t{}\tname={:?}\tinit={:?}",
            handle.index(),
            local.name,
            local.init
        ));
    }
    for (handle, name) in function.named_expressions.iter() {
        lines.push(format!(
            "named-expression\t{label}\t{}\t{name}",
            handle.index()
        ));
    }
    for (handle, expression) in function.expressions.iter() {
        lines.push(format!(
            "expression\t{label}\t{}\t{expression:?}",
            handle.index()
        ));
    }
    for (index, statement) in function.body.iter().enumerate() {
        lines.push(format!(
            "raw-statement\t{label}\t{index}\t{}",
            statement_inventory_kind(statement)
        ));
    }
    let mut helper_temp_order = 0usize;
    push_block_helper_temp_inventory(lines, label, &function.body, &mut helper_temp_order);
    lines.push(format!("body\t{label}\t{:?}", function.body));
}

fn push_block_helper_temp_inventory(
    lines: &mut Vec<String>,
    label: &str,
    block: &naga::Block,
    order: &mut usize,
) {
    for statement in block.iter() {
        push_statement_helper_temp_inventory(lines, label, statement, order);
    }
}

fn push_statement_helper_temp_inventory(
    lines: &mut Vec<String>,
    label: &str,
    statement: &naga::Statement,
    order: &mut usize,
) {
    if let Some(result) = statement_inventory_result(statement) {
        lines.push(format!(
            "helper-temp\t{label}\t{}\texpression={}\ttemp=_e{}",
            *order,
            result.index(),
            result.index()
        ));
        *order += 1;
    }
    match statement {
        naga::Statement::Block(block) => {
            push_block_helper_temp_inventory(lines, label, block, order)
        }
        naga::Statement::If { accept, reject, .. } => {
            push_block_helper_temp_inventory(lines, label, accept, order);
            push_block_helper_temp_inventory(lines, label, reject, order);
        }
        naga::Statement::Switch { cases, .. } => {
            for case in cases {
                push_block_helper_temp_inventory(lines, label, &case.body, order);
            }
        }
        naga::Statement::Loop {
            body, continuing, ..
        } => {
            push_block_helper_temp_inventory(lines, label, body, order);
            push_block_helper_temp_inventory(lines, label, continuing, order);
        }
        _ => {}
    }
}

fn statement_inventory_result(
    statement: &naga::Statement,
) -> Option<naga::Handle<naga::Expression>> {
    match statement {
        naga::Statement::Atomic { result, .. } => *result,
        naga::Statement::WorkGroupUniformLoad { result, .. }
        | naga::Statement::SubgroupBallot { result, .. }
        | naga::Statement::SubgroupGather { result, .. }
        | naga::Statement::SubgroupCollectiveOperation { result, .. } => Some(*result),
        naga::Statement::Call { result, .. } => *result,
        _ => None,
    }
}

fn statement_inventory_kind(statement: &naga::Statement) -> String {
    match statement {
        naga::Statement::Emit(range) => emit_range_inventory_kind(range.clone()),
        naga::Statement::Block(_) => "Block".to_owned(),
        naga::Statement::If { .. } => "If".to_owned(),
        naga::Statement::Switch { .. } => "Switch".to_owned(),
        naga::Statement::Loop { .. } => "Loop".to_owned(),
        naga::Statement::Break => "Break".to_owned(),
        naga::Statement::Continue => "Continue".to_owned(),
        naga::Statement::Return { .. } => "Return".to_owned(),
        naga::Statement::Kill => "Kill".to_owned(),
        naga::Statement::ControlBarrier(_) => "ControlBarrier".to_owned(),
        naga::Statement::MemoryBarrier(_) => "MemoryBarrier".to_owned(),
        naga::Statement::Store { .. } => "Store".to_owned(),
        naga::Statement::ImageStore { .. } => "ImageStore".to_owned(),
        naga::Statement::Atomic { result, .. } => match result {
            Some(handle) => format!("Atomic(result={})", handle.index()),
            None => "Atomic(result=-)".to_owned(),
        },
        naga::Statement::ImageAtomic { .. } => "ImageAtomic".to_owned(),
        naga::Statement::WorkGroupUniformLoad { result, .. } => {
            format!("WorkGroupUniformLoad(result={})", result.index())
        }
        naga::Statement::Call { result, .. } => match result {
            Some(handle) => format!("Call(result={})", handle.index()),
            None => "Call(result=-)".to_owned(),
        },
        naga::Statement::RayQuery { .. } => "RayQuery".to_owned(),
        naga::Statement::RayPipelineFunction(_) => "RayPipelineFunction".to_owned(),
        naga::Statement::SubgroupBallot { result, .. } => {
            format!("SubgroupBallot(result={})", result.index())
        }
        naga::Statement::SubgroupGather { result, .. } => {
            format!("SubgroupGather(result={})", result.index())
        }
        naga::Statement::SubgroupCollectiveOperation { result, .. } => {
            format!("SubgroupCollectiveOperation(result={})", result.index())
        }
        naga::Statement::CooperativeStore { .. } => "CooperativeStore".to_owned(),
    }
}

fn emit_range_inventory_kind(mut range: naga::Range<naga::Expression>) -> String {
    let Some(first) = range.next() else {
        return "Emit(empty)".to_owned();
    };
    let mut last = first;
    for handle in range {
        last = handle;
    }
    format!("Emit({}..{})", first.index(), last.index())
}

pub fn module_expression_inventory(module: &naga::Module) -> String {
    let mut lines = Vec::new();
    for (handle, function) in module.functions.iter() {
        let label = function
            .name
            .as_deref()
            .map(|name| format!("fn:{name}"))
            .unwrap_or_else(|| format!("fn#{}", handle.index()));
        push_function_expression_inventory(&mut lines, &label, function);
    }
    for (index, entry_point) in module.entry_points.iter().enumerate() {
        let label = format!("entry#{index}:{}", entry_point.name);
        push_function_expression_inventory(&mut lines, &label, &entry_point.function);
    }
    lines.join("\n") + "\n"
}

pub fn module_arena_inventory(module: &naga::Module, written_wgsl: &str) -> String {
    let written = written_declarations(written_wgsl);
    let mut lines = Vec::new();
    lines.push(format!(
        "module\tdirectives=0\ttypes={}\tconstants={}\toverrides={}\tglobals={}\tfunctions={}\tentry_points={}\tconst_asserts=0",
        module.types.len(),
        module.constants.len(),
        module.overrides.len(),
        module.global_variables.len(),
        module.functions.len(),
        module.entry_points.len(),
    ));
    for (handle, ty) in module.types.iter() {
        lines.push(format!(
            "slot\ttype\t{}\tsource={}\tname={}\tfinal={}\troot=emit",
            handle.index(),
            handle.index(),
            inventory_name(ty.name.as_deref()),
            written
                .types
                .get(handle.index())
                .cloned()
                .unwrap_or_else(|| inventory_name(ty.name.as_deref())),
        ));
    }
    for (handle, constant) in module.constants.iter() {
        lines.push(format!(
            "slot\tconstant\t{}\tsource={}\tname={}\tfinal={}\troot=emit",
            handle.index(),
            handle.index(),
            inventory_name(constant.name.as_deref()),
            written
                .constants
                .get(handle.index())
                .cloned()
                .unwrap_or_else(|| inventory_name(constant.name.as_deref())),
        ));
    }
    for (handle, override_) in module.overrides.iter() {
        lines.push(format!(
            "slot\toverride\t{}\tsource={}\tname={}\tfinal={}\troot=emit",
            handle.index(),
            handle.index(),
            inventory_name(override_.name.as_deref()),
            written
                .overrides
                .get(handle.index())
                .cloned()
                .unwrap_or_else(|| inventory_name(override_.name.as_deref())),
        ));
    }
    for (handle, global) in module.global_variables.iter() {
        lines.push(format!(
            "slot\tglobal\t{}\tsource={}\tname={}\tfinal={}\troot=emit",
            handle.index(),
            handle.index(),
            inventory_name(global.name.as_deref()),
            written
                .globals
                .get(handle.index())
                .cloned()
                .unwrap_or_else(|| inventory_name(global.name.as_deref())),
        ));
    }
    for (handle, function) in module.functions.iter() {
        lines.push(format!(
            "slot\tfunction\t{}\tsource={}\tname={}\tfinal={}\troot=emit",
            handle.index(),
            handle.index(),
            inventory_name(function.name.as_deref()),
            written
                .functions
                .get(handle.index())
                .cloned()
                .unwrap_or_else(|| inventory_name(function.name.as_deref())),
        ));
    }
    for (index, entry_point) in module.entry_points.iter().enumerate() {
        lines.push(format!(
            "slot\tentry_point\t{index}\tsource={index}\tname={}\tfinal={}\troot=emit",
            inventory_name(Some(&entry_point.name)),
            written
                .entry_points
                .get(index)
                .cloned()
                .unwrap_or_else(|| inventory_name(Some(&entry_point.name))),
        ));
    }
    lines.join("\n") + "\n"
}

#[derive(Default)]
struct WrittenDeclarations {
    types: Vec<String>,
    constants: Vec<String>,
    overrides: Vec<String>,
    globals: Vec<String>,
    functions: Vec<String>,
    entry_points: Vec<String>,
}

fn written_declarations(wgsl: &str) -> WrittenDeclarations {
    let mut declarations = WrittenDeclarations::default();
    let mut next_function_is_entry_point = false;
    for raw_line in wgsl.lines() {
        let line = raw_line.trim();
        if line.starts_with("@compute")
            || line.starts_with("@fragment")
            || line.starts_with("@vertex")
        {
            next_function_is_entry_point = true;
        }
        if let Some(rest) = line.strip_prefix("struct ") {
            if let Some(name) = declaration_name_before(rest, " {") {
                declarations.types.push(name);
            }
            continue;
        }
        if let Some(rest) = line.strip_prefix("const ") {
            if let Some(name) = declaration_name_until_colon_or_equal(rest) {
                declarations.constants.push(name);
            }
            continue;
        }
        if let Some(rest) = line.strip_prefix("override ") {
            if let Some(name) = declaration_name_until_colon_or_equal(rest) {
                declarations.overrides.push(name);
            }
            continue;
        }
        if let Some(rest) = line.strip_prefix("var") {
            if let Some(name) = global_var_name(rest) {
                declarations.globals.push(name);
            }
            continue;
        }
        if let Some(rest) = line.strip_prefix("fn ") {
            if let Some(name) = declaration_name_before(rest, "(") {
                if next_function_is_entry_point {
                    declarations.entry_points.push(name);
                } else {
                    declarations.functions.push(name);
                }
            }
            next_function_is_entry_point = false;
        }
    }
    declarations
}

fn declaration_name_before(rest: &str, marker: &str) -> Option<String> {
    let name = rest.split_once(marker)?.0.trim();
    (!name.is_empty()).then(|| inventory_name(Some(name)))
}

fn declaration_name_until_colon_or_equal(rest: &str) -> Option<String> {
    let end = rest
        .find(':')
        .into_iter()
        .chain(rest.find('='))
        .min()
        .unwrap_or(rest.len());
    let name = rest[..end].trim();
    (!name.is_empty()).then(|| inventory_name(Some(name)))
}

fn global_var_name(rest: &str) -> Option<String> {
    let rest = rest.trim_start();
    let after_template = if let Some(rest) = rest.strip_prefix('<') {
        rest.split_once('>')?.1.trim_start()
    } else {
        rest
    };
    declaration_name_until_colon_or_equal(after_template)
}

fn inventory_name(value: Option<&str>) -> String {
    value
        .map(|text| {
            text.replace('\t', "\\t")
                .replace('\n', "\\n")
                .replace('\r', "\\r")
        })
        .unwrap_or_else(|| "-".to_owned())
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
