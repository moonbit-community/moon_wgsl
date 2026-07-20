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
pub fn wgsl_ir_identifier_is_predeclared_type(ident : String) -> Bool {
  ident == "array" ||
  ident == "atomic" ||
  ident == "bool" ||
  ident == "f32" ||
  ident == "f16" ||
  ident == "i32" ||
  ident == "i64" ||
  ident == "mat2x2" ||
  ident == "mat2x3" ||
  ident == "mat2x4" ||
  ident == "mat3x2" ||
  ident == "mat3x3" ||
  ident == "mat3x4" ||
  ident == "mat4x2" ||
  ident == "mat4x3" ||
  ident == "mat4x4" ||
  ident == "ptr" ||
  ident == "sampler" ||
  ident == "sampler_comparison" ||
  ident == "texture_1d" ||
  ident == "texture_2d" ||
  ident == "texture_2d_array" ||
  ident == "texture_3d" ||
  ident == "texture_cube" ||
  ident == "texture_cube_array" ||
  ident == "texture_external" ||
  ident == "texture_multisampled_2d" ||
  ident == "texture_storage_1d" ||
  ident == "texture_storage_2d" ||
  ident == "texture_storage_2d_array" ||
  ident == "texture_storage_3d" ||
  ident == "texture_depth_2d" ||
  ident == "texture_depth_2d_array" ||
  ident == "texture_depth_cube" ||
  ident == "texture_depth_cube_array" ||
  ident == "texture_depth_multisampled_2d" ||
  ident == "u32" ||
  ident == "u64" ||
  ident == "vec2" ||
  ident == "vec3" ||
  ident == "vec4"
}

///|
pub fn wgsl_ir_identifier_is_reserved(ident : String) -> Bool {
  if ident == "" {
    return false
  }
  wgsl_ir_identifier_is_predeclared_type(ident) ||
  ident == "alias" ||
  ident == "bitcast" ||
  ident == "break" ||
  ident == "case" ||
  ident == "const" ||
  ident == "const_assert" ||
  ident == "continue" ||
  ident == "continuing" ||
  ident == "default" ||
  ident == "diagnostic" ||
  ident == "discard" ||
  ident == "else" ||
  ident == "enable" ||
  ident == "false" ||
  ident == "fn" ||
  ident == "for" ||
  ident == "if" ||
  ident == "let" ||
  ident == "loop" ||
  ident == "override" ||
  ident == "return" ||
  ident == "static_assert" ||
  ident == "struct" ||
  ident == "switch" ||
  ident == "true" ||
  ident == "type" ||
  ident == "var" ||
  ident == "while" ||
  ident == "CompileShader" ||
  ident == "ComputeShader" ||
  ident == "DomainShader" ||
  ident == "GeometryShader" ||
  ident == "Hullshader" ||
  ident == "NULL" ||
  ident == "Self" ||
  ident == "abstract" ||
  ident == "active" ||
  ident == "alignas" ||
  ident == "alignof" ||
  ident == "as" ||
  ident == "asm" ||
  ident == "asm_fragment" ||
  ident == "async" ||
  ident == "attribute" ||
  ident == "auto" ||
  ident == "await" ||
  ident == "become" ||
  ident == "binding_array" ||
  ident == "cast" ||
  ident == "catch" ||
  ident == "class" ||
  ident == "co_await" ||
  ident == "co_return" ||
  ident == "co_yield" ||
  ident == "coherent" ||
  ident == "column_major" ||
  ident == "common" ||
  ident == "compile" ||
  ident == "compile_fragment" ||
  ident == "concept" ||
  ident == "const_cast" ||
  ident == "consteval" ||
  ident == "constexpr" ||
  ident == "constinit" ||
  ident == "crate" ||
  ident == "debugger" ||
  ident == "decltype" ||
  ident == "delete" ||
  ident == "demote" ||
  ident == "demote_to_helper" ||
  ident == "do" ||
  ident == "dynamic_cast" ||
  ident == "enum" ||
  ident == "explicit" ||
  ident == "export" ||
  ident == "extends" ||
  ident == "extern" ||
  ident == "external" ||
  ident == "fallthrough" ||
  ident == "filter" ||
  ident == "final" ||
  ident == "finally" ||
  ident == "friend" ||
  ident == "from" ||
  ident == "fxgroup" ||
  ident == "get" ||
  ident == "goto" ||
  ident == "groupshared" ||
  ident == "handle" ||
  ident == "highp" ||
  ident == "impl" ||
  ident == "implements" ||
  ident == "import" ||
  ident == "inline" ||
  ident == "inout" ||
  ident == "instanceof" ||
  ident == "interface" ||
  ident == "layout" ||
  ident == "lowp" ||
  ident == "macro" ||
  ident == "macro_rules" ||
  ident == "match" ||
  ident == "mediump" ||
  ident == "meta" ||
  ident == "mod" ||
  ident == "module" ||
  ident == "move" ||
  ident == "mut" ||
  ident == "mutable" ||
  ident == "namespace" ||
  ident == "new" ||
  ident == "nil" ||
  ident == "noexcept" ||
  ident == "noinline" ||
  ident == "nointerpolation" ||
  ident == "noperspective" ||
  ident == "null" ||
  ident == "nullptr" ||
  ident == "of" ||
  ident == "operator" ||
  ident == "package" ||
  ident == "packoffset" ||
  ident == "partition" ||
  ident == "pass" ||
  ident == "patch" ||
  ident == "pixelfragment" ||
  ident == "precise" ||
  ident == "precision" ||
  ident == "premerge" ||
  ident == "priv" ||
  ident == "protected" ||
  ident == "pub" ||
  ident == "public" ||
  ident == "readonly" ||
  ident == "ref" ||
  ident == "regardless" ||
  ident == "register" ||
  ident == "reinterpret_cast" ||
  ident == "requires" ||
  ident == "resource" ||
  ident == "restrict" ||
  ident == "self" ||
  ident == "set" ||
  ident == "shared" ||
  ident == "signed" ||
  ident == "sizeof" ||
  ident == "smooth" ||
  ident == "snorm" ||
  ident == "static" ||
  ident == "static_cast" ||
  ident == "std" ||
  ident == "subroutine" ||
  ident == "super" ||
  ident == "target" ||
  ident == "template" ||
  ident == "this" ||
  ident == "thread_local" ||
  ident == "throw" ||
  ident == "trait" ||
  ident == "try" ||
  ident == "typedef" ||
  ident == "typeid" ||
  ident == "typename" ||
  ident == "typeof" ||
  ident == "union" ||
  ident == "unless" ||
  ident == "unorm" ||
  ident == "unsafe" ||
  ident == "unsized" ||
  ident == "use" ||
  ident == "using" ||
  ident == "varying" ||
  ident == "virtual" ||
  ident == "volatile" ||
  ident == "wgsl" ||
  ident == "where" ||
  ident == "with" ||
  ident == "writeonly" ||
  ident == "yield"
}

///|
pub fn wgsl_ir_identifier_is_builtin_function(ident : String) -> Bool {
  ident == "abs" ||
  ident == "acos" ||
  ident == "acosh" ||
  ident == "all" ||
  ident == "any" ||
  ident == "arrayLength" ||
  ident == "asin" ||
  ident == "asinh" ||
  ident == "atan" ||
  ident == "atan2" ||
  ident == "atanh" ||
  ident == "atomicAdd" ||
  ident == "atomicAnd" ||
  ident == "atomicCompareExchangeWeak" ||
  ident == "atomicExchange" ||
  ident == "atomicLoad" ||
  ident == "atomicMax" ||
  ident == "atomicMin" ||
  ident == "atomicOr" ||
  ident == "atomicStore" ||
  ident == "atomicSub" ||
  ident == "atomicXor" ||
  ident == "ceil" ||
  ident == "clamp" ||
  ident == "cos" ||
  ident == "cosh" ||
  ident == "countLeadingZeros" ||
  ident == "countOneBits" ||
  ident == "countTrailingZeros" ||
  ident == "cross" ||
  ident == "degrees" ||
  ident == "determinant" ||
  ident == "distance" ||
  ident == "dot" ||
  ident == "dot4I8Packed" ||
  ident == "dot4U8Packed" ||
  ident == "dpdx" ||
  ident == "dpdxCoarse" ||
  ident == "dpdxFine" ||
  ident == "dpdy" ||
  ident == "dpdyCoarse" ||
  ident == "dpdyFine" ||
  ident == "exp" ||
  ident == "exp2" ||
  ident == "extractBits" ||
  ident == "faceForward" ||
  ident == "firstLeadingBit" ||
  ident == "firstTrailingBit" ||
  ident == "floor" ||
  ident == "fma" ||
  ident == "fract" ||
  ident == "frexp" ||
  ident == "fwidth" ||
  ident == "fwidthCoarse" ||
  ident == "fwidthFine" ||
  ident == "insertBits" ||
  ident == "inverse" ||
  ident == "inverseSqrt" ||
  ident == "isInf" ||
  ident == "isNan" ||
  ident == "ldexp" ||
  ident == "length" ||
  ident == "log" ||
  ident == "log2" ||
  ident == "max" ||
  ident == "min" ||
  ident == "mix" ||
  ident == "modf" ||
  ident == "normalize" ||
  ident == "pack2x16float" ||
  ident == "pack2x16snorm" ||
  ident == "pack2x16unorm" ||
  ident == "pack4x8snorm" ||
  ident == "pack4x8unorm" ||
  ident == "pack4xI8" ||
  ident == "pack4xI8Clamp" ||
  ident == "pack4xU8" ||
  ident == "pack4xU8Clamp" ||
  ident == "pow" ||
  ident == "quantizeToF16" ||
  ident == "radians" ||
  ident == "reflect" ||
  ident == "refract" ||
  ident == "reverseBits" ||
  ident == "round" ||
  ident == "saturate" ||
  ident == "sign" ||
  ident == "sin" ||
  ident == "sinh" ||
  ident == "smoothstep" ||
  ident == "sqrt" ||
  ident == "step" ||
  ident == "subgroupBallot" ||
  ident == "subgroupBroadcast" ||
  ident == "subgroupElect" ||
  ident == "subgroupShuffle" ||
  ident == "subgroupShuffleDown" ||
  ident == "subgroupShuffleUp" ||
  ident == "subgroupShuffleXor" ||
  ident == "tan" ||
  ident == "tanh" ||
  ident == "textureDimensions" ||
  ident == "textureGather" ||
  ident == "textureGatherCompare" ||
  ident == "textureLoad" ||
  ident == "textureNumLayers" ||
  ident == "textureNumLevels" ||
  ident == "textureNumSamples" ||
  ident == "textureSample" ||
  ident == "textureSampleBaseClampToEdge" ||
  ident == "textureSampleBias" ||
  ident == "textureSampleCompare" ||
  ident == "textureSampleCompareLevel" ||
  ident == "textureSampleGrad" ||
  ident == "textureSampleLevel" ||
  ident == "textureStore" ||
  ident == "transpose" ||
  ident == "trunc" ||
  ident == "unpack2x16float" ||
  ident == "unpack2x16snorm" ||
  ident == "unpack2x16unorm" ||
  ident == "unpack4x8snorm" ||
  ident == "unpack4x8unorm" ||
  ident == "unpack4xI8" ||
  ident == "unpack4xU8" ||
  ident == "workgroupBarrier" ||
  ident == "workgroupUniformLoad"
}

///|
pub fn wgsl_ir_identifier_ends_with_digit(ident : String) -> Bool {
  if ident == "" {
    return false
  }
  ident.has_suffix("0") ||
  ident.has_suffix("1") ||
  ident.has_suffix("2") ||
  ident.has_suffix("3") ||
  ident.has_suffix("4") ||
  ident.has_suffix("5") ||
  ident.has_suffix("6") ||
  ident.has_suffix("7") ||
  ident.has_suffix("8") ||
  ident.has_suffix("9")
}

///|
pub fn sanitize_wgsl_ir_identifier(ident : String) -> String {
  let had_trailing_separator = ident.has_suffix("_")
  let mut out = ident
  while out.has_suffix("_") {
    out = out[:out.length() - 1].to_owned()
  }
  while out.has_prefix("__") {
    out = out[1:out.length()].to_owned()
  }
  if out == "" {
    out = "unnamed"
  }
  if out.has_prefix("_naga") {
    out = "gen_\{out}"
  }
  if wgsl_ir_identifier_is_reserved(out) {
    out = "\{out}_wgsl"
  } else if had_trailing_separator && wgsl_ir_identifier_ends_with_digit(out) {
    out = "\{out}_"
  }
  out
}
