// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn empty_shader_defs() -> @hashmap.HashMap[String, @common.ShaderDefValue] {
  @hashmap.HashMap::new()
}

///|
fn bool_shader_def(
  name : String,
  value : Bool,
) -> @hashmap.HashMap[String, @common.ShaderDefValue] {
  let shader_defs = empty_shader_defs()
  shader_defs.set(name, @common.ShaderDefValue::Bool(value))
  shader_defs
}

///|
fn int_shader_def(
  name : String,
  value : Int,
) -> @hashmap.HashMap[String, @common.ShaderDefValue] {
  let shader_defs = empty_shader_defs()
  shader_defs.set(name, @common.ShaderDefValue::Int(value))
  shader_defs
}

///|
fn preprocess_without_ascii_whitespace(
  source : String,
  shader_defs : @hashmap.HashMap[String, @common.ShaderDefValue],
) -> String {
  let output = @preprocess.Preprocessor::default().preprocess(
    source, shader_defs,
  ) catch {
    _ => abort("expected preprocess success")
  }
  let mut normalized = ""
  for i in 0..<output.preprocessed_source.length() {
    let code = output.preprocessed_source.code_unit_at(i).to_int()
    if code != 9 && code != 10 && code != 13 && code != 32 {
      normalized = normalized + output.preprocessed_source[i:i + 1].to_owned()
    }
  }
  normalized
}

///|
fn metadata_or_abort(source : String) -> @common.PreprocessorMetaData {
  @metadata.get_preprocessor_metadata(source) catch {
    _ => abort("expected metadata parse success")
  }
}

///|
fn metadata_imports_or_abort(
  source : String,
) -> Array[@common.ImportDefinition] {
  let metadata = metadata_or_abort(source)
  let imports : Array[@common.ImportDefinition] = []
  for import_with_offset in metadata.imports {
    imports.push(import_with_offset.definition)
  }
  imports
}

///|
fn upstream_compose_fixture_source(
  case_name : String,
  rel_path : String,
) -> String {
  let files = @resolver.scan_wgsl_source_files(
    "testdata/naga_oil_upstream/compose_tests/\{case_name}",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected upstream compose fixture scan success")
  }
  for file in files {
    if file.rel_path == rel_path {
      return file.source
    }
  }
  abort("expected upstream compose fixture source \{case_name}/\{rel_path}")
}

///|
test "naga_oil: metadata parser records only used imports like upstream" {
  let metadata = metadata_or_abort(
    "#define_import_path bevy_ui::ui_node\n#define HDR\n#define TONEMAP_MODE 2u\n#import bevy_render::{\n  view::View,\n  globals::Globals,\n}\n#import bevy_render::maths as maths\nfn main(view: View, globals: Globals) -> f32 {\n  return maths::tone_map(1.0);\n}\n",
  )
  debug_inspect(metadata.name, content="Some(\"bevy_ui::ui_node\")")
  debug_inspect(metadata.imports.length(), content="3")
  debug_inspect(
    metadata.imports[0].definition.import_path,
    content="\"bevy_render::view\"",
  )
  debug_inspect(metadata.imports[0].definition.items[0], content="\"View\"")
  debug_inspect(
    metadata.imports[1].definition.import_path,
    content="\"bevy_render::globals\"",
  )
  debug_inspect(metadata.imports[1].definition.items[0], content="\"Globals\"")
  debug_inspect(
    metadata.imports[2].definition.import_path,
    content="\"bevy_render::maths\"",
  )
  debug_inspect(metadata.imports[2].definition.items[0], content="\"tone_map\"")
  debug_inspect(metadata.cleaned_source.contains("#import"), content="true")
  debug_inspect(
    metadata.cleaned_source.contains("fn main(view: View"),
    content="true",
  )
  debug_inspect(metadata.effective_defs.contains("HDR"), content="false")
  debug_inspect(metadata.wgsl_directives.is_empty(), content="true")

  guard metadata.defines.get("HDR")
    is Some(@common.ShaderDefValue::Bool(enabled)) else {
    abort("expected HDR define")
  }
  debug_inspect(enabled, content="true")

  guard metadata.defines.get("TONEMAP_MODE")
    is Some(@common.ShaderDefValue::Bool(mode)) else {
    abort("expected TONEMAP_MODE define")
  }
  debug_inspect(mode, content="false")
}

///|
test "naga_oil: metadata parser keeps quoted path imports and duplicate item uses" {
  let imports = metadata_imports_or_abort(
    "#import \"shaders/skills/shared.wgsl\" Vertex, VertexOutput\nfn vertex(vertex: Vertex) -> VertexOutput {\n  var out : VertexOutput;\n  return out;\n}\n",
  )
  debug_inspect(imports.length(), content="1")
  debug_inspect(
    imports[0].import_path,
    content="\"\\\"shaders/skills/shared.wgsl\\\"\"",
  )
  debug_inspect(imports[0].items.length(), content="3")
  debug_inspect(imports[0].items[0], content="\"Vertex\"")
  debug_inspect(imports[0].items[1], content="\"VertexOutput\"")
  debug_inspect(imports[0].items[2], content="\"VertexOutput\"")
}

///|
test "naga_oil: multiline import brace counting includes quoted braces" {
  let _ = @preprocess.Preprocessor::default().preprocess(
    "#import demo::{\n  \"quoted}\" as quoted,\n  item,\n}\nfn shade() {}\n",
    empty_shader_defs(),
  ) catch {
    @preprocess.PreprocessError::ImportParseError(_, _) => return
    _ => abort("expected import parse error")
  }
  abort("expected import parse error")
}

///|
test "naga_oil: metadata parser preserves wgsl directives and effective defs" {
  let metadata = metadata_or_abort(
    "enable f16, subgroups;\nrequires readonly_and_readwrite_storage_textures;\ndiagnostic(warn, derivative_uniformity);\nfn shade() -> f32 {\n  return #EXPOSURE + #{WHITE_POINT};\n}\n",
  )
  debug_inspect(metadata.wgsl_directives.is_empty(), content="false")
  debug_inspect(
    metadata.wgsl_directives.to_wgsl_string().contains("enable f16, subgroups;"),
    content="true",
  )
  debug_inspect(
    metadata.wgsl_directives
    .to_wgsl_string()
    .contains("requires readonly_and_readwrite_storage_textures;"),
    content="true",
  )
  debug_inspect(
    metadata.wgsl_directives
    .to_wgsl_string()
    .contains("diagnostic(warn, derivative_uniformity);"),
    content="true",
  )
  debug_inspect(metadata.effective_defs.contains("EXPOSURE"), content="true")
  debug_inspect(metadata.effective_defs.contains("WHITE_POINT"), content="true")
}

///|
test "naga_oil: metadata parser matches upstream bevy path import usage shape" {
  let imports = metadata_imports_or_abort(
    "#import \"shaders/skills/shared.wgsl\" Vertex, VertexOutput\n\n#if EFFECT_ID == 0\n    #import \"shaders/skills/sound.wgsl\" frag, vert\n#else if EFFECT_ID == 1\n    #import \"shaders/skills/orb.wgsl\" frag, vert\n#else if EFFECT_ID == 2\n    #import \"shaders/skills/slash.wgsl\" frag, vert\n#else if EFFECT_ID == 3\n    #import \"shaders/skills/railgun_trail.wgsl\" frag, vert\n#else if EFFECT_ID == 4\n    #import \"shaders/skills/magic_arrow.wgsl\" frag, vert\n#else if EFFECT_ID == 5\n    #import \"shaders/skills/hit.wgsl\" frag, vert\n#else if EFFECT_ID == 6\n    #import \"shaders/skills/lightning_ring.wgsl\" frag, vert\n#else if EFFECT_ID == 7\n    #import \"shaders/skills/lightning.wgsl\" frag, vert\n#endif\n\n#import something_unused\n\n@fragment\nfn fragment(in: VertexOutput) -> @location(0) vec4<f32> {\n    return frag(in);\n}\n\n@vertex\nfn vertex(vertex: Vertex) -> VertexOutput {\n    return vert(vertex);\n}\n",
  )
  debug_inspect(imports.length(), content="9")
  debug_inspect(
    imports[0].import_path,
    content="\"\\\"shaders/skills/shared.wgsl\\\"\"",
  )
  debug_inspect(imports[0].items.length(), content="3")
  debug_inspect(
    imports[1].import_path,
    content="\"\\\"shaders/skills/sound.wgsl\\\"\"",
  )
  debug_inspect(
    imports[2].import_path,
    content="\"\\\"shaders/skills/orb.wgsl\\\"\"",
  )
  debug_inspect(
    imports[3].import_path,
    content="\"\\\"shaders/skills/slash.wgsl\\\"\"",
  )
  debug_inspect(
    imports[4].import_path,
    content="\"\\\"shaders/skills/railgun_trail.wgsl\\\"\"",
  )
  debug_inspect(
    imports[5].import_path,
    content="\"\\\"shaders/skills/magic_arrow.wgsl\\\"\"",
  )
  debug_inspect(
    imports[6].import_path,
    content="\"\\\"shaders/skills/hit.wgsl\\\"\"",
  )
  debug_inspect(
    imports[7].import_path,
    content="\"\\\"shaders/skills/lightning_ring.wgsl\\\"\"",
  )
  debug_inspect(
    imports[8].import_path,
    content="\"\\\"shaders/skills/lightning.wgsl\\\"\"",
  )
}

///|
test "naga_oil upstream mirror: metadata parser matches bevy path import fixture" {
  let imports = metadata_imports_or_abort(
    upstream_compose_fixture_source("bevy_path_imports", "skill.wgsl"),
  )
  debug_inspect(imports.length(), content="9")
  debug_inspect(
    imports[0].import_path,
    content="\"\\\"shaders/skills/shared.wgsl\\\"\"",
  )
  debug_inspect(imports[0].items.length(), content="3")
  debug_inspect(imports[0].items[0], content="\"VertexOutput\"")
  debug_inspect(imports[0].items[1], content="\"Vertex\"")
  debug_inspect(imports[0].items[2], content="\"VertexOutput\"")
  debug_inspect(
    imports[1].import_path,
    content="\"\\\"shaders/skills/sound.wgsl\\\"\"",
  )
  debug_inspect(
    imports[2].import_path,
    content="\"\\\"shaders/skills/orb.wgsl\\\"\"",
  )
  debug_inspect(
    imports[3].import_path,
    content="\"\\\"shaders/skills/slash.wgsl\\\"\"",
  )
  debug_inspect(
    imports[4].import_path,
    content="\"\\\"shaders/skills/railgun_trail.wgsl\\\"\"",
  )
  debug_inspect(
    imports[5].import_path,
    content="\"\\\"shaders/skills/magic_arrow.wgsl\\\"\"",
  )
  debug_inspect(
    imports[6].import_path,
    content="\"\\\"shaders/skills/hit.wgsl\\\"\"",
  )
  debug_inspect(
    imports[7].import_path,
    content="\"\\\"shaders/skills/lightning_ring.wgsl\\\"\"",
  )
  debug_inspect(
    imports[8].import_path,
    content="\"\\\"shaders/skills/lightning.wgsl\\\"\"",
  )
}

///|
test "naga_oil: preprocess strips imports and records used import offsets" {
  let output = @preprocess.Preprocessor::default().preprocess(
    "#import bevy_render::view::View\nfn main(view: View) -> View {\n  return view;\n}\n",
    empty_shader_defs(),
  ) catch {
    _ => abort("expected preprocess success")
  }
  debug_inspect(output.imports.length(), content="1")
  debug_inspect(
    output.imports[0].definition.import_path,
    content="\"bevy_render::view\"",
  )
  debug_inspect(output.imports[0].definition.items[0], content="\"View\"")
  debug_inspect(output.preprocessed_source.contains("#import"), content="false")
  debug_inspect(
    output.preprocessed_source.contains("return view;"),
    content="true",
  )
}

///|
test "issue 5: preprocessor shader defs preserve non-BMP source text" {
  let shader_defs = empty_shader_defs()
  shader_defs.set("CUSTOM_LIMIT", @common.ShaderDefValue::Int(42))
  let output = @preprocess.Preprocessor::default().preprocess(
    "// 😀 before a braced shader def\nlet a = #{CUSTOM_LIMIT};\n// 😃 before a bare shader def\nlet b = #CUSTOM_LIMIT;\n// 😄 before an unknown shader def\nlet c = #UNKNOWN;\n",
    shader_defs,
  ) catch {
    _ => abort("expected non-BMP shader-def preprocess success")
  }
  debug_inspect(output.preprocessed_source.contains("😀"), content="true")
  debug_inspect(output.preprocessed_source.contains("😃"), content="true")
  debug_inspect(output.preprocessed_source.contains("😄"), content="true")
  debug_inspect(
    output.preprocessed_source.contains("let a = 42;"),
    content="true",
  )
  debug_inspect(
    output.preprocessed_source.contains("let b = 42;"),
    content="true",
  )
  debug_inspect(
    output.preprocessed_source.contains("let c = #UNKNOWN;"),
    content="true",
  )
}

///|
test "naga_oil: preprocess follows else-ifdef fallback semantics" {
  let source = "\nstruct View {\n    view_proj: mat4x4<f32>,\n    world_position: vec3<f32>,\n};\n@group(0) @binding(0)\nvar<uniform> view: View;\n\n#ifdef TEXTURE\n@group(1) @binding(0)\nvar sprite_texture: texture_2d<f32>;\n#else ifdef SECOND_TEXTURE\n@group(1) @binding(0)\nvar sprite_texture: texture_2d<f32>;\n#else\n@group(1) @binding(0)\nvar sprite_texture: texture_2d_array<f32>;\n#endif\n"
  let fallback_output = @preprocess.Preprocessor::default().preprocess(
    source,
    empty_shader_defs(),
  ) catch {
    _ => abort("expected fallback preprocess success")
  }
  debug_inspect(
    fallback_output.preprocessed_source.contains("texture_2d_array<f32>;"),
    content="true",
  )
  debug_inspect(
    fallback_output.preprocessed_source.contains("texture_2d<f32>;"),
    content="false",
  )

  let first_clause_output = @preprocess.Preprocessor::default().preprocess(
    source,
    bool_shader_def("TEXTURE", true),
  ) catch {
    _ => abort("expected first-clause preprocess success")
  }
  debug_inspect(
    first_clause_output.preprocessed_source.contains("texture_2d<f32>;"),
    content="true",
  )
  debug_inspect(
    first_clause_output.preprocessed_source.contains("texture_2d_array<f32>;"),
    content="false",
  )
}

///|
test "naga_oil upstream: preprocess else-if chains choose only first active branch" {
  let source = "\n#ifdef TEXTURE\nmain\n#else ifdef SECOND_TEXTURE\nsecond\n#else ifdef THIRD_TEXTURE\nthird\n#else\nfallback\n#endif\n"
  debug_inspect(
    preprocess_without_ascii_whitespace(source, empty_shader_defs()),
    content="\"fallback\"",
  )
  debug_inspect(
    preprocess_without_ascii_whitespace(
      source,
      bool_shader_def("SECOND_TEXTURE", true),
    ),
    content="\"second\"",
  )
  let defs = bool_shader_def("SECOND_TEXTURE", true)
  defs.set("THIRD_TEXTURE", @common.ShaderDefValue::Bool(true))
  debug_inspect(
    preprocess_without_ascii_whitespace(source, defs),
    content="\"second\"",
  )
}

///|
test "naga_oil upstream: preprocess supports else-ifndef and else-if comparisons" {
  let ifndef_source = "\n#ifdef NOT_DEFINED\nfail1\n#else ifdef ALSO_NOT_DEFINED\nfail2\n#else ifndef ALSO_ALSO_NOT_DEFINED\nok\n#else\nfail3\n#endif\n"
  debug_inspect(
    preprocess_without_ascii_whitespace(ifndef_source, empty_shader_defs()),
    content="\"ok\"",
  )

  let if_source = "\n#ifdef NOT_DEFINED\nfail1\n#else if x == 1\nfail2\n#else if x == 2\nok\n#else\nfail3\n#endif\n"
  debug_inspect(
    preprocess_without_ascii_whitespace(if_source, int_shader_def("x", 2)),
    content="\"ok\"",
  )
}

///|
test "naga_oil upstream: else and endif directives use prefix regex matching" {
  let else_source = "\n#ifdef ENABLED\nactive\n#elsewhere\nfallback\n#endif\n"
  debug_inspect(
    preprocess_without_ascii_whitespace(else_source, empty_shader_defs()),
    content="\"fallback\"",
  )
  debug_inspect(
    preprocess_without_ascii_whitespace(
      else_source,
      bool_shader_def("ENABLED", true),
    ),
    content="\"active\"",
  )
  let else_ifdef_without_space_source = "\n#ifdef NOT_DEFINED\nfail\n#elseifdef ENABLED\nplain_else\n#endif\n"
  debug_inspect(
    preprocess_without_ascii_whitespace(
      else_ifdef_without_space_source,
      empty_shader_defs(),
    ),
    content="\"plain_else\"",
  )

  let endif_source = "\n#ifdef ENABLED\nactive\n#endif_trailing\noutside\n"
  debug_inspect(
    preprocess_without_ascii_whitespace(
      endif_source,
      bool_shader_def("ENABLED", true),
    ),
    content="\"activeoutside\"",
  )
}

///|
test "naga_oil upstream: preprocess handles complicated nested else-ifdef scopes" {
  let source = "\n#ifdef NOT_DEFINED\nfail1\n#else ifdef IS_DEFINED\nok1\n#ifdef NOT_DEFINED\nfail2\n#else\nok2\n#ifdef NOT_DEFINED\nfail3\n#else ifdef ALSO_NOT_DEFINED\nfail4\n#else ifdef IS_DEFINED\nok3\n#endif\n#endif\n#endif\n"
  debug_inspect(
    preprocess_without_ascii_whitespace(
      source,
      bool_shader_def("IS_DEFINED", true),
    ),
    content="\"ok1ok2ok3\"",
  )
}

///|
test "naga_oil upstream: preprocess reports shader-def comparison errors" {
  let unknown_operator_defs = bool_shader_def("TEXTURE", true)
  let _ = @preprocess.Preprocessor::default().preprocess(
    "#if TEXTURE !! true\nok\n#endif\n", unknown_operator_defs,
  ) catch {
    @preprocess.PreprocessError::UnknownShaderDefOperator(operator, _) => {
      debug_inspect(operator, content="\"!!\"")
      return
    }
    _ => abort("expected unknown shader-def operator")
  }
  abort("expected unknown shader-def operator")
}

///|
test "naga_oil upstream: if comparison parser preserves whitespace token boundaries" {
  let mut saw_missing_def = false
  ignore(
    @preprocess.Preprocessor::default().preprocess(
      "#if TEXTURE true\nok\n#endif\n",
      empty_shader_defs(),
    ),
  ) catch {
    @preprocess.PreprocessError::UnknownShaderDef(name, _) => {
      debug_inspect(name, content="\"TEXTURE\"")
      saw_missing_def = true
    }
    _ => abort("expected missing shader-def for operatorless comparison")
  }
  debug_inspect(saw_missing_def, content="true")

  let defs = bool_shader_def("TEXTURE", true)
  let mut saw_empty_operator = false
  ignore(
    @preprocess.Preprocessor::default().preprocess(
      "#if TEXTURE true\nok\n#endif\n", defs,
    ),
  ) catch {
    @preprocess.PreprocessError::UnknownShaderDefOperator(operator, _) => {
      debug_inspect(operator, content="\"\"")
      saw_empty_operator = true
    }
    _ => abort("expected empty shader-def operator")
  }
  debug_inspect(saw_empty_operator, content="true")

  let metadata = metadata_or_abort("#if TEXTURE true\n#VALUE\n#endif\n")
  debug_inspect(metadata.effective_defs.contains("TEXTURE"), content="true")
  debug_inspect(
    metadata.effective_defs.contains("TEXTUREtrue"),
    content="false",
  )
}

///|
test "naga_oil upstream: preprocess validates int and bool comparison values" {
  ignore(
    @preprocess.Preprocessor::default().preprocess(
      "#if TEXTURE == 3\nok\n#endif\n",
      empty_shader_defs(),
    ),
  ) catch {
    @preprocess.PreprocessError::UnknownShaderDef(name, _) =>
      debug_inspect(name, content="\"TEXTURE\"")
    _ => abort("expected missing shader-def error")
  }

  ignore(
    @preprocess.Preprocessor::default().preprocess(
      "#if TEXTURE == 3\nok\n#endif\n",
      bool_shader_def("TEXTURE", true),
    ),
  ) catch {
    @preprocess.PreprocessError::InvalidShaderDefComparisonValue(
      name,
      value,
      expected,
      _
    ) => {
      debug_inspect(name, content="\"TEXTURE\"")
      debug_inspect(value, content="\"3\"")
      debug_inspect(expected, content="\"bool\"")
    }
    _ => abort("expected invalid bool comparison value")
  }

  let _ = @preprocess.Preprocessor::default().preprocess(
    "#if TEXTURE != false\nok\n#endif\n",
    int_shader_def("TEXTURE", 7),
  ) catch {
    @preprocess.PreprocessError::InvalidShaderDefComparisonValue(
      name,
      value,
      expected,
      _
    ) => {
      debug_inspect(name, content="\"TEXTURE\"")
      debug_inspect(value, content="\"false\"")
      debug_inspect(expected, content="\"int\"")
      return
    }
    _ => abort("expected invalid int comparison value")
  }
  abort("expected invalid int comparison value")
}

///|
test "naga_oil: preprocess applies module defines to output" {
  let source = "#define DEFUINT 1\n#define DEFINT -1\n#define DEFBOOL false\n#if DEFUINT == 1\nuint: #DEFUINT\n#endif\n#if DEFINT == -1\nint: #DEFINT\n#endif\n#if DEFBOOL == false\nbool: #DEFBOOL\n#endif\n"
  let metadata = metadata_or_abort(source)
  let output = @preprocess.Preprocessor::default().preprocess(
    source,
    metadata.defines,
  ) catch {
    _ => abort("expected preprocess success with module defines")
  }
  debug_inspect(output.preprocessed_source.contains("uint: 1"), content="true")
  debug_inspect(output.preprocessed_source.contains("int: -1"), content="true")
  debug_inspect(
    output.preprocessed_source.contains("bool: false"),
    content="true",
  )
  guard metadata.defines.get("DEFUINT")
    is Some(@common.ShaderDefValue::UInt(uint_value)) else {
    abort("expected naga_oil-style unsigned positive define")
  }
  debug_inspect(uint_value.to_string(), content="\"1\"")
}

///|
test "naga_oil: define metadata rejects unsigned suffix like upstream" {
  let metadata = metadata_or_abort("#define VALUE 2u\n#define NEG_ZERO -0\n")
  guard metadata.defines.get("VALUE")
    is Some(@common.ShaderDefValue::Bool(value)) else {
    abort("expected naga_oil-style failed unsigned suffix define")
  }
  debug_inspect(value, content="false")
  guard metadata.defines.get("NEG_ZERO")
    is Some(@common.ShaderDefValue::Int(neg_zero)) else {
    abort("expected naga_oil-style signed negative zero define")
  }
  debug_inspect(neg_zero.to_string(), content="\"0\"")
}

///|
test "naga_oil: unsigned shader defs support full u32 range" {
  let source = "#define BIG 4000000000\n#if BIG == 4000000000\nbig\n#else\nsmall\n#endif\n"
  let metadata = metadata_or_abort(source)
  guard metadata.defines.get("BIG") is Some(@common.ShaderDefValue::UInt(big)) else {
    abort("expected full-range unsigned define")
  }
  debug_inspect(big.to_string(), content="\"4000000000\"")
  let output = @preprocess.Preprocessor::default().preprocess(
    source,
    metadata.defines,
  ) catch {
    _ => abort("expected full-range unsigned comparison preprocess success")
  }
  debug_inspect(output.preprocessed_source.contains("big"), content="true")
  debug_inspect(output.preprocessed_source.contains("small"), content="false")
}

///|
test "naga_oil: preprocess accepts whitespace after hash directives" {
  let source = "# define_import_path demo::spaced\n# define MODE 2\n# if MODE==1\none\n# else if MODE==2\ntwo #MODE\n# else\nthree\n# endif\n"
  let metadata = metadata_or_abort(source)
  debug_inspect(metadata.name, content="Some(\"demo::spaced\")")
  guard metadata.defines.get("MODE") is Some(@common.ShaderDefValue::UInt(mode)) else {
    abort("expected MODE define")
  }
  debug_inspect(mode.to_string(), content="\"2\"")
  let output = @preprocess.Preprocessor::default().preprocess(
    source,
    metadata.defines,
  ) catch {
    _ => abort("expected spaced directive preprocess success")
  }
  debug_inspect(output.preprocessed_source.contains("two 2"), content="true")
  debug_inspect(output.preprocessed_source.contains("one"), content="false")
  debug_inspect(output.preprocessed_source.contains("three"), content="false")
}

///|
test "naga_oil: preprocess accepts whitespace after hash import directives" {
  let output = @preprocess.Preprocessor::default().preprocess(
    "# import demo::math::PI\nfn main() -> f32 {\n  return PI;\n}\n",
    empty_shader_defs(),
  ) catch {
    _ => abort("expected spaced import preprocess success")
  }
  debug_inspect(output.imports.length(), content="1")
  debug_inspect(
    output.imports[0].definition.import_path,
    content="\"demo::math\"",
  )
  debug_inspect(output.imports[0].definition.items[0], content="\"PI\"")
  debug_inspect(
    output.preprocessed_source.contains("# import"),
    content="false",
  )
  debug_inspect(
    output.preprocessed_source.contains("return PIX_naga_oil_mod_"),
    content="true",
  )
}

///|
test "naga_oil: shader def placeholders accept hash whitespace and upstream name chars" {
  let source = "let a = # lower_def;\nlet b = # {MIXED|PIPE};\n"
  let metadata = metadata_or_abort(source)
  debug_inspect(metadata.effective_defs.contains("lower_def"), content="true")
  debug_inspect(metadata.effective_defs.contains("MIXED|PIPE"), content="true")

  let shader_defs = empty_shader_defs()
  shader_defs.set("lower_def", @common.ShaderDefValue::Int(7))
  shader_defs.set("MIXED|PIPE", @common.ShaderDefValue::Int(9))
  let output = @preprocess.Preprocessor::default().preprocess(
    source, shader_defs,
  ) catch {
    _ => abort("expected spaced shader-def preprocess success")
  }
  debug_inspect(
    output.preprocessed_source.contains("let a = 7;"),
    content="true",
  )
  debug_inspect(
    output.preprocessed_source.contains("let b = 9;"),
    content="true",
  )
}

///|
test "naga_oil: ifdef identifiers accept upstream pipe names" {
  let source = "#ifdef MIXED|PIPE\nactive\n#else\ninactive\n#endif\n"
  let shader_defs = empty_shader_defs()
  shader_defs.set("MIXED|PIPE", @common.ShaderDefValue::Bool(true))
  let output = @preprocess.Preprocessor::default().preprocess(
    source, shader_defs,
  ) catch {
    _ => abort("expected pipe shader-def preprocess success")
  }
  debug_inspect(output.preprocessed_source.contains("active"), content="true")
  debug_inspect(
    output.preprocessed_source.contains("inactive"),
    content="false",
  )
}

///|
test "naga_oil: ifdef identifiers accept upstream leading digit and pipe names" {
  let source = "#ifdef 1FLAG\none\n#endif\n#ifdef |PIPE\npipe\n#endif\n#ifdef 1FLAG trailing\ntrail\n#endif\n"
  let shader_defs = empty_shader_defs()
  shader_defs.set("1FLAG", @common.ShaderDefValue::Bool(true))
  shader_defs.set("|PIPE", @common.ShaderDefValue::Bool(true))
  let output = @preprocess.Preprocessor::default().preprocess(
    source, shader_defs,
  ) catch {
    _ => abort("expected leading-character shader-def preprocess success")
  }
  debug_inspect(output.preprocessed_source.contains("one"), content="true")
  debug_inspect(output.preprocessed_source.contains("pipe"), content="true")
  debug_inspect(output.preprocessed_source.contains("trail"), content="true")

  let metadata = metadata_or_abort(
    "#ifdef 1FLAG\n#VALUE\n#endif\n#ifndef |PIPE\n#OTHER\n#endif\n#ifdef 1FLAG trailing\n#TAIL\n#endif\n",
  )
  debug_inspect(metadata.effective_defs.contains("1FLAG"), content="true")
  debug_inspect(metadata.effective_defs.contains("|PIPE"), content="true")
  debug_inspect(
    metadata.effective_defs.contains("1FLAGtrailing"),
    content="false",
  )
}

///|
test "naga_oil: if comparison identifiers accept upstream pipe names" {
  let source = "#if MIXED|PIPE == 4\nactive\n#else\ninactive\n#endif\n"
  let shader_defs = empty_shader_defs()
  shader_defs.set("MIXED|PIPE", @common.ShaderDefValue::Int(4))
  let output = @preprocess.Preprocessor::default().preprocess(
    source, shader_defs,
  ) catch {
    _ => abort("expected pipe shader-def comparison preprocess success")
  }
  debug_inspect(output.preprocessed_source.contains("active"), content="true")
  debug_inspect(
    output.preprocessed_source.contains("inactive"),
    content="false",
  )
}

///|
test "naga_oil: define metadata consumes one token like upstream regexes" {
  let metadata = metadata_or_abort(
    "# define_import_path demo::module trailing_text\n# define COUNT 3 ignored_tail\n# define FLAG true ignored_tail\n",
  )
  debug_inspect(metadata.name, content="Some(\"demo::module\")")
  guard metadata.defines.get("COUNT")
    is Some(@common.ShaderDefValue::UInt(count)) else {
    abort("expected COUNT define")
  }
  debug_inspect(count.to_string(), content="\"3\"")
  guard metadata.defines.get("FLAG") is Some(@common.ShaderDefValue::Bool(flag)) else {
    abort("expected FLAG define")
  }
  debug_inspect(flag, content="true")
}

///|
test "naga_oil: define import path keeps semicolon in captured token" {
  let metadata = metadata_or_abort("#define_import_path demo::module;\n")
  debug_inspect(metadata.name, content="Some(\"demo::module;\")")
}

///|
test "naga_oil: define metadata follows upstream regex character classes" {
  let metadata = metadata_or_abort(
    "#define NAME+TAIL 7\n#define PLUS +1\n#define PIPE|NAME value|tail ignored\n",
  )
  guard metadata.defines.get("NAME")
    is Some(@common.ShaderDefValue::Bool(name_value)) else {
    abort("expected NAME define")
  }
  debug_inspect(name_value, content="true")
  guard metadata.defines.get("PLUS")
    is Some(@common.ShaderDefValue::Bool(plus_value)) else {
    abort("expected PLUS define")
  }
  debug_inspect(plus_value, content="true")
  guard metadata.defines.get("PIPE|NAME")
    is Some(@common.ShaderDefValue::Bool(pipe_value)) else {
    abort("expected PIPE|NAME define")
  }
  debug_inspect(pipe_value, content="false")
}

///|
test "naga_oil: shader-def token parsing keeps upstream underscore tails" {
  let metadata = metadata_or_abort("#define 1_NAME false\n#define BAD 1_name\n")
  guard metadata.defines.get("1_NAME")
    is Some(@common.ShaderDefValue::Bool(one_name)) else {
    abort("expected full digit-leading underscore define name")
  }
  debug_inspect(one_name, content="false")
  debug_inspect(metadata.defines.contains("1"), content="false")
  guard metadata.defines.get("BAD") is Some(@common.ShaderDefValue::Bool(bad)) else {
    abort("expected malformed underscore value to follow upstream fallback")
  }
  debug_inspect(bad, content="false")

  let shader_defs = empty_shader_defs()
  shader_defs.set("1_NAME", @common.ShaderDefValue::UInt(3U))
  let output = @preprocess.Preprocessor::default().preprocess(
    "let value = #1_NAME;\n", shader_defs,
  ) catch {
    _ => abort("expected digit-leading underscore shader-def replacement")
  }
  debug_inspect(
    output.preprocessed_source.contains("let value = 3;"),
    content="true",
  )
}

///|
test "naga_oil: directive keywords without required tail whitespace stay as source" {
  let metadata = @metadata.get_preprocessor_metadata(
    "#define\n#import\n#define_import_path\nfn shade() {}\n",
    allow_defines=false,
  ) catch {
    _ => abort("expected keyword-only directive metadata success")
  }
  debug_inspect(metadata.defines.is_empty(), content="true")
  debug_inspect(metadata.effective_defs.contains("define"), content="true")
  debug_inspect(metadata.effective_defs.contains("import"), content="true")
  debug_inspect(
    metadata.effective_defs.contains("define_import_path"),
    content="true",
  )

  let output = @preprocess.Preprocessor::default().preprocess(
    "#define\n#import\n#define_import_path\nfn shade() {}\n",
    empty_shader_defs(),
  ) catch {
    _ => abort("expected keyword-only directive preprocess success")
  }
  debug_inspect(output.preprocessed_source.contains("#define"), content="true")
  debug_inspect(output.preprocessed_source.contains("#import"), content="true")
  debug_inspect(
    output.preprocessed_source.contains("#define_import_path"),
    content="true",
  )
}

///|
test "naga_oil: shader-def replacement follows upstream first-match loop" {
  let shader_defs = empty_shader_defs()
  shader_defs.set("KNOWN", @common.ShaderDefValue::Int(7))
  shader_defs.set("KNOWN_BRACED", @common.ShaderDefValue::Int(9))
  let output = @preprocess.Preprocessor::default().preprocess(
    "let a = #MISSING + #KNOWN;\nlet b = #{MISSING_BRACED} + #{KNOWN_BRACED};\n",
    shader_defs,
  ) catch {
    _ => abort("expected upstream first-match replacement success")
  }
  debug_inspect(
    output.preprocessed_source.contains("let a = 7 + #KNOWN;"),
    content="true",
  )
  debug_inspect(
    output.preprocessed_source.contains("let b = 9 + #{KNOWN_BRACED};"),
    content="true",
  )
}

///|
test "naga_oil: delimited shader-def references require regex name body" {
  let metadata = metadata_or_abort(
    "let a = #{KNOWN BAD};\nlet b = #{KNOWN+BAD};\nlet c = #{KNOWN_OK};\n",
  )
  debug_inspect(metadata.effective_defs.contains("KNOWN BAD"), content="false")
  debug_inspect(metadata.effective_defs.contains("KNOWN+BAD"), content="false")
  debug_inspect(metadata.effective_defs.contains("KNOWN_OK"), content="true")

  let shader_defs = empty_shader_defs()
  shader_defs.set("KNOWN BAD", @common.ShaderDefValue::Int(1))
  shader_defs.set("KNOWN+BAD", @common.ShaderDefValue::Int(2))
  shader_defs.set("KNOWN_OK", @common.ShaderDefValue::Int(3))
  let output = @preprocess.Preprocessor::default().preprocess(
    "let a = #{KNOWN BAD};\nlet b = #{KNOWN+BAD};\nlet c = #{KNOWN_OK};\n", shader_defs,
  ) catch {
    _ => abort("expected delimited shader-def preprocess success")
  }
  debug_inspect(
    output.preprocessed_source.contains("#{KNOWN BAD}"),
    content="true",
  )
  debug_inspect(
    output.preprocessed_source.contains("#{KNOWN+BAD}"),
    content="true",
  )
  debug_inspect(
    output.preprocessed_source.contains("let c = 3;"),
    content="true",
  )
}

///|
test "naga_oil: shader-def regex word rejects emoji but keeps Unicode words" {
  let shader_defs = empty_shader_defs()
  shader_defs.set("KNOWN", @common.ShaderDefValue::Int(7))
  shader_defs.set("中文", @common.ShaderDefValue::Int(9))
  let output = @preprocess.Preprocessor::default().preprocess(
    "let a = #KNOWN💡;\nlet b = #{KNOWN💡};\nlet c = #中文;\n", shader_defs,
  ) catch {
    _ => abort("expected unicode shader-def preprocess success")
  }
  debug_inspect(
    output.preprocessed_source.contains("let a = 7💡;"),
    content="true",
  )
  debug_inspect(
    output.preprocessed_source.contains("let b = #{KNOWN💡};"),
    content="true",
  )
  debug_inspect(
    output.preprocessed_source.contains("let c = 9;"),
    content="true",
  )
}

///|
test "naga_oil: conditional directive regex word stops before emoji" {
  let shader_defs = empty_shader_defs()
  shader_defs.set("FLAG", @common.ShaderDefValue::Bool(true))
  let output = @preprocess.Preprocessor::default().preprocess(
    "#ifdef FLAG💡\nactive\n#else\ninactive\n#endif\n", shader_defs,
  ) catch {
    _ => abort("expected emoji-suffixed ifdef preprocess success")
  }
  debug_inspect(output.preprocessed_source.contains("active"), content="true")
  debug_inspect(
    output.preprocessed_source.contains("inactive"),
    content="false",
  )
  let metadata = metadata_or_abort(
    "#ifdef FLAG💡\n#endif\n#FLAG💡\n#中文\n",
  )
  debug_inspect(metadata.effective_defs.contains("FLAG"), content="true")
  debug_inspect(metadata.effective_defs.contains("FLAG💡"), content="false")
  debug_inspect(metadata.effective_defs.contains("中文"), content="true")
}

///|
test "naga_oil: conditional directive keywords require trailing whitespace" {
  let shader_defs = empty_shader_defs()
  shader_defs.set("|FLAG", @common.ShaderDefValue::Bool(true))
  let direct = @preprocess.Preprocessor::default().preprocess(
    "#ifdef|FLAG\nbody\n", shader_defs,
  ) catch {
    _ => abort("expected non-directive ifdef source success")
  }
  debug_inspect(
    direct.preprocessed_source.contains("#ifdef|FLAG"),
    content="true",
  )
  debug_inspect(direct.preprocessed_source.contains("body"), content="true")

  let fallback = @preprocess.Preprocessor::default().preprocess(
    "#ifdef MISSING\nno\n#else ifdef|FLAG\nfallback\n#endif\n",
    empty_shader_defs(),
  ) catch {
    _ => abort("expected else-prefix fallback success")
  }
  debug_inspect(
    fallback.preprocessed_source.contains("fallback"),
    content="true",
  )
  debug_inspect(fallback.preprocessed_source.contains("no"), content="false")
}

///|
test "naga_oil: glsl version directive captures numeric version token" {
  let output = @preprocess.Preprocessor::default().preprocess(
    "#version\t450 trailing_text\nfn main() -> f32 {\n  return 1.0;\n}\n",
    empty_shader_defs(),
  ) catch {
    _ => abort("expected naga_oil-style glsl version preprocess success")
  }
  debug_inspect(
    output.preprocessed_source.contains("#version"),
    content="false",
  )
  debug_inspect(
    output.preprocessed_source.contains("return 1.0;"),
    content="true",
  )
}

///|
test "naga_oil: glsl version directive does not allow hash whitespace" {
  let output = @preprocess.Preprocessor::default().preprocess(
    "# version 450\nfn main() -> f32 {\n  return 1.0;\n}\n",
    empty_shader_defs(),
  ) catch {
    _ => abort("expected spaced hash version to stay as normal source")
  }
  debug_inspect(
    output.preprocessed_source.contains("# version 450"),
    content="true",
  )
}

///|
test "naga_oil: wgsl directives accept upstream whitespace forms" {
  let metadata = metadata_or_abort(
    "enable   f16, subgroups ; trailing\nrequires\treadonly_and_readwrite_storage_textures ; trailing\ndiagnostic ( warn , derivative_uniformity ) ; trailing\nfn shade() -> f32 {\n  return 1.0;\n}\n",
  )
  debug_inspect(metadata.wgsl_directives.enables.length(), content="1")
  debug_inspect(
    metadata.wgsl_directives.enables[0].extensions[0],
    content="\"f16\"",
  )
  debug_inspect(
    metadata.wgsl_directives.enables[0].extensions[1],
    content="\"subgroups\"",
  )
  debug_inspect(metadata.wgsl_directives.requires.length(), content="1")
  debug_inspect(
    metadata.wgsl_directives.requires[0].extensions[0],
    content="\"readonly_and_readwrite_storage_textures\"",
  )
  debug_inspect(metadata.wgsl_directives.diagnostics.length(), content="1")
  debug_inspect(
    metadata.wgsl_directives.diagnostics[0].severity,
    content="\"warn\"",
  )
  debug_inspect(
    metadata.wgsl_directives.diagnostics[0].rule,
    content="\"derivative_uniformity\"",
  )
  debug_inspect(metadata.cleaned_source.contains("fn shade()"), content="true")
}

///|
test "naga_oil: wgsl directive extension lists split only on commas" {
  let metadata = metadata_or_abort(
    "enable foo-bar, spaced extension;\nrequires one two, three-four;\nfn shade() {}\n",
  )
  debug_inspect(metadata.wgsl_directives.enables.length(), content="1")
  debug_inspect(
    metadata.wgsl_directives.enables[0].extensions[0],
    content="\"foo-bar\"",
  )
  debug_inspect(
    metadata.wgsl_directives.enables[0].extensions[1],
    content="\"spaced extension\"",
  )
  debug_inspect(
    metadata.wgsl_directives.requires[0].extensions[0],
    content="\"one two\"",
  )
  debug_inspect(
    metadata.wgsl_directives.requires[0].extensions[1],
    content="\"three-four\"",
  )
}

///|
test "naga_oil: diagnostic directive captures raw rule text" {
  let metadata = metadata_or_abort(
    "diagnostic(warn, derivative-uniformity rule); trailing\nfn shade() {}\n",
  )
  debug_inspect(metadata.wgsl_directives.diagnostics.length(), content="1")
  debug_inspect(
    metadata.wgsl_directives.diagnostics[0].severity,
    content="\"warn\"",
  )
  debug_inspect(
    metadata.wgsl_directives.diagnostics[0].rule,
    content="\"derivative-uniformity rule\"",
  )
}

///|
test "naga_oil: directive section stays open on directive name prefix" {
  let metadata = metadata_or_abort(
    "enable_extra();\ndiagnostic_extra();\nenable f16;\nfn shade() -> f32 {\n  return 1.0;\n}\n",
  )
  debug_inspect(metadata.wgsl_directives.enables.length(), content="1")
  debug_inspect(
    metadata.wgsl_directives.enables[0].extensions[0],
    content="\"f16\"",
  )
  debug_inspect(metadata.wgsl_directives.diagnostics.length(), content="0")
  debug_inspect(
    metadata.cleaned_source.contains("enable f16;"),
    content="false",
  )
}

///|
test "naga_oil: enable and requires directives require whitespace body separator" {
  let metadata = metadata_or_abort(
    "enable+f16;\nrequires+subgroups;\nenable f16;\nfn shade() -> f32 {\n  return 1.0;\n}\n",
  )
  debug_inspect(metadata.wgsl_directives.enables.length(), content="1")
  debug_inspect(metadata.wgsl_directives.requires.length(), content="0")
  debug_inspect(metadata.cleaned_source.contains("enable+f16;"), content="true")
  debug_inspect(
    metadata.cleaned_source.contains("requires+subgroups;"),
    content="true",
  )
  debug_inspect(
    metadata.cleaned_source.contains("enable f16;"),
    content="false",
  )
}

///|
test "naga_oil: single whitespace empty enable body stays source" {
  let metadata = metadata_or_abort(
    "enable ;\nenable f16;\nfn shade() -> f32 {\n  return 1.0;\n}\n",
  )
  debug_inspect(metadata.wgsl_directives.enables.length(), content="1")
  debug_inspect(metadata.cleaned_source.contains("enable ;"), content="true")
  debug_inspect(
    metadata.cleaned_source.contains("enable f16;"),
    content="false",
  )
}

///|
test "naga_oil: repeated whitespace empty enable body raises directive error" {
  let _ = @preprocess.Preprocessor::default().extract_wgsl_directives(
    "enable  ;\nfn shade() -> f32 {\n  return 1.0;\n}\n",
  ) catch {
    @preprocess.PreprocessError::InvalidWgslDirective(_, _, message) => {
      debug_inspect(message, content="\"No extensions specified\"")
      return
    }
    _ => abort("expected empty enable directive error")
  }
  abort("expected empty enable directive error")
}

///|
test "naga_oil: preprocessor directive regex whitespace includes form feed" {
  let ff = "\u{000C}"
  let shader_defs = empty_shader_defs()
  shader_defs.set("FLAG", @common.ShaderDefValue::Bool(true))
  shader_defs.set("VALUE", @common.ShaderDefValue::Int(7))
  let output = @preprocess.Preprocessor::default().preprocess(
    "#\{ff}ifdef\{ff}FLAG\nlet a = #\{ff}VALUE;\n#\{ff}else\nlet a = 0;\n#\{ff}endif\n",
    shader_defs,
  ) catch {
    _ => abort("expected regex-whitespace preprocess success")
  }
  debug_inspect(
    output.preprocessed_source.contains("let a = 7;"),
    content="true",
  )
  debug_inspect(
    output.preprocessed_source.contains("let a = 0;"),
    content="false",
  )
}

///|
test "naga_oil: wgsl source directives accept form feed whitespace" {
  let ff = "\u{000C}"
  let metadata = metadata_or_abort(
    "enable\{ff}f16;\nrequires\{ff}subgroups;\ndiagnostic\{ff}(\{ff}off\{ff},\{ff}derivative_uniformity\{ff})\{ff};\nfn shade() -> f32 {\n  return 1.0;\n}\n",
  )
  debug_inspect(metadata.wgsl_directives.enables.length(), content="1")
  debug_inspect(metadata.wgsl_directives.requires.length(), content="1")
  debug_inspect(metadata.wgsl_directives.diagnostics.length(), content="1")
}

///|
test "naga_oil: preprocessor directive regex whitespace includes Unicode spaces" {
  let nbsp = "\u{00A0}"
  let em = "\u{2003}"
  let ideographic = "\u{3000}"
  let shader_defs = empty_shader_defs()
  shader_defs.set("FLAG", @common.ShaderDefValue::Bool(true))
  shader_defs.set("VALUE", @common.ShaderDefValue::Int(9))
  let output = @preprocess.Preprocessor::default().preprocess(
    "#\{nbsp}ifdef\{em}FLAG\nlet a = #\{ideographic}VALUE;\n#\{nbsp}else\nlet a = 0;\n#\{em}endif\n",
    shader_defs,
  ) catch {
    _ => abort("expected Unicode regex-whitespace preprocess success")
  }
  debug_inspect(
    output.preprocessed_source.contains("let a = 9;"),
    content="true",
  )
  debug_inspect(
    output.preprocessed_source.contains("let a = 0;"),
    content="false",
  )
}

///|
test "naga_oil: wgsl source directives accept Unicode regex whitespace" {
  let nbsp = "\u{00A0}"
  let em = "\u{2003}"
  let ideographic = "\u{3000}"
  let metadata = metadata_or_abort(
    "enable\{nbsp}f16;\nrequires\{em}subgroups;\ndiagnostic\{ideographic}(\{nbsp}off\{em},\{ideographic}derivative_uniformity\{nbsp})\{em};\nfn shade() -> f32 {\n  return 1.0;\n}\n",
  )
  debug_inspect(metadata.wgsl_directives.enables.length(), content="1")
  debug_inspect(metadata.wgsl_directives.requires.length(), content="1")
  debug_inspect(metadata.wgsl_directives.diagnostics.length(), content="1")
}

///|
test "naga_oil: block comments terminate directive section like upstream" {
  let metadata = metadata_or_abort(
    "/* block comment */\nenable f16;\nfn shade() -> f32 {\n  return 1.0;\n}\n",
  )
  debug_inspect(metadata.wgsl_directives.enables.length(), content="0")
  debug_inspect(metadata.cleaned_source.contains("enable f16;"), content="true")
}

///|
test "naga_oil: invalid diagnostic severity reports directive error" {
  let _ = @preprocess.Preprocessor::default().extract_wgsl_directives(
    "diagnostic(note, derivative_uniformity);\nfn shade() {}\n",
  ) catch {
    @preprocess.PreprocessError::InvalidWgslDirective(
      directive,
      position,
      reason
    ) => {
      debug_inspect(
        directive,
        content="\"diagnostic(note, derivative_uniformity);\"",
      )
      debug_inspect(position.to_string(), content="\"0\"")
      debug_inspect(reason.contains("Invalid severity 'note'"), content="true")
      return
    }
    _ => abort("expected invalid WGSL directive error")
  }
  abort("expected invalid WGSL directive error")
}

///|
test "naga_oil: metadata parser reports invalid WGSL directive errors" {
  ignore(
    @metadata.get_preprocessor_metadata(
      "diagnostic(note, derivative_uniformity);\nfn shade() {}\n",
    ),
  ) catch {
    @metadata.MetadataError::InvalidWgslDirective(directive, _, reason) => {
      debug_inspect(
        directive,
        content="\"diagnostic(note, derivative_uniformity);\"",
      )
      debug_inspect(reason.contains("Invalid severity 'note'"), content="true")
      return
    }
    _ => abort("expected invalid metadata directive error")
  }
  abort("expected invalid metadata directive error")
}

///|
test "naga_oil: empty directive extension list reports directive error" {
  let _ = @preprocess.Preprocessor::default().extract_wgsl_directives(
    "enable , ;\nfn shade() {}\n",
  ) catch {
    @preprocess.PreprocessError::InvalidWgslDirective(
      directive,
      position,
      reason
    ) => {
      debug_inspect(directive, content="\"enable , ;\"")
      debug_inspect(position.to_string(), content="\"0\"")
      debug_inspect(reason, content="\"No extensions specified\"")
      return
    }
    _ => abort("expected invalid WGSL directive error")
  }
  abort("expected invalid WGSL directive error")
}

///|
test "naga_oil: uint comparison rejects unsigned suffix values" {
  let defs = empty_shader_defs()
  defs.set("COUNT", @common.ShaderDefValue::UInt(1U))
  let mut saw_suffix_error = false
  ignore(
    @preprocess.Preprocessor::default().preprocess(
      "#if COUNT == 1u\nok\n#endif\n", defs,
    ),
  ) catch {
    @preprocess.PreprocessError::InvalidShaderDefComparisonValue(
      name,
      value,
      expected,
      _
    ) => {
      debug_inspect(name, content="\"COUNT\"")
      debug_inspect(value, content="\"1u\"")
      debug_inspect(expected, content="\"uint\"")
      saw_suffix_error = true
    }
    _ => abort("expected invalid uint comparison value")
  }
  debug_inspect(saw_suffix_error, content="true")

  let mut saw_negative_error = false
  ignore(
    @preprocess.Preprocessor::default().preprocess(
      "#if COUNT == -1\nok\n#endif\n", defs,
    ),
  ) catch {
    @preprocess.PreprocessError::InvalidShaderDefComparisonValue(
      name,
      value,
      expected,
      _
    ) => {
      debug_inspect(name, content="\"COUNT\"")
      debug_inspect(value, content="\"-1\"")
      debug_inspect(expected, content="\"uint\"")
      saw_negative_error = true
    }
    _ => abort("expected invalid negative uint comparison value")
  }
  debug_inspect(saw_negative_error, content="true")
}

///|
test "naga_oil: preprocess uses Rust lines trailing newline semantics" {
  let source = "fn main() -> f32 {\r\n  return 1.0;\r\n}\r\n"
  let output = @preprocess.Preprocessor::default().preprocess(
    source,
    empty_shader_defs(),
  ) catch {
    _ => abort("expected trailing newline preprocess success")
  }
  debug_inspect(
    output.preprocessed_source,
    content="\"fn main() -> f32 {\\n  return 1.0;\\n}\\n\"",
  )
}

///|
test "naga_oil: strict ifdefs parse decommented conditions like preprocess" {
  let defs = empty_shader_defs()
  defs.set("COUNT", @common.ShaderDefValue::Int(2))
  let output = @preprocess.apply_wgsl_ifdefs_strict(
    "#if COUNT /* comment before operator */ == 2\nactive\n#else\ninactive\n#endif\n",
    defs,
  ) catch {
    _ => abort("expected strict ifdef success with block comment")
  }
  debug_inspect(output.contains("active"), content="true")
  debug_inspect(output.contains("inactive"), content="false")
}

///|
test "naga_oil: strict ifdefs apply GLSL version preprocessing" {
  let output = @preprocess.apply_wgsl_ifdefs_strict(
    "#version 450\nfn shade() -> f32 { return 1.0; }\n",
    empty_shader_defs(),
  ) catch {
    _ => abort("expected accepted GLSL version strict preprocess success")
  }
  debug_inspect(output.contains("#version"), content="false")
  debug_inspect(output.contains("fn shade()"), content="true")

  ignore(
    @preprocess.apply_wgsl_ifdefs_strict(
      "#version 430\nfn shade() -> f32 { return 1.0; }\n",
      empty_shader_defs(),
    ),
  ) catch {
    @preprocess.PreprocessError::GlslInvalidVersion(_) => return
    _ => abort("expected invalid GLSL version strict preprocess error")
  }
  abort("expected invalid GLSL version strict preprocess error")
}
