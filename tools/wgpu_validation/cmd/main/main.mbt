///|
priv struct WgpuValidationArgs {
  mut input : String?
  mut mode : String
  mut compute_entry : String
  mut vertex_entry : String
  mut fragment_entry : String
}

///|
fn WgpuValidationArgs::WgpuValidationArgs() -> WgpuValidationArgs {
  {
    input: None,
    mode: "shader-module",
    compute_entry: "main",
    vertex_entry: "vs_main",
    fragment_entry: "fs_main",
  }
}

///|
fn usage() -> String {
  "usage: tools/wgpu_validation/_build/native/debug/build/cmd/main/main.exe --input FILE [--mode shader-module|compute|compute-storage-read|render-rgba8] [--compute-entry NAME] [--vertex-entry NAME] [--fragment-entry NAME]"
}

///|
fn[T] fail(message : String) -> T {
  println(message)
  @sys.exit(1)
  abort(message)
}

///|
fn parse_args() -> WgpuValidationArgs {
  let args = @env.args()
  let parsed = WgpuValidationArgs()
  let mut index = 1
  while index < args.length() {
    match args[index] {
      "--input" => {
        guard index + 1 < args.length() else { fail(usage()) }
        parsed.input = Some(args[index + 1])
        index = index + 2
      }
      "--mode" => {
        guard index + 1 < args.length() else { fail(usage()) }
        parsed.mode = args[index + 1]
        index = index + 2
      }
      "--compute-entry" => {
        guard index + 1 < args.length() else { fail(usage()) }
        parsed.compute_entry = args[index + 1]
        index = index + 2
      }
      "--vertex-entry" => {
        guard index + 1 < args.length() else { fail(usage()) }
        parsed.vertex_entry = args[index + 1]
        index = index + 2
      }
      "--fragment-entry" => {
        guard index + 1 < args.length() else { fail(usage()) }
        parsed.fragment_entry = args[index + 1]
        index = index + 2
      }
      "--help" | "-h" => fail(usage())
      _ => fail(usage())
    }
  }
  parsed
}

///|
fn read_input(args : WgpuValidationArgs) -> String {
  let input = match args.input {
    Some(value) => value
    None => fail(usage())
  }
  @fs.read_file_to_string(input) catch {
    _ => fail("failed to read input WGSL: \{input}")
  }
}

///|
fn error_scope_message(label : String, message : String) -> String {
  if message == "" {
    "\{label} failed wgpu validation"
  } else {
    "\{label} failed wgpu validation: \{message}"
  }
}

///|
fn expect_no_validation_error(
  device : @wgpu.Device,
  instance : @wgpu.Instance,
  label : String,
) -> Unit {
  let result = device.pop_error_scope_sync_result(instance)
  if result.error_type != @wgpu.ERROR_TYPE_NO_ERROR {
    fail(error_scope_message(label, result.message))
  }
}

///|
fn validate_compilation_info(
  shader : @wgpu.ShaderModule,
  instance : @wgpu.Instance,
) -> Unit {
  let info = shader.get_compilation_info_sync(instance)
  if info.status_u32 != 0U &&
    info.status_u32 != @wgpu.COMPILATION_INFO_REQUEST_STATUS_SUCCESS {
    fail(
      "shader compilation info request failed with status \{info.status_u32}",
    )
  }
  for message in info.messages {
    if message.type_u32 == @wgpu.COMPILATION_MESSAGE_TYPE_ERROR {
      fail("shader compilation error: \{message.text}")
    }
  }
}

///|
fn create_shader_module_checked(
  device : @wgpu.Device,
  instance : @wgpu.Instance,
  source : String,
) -> @wgpu.ShaderModule {
  device.push_error_scope(@wgpu.ERROR_FILTER_VALIDATION)
  let shader = device.create_shader_module_wgsl(source)
  expect_no_validation_error(device, instance, "shader module creation")
  validate_compilation_info(shader, instance)
  shader
}

///|
fn create_compute_pipeline_checked(
  device : @wgpu.Device,
  instance : @wgpu.Instance,
  shader : @wgpu.ShaderModule,
  entry : String,
) -> @wgpu.ComputePipeline {
  device.push_error_scope(@wgpu.ERROR_FILTER_VALIDATION)
  let pipeline = device.create_compute_pipeline_entry(shader, entry) catch {
    error =>
      fail("failed to build compute pipeline descriptor: \{error.message()}")
  }
  expect_no_validation_error(device, instance, "compute pipeline creation")
  pipeline
}

///|
fn create_storage_read_pipeline_checked(
  device : @wgpu.Device,
  instance : @wgpu.Instance,
  shader : @wgpu.ShaderModule,
  entry : String,
) -> @wgpu.ComputePipeline {
  let bglb = @wgpu.BindGroupLayoutBuilder::new(max_entries=2UL)
  let read_only_binding_type = device.get_supported_read_only_binding_type_u32(
    1U,
  )
  let stage = @wgpu.ShaderStage::from_u64(@wgpu.SHADER_STAGE_COMPUTE)
  guard bglb.add_buffer(0U, stage, read_only_binding_type) else {
    bglb.free()
    fail("failed to add read-only storage binding layout entry")
  }
  guard bglb.add_buffer(1U, stage, @wgpu.BUFFER_BINDING_TYPE_STORAGE) else {
    bglb.free()
    fail("failed to add writable storage binding layout entry")
  }
  let bgl = bglb.finish(device)
  let layout = device.create_pipeline_layout_1(bgl)
  device.push_error_scope(@wgpu.ERROR_FILTER_VALIDATION)
  let pipeline = device.create_compute_pipeline_with_layout_entry(
    layout, shader, entry,
  ) catch {
    error => {
      layout.release()
      bgl.release()
      fail(
        "failed to build storage-read compute pipeline descriptor: \{error.message()}",
      )
    }
  }
  expect_no_validation_error(
    device, instance, "storage-read compute pipeline creation",
  )
  layout.release()
  bgl.release()
  pipeline
}

///|
fn create_render_pipeline_checked(
  device : @wgpu.Device,
  instance : @wgpu.Instance,
  shader : @wgpu.ShaderModule,
  vertex_entry : String,
  fragment_entry : String,
) -> @wgpu.RenderPipeline {
  let builder = @wgpu.RenderPipelineDescBuilder::new(shader) catch {
    error =>
      fail("failed to allocate render pipeline descriptor: \{error.message()}")
  }
  builder.set_entry_points(vertex_entry, fragment_entry) catch {
    error => {
      builder.free()
      fail("failed to set render entry points: \{error.message()}")
    }
  }
  builder.set_color_target_format(
    @wgpu.TextureFormat::from_u32(@wgpu.TEXTURE_FORMAT_RGBA8_UNORM),
  ) catch {
    error => {
      builder.free()
      fail("failed to set render target format: \{error.message()}")
    }
  }
  device.push_error_scope(@wgpu.ERROR_FILTER_VALIDATION)
  let pipeline = builder.create_pipeline(device) catch {
    error => {
      builder.free()
      fail("failed to build render pipeline descriptor: \{error.message()}")
    }
  }
  builder.free()
  expect_no_validation_error(device, instance, "render pipeline creation")
  pipeline
}

///|
fn validate_wgsl_with_wgpu(source : String, args : WgpuValidationArgs) -> Unit {
  let instance = @wgpu.Instance::create() catch {
    error => fail("failed to create wgpu instance: \{error.message()}")
  }
  let adapter = instance.request_adapter_sync() catch {
    error => {
      instance.release()
      fail("failed to request wgpu adapter: \{error.message()}")
    }
  }
  let device = adapter.request_device_sync(instance) catch {
    error => {
      adapter.release()
      instance.release()
      fail("failed to request wgpu device: \{error.message()}")
    }
  }
  let shader = create_shader_module_checked(device, instance, source)
  match args.mode {
    "shader-module" => ()
    "compute" => {
      let pipeline = create_compute_pipeline_checked(
        device,
        instance,
        shader,
        args.compute_entry,
      )
      pipeline.release()
    }
    "compute-storage-read" => {
      let pipeline = create_storage_read_pipeline_checked(
        device,
        instance,
        shader,
        args.compute_entry,
      )
      pipeline.release()
    }
    "render-rgba8" => {
      let pipeline = create_render_pipeline_checked(
        device,
        instance,
        shader,
        args.vertex_entry,
        args.fragment_entry,
      )
      pipeline.release()
    }
    _ => fail(usage())
  }
  shader.release()
  device.release()
  adapter.release()
  instance.release()
}

///|
fn main {
  let args = parse_args()
  let source = read_input(args)
  validate_wgsl_with_wgpu(source, args)
  println("wgpu validation passed")
}
