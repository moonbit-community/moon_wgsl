///|
fn ir_roundtrip_usage() -> String {
  "usage: moon run tools/ir_roundtrip -- --input FILE [--output FILE] [--mode parse|ir]"
}

///|
priv struct IrRoundtripArgs {
  mut input : String?
  mut output : String?
  mut mode : String
}

///|
fn IrRoundtripArgs::new() -> IrRoundtripArgs {
  { input: None, output: None, mode: "ir" }
}

///|
fn parse_ir_roundtrip_args() -> IrRoundtripArgs {
  let args = @env.args()
  let parsed = IrRoundtripArgs::new()
  let mut index = 1
  while index < args.length() {
    match args[index] {
      "--input" => {
        guard index + 1 < args.length() else { abort(ir_roundtrip_usage()) }
        parsed.input = Some(args[index + 1])
        index = index + 2
      }
      "--output" => {
        guard index + 1 < args.length() else { abort(ir_roundtrip_usage()) }
        parsed.output = Some(args[index + 1])
        index = index + 2
      }
      "--mode" => {
        guard index + 1 < args.length() else { abort(ir_roundtrip_usage()) }
        parsed.mode = args[index + 1]
        index = index + 2
      }
      _ => abort(ir_roundtrip_usage())
    }
  }
  parsed
}

///|
fn main {
  let args = parse_ir_roundtrip_args()
  let input = match args.input {
    Some(value) => value
    None => abort(ir_roundtrip_usage())
  }
  let source = @fs.read_file_to_string(input) catch {
    _ => abort("failed to read input")
  }
  if args.mode == "parse" {
    ignore(@parser.parse_wgsl_translation_unit_strict(source)) catch {
      error => abort(error.message())
    }
    match args.output {
      Some(path) =>
        @fs.write_string_to_file(path, source) catch {
          _ => abort("failed to write output")
        }
      None => println(source)
    }
    return
  }
  guard args.mode == "ir" else { abort(ir_roundtrip_usage()) }
  let module_ = @ir.parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = @ir.emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  match args.output {
    Some(path) =>
      @fs.write_string_to_file(path, emitted) catch {
        _ => abort("failed to write output")
      }
    None => println(emitted)
  }
}
