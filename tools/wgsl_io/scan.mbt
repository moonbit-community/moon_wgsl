///|
pub(all) struct WgslSourceScanOptions {
  recursive : Bool
  extensions : Array[String]
  exclude_prefixes : Array[String]
} derive(Eq, Debug)

///|
pub fn WgslSourceScanOptions::default() -> WgslSourceScanOptions {
  { recursive: true, extensions: [".wgsl"], exclude_prefixes: [] }
}

///|
fn normalize_scan_path(path : String) -> String {
  let trimmed = path.trim().to_owned()
  if trimmed == "" {
    return ""
  }
  let parts : Array[String] = []
  let mut start = 0
  for i in 0..<trimmed.length() {
    if trimmed.code_unit_at(i).to_int() == 92 {
      parts.push(trimmed[start:i].to_owned())
      start = i + 1
    }
  }
  parts.push(trimmed[start:trimmed.length()].to_owned())
  parts.join("/")
}

///|
fn join_scan_path(prefix : String, path : String) -> String {
  let lhs = normalize_scan_path(prefix)
  let rhs = normalize_scan_path(path)
  if lhs == "" {
    return rhs
  }
  if rhs == "" {
    return lhs
  }
  "\{lhs}/\{rhs}"
}

///|
fn normalize_scan_extensions(extensions : Array[String]) -> Array[String] {
  let normalized : Array[String] = []
  for extension in extensions {
    let trimmed = extension.trim().to_owned()
    if trimmed == "" {
      continue
    }
    normalized.push(
      if trimmed.has_prefix(".") {
        trimmed
      } else {
        ".\{trimmed}"
      },
    )
  }
  normalized
}

///|
fn scan_path_is_excluded(
  rel_path : String,
  exclude_prefixes : Array[String],
) -> Bool {
  let normalized_rel_path = @resolver.normalize_shader_rel_path(rel_path)
  for prefix in exclude_prefixes {
    let normalized_prefix = @resolver.normalize_shader_rel_path(
      normalize_scan_path(prefix),
    )
    if normalized_prefix != "" &&
      (
        normalized_rel_path == normalized_prefix ||
        normalized_rel_path.has_prefix("\{normalized_prefix}/")
      ) {
      return true
    }
  }
  false
}

///|
fn scan_path_matches_extension(
  rel_path : String,
  extensions : Array[String],
) -> Bool {
  if extensions.length() == 0 {
    return true
  }
  for extension in extensions {
    if rel_path.has_suffix(extension) {
      return true
    }
  }
  false
}

///|
fn collect_source_files(
  fs_path : String,
  rel_prefix : String,
  options : WgslSourceScanOptions,
  normalized_extensions : Array[String],
  out : Array[@contract.WgslSourceFile],
) -> Unit raise @fs.IOError {
  let entries = @fs.read_dir(fs_path)
  entries.sort()
  for entry_name in entries {
    let entry_rel_path = if rel_prefix == "" {
      normalize_scan_path(entry_name)
    } else {
      join_scan_path(rel_prefix, entry_name)
    }
    if scan_path_is_excluded(entry_rel_path, options.exclude_prefixes) {
      continue
    }
    let entry_fs_path = join_scan_path(fs_path, entry_name)
    if @fs.is_dir(entry_fs_path) {
      if options.recursive {
        collect_source_files(
          entry_fs_path, entry_rel_path, options, normalized_extensions, out,
        )
      }
      continue
    }
    if !@fs.is_file(entry_fs_path) ||
      !scan_path_matches_extension(
        @resolver.normalize_shader_rel_path(entry_rel_path),
        normalized_extensions,
      ) {
      continue
    }
    out.push({
      rel_path: @resolver.normalize_shader_rel_path(entry_rel_path),
      source: @fs.read_file_to_string(entry_fs_path),
    })
  }
}

///|
pub fn scan_wgsl_source_files(
  root : String,
  options : WgslSourceScanOptions,
) -> Array[@contract.WgslSourceFile] raise @fs.IOError {
  let normalized_root = normalize_scan_path(root)
  let scan_root = if normalized_root == "" { "." } else { normalized_root }
  let files : Array[@contract.WgslSourceFile] = []
  collect_source_files(
    scan_root,
    "",
    options,
    normalize_scan_extensions(options.extensions),
    files,
  )
  files
}

///|
pub fn scan_wgsl_source_files_checked(
  root : String,
  options : WgslSourceScanOptions,
) -> (Array[@contract.WgslSourceFile], Array[@contract.WgslDiagnostic]) raise @fs.IOError {
  let files = scan_wgsl_source_files(root, options)
  (files, @resolver.WgslSourceRegistry::default().analyze_source_files(files))
}

///|
pub fn register_source_tree(
  composer : @compose.Composer,
  root : String,
  options : WgslSourceScanOptions,
) -> Unit raise @fs.IOError {
  composer.register_source_files(scan_wgsl_source_files(root, options))
}

///|
pub fn register_source_tree_checked(
  composer : @compose.Composer,
  root : String,
  options : WgslSourceScanOptions,
) -> Array[@contract.WgslDiagnostic] raise @fs.IOError {
  composer.register_source_files_checked(scan_wgsl_source_files(root, options))
}
