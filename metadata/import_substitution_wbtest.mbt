///|
fn parse_imports_snapshot(input : String) -> String {
  let declared_imports : Array[DeclaredImportBinding] = []
  parse_imports(input, declared_imports) catch {
    Parse(message, offset) => return "ERR \{offset.to_string()} \{message}"
  }

  let rows : Array[String] = []
  for binding in declared_imports {
    let full_paths = binding.full_paths.join(",")
    rows.push("\{binding.used_name}=\{full_paths}")
  }
  rows.join("\n")
}

///|
fn substitute_snapshot(imports : String, source : String) -> String {
  let declared_imports : Array[DeclaredImportBinding] = []
  parse_imports(imports, declared_imports) catch {
    Parse(message, offset) => return "ERR \{offset.to_string()} \{message}"
  }
  let used_imports : Array[ImportDefWithOffset] = []
  substitute_identifiers(source, 0, declared_imports, used_imports, false) catch {
    AmbiguousImport(offset) => return "ERR \{offset.to_string()} ambiguous"
  }
}

///|
test "naga_oil wb: parse_imports matches upstream top-level item-list disambiguation" {
  debug_inspect(
    parse_imports_snapshot("#import a::b c, d\n"),
    content="\"c=a::b::c\\nd=a::b::d\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a::b c\n"),
    content="\"c=a::b::c\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a:: b\n"),
    content="\"b=a::::b\"",
  )
}

///|
test "naga_oil wb: parse_imports matches upstream grouped nested imports" {
  debug_inspect(
    parse_imports_snapshot(
      "#import a::b::{c::{d, e}, f, g::{h as i, j::k::l as m}}\n",
    ),
    content="\"d=a::b::c::d\\ne=a::b::c::e\\nf=a::b::f\\ni=a::b::g::h\\nm=a::b::g::j::k::l\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a::b::{c::{d, e}, f, g::{h as i, j}}\n"),
    content="\"d=a::b::c::d\\ne=a::b::c::e\\nf=a::b::f\\ni=a::b::g::h\\nj=a::b::g::j\"",
  )
}

///|
test "naga_oil wb: parse_imports matches upstream quoted path grouping" {
  debug_inspect(
    parse_imports_snapshot(
      "#import \"path//with\\\\ all sorts of .stuff\"::{a, b}\n",
    ),
    content="\"a=\\\"path//with\\\\\\\\ all sorts of .stuff\\\"::a\\nb=\\\"path//with\\\\\\\\ all sorts of .stuff\\\"::b\"",
  )
}

///|
test "naga_oil wb: parse_imports mirrors upstream import token suite" {
  debug_inspect(parse_imports_snapshot("#import a::b\n"), content="\"b=a::b\"")
  debug_inspect(
    parse_imports_snapshot("#import a::{b, c}\n"),
    content="\"b=a::b\\nc=a::c\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a::{b as d, c}\n"),
    content="\"d=a::b\\nc=a::c\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a::{b::{c, d}, e}\n"),
    content="\"c=a::b::c\\nd=a::b::d\\ne=a::e\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a::b::{c, d}, e\n"),
    content="\"c=a::b::c\\nd=a::b::d\\ne=e\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a, b\n"),
    content="\"a=a\\nb=b\"",
  )
  debug_inspect(parse_imports_snapshot("#import as\n"), content="\"as=as\"")
  debug_inspect(parse_imports_snapshot("#import a as as\n"), content="\"as=a\"")
  debug_inspect(
    parse_imports_snapshot("#import 𐐀\n"),
    content="\"𐐀=𐐀\"",
  )
  debug_inspect(
    parse_imports_snapshot(
      "#import a::b::{\n  c::{d, e},\n  f,\n  g::{\n    h as i,\n    j::k::l as m,\n  }\n}\n",
    ),
    content="\"d=a::b::c::d\\ne=a::b::c::e\\nf=a::b::f\\ni=a::b::g::h\\nm=a::b::g::j::k::l\"",
  )
}

///|
test "naga_oil wb: direct parse_imports uses one upstream token stream" {
  debug_inspect(parse_imports_snapshot("# import a\n"), content="\"a=a\"")
  debug_inspect(parse_imports_snapshot("  #import a\n"), content="\"a=a\"")
  debug_inspect(
    parse_imports_snapshot("  not_import\n"),
    content="\"ERR 2 expected `#import`\"",
  )
  debug_inspect(parse_imports_snapshot("#import"), content="\"\"")
  debug_inspect(parse_imports_snapshot("#import ;"), content="\"\"")
  debug_inspect(parse_imports_snapshot("#import a\nb\n"), content="\"b=a::b\"")
  debug_inspect(
    parse_imports_snapshot("#import a\n#import b\n"),
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
    parse_imports_snapshot("#import a::b::{\n").has_prefix("ERR "),
    content="true",
  )
  debug_inspect(
    parse_imports_snapshot("#import a::b::{{c}\n").has_prefix("ERR "),
    content="true",
  )
  debug_inspect(
    parse_imports_snapshot("#import a::b::{c}}\n").has_prefix("ERR "),
    content="true",
  )
  debug_inspect(
    parse_imports_snapshot("#import a::b{{c,d}}\n").has_prefix("ERR "),
    content="true",
  )
  debug_inspect(
    parse_imports_snapshot("#import a {b}\n"),
    content="\"ERR 10 open brace must follow `::`\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a b {c}\n"),
    content="\"ERR 12 open brace must follow `::`\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a as {\n"),
    content="\"ERR 10 expected identifier after `as`\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a:b\n").has_prefix("ERR "),
    content="true",
  )
}

///|
test "naga_oil wb: parse_imports collects import blocks with raw brace counts" {
  debug_inspect(
    parse_imports_snapshot("#import \"path{\" Item\n#import other\n").has_prefix(
      "ERR ",
    ),
    content="true",
  )
}

///|
test "AST import substitution does not rewrite numeric literal suffixes" {
  let output = substitute_snapshot("#import math::u\n", "let x = 1u;\n")
  debug_inspect(output.contains("1uX_naga_oil_mod_XNVQXI"), content="false")
}

///|
test "AST import substitution rewrites full declaration references only" {
  let output = substitute_snapshot(
    "#import math::{mix_value, Value}\n",
    (
      #|fn entry(input: Value) -> f32 {
      #|  let local = mix_value(input.value);
      #|  return local;
      #|}
      #|,
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
