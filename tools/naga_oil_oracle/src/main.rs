use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use naga_oil::compose::{
    ComposableModuleDescriptor, Composer, ImportDefinition, NagaModuleDescriptor, ShaderDefValue,
    ShaderLanguage, ShaderType,
};

#[derive(Debug)]
struct Options {
    fixture_root: PathBuf,
    entry: String,
    shader_type: ShaderType,
    file_path_prefix: String,
    output: Option<PathBuf>,
    error_output: Option<PathBuf>,
    defs: HashMap<String, ShaderDefValue>,
    additional_imports: Vec<String>,
    capabilities: naga::valid::Capabilities,
    entry_only: bool,
    check_only: bool,
}

#[derive(Debug)]
struct WgslFile {
    rel_path: String,
    source: String,
    language: ShaderLanguage,
}

fn usage() -> ! {
    eprintln!(
        "usage: naga_oil_oracle --fixture-root <dir> --entry <rel.wgsl|rel.glsl> [--shader-type wgsl|glsl-vertex|glsl-fragment] [--file-path-prefix PREFIX] [--def NAME=true|false|INT] [--additional-import MODULE] [--entry-only] [--capability ray-query] [--check-only] [--output <file>] [--error-output <file>]"
    );
    std::process::exit(2);
}

fn parse_shader_def(text: &str) -> (String, ShaderDefValue) {
    let Some((name, raw_value)) = text.split_once('=') else {
        return (text.to_owned(), ShaderDefValue::Bool(true));
    };
    let value = match raw_value {
        "true" => ShaderDefValue::Bool(true),
        "false" => ShaderDefValue::Bool(false),
        _ if raw_value.ends_with('u') => {
            let number = raw_value
                .trim_end_matches('u')
                .parse::<u32>()
                .unwrap_or_else(|err| {
                    panic!("invalid unsigned shader def value `{raw_value}`: {err}");
                });
            ShaderDefValue::UInt(number)
        }
        _ => {
            let number = raw_value.parse::<i32>().unwrap_or_else(|err| {
                panic!("invalid integer shader def value `{raw_value}`: {err}");
            });
            ShaderDefValue::Int(number)
        }
    };
    (name.to_owned(), value)
}

fn parse_shader_type(text: &str) -> ShaderType {
    match text {
        "wgsl" => ShaderType::Wgsl,
        "glsl-vertex" => ShaderType::GlslVertex,
        "glsl-fragment" => ShaderType::GlslFragment,
        _ => usage(),
    }
}

fn parse_options() -> Options {
    let mut fixture_root = None;
    let mut entry = None;
    let mut shader_type = None;
    let mut file_path_prefix = String::new();
    let mut output = None;
    let mut error_output = None;
    let mut defs = HashMap::new();
    let mut additional_imports = Vec::new();
    let mut capabilities = naga::valid::Capabilities::default();
    let mut entry_only = false;
    let mut check_only = false;
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--fixture-root" => fixture_root = args.next().map(PathBuf::from),
            "--entry" => entry = args.next(),
            "--shader-type" => {
                let Some(value) = args.next() else { usage() };
                shader_type = Some(parse_shader_type(&value));
            }
            "--file-path-prefix" => {
                let Some(value) = args.next() else { usage() };
                file_path_prefix = value;
            }
            "--output" => output = args.next().map(PathBuf::from),
            "--error-output" => error_output = args.next().map(PathBuf::from),
            "--def" => {
                let Some(value) = args.next() else { usage() };
                let (name, def_value) = parse_shader_def(&value);
                defs.insert(name, def_value);
            }
            "--additional-import" => {
                let Some(value) = args.next() else { usage() };
                additional_imports.push(value);
            }
            "--capability" => {
                let Some(value) = args.next() else { usage() };
                match value.as_str() {
                    "ray-query" => capabilities |= naga::valid::Capabilities::RAY_QUERY,
                    _ => usage(),
                }
            }
            "--entry-only" => entry_only = true,
            "--check-only" => check_only = true,
            _ => usage(),
        }
    }
    let entry = entry.unwrap_or_else(|| usage());
    let shader_type = shader_type.unwrap_or_else(|| {
        if entry.ends_with(".glsl") {
            ShaderType::GlslFragment
        } else {
            ShaderType::Wgsl
        }
    });
    Options {
        fixture_root: fixture_root.unwrap_or_else(|| usage()),
        entry,
        shader_type,
        file_path_prefix,
        output,
        error_output,
        defs,
        additional_imports,
        capabilities,
        entry_only,
        check_only,
    }
}

fn normalize_rel_path(path: &Path) -> String {
    path.to_string_lossy().replace('\\', "/")
}

fn display_file_path(prefix: &str, rel_path: &str) -> String {
    if prefix.is_empty() {
        rel_path.to_owned()
    } else {
        format!("{}/{}", prefix.trim_end_matches('/'), rel_path)
    }
}

fn collect_wgsl_files(root: &Path, dir: &Path, files: &mut Vec<WgslFile>) {
    for entry in fs::read_dir(dir).unwrap_or_else(|err| {
        panic!("failed to read directory `{}`: {err}", dir.display());
    }) {
        let entry = entry.unwrap_or_else(|err| panic!("failed to read directory entry: {err}"));
        let path = entry.path();
        if path.is_dir() {
            collect_wgsl_files(root, &path, files);
            continue;
        }
        let language = match path.extension().and_then(|ext| ext.to_str()) {
            Some("wgsl") => ShaderLanguage::Wgsl,
            Some("glsl") => ShaderLanguage::Glsl,
            _ => continue,
        };
        let source = fs::read_to_string(&path).unwrap_or_else(|err| {
            panic!("failed to read WGSL file `{}`: {err}", path.display());
        });
        let rel_path = normalize_rel_path(path.strip_prefix(root).unwrap_or(&path));
        files.push(WgslFile {
            rel_path,
            source,
            language,
        });
    }
}

fn has_import_path(source: &str) -> bool {
    source
        .lines()
        .any(|line| line.trim_start().starts_with("#define_import_path "))
}

fn inferred_module_path(rel_path: &str) -> Option<String> {
    let without_ext = rel_path
        .strip_suffix(".wgsl")
        .or_else(|| rel_path.strip_suffix(".glsl"))?;
    let without_prefix = without_ext.strip_prefix("shaders/").unwrap_or(without_ext);
    let segments = without_prefix
        .split('/')
        .filter(|segment| !segment.trim().is_empty())
        .collect::<Vec<_>>();
    (!segments.is_empty()).then(|| segments.join("::"))
}

fn add_modules_until_fixed_point(
    composer: &mut Composer,
    files: &[WgslFile],
    defs: &HashMap<String, ShaderDefValue>,
    additional_imports: &[String],
    file_path_prefix: &str,
) {
    let mut pending: Vec<usize> = files
        .iter()
        .enumerate()
        .filter_map(|(index, file)| {
            let is_named_additional = inferred_module_path(&file.rel_path)
                .is_some_and(|module| additional_imports.iter().any(|item| item == &module));
            (has_import_path(&file.source) || is_named_additional).then_some(index)
        })
        .collect();
    let mut made_progress = true;
    while made_progress && !pending.is_empty() {
        made_progress = false;
        let mut still_pending = Vec::new();
        for index in pending {
            let file = &files[index];
            let file_path = display_file_path(file_path_prefix, &file.rel_path);
            let as_name = if has_import_path(&file.source) {
                None
            } else {
                inferred_module_path(&file.rel_path)
            };
            let result = composer.add_composable_module(ComposableModuleDescriptor {
                source: &file.source,
                file_path: &file_path,
                language: file.language,
                as_name,
                shader_defs: defs.clone(),
                ..Default::default()
            });
            if result.is_ok() {
                made_progress = true;
            } else {
                still_pending.push(index);
            }
        }
        pending = still_pending;
    }
    if !pending.is_empty() {
        let unresolved = pending
            .iter()
            .map(|index| files[*index].rel_path.as_str())
            .collect::<Vec<_>>()
            .join(", ");
        panic!("failed to add all composable modules; unresolved or invalid modules: {unresolved}");
    }
}

fn main() {
    let options = parse_options();
    let mut files = Vec::new();
    collect_wgsl_files(&options.fixture_root, &options.fixture_root, &mut files);
    files.sort_by(|lhs, rhs| lhs.rel_path.cmp(&rhs.rel_path));

    let mut composer = Composer::default().with_capabilities(options.capabilities);
    if !options.entry_only {
        add_modules_until_fixed_point(
            &mut composer,
            &files,
            &options.defs,
            &options.additional_imports,
            &options.file_path_prefix,
        );
    }

    let entry = files
        .iter()
        .find(|file| file.rel_path == options.entry)
        .unwrap_or_else(|| panic!("entry `{}` not found under fixture root", options.entry));
    let additional_imports = options
        .additional_imports
        .iter()
        .map(|import| ImportDefinition {
            import: import.clone(),
            ..Default::default()
        })
        .collect::<Vec<_>>();
    let entry_file_path = display_file_path(&options.file_path_prefix, &entry.rel_path);
    let module = composer
        .make_naga_module(NagaModuleDescriptor {
            source: &entry.source,
            file_path: &entry_file_path,
            shader_type: options.shader_type,
            shader_defs: options.defs,
            additional_imports: &additional_imports,
            ..Default::default()
        })
        .unwrap_or_else(|err| {
            let text = err.emit_to_string(&composer);
            if let Some(output) = &options.error_output {
                fs::write(output, &text).unwrap_or_else(|write_err| {
                    panic!(
                        "failed to write error output `{}`: {write_err}",
                        output.display()
                    );
                });
            } else {
                eprint!("{text}");
            }
            std::process::exit(1);
        });
    let mut validator =
        naga::valid::Validator::new(naga::valid::ValidationFlags::all(), options.capabilities);
    let info = validator
        .validate(&module)
        .unwrap_or_else(|err| panic!("naga validation failed for `{}`: {err:?}", entry.rel_path));
    if options.check_only {
        return;
    }
    let wgsl = naga::back::wgsl::write_string(
        &module,
        &info,
        naga::back::wgsl::WriterFlags::EXPLICIT_TYPES,
    )
    .unwrap_or_else(|err| panic!("failed to write oracle WGSL: {err:?}"));
    if let Some(output) = options.output {
        fs::write(&output, wgsl).unwrap_or_else(|err| {
            panic!("failed to write output `{}`: {err}", output.display());
        });
    } else {
        print!("{wgsl}");
    }
}
