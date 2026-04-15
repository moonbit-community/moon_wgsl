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
    is Some(@moon_wgsl.ShaderDefValue::UInt(mode)) else {
    abort("expected TONEMAP_MODE define")
  }
  debug_inspect(mode.to_string(), content="\"2\"")
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
}
