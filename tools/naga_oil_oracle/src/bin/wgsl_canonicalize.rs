use std::env;
use std::fs;
use std::path::PathBuf;

use naga_oil_oracle::{add_wgsl_capability, normalize_wgsl_for_naga_parser, WGSL_CAPABILITY_NAMES};

#[derive(Debug)]
struct Options {
    input: PathBuf,
    output: PathBuf,
    capabilities: naga::valid::Capabilities,
}

fn usage() -> ! {
    eprintln!(
        "usage: wgsl_canonicalize [--capability {WGSL_CAPABILITY_NAMES}] --input <file.wgsl> --output <file.wgsl>"
    );
    std::process::exit(2);
}

fn parse_options() -> Options {
    let mut input = None;
    let mut output = None;
    let mut capabilities = naga::valid::Capabilities::default();
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--input" => input = args.next().map(PathBuf::from),
            "--output" => output = args.next().map(PathBuf::from),
            "--capability" => {
                let Some(value) = args.next() else { usage() };
                if !add_wgsl_capability(&mut capabilities, &value) {
                    usage();
                }
            }
            _ => usage(),
        }
    }
    Options {
        input: input.unwrap_or_else(|| usage()),
        output: output.unwrap_or_else(|| usage()),
        capabilities,
    }
}

fn main() {
    let options = parse_options();
    let source = fs::read_to_string(&options.input).unwrap_or_else(|err| {
        panic!("failed to read `{}`: {err}", options.input.display());
    });
    let source = normalize_wgsl_for_naga_parser(&source, options.capabilities);
    let module = naga::front::wgsl::parse_str(&source).unwrap_or_else(|err| {
        panic!(
            "WGSL parse failed for `{}`:\n{err}",
            options.input.display()
        );
    });
    let mut validator =
        naga::valid::Validator::new(naga::valid::ValidationFlags::all(), options.capabilities);
    let info = validator.validate(&module).unwrap_or_else(|err| {
        panic!(
            "WGSL validation failed for `{}`:\n{err:?}",
            options.input.display()
        );
    });
    let canonical =
        naga::back::wgsl::write_string(&module, &info, naga::back::wgsl::WriterFlags::empty())
            .unwrap_or_else(|err| {
                panic!(
                    "WGSL canonicalization failed for `{}`:\n{err}",
                    options.input.display()
                );
            });
    fs::write(&options.output, canonical).unwrap_or_else(|err| {
        panic!("failed to write `{}`: {err}", options.output.display());
    });
}
