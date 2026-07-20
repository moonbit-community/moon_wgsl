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
fn const_eval_clamp_type(
  values : Array[ConstEvalValue],
) -> ConstEvalType raise WeslCompileError {
  let mut has_f32 = false
  let mut has_abstract_float = false
  let mut has_i32 = false
  let mut has_u32 = false
  for value in values {
    match value.value_type() {
      Void =>
        raise WeslCompileError::Validation(
          "cannot use void with clamp arguments",
        )
      Bool =>
        raise WeslCompileError::Validation(
          "cannot use bool with clamp arguments",
        )
      F32 => has_f32 = true
      AbstractFloat => has_abstract_float = true
      I32 => has_i32 = true
      U32 => has_u32 = true
      AbstractInt => ()
      FrexpAbstractResult | FrexpF32Result =>
        raise WeslCompileError::Validation(
          "cannot use frexp result with clamp arguments",
        )
      Vector(_, _) =>
        raise WeslCompileError::Validation(
          "cannot use vector with clamp arguments",
        )
      Matrix(_, _, _) | Array(_, _) =>
        raise WeslCompileError::Validation(
          "cannot use aggregate with clamp arguments",
        )
      Struct(_) =>
        raise WeslCompileError::Validation(
          "cannot use struct with clamp arguments",
        )
    }
  }
  if has_u32 && has_i32 {
    raise WeslCompileError::Validation("ambiguous clamp argument types")
  }
  if has_f32 {
    return ConstEvalType::F32
  }
  if has_abstract_float {
    return ConstEvalType::F32
  }
  if has_u32 {
    return ConstEvalType::U32
  }
  ConstEvalType::I32
}

///|
fn const_eval_numeric_join_type(
  values : Array[ConstEvalValue],
  context : String,
) -> ConstEvalType raise WeslCompileError {
  let mut has_f32 = false
  let mut has_abstract_float = false
  let mut has_i32 = false
  let mut has_u32 = false
  for value in values {
    match value.value_type() {
      Void =>
        raise WeslCompileError::Validation(
          "cannot use void with \{context} arguments",
        )
      Bool =>
        raise WeslCompileError::Validation(
          "cannot use bool with \{context} arguments",
        )
      F32 => has_f32 = true
      AbstractFloat => has_abstract_float = true
      I32 => has_i32 = true
      U32 => has_u32 = true
      AbstractInt => ()
      FrexpAbstractResult | FrexpF32Result =>
        raise WeslCompileError::Validation(
          "cannot use frexp result with \{context} arguments",
        )
      Vector(_, _) =>
        raise WeslCompileError::Validation(
          "cannot use vector with \{context} arguments",
        )
      Matrix(_, _, _) | Array(_, _) =>
        raise WeslCompileError::Validation(
          "cannot use aggregate with \{context} arguments",
        )
      Struct(_) =>
        raise WeslCompileError::Validation(
          "cannot use struct with \{context} arguments",
        )
    }
  }
  if has_u32 && has_i32 {
    raise WeslCompileError::Validation("ambiguous \{context} argument types")
  }
  if has_f32 {
    return ConstEvalType::F32
  }
  if has_abstract_float {
    return ConstEvalType::AbstractFloat
  }
  if has_u32 {
    return ConstEvalType::U32
  }
  if has_i32 {
    return ConstEvalType::I32
  }
  ConstEvalType::AbstractInt
}

///|
fn const_eval_select_join_type(
  first : ConstEvalValue,
  second : ConstEvalValue,
) -> ConstEvalType raise WeslCompileError {
  match (first.value_type(), second.value_type()) {
    (Bool, Bool) => ConstEvalType::Bool
    (Bool, _) | (_, Bool) =>
      raise WeslCompileError::Validation(
        "`select` 1st and 2nd arguments are incompatible",
      )
    _ => const_eval_numeric_join_type([first, second], "`select` 1st and 2nd")
  }
}

///|
fn const_eval_builtin_vector_width(
  name : String,
  args : Array[ConstEvalValue],
) -> Int? raise WeslCompileError {
  const_eval_vector_width_for_values(args, "`\{name}`")
}

///|
fn const_eval_apply_clamp(
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 3 {
    raise WeslCompileError::Validation("clamp expects three arguments")
  }
  match const_eval_builtin_vector_width("clamp", args) {
    Some(width) => {
      let values : Array[ConstEvalValue] = []
      for index in 0..<width {
        values.push(
          const_eval_apply_clamp([
            const_eval_vector_component(args[0], index),
            const_eval_vector_component(args[1], index),
            const_eval_vector_component(args[2], index),
          ]),
        )
      }
      return const_eval_vector_from_elements(width, values, "clamp")
    }
    None => ()
  }
  let target = const_eval_clamp_type(args)
  match target {
    F32 => {
      let value = const_eval_require_f32(args[0], "clamp")
      let min_value = const_eval_require_f32(args[1], "clamp")
      let max_value = const_eval_require_f32(args[2], "clamp")
      ConstEvalValue::F32(Float::clamp(value, min=min_value, max=max_value))
    }
    U32 => {
      let value = const_eval_require_u32(args[0], "clamp")
      let min_value = const_eval_require_u32(args[1], "clamp")
      let max_value = const_eval_require_u32(args[2], "clamp")
      ConstEvalValue::U32(Int64::clamp(value, min=min_value, max=max_value))
    }
    _ => {
      let value = const_eval_require_i32(args[0], "clamp")
      let min_value = const_eval_require_i32(args[1], "clamp")
      let max_value = const_eval_require_i32(args[2], "clamp")
      ConstEvalValue::I32(Int64::clamp(value, min=min_value, max=max_value))
    }
  }
}

///|
fn const_eval_apply_saturate(
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 1 {
    let signature = const_eval_format_call_signature("saturate", args)
    raise WeslCompileError::Validation(
      "invalid function call signature: `\{signature}`",
    )
  }
  match const_eval_builtin_vector_width("saturate", args) {
    Some(width) => {
      let values : Array[ConstEvalValue] = []
      for index in 0..<width {
        values.push(
          const_eval_apply_saturate([
            const_eval_vector_component(args[0], index),
          ]),
        )
      }
      return const_eval_vector_from_elements(width, values, "saturate")
    }
    None => ()
  }
  match args[0] {
    Bool(_) | I32(_) | U32(_) =>
      raise WeslCompileError::Validation("`clamp` arguments are incompatible")
    FrexpAbstract(_, _) | FrexpF32(_, _) =>
      raise WeslCompileError::Validation("`clamp` arguments are incompatible")
    Vector(_, _, _) =>
      raise WeslCompileError::Validation("`clamp` arguments are incompatible")
    Matrix(_, _, _, _) | Array(_, _, _) =>
      raise WeslCompileError::Validation("`clamp` arguments are incompatible")
    Struct(_, _) =>
      raise WeslCompileError::Validation("`clamp` arguments are incompatible")
    AbstractInt(number) =>
      ConstEvalValue::AbstractFloat(
        Double::clamp(number.to_double(), min=0.0, max=1.0),
        true,
      )
    AbstractFloat(number, _) =>
      ConstEvalValue::AbstractFloat(
        Double::clamp(number, min=0.0, max=1.0),
        true,
      )
    F32(number) =>
      ConstEvalValue::F32(
        Float::clamp(
          number,
          min=Float::from_double(0.0),
          max=Float::from_double(1.0),
        ),
      )
  }
}

///|
fn const_eval_apply_min_or_max(
  name : String,
  args : Array[ConstEvalValue],
  choose_min : Bool,
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 2 {
    raise WeslCompileError::Validation("`\{name}` expects two arguments")
  }
  match const_eval_builtin_vector_width(name, args) {
    Some(width) => {
      let values : Array[ConstEvalValue] = []
      for index in 0..<width {
        values.push(
          const_eval_apply_min_or_max(
            name,
            [
              const_eval_vector_component(args[0], index),
              const_eval_vector_component(args[1], index),
            ],
            choose_min,
          ),
        )
      }
      return const_eval_vector_from_elements(width, values, name)
    }
    None => ()
  }
  let target = const_eval_numeric_join_type(args, "`\{name}`")
  match target {
    Void =>
      raise WeslCompileError::Validation(
        "cannot use void with `\{name}` arguments",
      )
    AbstractFloat => {
      let left = const_eval_to_abstract_float(args[0], name)
      let right = const_eval_to_abstract_float(args[1], name)
      ConstEvalValue::AbstractFloat(
        if choose_min {
          if left <= right {
            left
          } else {
            right
          }
        } else if left >= right {
          left
        } else {
          right
        },
        true,
      )
    }
    F32 => {
      let left = const_eval_require_f32(args[0], name)
      let right = const_eval_require_f32(args[1], name)
      ConstEvalValue::F32(
        if choose_min {
          if left <= right {
            left
          } else {
            right
          }
        } else if left >= right {
          left
        } else {
          right
        },
      )
    }
    U32 => {
      let left = const_eval_require_u32(args[0], name)
      let right = const_eval_require_u32(args[1], name)
      ConstEvalValue::U32(
        if choose_min {
          if left <= right {
            left
          } else {
            right
          }
        } else if left >= right {
          left
        } else {
          right
        },
      )
    }
    I32 => {
      let left = const_eval_require_i32(args[0], name)
      let right = const_eval_require_i32(args[1], name)
      ConstEvalValue::I32(
        if choose_min {
          if left <= right {
            left
          } else {
            right
          }
        } else if left >= right {
          left
        } else {
          right
        },
      )
    }
    AbstractInt => {
      let left = const_eval_require_abstract_int(args[0], name)
      let right = const_eval_require_abstract_int(args[1], name)
      ConstEvalValue::AbstractInt(
        if choose_min {
          if left <= right {
            left
          } else {
            right
          }
        } else if left >= right {
          left
        } else {
          right
        },
      )
    }
    Bool =>
      raise WeslCompileError::Validation(
        "cannot use bool with `\{name}` arguments",
      )
    FrexpAbstractResult | FrexpF32Result =>
      raise WeslCompileError::Validation(
        "cannot use frexp result with `\{name}` arguments",
      )
    Vector(_, _) =>
      raise WeslCompileError::Validation(
        "cannot use vector with `\{name}` arguments",
      )
    Matrix(_, _, _) | Array(_, _) =>
      raise WeslCompileError::Validation(
        "cannot use aggregate with `\{name}` arguments",
      )
    Struct(_) =>
      raise WeslCompileError::Validation(
        "cannot use struct with `\{name}` arguments",
      )
  }
}

///|
fn const_eval_abs_i64(value : Int64) -> Int64 {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn const_eval_abs_double(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn const_eval_abs_float(value : Float) -> Float {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn const_eval_apply_abs(
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 1 {
    raise WeslCompileError::Validation("`abs` expects one argument")
  }
  match args[0] {
    Bool(_) =>
      raise WeslCompileError::Validation(
        "`abs` expects a scalar or vector of scalar argument",
      )
    AbstractInt(number) =>
      ConstEvalValue::AbstractInt(const_eval_abs_i64(number))
    I32(number) => ConstEvalValue::I32(const_eval_abs_i64(number))
    U32(number) => ConstEvalValue::U32(number)
    AbstractFloat(number, f32_lossless) =>
      ConstEvalValue::AbstractFloat(const_eval_abs_double(number), f32_lossless)
    F32(number) => ConstEvalValue::F32(const_eval_abs_float(number))
    FrexpAbstract(_, _) | FrexpF32(_, _) =>
      raise WeslCompileError::Validation(
        "`abs` expects a scalar or vector of scalar argument",
      )
    Matrix(_, _, _, _) | Array(_, _, _) =>
      raise WeslCompileError::Validation(
        "`abs` expects a scalar or vector of scalar argument",
      )
    Struct(_, _) =>
      raise WeslCompileError::Validation(
        "`abs` expects a scalar or vector of scalar argument",
      )
    Vector(width, _, elements) => {
      let values : Array[ConstEvalValue] = []
      for element in elements {
        values.push(const_eval_apply_abs([element]))
      }
      const_eval_vector_from_elements(width, values, "abs")
    }
  }
}

///|
fn const_eval_apply_select(
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 3 {
    raise WeslCompileError::Validation("`select` expects three arguments")
  }
  match const_eval_builtin_vector_width("select", args) {
    Some(width) => {
      let values : Array[ConstEvalValue] = []
      for index in 0..<width {
        let condition = const_eval_require_bool(
          const_eval_vector_component(args[2], index),
          "select",
        )
        values.push(
          if condition {
            const_eval_vector_component(args[1], index)
          } else {
            const_eval_vector_component(args[0], index)
          },
        )
      }
      return const_eval_vector_from_elements(width, values, "select")
    }
    None => ()
  }
  let condition = match args[2] {
    Bool(value) => value
    _ =>
      raise WeslCompileError::Validation(
        "`select` 3rd argument must be a boolean or vector of boolean",
      )
  }
  let target = const_eval_select_join_type(args[0], args[1])
  let chosen = if condition { args[1] } else { args[0] }
  const_eval_convert_to_type(chosen, target, "select")
}

///|
fn const_eval_apply_bool_builtin(
  name : String,
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 1 {
    raise WeslCompileError::Validation("`\{name}` expects one argument")
  }
  match args[0] {
    Vector(_, _, elements) => {
      let mut result = name == "all"
      for element in elements {
        let value = const_eval_require_bool(element, name)
        if name == "all" {
          result = result && value
        } else {
          result = result || value
        }
      }
      ConstEvalValue::Bool(result)
    }
    _ => ConstEvalValue::Bool(const_eval_require_bool(args[0], name))
  }
}

///|
fn const_eval_require_float_builtin_arg(
  name : String,
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 1 {
    raise WeslCompileError::Validation("`\{name}` expects one argument")
  }
  match args[0] {
    Bool(_)
    | I32(_)
    | U32(_)
    | FrexpAbstract(_, _)
    | FrexpF32(_, _)
    | Struct(_, _) =>
      raise WeslCompileError::Validation(
        "`\{name}` expects a float or vector of float argument",
      )
    value => value
  }
}

///|
fn const_eval_apply_float_unary_builtin(
  name : String,
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  let value = const_eval_require_float_builtin_arg(name, args)
  match value {
    Vector(width, _, elements) => {
      let values : Array[ConstEvalValue] = []
      for element in elements {
        values.push(const_eval_apply_float_unary_builtin(name, [element]))
      }
      const_eval_vector_from_elements(width, values, name)
    }
    Struct(_, _) =>
      raise WeslCompileError::Validation(
        "`\{name}` expects a float or vector of float argument",
      )
    Matrix(_, _, _, _) | Array(_, _, _) =>
      raise WeslCompileError::Validation(
        "`\{name}` expects a float or vector of float argument",
      )
    AbstractInt(number) =>
      ConstEvalValue::AbstractFloat(
        match name {
          "floor" => number.to_double().floor()
          "ceil" => number.to_double().ceil()
          "round" => number.to_double().round()
          "trunc" => number.to_double().trunc()
          "fract" => number.to_double() - number.to_double().floor()
          "sqrt" => number.to_double().sqrt()
          "inverseSqrt" => 1.0 / number.to_double().sqrt()
          "exp" => @math.exp(number.to_double())
          "exp2" => @math.pow(2.0, number.to_double())
          "log" => @math.ln(number.to_double())
          "log2" => @math.log2(number.to_double())
          "sin" => @math.sin(number.to_double())
          "cos" => @math.cos(number.to_double())
          "tan" => @math.tan(number.to_double())
          "asin" => @math.asin(number.to_double())
          "acos" => @math.acos(number.to_double())
          "atan" => @math.atan(number.to_double())
          "sinh" => @math.sinh(number.to_double())
          "cosh" => @math.cosh(number.to_double())
          "tanh" => @math.tanh(number.to_double())
          "radians" => number.to_double() * @math.acos(-1.0) / 180.0
          "degrees" => number.to_double() * 180.0 / @math.acos(-1.0)
          _ =>
            raise WeslCompileError::Validation(
              "unsupported float builtin `\{name}`",
            )
        },
        true,
      )
    AbstractFloat(number, _) =>
      ConstEvalValue::AbstractFloat(
        match name {
          "floor" => number.floor()
          "ceil" => number.ceil()
          "round" => number.round()
          "trunc" => number.trunc()
          "fract" => number - number.floor()
          "sqrt" => number.sqrt()
          "inverseSqrt" => 1.0 / number.sqrt()
          "exp" => @math.exp(number)
          "exp2" => @math.pow(2.0, number)
          "log" => @math.ln(number)
          "log2" => @math.log2(number)
          "sin" => @math.sin(number)
          "cos" => @math.cos(number)
          "tan" => @math.tan(number)
          "asin" => @math.asin(number)
          "acos" => @math.acos(number)
          "atan" => @math.atan(number)
          "sinh" => @math.sinh(number)
          "cosh" => @math.cosh(number)
          "tanh" => @math.tanh(number)
          "radians" => number * @math.acos(-1.0) / 180.0
          "degrees" => number * 180.0 / @math.acos(-1.0)
          _ =>
            raise WeslCompileError::Validation(
              "unsupported float builtin `\{name}`",
            )
        },
        true,
      )
    F32(number) =>
      ConstEvalValue::F32(
        match name {
          "floor" => number.floor()
          "ceil" => number.ceil()
          "round" => number.round()
          "trunc" => number.trunc()
          "fract" => number - number.floor()
          "sqrt" => number.sqrt()
          "inverseSqrt" => Float::from_double(1.0) / number.sqrt()
          "exp" => Float::from_double(@math.exp(number.to_double()))
          "exp2" => Float::from_double(@math.pow(2.0, number.to_double()))
          "log" => Float::from_double(@math.ln(number.to_double()))
          "log2" => Float::from_double(@math.log2(number.to_double()))
          "sin" => Float::from_double(@math.sin(number.to_double()))
          "cos" => Float::from_double(@math.cos(number.to_double()))
          "tan" => Float::from_double(@math.tan(number.to_double()))
          "asin" => Float::from_double(@math.asin(number.to_double()))
          "acos" => Float::from_double(@math.acos(number.to_double()))
          "atan" => Float::from_double(@math.atan(number.to_double()))
          "sinh" => Float::from_double(@math.sinh(number.to_double()))
          "cosh" => Float::from_double(@math.cosh(number.to_double()))
          "tanh" => Float::from_double(@math.tanh(number.to_double()))
          "radians" =>
            Float::from_double(number.to_double() * @math.acos(-1.0) / 180.0)
          "degrees" =>
            Float::from_double(number.to_double() * 180.0 / @math.acos(-1.0))
          _ =>
            raise WeslCompileError::Validation(
              "unsupported float builtin `\{name}`",
            )
        },
      )
    Bool(_) | I32(_) | U32(_) | FrexpAbstract(_, _) | FrexpF32(_, _) =>
      raise WeslCompileError::Validation(
        "`\{name}` expects a float or vector of float argument",
      )
  }
}

///|
fn const_eval_float_binary_type(
  name : String,
  args : Array[ConstEvalValue],
) -> ConstEvalType raise WeslCompileError {
  if args.length() != 2 {
    raise WeslCompileError::Validation("`\{name}` expects two arguments")
  }
  let mut has_f32 = false
  for arg in args {
    match arg {
      Bool(_)
      | I32(_)
      | U32(_)
      | FrexpAbstract(_, _)
      | FrexpF32(_, _)
      | Struct(_, _)
      | Matrix(_, _, _, _)
      | Array(_, _, _)
      | Vector(_, _, _) =>
        raise WeslCompileError::Validation(
          "`\{name}` expects a float or vector of float argument",
        )
      F32(_) => has_f32 = true
      AbstractInt(_) | AbstractFloat(_, _) => ()
    }
  }
  if has_f32 {
    ConstEvalType::F32
  } else {
    ConstEvalType::AbstractFloat
  }
}

///|
fn const_eval_apply_float_binary_builtin(
  name : String,
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  match const_eval_builtin_vector_width(name, args) {
    Some(width) => {
      let values : Array[ConstEvalValue] = []
      for index in 0..<width {
        values.push(
          const_eval_apply_float_binary_builtin(name, [
            const_eval_vector_component(args[0], index),
            const_eval_vector_component(args[1], index),
          ]),
        )
      }
      return const_eval_vector_from_elements(width, values, name)
    }
    None => ()
  }
  let target = const_eval_float_binary_type(name, args)
  match target {
    F32 => {
      let left = const_eval_require_f32(args[0], name)
      let right = const_eval_require_f32(args[1], name)
      ConstEvalValue::F32(
        Float::from_double(
          match name {
            "pow" => @math.pow(left.to_double(), right.to_double())
            "atan2" => @math.atan2(left.to_double(), right.to_double())
            _ =>
              raise WeslCompileError::Validation(
                "unsupported float builtin `\{name}`",
              )
          },
        ),
      )
    }
    _ => {
      let left = const_eval_to_abstract_float(args[0], name)
      let right = const_eval_to_abstract_float(args[1], name)
      ConstEvalValue::AbstractFloat(
        match name {
          "pow" => @math.pow(left, right)
          "atan2" => @math.atan2(left, right)
          _ =>
            raise WeslCompileError::Validation(
              "unsupported float builtin `\{name}`",
            )
        },
        true,
      )
    }
  }
}

///|
fn const_eval_ldexp_factor(exponent : Int64) -> Double {
  @math.pow(2.0, exponent.to_double())
}

///|
fn const_eval_apply_ldexp(
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 2 {
    let signature = const_eval_format_call_signature("ldexp", args)
    raise WeslCompileError::Validation(
      "invalid function call signature: `\{signature}`",
    )
  }
  let exponent = match args[1] {
    AbstractInt(number) => number
    I32(number) => number
    _ =>
      raise WeslCompileError::Validation(
        "`ldexp` with scalar arguments expects a float and a i32 arguments",
      )
  }
  match args[0] {
    Bool(_)
    | I32(_)
    | U32(_)
    | FrexpAbstract(_, _)
    | FrexpF32(_, _)
    | Struct(_, _)
    | Matrix(_, _, _, _)
    | Array(_, _, _)
    | Vector(_, _, _) =>
      raise WeslCompileError::Validation(
        "`ldexp` with scalar arguments expects a float and a i32 arguments",
      )
    F32(number) =>
      ConstEvalValue::F32(
        Float::from_double(
          number.to_double() * const_eval_ldexp_factor(exponent),
        ),
      )
    AbstractInt(number) =>
      match args[1] {
        I32(_) =>
          ConstEvalValue::F32(
            Float::from_double(
              number.to_double() * const_eval_ldexp_factor(exponent),
            ),
          )
        _ =>
          ConstEvalValue::AbstractFloat(
            number.to_double() * const_eval_ldexp_factor(exponent),
            true,
          )
      }
    AbstractFloat(number, _) =>
      match args[1] {
        I32(_) =>
          ConstEvalValue::F32(
            Float::from_double(number * const_eval_ldexp_factor(exponent)),
          )
        _ =>
          ConstEvalValue::AbstractFloat(
            number * const_eval_ldexp_factor(exponent),
            true,
          )
      }
  }
}

///|
fn const_eval_require_float_builtin_double(
  value : ConstEvalValue,
  name : String,
) -> Double raise WeslCompileError {
  match value {
    Bool(_)
    | I32(_)
    | U32(_)
    | FrexpAbstract(_, _)
    | FrexpF32(_, _)
    | Struct(_, _)
    | Matrix(_, _, _, _)
    | Array(_, _, _)
    | Vector(_, _, _) =>
      raise WeslCompileError::Validation(
        "`\{name}` expects a float or vector of float argument",
      )
    AbstractInt(number) => number.to_double()
    AbstractFloat(number, _) => number
    F32(number) => number.to_double()
  }
}

///|
fn const_eval_apply_step(
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 2 {
    raise WeslCompileError::Validation("`step` expects two arguments")
  }
  match const_eval_builtin_vector_width("step", args) {
    Some(width) => {
      let values : Array[ConstEvalValue] = []
      for index in 0..<width {
        values.push(
          const_eval_apply_step([
            const_eval_vector_component(args[0], index),
            const_eval_vector_component(args[1], index),
          ]),
        )
      }
      return const_eval_vector_from_elements(width, values, "step")
    }
    None => ()
  }
  let edge = const_eval_require_float_builtin_double(args[0], "step")
  let value = const_eval_require_float_builtin_double(args[1], "step")
  ConstEvalValue::AbstractFloat(if value < edge { 0.0 } else { 1.0 }, true)
}

///|
fn const_eval_mix_type(
  args : Array[ConstEvalValue],
) -> ConstEvalType raise WeslCompileError {
  if args.length() != 3 {
    raise WeslCompileError::Validation("`mix` expects three arguments")
  }
  let mut has_f32 = false
  for arg in args {
    match arg {
      Bool(_)
      | I32(_)
      | U32(_)
      | FrexpAbstract(_, _)
      | FrexpF32(_, _)
      | Struct(_, _)
      | Matrix(_, _, _, _)
      | Array(_, _, _)
      | Vector(_, _, _) =>
        raise WeslCompileError::Validation("`mix` arguments are incompatible")
      F32(_) => has_f32 = true
      AbstractInt(_) | AbstractFloat(_, _) => ()
    }
  }
  if has_f32 {
    ConstEvalType::F32
  } else {
    ConstEvalType::AbstractFloat
  }
}

///|
fn const_eval_apply_mix(
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  match const_eval_builtin_vector_width("mix", args) {
    Some(width) => {
      let values : Array[ConstEvalValue] = []
      for index in 0..<width {
        values.push(
          const_eval_apply_mix([
            const_eval_vector_component(args[0], index),
            const_eval_vector_component(args[1], index),
            const_eval_vector_component(args[2], index),
          ]),
        )
      }
      return const_eval_vector_from_elements(width, values, "mix")
    }
    None => ()
  }
  let target = const_eval_mix_type(args)
  match target {
    F32 => {
      let first = const_eval_require_f32(args[0], "mix")
      let second = const_eval_require_f32(args[1], "mix")
      let factor = const_eval_require_f32(args[2], "mix")
      ConstEvalValue::F32(
        first * (Float::from_double(1.0) - factor) + second * factor,
      )
    }
    _ => {
      let first = const_eval_to_abstract_float(args[0], "mix")
      let second = const_eval_to_abstract_float(args[1], "mix")
      let factor = const_eval_to_abstract_float(args[2], "mix")
      ConstEvalValue::AbstractFloat(
        first * (1.0 - factor) + second * factor,
        true,
      )
    }
  }
}

///|
fn const_eval_sign_i64(value : Int64) -> Int64 {
  if value < 0 {
    -1L
  } else if value > 0 {
    1L
  } else {
    0L
  }
}

///|
fn const_eval_sign_double(value : Double) -> Double {
  if value < 0.0 {
    -1.0
  } else if value > 0.0 {
    1.0
  } else {
    0.0
  }
}

///|
fn const_eval_sign_float(value : Float) -> Float {
  if value < 0.0 {
    -1.0
  } else if value > 0.0 {
    1.0
  } else {
    0.0
  }
}

///|
fn const_eval_apply_sign(
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 1 {
    raise WeslCompileError::Validation("`sign` expects one argument")
  }
  match args[0] {
    Bool(_) =>
      raise WeslCompileError::Validation(
        "`sign` expects a float or vector of float argument",
      )
    AbstractInt(number) =>
      ConstEvalValue::AbstractInt(const_eval_sign_i64(number))
    I32(number) => ConstEvalValue::I32(const_eval_sign_i64(number))
    U32(number) => ConstEvalValue::U32(if number == 0 { 0L } else { 1L })
    AbstractFloat(number, _) =>
      ConstEvalValue::AbstractFloat(const_eval_sign_double(number), true)
    F32(number) => ConstEvalValue::F32(const_eval_sign_float(number))
    FrexpAbstract(_, _) | FrexpF32(_, _) =>
      raise WeslCompileError::Validation(
        "`sign` expects a float or vector of float argument",
      )
    Matrix(_, _, _, _) | Array(_, _, _) =>
      raise WeslCompileError::Validation(
        "`sign` expects a float or vector of float argument",
      )
    Struct(_, _) =>
      raise WeslCompileError::Validation(
        "`sign` expects a float or vector of float argument",
      )
    Vector(width, _, elements) => {
      let values : Array[ConstEvalValue] = []
      for element in elements {
        values.push(const_eval_apply_sign([element]))
      }
      const_eval_vector_from_elements(width, values, "sign")
    }
  }
}

///|
fn const_eval_count_one_bits_width(value : Int64, width : Int) -> Int64 {
  let mut bits = value
  let mut count = 0L
  for _ in 0..<width {
    if (bits & 1L) != 0L {
      count += 1L
    }
    bits = bits >> 1
  }
  count
}

///|
fn const_eval_count_leading_zeros_width(value : Int64, width : Int) -> Int64 {
  let mut count = 0L
  let mut done = false
  for offset in 0..<width {
    if done {
      continue
    }
    let shift = width - 1 - offset
    if ((value >> shift) & 1L) == 0L {
      count += 1L
    } else {
      done = true
    }
  }
  count
}

///|
fn const_eval_count_trailing_zeros_width(value : Int64, width : Int) -> Int64 {
  let mut bits = value
  let mut count = 0L
  let mut done = false
  for _ in 0..<width {
    if done {
      continue
    }
    if (bits & 1L) == 0L {
      count += 1L
      bits = bits >> 1
    } else {
      done = true
    }
  }
  count
}

///|
fn const_eval_vector_constructor_type(name : String) -> (Int, ConstEvalType)? {
  match name {
    "vec2<bool>" => Some((2, ConstEvalType::Bool))
    "vec2<i32>" => Some((2, ConstEvalType::I32))
    "vec2<u32>" => Some((2, ConstEvalType::U32))
    "vec2<f32>" => Some((2, ConstEvalType::F32))
    "vec3<bool>" => Some((3, ConstEvalType::Bool))
    "vec3<i32>" => Some((3, ConstEvalType::I32))
    "vec3<u32>" => Some((3, ConstEvalType::U32))
    "vec3<f32>" => Some((3, ConstEvalType::F32))
    "vec4<bool>" => Some((4, ConstEvalType::Bool))
    "vec4<i32>" => Some((4, ConstEvalType::I32))
    "vec4<u32>" => Some((4, ConstEvalType::U32))
    "vec4<f32>" => Some((4, ConstEvalType::F32))
    _ => None
  }
}

///|
fn const_eval_apply_vector_constructor(
  width : Int,
  element : ConstEvalType,
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  let elements : Array[ConstEvalValue] = []
  if args.length() == 1 {
    for _ in 0..<width {
      elements.push(
        const_eval_convert_to_type(args[0], element, "vector constructor"),
      )
    }
    return ConstEvalValue::Vector(width, element, elements)
  }
  if args.length() != width {
    raise WeslCompileError::Validation(
      "invalid function call signature: `vec\{width}<\{element.label()}>(...)`",
    )
  }
  for arg in args {
    elements.push(
      const_eval_convert_to_type(arg, element, "vector constructor"),
    )
  }
  ConstEvalValue::Vector(width, element, elements)
}

///|
fn const_eval_format_call_signature(
  name : String,
  args : Array[ConstEvalValue],
) -> String {
  let parts : Array[String] = []
  for arg in args {
    parts.push(arg.value_type().label())
  }
  let joined = parts.join(", ")
  "\{name}(\{joined})"
}

///|
fn const_eval_require_one_bit_count_arg(
  name : String,
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 1 {
    raise WeslCompileError::Validation(
      "invalid function call signature: `\{const_eval_format_call_signature(name, args)}`",
    )
  }
  args[0]
}

///|
fn const_eval_apply_integer_bit_count(
  name : String,
  args : Array[ConstEvalValue],
  count : (Int64, Int) -> Int64,
) -> ConstEvalValue raise WeslCompileError {
  let arg = const_eval_require_one_bit_count_arg(name, args)
  match arg {
    Bool(_)
    | AbstractFloat(_, _)
    | F32(_)
    | FrexpAbstract(_, _)
    | FrexpF32(_, _)
    | Matrix(_, _, _, _)
    | Array(_, _, _)
    | Struct(_, _) =>
      raise WeslCompileError::Validation(
        "`\{name}` expects a float or vector of float argument",
      )
    Vector(width, _, elements) => {
      let values : Array[ConstEvalValue] = []
      for element in elements {
        values.push(const_eval_apply_integer_bit_count(name, [element], count))
      }
      const_eval_vector_from_elements(width, values, name)
    }
    AbstractInt(number) => ConstEvalValue::AbstractInt(count(number, 64))
    I32(number) => ConstEvalValue::I32(count(number, 32))
    U32(number) => ConstEvalValue::U32(count(number, 32))
  }
}

///|
fn const_eval_frexp_parts(value : Double) -> (Double, Int64) {
  if value == 0.0 {
    return (value, 0L)
  }
  let mut fract = value
  let mut exponent = 0L
  let mut magnitude = const_eval_abs_double(fract)
  while magnitude < 0.5 {
    fract = fract * 2.0
    exponent -= 1L
    magnitude = const_eval_abs_double(fract)
  }
  while magnitude >= 1.0 {
    fract = fract / 2.0
    exponent += 1L
    magnitude = const_eval_abs_double(fract)
  }
  (fract, exponent)
}

///|
fn const_eval_frexp_abstract(value : Double) -> ConstEvalValue {
  let (fract, exponent) = const_eval_frexp_parts(value)
  ConstEvalValue::FrexpAbstract(fract, exponent)
}

///|
fn const_eval_frexp_f32(value : Float) -> ConstEvalValue {
  let (fract, exponent) = const_eval_frexp_parts(value.to_double())
  ConstEvalValue::FrexpF32(Float::from_double(fract), exponent)
}

///|
fn const_eval_apply_frexp(
  args : Array[ConstEvalValue],
) -> ConstEvalValue raise WeslCompileError {
  if args.length() != 1 {
    let signature = const_eval_format_call_signature("frexp", args)
    raise WeslCompileError::Validation(
      "invalid function call signature: `\{signature}`",
    )
  }
  match args[0] {
    AbstractFloat(value, _) => const_eval_frexp_abstract(value)
    F32(value) => const_eval_frexp_f32(value)
    _ => raise WeslCompileError::Validation("not implemented: `frexp`")
  }
}

///|
fn const_eval_dispatch_builtin(
  name : String,
  values : Array[ConstEvalValue],
) -> ConstEvalValue? raise WeslCompileError {
  match const_eval_vector_constructor_type(name) {
    Some((width, element)) =>
      return Some(const_eval_apply_vector_constructor(width, element, values))
    None => ()
  }
  match name {
    "clamp" => Some(const_eval_apply_clamp(values))
    "min" => Some(const_eval_apply_min_or_max("min", values, true))
    "max" => Some(const_eval_apply_min_or_max("max", values, false))
    "abs" => Some(const_eval_apply_abs(values))
    "select" => Some(const_eval_apply_select(values))
    "all" => Some(const_eval_apply_bool_builtin("all", values))
    "any" => Some(const_eval_apply_bool_builtin("any", values))
    "floor" => Some(const_eval_apply_float_unary_builtin("floor", values))
    "ceil" => Some(const_eval_apply_float_unary_builtin("ceil", values))
    "round" => Some(const_eval_apply_float_unary_builtin("round", values))
    "trunc" => Some(const_eval_apply_float_unary_builtin("trunc", values))
    "fract" => Some(const_eval_apply_float_unary_builtin("fract", values))
    "sqrt" => Some(const_eval_apply_float_unary_builtin("sqrt", values))
    "inverseSqrt" =>
      Some(const_eval_apply_float_unary_builtin("inverseSqrt", values))
    "exp" => Some(const_eval_apply_float_unary_builtin("exp", values))
    "exp2" => Some(const_eval_apply_float_unary_builtin("exp2", values))
    "log" => Some(const_eval_apply_float_unary_builtin("log", values))
    "log2" => Some(const_eval_apply_float_unary_builtin("log2", values))
    "sin" => Some(const_eval_apply_float_unary_builtin("sin", values))
    "cos" => Some(const_eval_apply_float_unary_builtin("cos", values))
    "tan" => Some(const_eval_apply_float_unary_builtin("tan", values))
    "asin" => Some(const_eval_apply_float_unary_builtin("asin", values))
    "acos" => Some(const_eval_apply_float_unary_builtin("acos", values))
    "atan" => Some(const_eval_apply_float_unary_builtin("atan", values))
    "sinh" => Some(const_eval_apply_float_unary_builtin("sinh", values))
    "cosh" => Some(const_eval_apply_float_unary_builtin("cosh", values))
    "tanh" => Some(const_eval_apply_float_unary_builtin("tanh", values))
    "radians" => Some(const_eval_apply_float_unary_builtin("radians", values))
    "degrees" => Some(const_eval_apply_float_unary_builtin("degrees", values))
    "saturate" => Some(const_eval_apply_saturate(values))
    "pow" => Some(const_eval_apply_float_binary_builtin("pow", values))
    "atan2" => Some(const_eval_apply_float_binary_builtin("atan2", values))
    "ldexp" => Some(const_eval_apply_ldexp(values))
    "step" => Some(const_eval_apply_step(values))
    "mix" => Some(const_eval_apply_mix(values))
    "sign" => Some(const_eval_apply_sign(values))
    "frexp" => Some(const_eval_apply_frexp(values))
    "countOneBits" =>
      Some(
        const_eval_apply_integer_bit_count(
          "countOneBits", values, const_eval_count_one_bits_width,
        ),
      )
    "countLeadingZeros" =>
      Some(
        const_eval_apply_integer_bit_count(
          "countLeadingZeros", values, const_eval_count_leading_zeros_width,
        ),
      )
    "countTrailingZeros" =>
      Some(
        const_eval_apply_integer_bit_count(
          "countTrailingZeros", values, const_eval_count_trailing_zeros_width,
        ),
      )
    "extractBits"
    | "firstLeadingBit"
    | "firstTrailingBit"
    | "fma"
    | "insertBits"
    | "modf"
    | "quantizeToF16"
    | "reverseBits"
    | "smoothstep" => {
      if const_eval_builtin_arity_is_valid(name, values.length()) {
        raise WeslCompileError::Validation("not implemented: `\{name}`")
      }
      let signature = const_eval_format_call_signature(name, values)
      raise WeslCompileError::Validation(
        "invalid function call signature: `\{signature}`",
      )
    }
    _ => None
  }
}

///|
fn const_eval_builtin_arity_is_valid(name : String, arity : Int) -> Bool {
  match name {
    "firstLeadingBit"
    | "firstTrailingBit"
    | "frexp"
    | "modf"
    | "quantizeToF16"
    | "reverseBits" => arity == 1
    "fma" | "smoothstep" => arity == 3
    "extractBits" | "insertBits" => arity == 4
    _ => false
  }
}
