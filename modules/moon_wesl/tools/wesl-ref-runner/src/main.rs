use std::borrow::Cow;
use std::collections::HashMap;
use std::io::{self, Read};

use serde::Deserialize;
use serde_json::{Value, json};
use wesl::{
    CompileOptions, Feature, Features, ManglerKind, ModulePath, VirtualResolver, Wesl, eval_str,
    validate_wesl, validate_wgsl,
};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "kebab-case")]
struct Request {
    op: String,
    source: Option<String>,
    root: Option<String>,
    modules: Option<Vec<Module>>,
    options: Option<Options>,
    mangler: Option<String>,
    sourcemap: Option<bool>,
}

#[derive(Clone, Debug, Deserialize)]
struct Module {
    path: String,
    source: String,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(default, rename_all = "kebab-case")]
struct Options {
    imports: bool,
    condcomp: bool,
    generics: bool,
    strip: bool,
    lower: bool,
    validate: bool,
    lazy: bool,
    mangle_root: bool,
    keep: Option<Vec<String>>,
    keep_root: bool,
    feature_default: String,
    features: HashMap<String, String>,
}

impl Default for Options {
    fn default() -> Self {
        let defaults = CompileOptions::default();
        Self {
            imports: defaults.imports,
            condcomp: defaults.condcomp,
            generics: defaults.generics,
            strip: defaults.strip,
            lower: defaults.lower,
            validate: defaults.validate,
            lazy: defaults.lazy,
            mangle_root: defaults.mangle_root,
            keep: defaults.keep,
            keep_root: defaults.keep_root,
            feature_default: "disable".to_string(),
            features: HashMap::new(),
        }
    }
}

impl TryFrom<Options> for CompileOptions {
    type Error = String;

    fn try_from(value: Options) -> Result<Self, Self::Error> {
        let mut flags = HashMap::new();
        for (name, feature) in value.features {
            flags.insert(name, parse_feature(&feature)?);
        }
        Ok(Self {
            imports: value.imports,
            condcomp: value.condcomp,
            generics: value.generics,
            strip: value.strip,
            lower: value.lower,
            validate: value.validate,
            lazy: value.lazy,
            mangle_root: value.mangle_root,
            keep: value.keep,
            keep_root: value.keep_root,
            features: Features {
                default: parse_feature(&value.feature_default)?,
                flags,
            },
        })
    }
}

fn parse_feature(value: &str) -> Result<Feature, String> {
    match value {
        "enable" | "true" => Ok(Feature::Enable),
        "disable" | "false" => Ok(Feature::Disable),
        "keep" => Ok(Feature::Keep),
        "error" => Ok(Feature::Error),
        other => Err(format!(
            "invalid feature value `{other}`, expected enable, disable, keep, or error",
        )),
    }
}

fn parse_mangler(value: Option<&str>) -> Result<ManglerKind, String> {
    match value.unwrap_or("escape") {
        "escape" => Ok(ManglerKind::Escape),
        "hash" => Ok(ManglerKind::Hash),
        "unicode" => Ok(ManglerKind::Unicode),
        "none" => Ok(ManglerKind::None),
        other => Err(format!(
            "invalid mangler `{other}`, expected escape, hash, unicode, or none",
        )),
    }
}

fn request_source(req: &Request) -> Result<&str, String> {
    req.source
        .as_deref()
        .ok_or_else(|| "`source` is required".to_string())
}

fn request_root(req: &Request) -> Result<ModulePath, String> {
    req.root
        .as_deref()
        .unwrap_or("package::main")
        .parse::<ModulePath>()
        .map_err(|e| e.to_string())
}

fn build_virtual_resolver(req: &Request) -> Result<(ModulePath, VirtualResolver<'static>), String> {
    let root = request_root(req)?;
    let mut resolver = VirtualResolver::new();
    for module in req.modules.as_deref().unwrap_or(&[]) {
        let path = module
            .path
            .parse::<ModulePath>()
            .map_err(|e| e.to_string())?;
        resolver.add_module(path, Cow::Owned(module.source.clone()));
    }
    Ok((root, resolver))
}

fn ok(value: Value) -> Value {
    json!({ "status": "ok", "value": value })
}

fn err(stage: &str, error: impl std::fmt::Display) -> Value {
    json!({
        "status": "err",
        "stage": stage,
        "message": error.to_string()
    })
}

fn run(req: Request) -> Value {
    match req.op.as_str() {
        "parse-display" => match request_source(&req) {
            Ok(source) => match source.parse::<wesl::syntax::TranslationUnit>() {
                Ok(unit) => ok(json!({ "source": unit.to_string() })),
                Err(error) => err("parse", error),
            },
            Err(error) => err("request", error),
        },
        "validate-wesl" => match request_source(&req) {
            Ok(source) => match source.parse::<wesl::syntax::TranslationUnit>() {
                Ok(unit) => match validate_wesl(&unit) {
                    Ok(()) => ok(json!({})),
                    Err(error) => err("validate-wesl", error),
                },
                Err(error) => err("parse", error),
            },
            Err(error) => err("request", error),
        },
        "validate-wgsl" => match request_source(&req) {
            Ok(source) => match source.parse::<wesl::syntax::TranslationUnit>() {
                Ok(unit) => match validate_wgsl(&unit) {
                    Ok(()) => ok(json!({})),
                    Err(error) => err("validate-wgsl", error),
                },
                Err(error) => err("parse", error),
            },
            Err(error) => err("request", error),
        },
        "eval-str" => match request_source(&req) {
            Ok(source) => match eval_str(source) {
                Ok(inst) => ok(json!({ "value": inst.to_string() })),
                Err(error) => err("eval", error),
            },
            Err(error) => err("request", error),
        },
        "compile-virtual" => {
            let options = match req.options.clone().unwrap_or_default().try_into() {
                Ok(options) => options,
                Err(error) => return err("request", error),
            };
            let mangler = match parse_mangler(req.mangler.as_deref()) {
                Ok(mangler) => mangler,
                Err(error) => return err("request", error),
            };
            let sourcemap = req.sourcemap.unwrap_or(false);
            let (root, resolver) = match build_virtual_resolver(&req) {
                Ok(value) => value,
                Err(error) => return err("request", error),
            };
            let mut compiler = Wesl::new_barebones();
            compiler
                .set_options(options)
                .use_sourcemap(sourcemap)
                .set_mangler(mangler);
            let compiler = compiler.set_custom_resolver(resolver);
            match compiler.compile(&root) {
                Ok(result) => ok(json!({
                    "source": result.to_string(),
                    "modules": result
                        .modules
                        .iter()
                        .map(ToString::to_string)
                        .collect::<Vec<_>>(),
                    "has_sourcemap": result.sourcemap.is_some(),
                })),
                Err(error) => err("compile", error),
            }
        }
        "compile-eval-virtual" => {
            let eval_source = match request_source(&req) {
                Ok(source) => source,
                Err(error) => return err("request", error),
            };
            let options = match req.options.clone().unwrap_or_default().try_into() {
                Ok(options) => options,
                Err(error) => return err("request", error),
            };
            let mangler = match parse_mangler(req.mangler.as_deref()) {
                Ok(mangler) => mangler,
                Err(error) => return err("request", error),
            };
            let sourcemap = req.sourcemap.unwrap_or(false);
            let (root, resolver) = match build_virtual_resolver(&req) {
                Ok(value) => value,
                Err(error) => return err("request", error),
            };
            let mut compiler = Wesl::new_barebones();
            compiler
                .set_options(options)
                .use_sourcemap(sourcemap)
                .set_mangler(mangler);
            let compiler = compiler.set_custom_resolver(resolver);
            match compiler.compile(&root) {
                Ok(result) => match result.eval(eval_source) {
                    Ok(value) => ok(json!({ "value": value.to_string() })),
                    Err(error) => err("eval", error),
                },
                Err(error) => err("compile", error),
            }
        }
        other => err("request", format!("unknown op `{other}`")),
    }
}

fn main() {
    let mut input = String::new();
    io::stdin()
        .read_to_string(&mut input)
        .expect("failed to read stdin");
    let response = match serde_json::from_str::<Request>(&input) {
        Ok(request) => run(request),
        Err(error) => err("request", error),
    };
    println!("{}", serde_json::to_string_pretty(&response).unwrap());
}
