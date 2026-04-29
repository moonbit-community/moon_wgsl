use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use naga_oil::compose::{
    ComposableModuleDescriptor, Composer, ImportDefinition, NagaModuleDescriptor, ShaderDefValue,
};

#[derive(Debug)]
struct Options {
    fixture_root: PathBuf,
    entry: String,
    output: Option<PathBuf>,
    defs: HashMap<String, ShaderDefValue>,
    additional_imports: Vec<String>,
    capabilities: naga::valid::Capabilities,
    check_only: bool,
}

#[derive(Debug)]
struct WgslFile {
    rel_path: String,
    source: String,
}

fn usage() -> ! {
    eprintln!(
        "usage: naga_oil_oracle --fixture-root <dir> --entry <rel.wgsl> [--def NAME=true|false|INT] [--additional-import MODULE] [--capability ray-query] [--check-only] [--output <file>]"
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

fn parse_options() -> Options {
    let mut fixture_root = None;
    let mut entry = None;
    let mut output = None;
    let mut defs = HashMap::new();
    let mut additional_imports = Vec::new();
    let mut capabilities = naga::valid::Capabilities::default();
    let mut check_only = false;
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--fixture-root" => fixture_root = args.next().map(PathBuf::from),
            "--entry" => entry = args.next(),
            "--output" => output = args.next().map(PathBuf::from),
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
            "--check-only" => check_only = true,
            _ => usage(),
        }
    }
    Options {
        fixture_root: fixture_root.unwrap_or_else(|| usage()),
        entry: entry.unwrap_or_else(|| usage()),
        output,
        defs,
        additional_imports,
        capabilities,
        check_only,
    }
}

fn normalize_rel_path(path: &Path) -> String {
    path.to_string_lossy().replace('\\', "/")
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
        if path.extension().and_then(|ext| ext.to_str()) != Some("wgsl") {
            continue;
        }
        let source = fs::read_to_string(&path).unwrap_or_else(|err| {
            panic!("failed to read WGSL file `{}`: {err}", path.display());
        });
        let rel_path = normalize_rel_path(path.strip_prefix(root).unwrap_or(&path));
        files.push(WgslFile { rel_path, source });
    }
}

fn has_import_path(source: &str) -> bool {
    source
        .lines()
        .any(|line| line.trim_start().starts_with("#define_import_path "))
}

fn inferred_module_path(rel_path: &str) -> Option<String> {
    let without_ext = rel_path.strip_suffix(".wgsl")?;
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
            let as_name = if has_import_path(&file.source) {
                None
            } else {
                inferred_module_path(&file.rel_path)
            };
            let result = composer.add_composable_module(ComposableModuleDescriptor {
                source: &file.source,
                file_path: &file.rel_path,
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
    add_modules_until_fixed_point(
        &mut composer,
        &files,
        &options.defs,
        &options.additional_imports,
    );

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
    let module = composer
        .make_naga_module(NagaModuleDescriptor {
            source: &entry.source,
            file_path: &entry.rel_path,
            shader_defs: options.defs,
            additional_imports: &additional_imports,
            ..Default::default()
        })
        .unwrap_or_else(|err| panic!("naga_oil failed to compose `{}`: {err:?}", entry.rel_path));
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
