///|
fn parse_imports_snapshot(input : String) -> String {
  let state = WgslImportSubstitutionState::default()
  state.declare_imports(input) catch {
    Parse(message, offset) => return "ERR \{offset.to_string()} \{message}"
  }

  let rows : Array[String] = []
  for binding in state.declared_imports {
    let full_paths = binding.full_paths.join(",")
    rows.push("\{binding.used_name}=\{full_paths}")
  }
  rows.join("\n")
}

///|
fn substitute_snapshot(imports : String, source : String) -> String {
  let state = WgslImportSubstitutionState::default()
  state.declare_imports(imports) catch {
    Parse(message, offset) => return "ERR \{offset.to_string()} \{message}"
  }
  let used_imports : Array[ImportDefWithOffset] = []
  state.rewrite_source(source, 0, used_imports, false) catch {
    AmbiguousImport(offset) => return "ERR \{offset.to_string()} ambiguous"
    InvalidWgslSyntax(message, offset) =>
      return "ERR \{offset.to_string()} \{message}"
  }
}

///|
test "naga_oil wb: parse_imports matches upstream top-level item-list disambiguation" {
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b c, d
        #|
      ),
    ),
    content="\"c=a::b::c\\nd=a::b::d\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b c
        #|
      ),
    ),
    content="\"c=a::b::c\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a:: b
        #|
      ),
    ),
    content="\"b=a::::b\"",
  )
}

///|
test "naga_oil wb: parse_imports matches upstream grouped nested imports" {
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b::{c::{d, e}, f, g::{h as i, j::k::l as m}}
        #|
      ),
    ),
    content="\"d=a::b::c::d\\ne=a::b::c::e\\nf=a::b::f\\ni=a::b::g::h\\nm=a::b::g::j::k::l\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b::{c::{d, e}, f, g::{h as i, j}}
        #|
      ),
    ),
    content="\"d=a::b::c::d\\ne=a::b::c::e\\nf=a::b::f\\ni=a::b::g::h\\nj=a::b::g::j\"",
  )
}

///|
test "naga_oil wb: parse_imports matches upstream quoted path grouping" {
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import "path//with\\ all sorts of .stuff"::{a, b}
        #|
      ),
    ),
    content="\"a=\\\"path//with\\\\\\\\ all sorts of .stuff\\\"::a\\nb=\\\"path//with\\\\\\\\ all sorts of .stuff\\\"::b\"",
  )
}

///|
test "naga_oil wb: parse_imports mirrors upstream import token suite" {
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b
        #|
      ),
    ),
    content="\"b=a::b\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::{b, c}
        #|
      ),
    ),
    content="\"b=a::b\\nc=a::c\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::{b as d, c}
        #|
      ),
    ),
    content="\"d=a::b\\nc=a::c\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import bevy_pbr::{pbr_types::{PbrInput, pbr_input_new}, pbr_deferred_types as deferred_types}
        #|
      ),
    ),
    content="\"PbrInput=bevy_pbr::pbr_types::PbrInput\\npbr_input_new=bevy_pbr::pbr_types::pbr_input_new\\ndeferred_types=bevy_pbr::pbr_deferred_types\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::{b::{c, d}, e}
        #|
      ),
    ),
    content="\"c=a::b::c\\nd=a::b::d\\ne=a::e\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b::{c, d}, e
        #|
      ),
    ),
    content="\"c=a::b::c\\nd=a::b::d\\ne=e\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a, b
        #|
      ),
    ),
    content="\"a=a\\nb=b\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import as
        #|
      ),
    ),
    content="\"as=as\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a as as
        #|
      ),
    ),
    content="\"as=a\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import 𐐀
        #|
      ),
    ),
    content="\"𐐀=𐐀\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b::{
        #|  c::{d, e},
        #|  f,
        #|  g::{
        #|    h as i,
        #|    j::k::l as m,
        #|  }
        #|}
        #|
      ),
    ),
    content="\"d=a::b::c::d\\ne=a::b::c::e\\nf=a::b::f\\ni=a::b::g::h\\nm=a::b::g::j::k::l\"",
  )
}

///|
test "naga_oil wb: direct parse_imports uses one upstream token stream" {
  debug_inspect(parse_imports_snapshot("# import a\n"), content="\"a=a\"")
  debug_inspect(
    parse_imports_snapshot(
      (
        #|  #import a
        #|
      ),
    ),
    content="\"a=a\"",
  )
  debug_inspect(
    parse_imports_snapshot("  not_import\n"),
    content="\"ERR 2 expected `#import`\"",
  )
  debug_inspect(parse_imports_snapshot("#import"), content="\"\"")
  debug_inspect(parse_imports_snapshot("#import ;"), content="\"\"")
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a
        #|b
        #|
      ),
    ),
    content="\"b=a::b\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a
        #|#import b
        #|
      ),
    ),
    content="\"ERR 10 unexpected token\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a\r\n#import b\r\n"),
    content="\"ERR 11 unexpected token\"",
  )
}

///|
test "naga_oil wb: parse_imports rejects malformed imports like upstream" {
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b::{
        #|
      ),
    ).has_prefix("ERR "),
    content="true",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b::{{c}
        #|
      ),
    ).has_prefix("ERR "),
    content="true",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b::{c}}
        #|
      ),
    ).has_prefix("ERR "),
    content="true",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a::b{{c,d}}
        #|
      ),
    ).has_prefix("ERR "),
    content="true",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a {b}
        #|
      ),
    ),
    content="\"ERR 10 open brace must follow `::`\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a b {c}
        #|
      ),
    ),
    content="\"ERR 12 open brace must follow `::`\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a as {
        #|
      ),
    ),
    content="\"ERR 10 expected identifier after `as`\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import a:b
        #|
      ),
    ).has_prefix("ERR "),
    content="true",
  )
}

///|
test "naga_oil wb: parse_imports collects import blocks with raw brace counts" {
  debug_inspect(
    parse_imports_snapshot(
      (
        #|#import "path{" Item
        #|#import other
        #|
      ),
    ).has_prefix("ERR "),
    content="true",
  )
}

///|
test "AST import substitution does not rewrite numeric literal suffixes" {
  let output = substitute_snapshot(
    (
      #|#import math::u
      #|
    ),
    "let x = 1u;\n",
  )
  debug_inspect(output.contains("1uX_naga_oil_mod_XNVQXI"), content="false")
}

///|
test "AST import substitution rewrites full declaration references only" {
  let output = substitute_snapshot(
    (
      #|#import math::{mix_value, Value}
      #|
    ),
    (
      #|fn entry(input: Value) -> f32 {
      #|  let local = mix_value(input.value);
      #|  return local;
      #|}
      #|
    ),
  )
  debug_inspect(output.contains("ValueX_naga_oil_mod_X"), content="true")
  debug_inspect(output.contains("mix_valueX_naga_oil_mod_X"), content="true")
  debug_inspect(output.contains(".valueX_naga_oil_mod"), content="false")
}

///|
test "naga_oil wb: parse_imports rejects empty or whitespace-only input" {
  debug_inspect(
    parse_imports_snapshot(""),
    content="\"ERR 0 expected #import\"",
  )
  debug_inspect(
    parse_imports_snapshot("\u{00A0}\n"),
    content="\"ERR 3 expected #import\"",
  )
}

///|
