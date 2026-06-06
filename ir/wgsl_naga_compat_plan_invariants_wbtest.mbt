///|
priv struct NagaCompatPlanInvariantCase {
  name : String
  source : String
  function_prefix : String
  required : Array[String]
}

///|
fn assert_naga_compat_plan_invariant_case(
  item : NagaCompatPlanInvariantCase,
) -> Unit {
  let trace = trace_naga_oil_writer_function_plan_for_source(
    item.source,
    item.function_prefix,
  ) catch {
    error => abort("\{item.name}: \{error.message()}")
  }
  let label_prefix = "fn:\{item.function_prefix}"
  let common_required = [
    "function\t\{label_prefix}",
    "compat-plan\t\{label_prefix}",
    "plan-arena\t\{label_prefix}",
    "plan-calls\t\{label_prefix}",
    "plan-short-circuit\t\{label_prefix}",
    "plan-materialization\t\{label_prefix}",
    "plan-body\t\{label_prefix}",
    "plan-names\t\{label_prefix}",
    "expression\t\{label_prefix}",
    "writer-statement\t\{label_prefix}",
  ]
  for needle in common_required {
    if !trace.contains(needle) {
      abort("\{item.name}: missing common plan invariant: \{needle}\n\{trace}")
    }
  }
  for needle in item.required {
    if !trace.contains(needle) {
      abort("\{item.name}: missing plan invariant: \{needle}\n\{trace}")
    }
  }
}

///|
test "Naga compat plan invariants are table driven" {
  let cases : Array[NagaCompatPlanInvariantCase] = [
    {
      name: "call-result materialization",
      function_prefix: "call_case",
      source: (
        #|fn make(value: f32) -> f32 {
        #|  return value;
        #|}
        #|
        #|fn call_case(x: f32, y: f32) -> f32 {
        #|  return x + make(y);
        #|}
      ),
      required: [
        "plan-calls\tfn:call_case\tcalls=0\tcall_results=1", "plan-materialization\tfn:call_case\tmaterialized=1",
        "reason=call-result", "Call(result=",
      ],
    },
    {
      name: "hoisted local declaration order",
      function_prefix: "local_case",
      source: (
        #|fn local_case(input: f32) -> f32 {
        #|  var r: f32 = 0.0;
        #|  var g: f32 = 0.0;
        #|  var b: f32 = 0.0;
        #|  return input;
        #|}
      ),
      required: [
        "plan-body\tfn:local_case\tlocal_decls=3", "plan-names\tfn:local_case\ttemp_names=0\tlocal_names=3",
        "writer-local-declare\tfn:local_case\t0\tlocal=0\tsource_local=0\tfinal=r",
        "writer-statement\tfn:local_case\t0\tDeclare(0)\tskip=true",
      ],
    },
    {
      name: "short-circuit return materialization",
      function_prefix: "is_enabled_pair",
      source: (
        #|fn enabled(flags: u32, mask: u32) -> bool {
        #|  return (flags & mask) != 0u;
        #|}
        #|
        #|fn is_enabled_pair(flags: u32, value: u32) -> bool {
        #|  return (enabled(flags, 1u) && value == 1u) ||
        #|    (enabled(flags, 2u) && value == 2u);
        #|}
      ),
      required: [
        "plan-short-circuit\tfn:is_enabled_pair\tresult_locals=3", "plan-body\tfn:is_enabled_pair\tlocal_decls=3",
        "writer-local-declare\tfn:is_enabled_pair\t0\tlocal=0\tsource_local=0\tfinal=local",
        "writer-statement\tfn:is_enabled_pair\t2\tIf",
      ],
    },
    {
      name: "implicit matrix constructor arena slots",
      function_prefix: "matrix_case",
      source: (
        #|struct S {
        #|  m: mat3x3<f32>,
        #|}
        #|
        #|fn matrix_case() -> S {
        #|  var s: S;
        #|  s.m = mat3x3<f32>(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0);
        #|  return s;
        #|}
      ),
      required: [
        "plan-arena\tfn:matrix_case\texpressions=16\timplicit_slots=0", "plan-materialization\tfn:matrix_case\tmaterialized=1",
        "plan-names\tfn:matrix_case\ttemp_names=1", "reason=load",
      ],
    },
  ]
  for item in cases {
    assert_naga_compat_plan_invariant_case(item)
  }
}

///|
test "Naga writer trace selects exact entry point before prefix-matching helpers" {
  let trace = trace_naga_oil_writer_function_plan_for_source(
    (
      #|fn fragment_helper(value: f32) -> f32 {
      #|  return value;
      #|}
      #|
      #|@fragment
      #|fn fragment(@location(0) value: f32) -> @location(0) f32 {
      #|  return fragment_helper(value);
      #|}
    ),
    "fragment",
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(trace.contains("function\tentry:fragment"), content="true")
  debug_inspect(trace.contains("function\tfn:fragment_helper"), content="false")
}

///|
test "Naga writer trace treats source var const initializer as declaration owned" {
  let trace = trace_naga_oil_writer_function_plan_for_source(
    (
      #|struct ScreenAabb {
      #|  min: vec3<f32>,
      #|  max: vec3<f32>,
      #|}
      #|
      #|fn projection() -> mat4x4<f32> {
      #|  return mat4x4<f32>();
      #|}
      #|
      #|fn takes(value: ptr<function, ScreenAabb>) -> bool {
      #|  return true;
      #|}
      #|
      #|fn probe() -> bool {
      #|  let clip = projection();
      #|  var screen_aabb = ScreenAabb(vec3<f32>(0.0), vec3<f32>(0.0));
      #|  if takes(&screen_aabb) {
      #|    return clip[3][3] == 1.0;
      #|  }
      #|  return false;
      #|}
    ),
    "probe",
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    trace.contains("expression\tfn:probe\t2\tCompose"),
    content="true",
  )
  debug_inspect(trace.contains("detail=ty:"), content="true")
  debug_inspect(trace.contains("components:1,1"), content="true")
  debug_inspect(
    trace.contains("writer-statement\tfn:probe\t0\tEmit(1..2)\tskip=true"),
    content="true",
  )
  debug_inspect(
    trace.contains("writer-statement\tfn:probe\t1\tCall(result=3)"),
    content="true",
  )
}
