use std::env;
use std::fs;
use std::path::PathBuf;

use naga_oil_oracle::{add_wgsl_capability, WGSL_CAPABILITY_NAMES};

#[derive(Debug)]
struct Options {
    files: Vec<PathBuf>,
    capabilities: naga::valid::Capabilities,
}

fn usage() -> ! {
    eprintln!("usage: wgsl_validate [--capability {WGSL_CAPABILITY_NAMES}] <file.wgsl>...");
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
                if !add_wgsl_capability(&mut capabilities, &value) {
                    usage();
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
