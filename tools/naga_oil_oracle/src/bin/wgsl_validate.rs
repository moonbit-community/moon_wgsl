use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Debug)]
struct Options {
    files: Vec<PathBuf>,
    capabilities: naga::valid::Capabilities,
}

fn usage() -> ! {
    eprintln!(
        "usage: wgsl_validate [--capability ray-query|dual-source-blending|texture-external|texture-atomic|f16|subgroups|immediates|binding-arrays] <file.wgsl>..."
    );
    std::process::exit(2);
}

fn parse_options() -> Options {
    let mut files = Vec::new();
    let mut capabilities = naga::valid::Capabilities::default();
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--capability" => {
                let Some(value) = args.next() else { usage() };
                match value.as_str() {
                    "ray-query" => capabilities |= naga::valid::Capabilities::RAY_QUERY,
                    "dual-source-blending" => {
                        capabilities |= naga::valid::Capabilities::DUAL_SOURCE_BLENDING
                    }
                    "texture-external" => {
                        capabilities |= naga::valid::Capabilities::TEXTURE_EXTERNAL
                    }
                    "texture-atomic" => {
                        capabilities |= naga::valid::Capabilities::TEXTURE_ATOMIC
                    }
                    "f16" => capabilities |= naga::valid::Capabilities::SHADER_FLOAT16,
                    "subgroups" => capabilities |= naga::valid::Capabilities::SUBGROUP,
                    "immediates" => capabilities |= naga::valid::Capabilities::IMMEDIATES,
                    "binding-arrays" => {
                        capabilities |=
                            naga::valid::Capabilities::TEXTURE_AND_SAMPLER_BINDING_ARRAY;
                        capabilities |= naga::valid::Capabilities::TEXTURE_AND_SAMPLER_BINDING_ARRAY_NON_UNIFORM_INDEXING;
                    }
                    _ => usage(),
                }
            }
            _ if arg.starts_with('-') => usage(),
            _ => files.push(PathBuf::from(arg)),
        }
    }
    if files.is_empty() {
        usage();
    }
    Options {
        files,
        capabilities,
    }
}

fn validate_file(path: &PathBuf, capabilities: naga::valid::Capabilities) -> Result<(), String> {
    let source = fs::read_to_string(path)
        .map_err(|err| format!("failed to read `{}`: {err}", path.display()))?;
    let module = naga::front::wgsl::parse_str(&source)
        .map_err(|err| format!("WGSL parse failed for `{}`:\n{err}", path.display()))?;
    let mut validator =
        naga::valid::Validator::new(naga::valid::ValidationFlags::all(), capabilities);
    validator
        .validate(&module)
        .map_err(|err| format!("WGSL validation failed for `{}`:\n{err:?}", path.display()))?;
    Ok(())
}

fn main() {
    let options = parse_options();
    let mut failed = false;
    for file in &options.files {
        match validate_file(file, options.capabilities) {
            Ok(()) => println!("validated {}", file.display()),
            Err(message) => {
                eprintln!("{message}");
                failed = true;
            }
        }
    }
    if failed {
        std::process::exit(1);
    }
}
