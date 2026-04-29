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
fn empty_shader_defs() -> @hashmap.HashMap[String, @moon_wgsl.ShaderDefValue] {
  @hashmap.HashMap::new()
}

///|
fn bool_shader_def(
  name : String,
  value : Bool,
) -> @hashmap.HashMap[String, @moon_wgsl.ShaderDefValue] {
  let shader_defs = empty_shader_defs()
  shader_defs.set(name, @moon_wgsl.ShaderDefValue::Bool(value))
  shader_defs
}

///|
fn int_shader_def(
  name : String,
  value : Int,
) -> @hashmap.HashMap[String, @moon_wgsl.ShaderDefValue] {
  let shader_defs = empty_shader_defs()
  shader_defs.set(name, @moon_wgsl.ShaderDefValue::Int(value))
  shader_defs
}

///|
fn preprocess_without_ascii_whitespace(
  source : String,
  shader_defs : @hashmap.HashMap[String, @moon_wgsl.ShaderDefValue],
) -> String {
  let output = @moon_wgsl.Preprocessor::default().preprocess(
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
fn upstream_compose_fixture_source(
  case_name : String,
  rel_path : String,
) -> String {
  let files = @moon_wgsl.scan_wgsl_source_files(
    "testdata/naga_oil_upstream/compose_tests/\{case_name}",
    @moon_wgsl.WgslSourceScanOptions::default(),
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
  let metadata = @moon_wgsl.get_preprocessor_metadata(
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
    is Some(@moon_wgsl.ShaderDefValue::Bool(enabled)) else {
    abort("expected HDR define")
  }
  debug_inspect(enabled, content="true")

  guard metadata.defines.get("TONEMAP_MODE")
    is Some(@moon_wgsl.ShaderDefValue::Bool(mode)) else {
    abort("expected TONEMAP_MODE define")
  }
  debug_inspect(mode, content="false")
}

///|
test "naga_oil: metadata parser keeps quoted path imports and duplicate item uses" {
  let (_, imports, _) = @moon_wgsl.get_preprocessor_data(
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
test "naga_oil: metadata parser preserves wgsl directives and effective defs" {
  let metadata = @moon_wgsl.get_preprocessor_metadata(
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
  let (_, imports, _) = @moon_wgsl.get_preprocessor_data(
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
  let (_, imports, _) = @moon_wgsl.get_preprocessor_data(
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
  let output = @moon_wgsl.Preprocessor::default().preprocess(
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
  shader_defs.set("CUSTOM_LIMIT", @moon_wgsl.ShaderDefValue::Int(42))
  let output = @moon_wgsl.Preprocessor::default().preprocess(
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
  let fallback_output = @moon_wgsl.Preprocessor::default().preprocess(
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

  let first_clause_output = @moon_wgsl.Preprocessor::default().preprocess(
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
  defs.set("THIRD_TEXTURE", @moon_wgsl.ShaderDefValue::Bool(true))
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
  let _ = @moon_wgsl.Preprocessor::default().preprocess(
    "#if TEXTURE !! true\nok\n#endif\n", unknown_operator_defs,
  ) catch {
    @moon_wgsl.PreprocessError::UnknownShaderDefOperator(operator, _) => {
      debug_inspect(operator, content="\"!!\"")
      return
    }
    _ => abort("expected unknown shader-def operator")
  }
  abort("expected unknown shader-def operator")
}

///|
test "naga_oil upstream: preprocess validates int and bool comparison values" {
  ignore(
    @moon_wgsl.Preprocessor::default().preprocess(
      "#if TEXTURE == 3\nok\n#endif\n",
      empty_shader_defs(),
    ),
  ) catch {
    @moon_wgsl.PreprocessError::UnknownShaderDef(name, _) =>
      debug_inspect(name, content="\"TEXTURE\"")
    _ => abort("expected missing shader-def error")
  }

  ignore(
    @moon_wgsl.Preprocessor::default().preprocess(
      "#if TEXTURE == 3\nok\n#endif\n",
      bool_shader_def("TEXTURE", true),
    ),
  ) catch {
    @moon_wgsl.PreprocessError::InvalidShaderDefComparisonValue(
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

  let _ = @moon_wgsl.Preprocessor::default().preprocess(
    "#if TEXTURE != false\nok\n#endif\n",
    int_shader_def("TEXTURE", 7),
  ) catch {
    @moon_wgsl.PreprocessError::InvalidShaderDefComparisonValue(
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
  let metadata = @moon_wgsl.get_preprocessor_metadata(source)
  let output = @moon_wgsl.Preprocessor::default().preprocess(
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
    is Some(@moon_wgsl.ShaderDefValue::UInt(uint_value)) else {
    abort("expected naga_oil-style unsigned positive define")
  }
  debug_inspect(uint_value.to_string(), content="\"1\"")
}

///|
test "naga_oil: define metadata rejects unsigned suffix like upstream" {
  let metadata = @moon_wgsl.get_preprocessor_metadata("#define VALUE 2u\n")
  guard metadata.defines.get("VALUE")
    is Some(@moon_wgsl.ShaderDefValue::Bool(value)) else {
    abort("expected naga_oil-style failed unsigned suffix define")
  }
  debug_inspect(value, content="false")
}

///|
test "naga_oil: preprocess accepts whitespace after hash directives" {
  let source = "# define_import_path demo::spaced\n# define MODE 2\n# if MODE==1\none\n# else if MODE==2\ntwo #MODE\n# else\nthree\n# endif\n"
  let metadata = @moon_wgsl.get_preprocessor_metadata(source)
  debug_inspect(metadata.name, content="Some(\"demo::spaced\")")
  guard metadata.defines.get("MODE")
    is Some(@moon_wgsl.ShaderDefValue::UInt(mode)) else {
    abort("expected MODE define")
  }
  debug_inspect(mode.to_string(), content="\"2\"")
  let output = @moon_wgsl.Preprocessor::default().preprocess(
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
  let output = @moon_wgsl.Preprocessor::default().preprocess(
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
  let metadata = @moon_wgsl.get_preprocessor_metadata(source)
  debug_inspect(metadata.effective_defs.contains("lower_def"), content="true")
  debug_inspect(metadata.effective_defs.contains("MIXED|PIPE"), content="true")

  let shader_defs = empty_shader_defs()
  shader_defs.set("lower_def", @moon_wgsl.ShaderDefValue::Int(7))
  shader_defs.set("MIXED|PIPE", @moon_wgsl.ShaderDefValue::Int(9))
  let output = @moon_wgsl.Preprocessor::default().preprocess(
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
test "naga_oil: define metadata consumes one token like upstream regexes" {
  let metadata = @moon_wgsl.get_preprocessor_metadata(
    "# define_import_path demo::module trailing_text\n# define COUNT 3 ignored_tail\n# define FLAG true ignored_tail\n",
  )
  debug_inspect(metadata.name, content="Some(\"demo::module\")")
  guard metadata.defines.get("COUNT")
    is Some(@moon_wgsl.ShaderDefValue::UInt(count)) else {
    abort("expected COUNT define")
  }
  debug_inspect(count.to_string(), content="\"3\"")
  guard metadata.defines.get("FLAG")
    is Some(@moon_wgsl.ShaderDefValue::Bool(flag)) else {
    abort("expected FLAG define")
  }
  debug_inspect(flag, content="true")
}

///|
test "naga_oil: define metadata follows upstream regex character classes" {
  let metadata = @moon_wgsl.get_preprocessor_metadata(
    "#define NAME+TAIL 7\n#define PLUS +1\n#define PIPE|NAME value|tail ignored\n",
  )
  guard metadata.defines.get("NAME")
    is Some(@moon_wgsl.ShaderDefValue::Bool(name_value)) else {
    abort("expected NAME define")
  }
  debug_inspect(name_value, content="true")
  guard metadata.defines.get("PLUS")
    is Some(@moon_wgsl.ShaderDefValue::Bool(plus_value)) else {
    abort("expected PLUS define")
  }
  debug_inspect(plus_value, content="true")
  guard metadata.defines.get("PIPE|NAME")
    is Some(@moon_wgsl.ShaderDefValue::Bool(pipe_value)) else {
    abort("expected PIPE|NAME define")
  }
  debug_inspect(pipe_value, content="false")
}

///|
test "naga_oil: glsl version directive captures numeric version token" {
  let output = @moon_wgsl.Preprocessor::default().preprocess(
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
test "naga_oil: wgsl directives accept upstream whitespace forms" {
  let metadata = @moon_wgsl.get_preprocessor_metadata(
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
test "naga_oil: directive section ends on non-directive identifier prefix" {
  let metadata = @moon_wgsl.get_preprocessor_metadata(
    "enable_extra();\nenable f16;\nfn shade() -> f32 {\n  return 1.0;\n}\n",
  )
  debug_inspect(metadata.wgsl_directives.enables.length(), content="0")
  debug_inspect(metadata.cleaned_source.contains("enable f16;"), content="true")
}

///|
test "naga_oil: invalid diagnostic severity reports directive error" {
  let _ = @moon_wgsl.Preprocessor::default().extract_wgsl_directives(
    "diagnostic(note, derivative_uniformity);\nfn shade() {}\n",
  ) catch {
    @moon_wgsl.PreprocessError::InvalidWgslDirective(
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
test "naga_oil: empty directive extension list reports directive error" {
  let _ = @moon_wgsl.Preprocessor::default().extract_wgsl_directives(
    "enable , ;\nfn shade() {}\n",
  ) catch {
    @moon_wgsl.PreprocessError::InvalidWgslDirective(
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
  defs.set("COUNT", @moon_wgsl.ShaderDefValue::UInt(1U))
  let _ = @moon_wgsl.Preprocessor::default().preprocess(
    "#if COUNT == 1u\nok\n#endif\n", defs,
  ) catch {
    @moon_wgsl.PreprocessError::InvalidShaderDefComparisonValue(
      name,
      value,
      expected,
      _
    ) => {
      debug_inspect(name, content="\"COUNT\"")
      debug_inspect(value, content="\"1u\"")
      debug_inspect(expected, content="\"uint\"")
      return
    }
    _ => abort("expected invalid uint comparison value")
  }
  abort("expected invalid uint comparison value")
}

///|
test "naga_oil: preprocess uses Rust lines trailing newline semantics" {
  let source = "fn main() -> f32 {\r\n  return 1.0;\r\n}\r\n"
  let output = @moon_wgsl.Preprocessor::default().preprocess(
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
