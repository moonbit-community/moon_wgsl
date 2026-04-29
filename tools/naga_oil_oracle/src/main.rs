use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use naga_oil::compose::{
    ComposableModuleDescriptor, Composer, NagaModuleDescriptor, ShaderDefValue,
};

#[derive(Debug)]
struct Options {
    fixture_root: PathBuf,
    entry: String,
    output: Option<PathBuf>,
    defs: HashMap<String, ShaderDefValue>,
}

#[derive(Debug)]
struct WgslFile {
    rel_path: String,
    source: String,
}

fn usage() -> ! {
    eprintln!(
        "usage: naga_oil_oracle --fixture-root <dir> --entry <rel.wgsl> [--def NAME=true|false|INT] [--output <file>]"
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
            _ => usage(),
        }
    }
    Options {
        fixture_root: fixture_root.unwrap_or_else(|| usage()),
        entry: entry.unwrap_or_else(|| usage()),
        output,
        defs,
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

fn add_modules_until_fixed_point(
    composer: &mut Composer,
    files: &[WgslFile],
    defs: &HashMap<String, ShaderDefValue>,
) {
    let mut pending: Vec<usize> = files
        .iter()
        .enumerate()
        .filter_map(|(index, file)| has_import_path(&file.source).then_some(index))
        .collect();
    let mut made_progress = true;
    while made_progress && !pending.is_empty() {
        made_progress = false;
        let mut still_pending = Vec::new();
        for index in pending {
            let file = &files[index];
            let result = composer.add_composable_module(ComposableModuleDescriptor {
                source: &file.source,
                file_path: &file.rel_path,
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

    let mut composer = Composer::default();
    add_modules_until_fixed_point(&mut composer, &files, &options.defs);

    let entry = files
        .iter()
        .find(|file| file.rel_path == options.entry)
        .unwrap_or_else(|| panic!("entry `{}` not found under fixture root", options.entry));
    let module = composer
        .make_naga_module(NagaModuleDescriptor {
            source: &entry.source,
            file_path: &entry.rel_path,
            shader_defs: options.defs,
            ..Default::default()
        })
        .unwrap_or_else(|err| panic!("naga_oil failed to compose `{}`: {err:?}", entry.rel_path));
    let mut validator = naga::valid::Validator::new(
        naga::valid::ValidationFlags::all(),
        naga::valid::Capabilities::default(),
    );
    let info = validator
        .validate(&module)
        .unwrap_or_else(|err| panic!("naga validation failed for `{}`: {err:?}", entry.rel_path));
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
