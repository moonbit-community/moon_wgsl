///|
pub enum Severity {
  Off
  Info
  Warning
  Error
} derive(Eq, Debug)

///|
pub enum StandardFilterableTriggeringRule {
  DerivativeUniformity
} derive(Eq, Debug)

///|
pub enum FilterableTriggeringRule {
  Standard(StandardFilterableTriggeringRule)
  Unknown(String)
  User(String, String)
} derive(Eq, Debug)

///|
pub(all) struct DiagnosticFilter {
  new_severity : Severity
  triggering_rule : FilterableTriggeringRule
} derive(Eq, Debug)

///|
pub(all) struct DiagnosticFilterNode {
  inner : DiagnosticFilter
  parent : Handle?
} derive(Eq, Debug)

///|
pub enum RayQueryIntersection {
  None
  Triangle
  Generated
  Aabb
} derive(Eq, Debug)

///|
pub(all) struct DocComments {
  types : Array[(Handle, Array[String])]
  struct_members : Array[(Handle, Int, Array[String])]
  entry_points : Array[(Int, Array[String])]
  functions : Array[(Handle, Array[String])]
  constants : Array[(Handle, Array[String])]
  global_variables : Array[(Handle, Array[String])]
  module_comments : Array[String]
} derive(Eq, Debug)

///|
pub fn DocComments::DocComments() -> DocComments {
  {
    types: [],
    struct_members: [],
    entry_points: [],
    functions: [],
    constants: [],
    global_variables: [],
    module_comments: [],
  }
}
