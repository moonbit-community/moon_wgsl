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
test "naga_oil wb: parse_imports matches upstream top-level item-list disambiguation" {
  debug_inspect(
    parse_imports_snapshot("#import a::b c, d\n"),
    content="\"c=a::b::c\\nd=a::b::d\"",
  )
  debug_inspect(
    parse_imports_snapshot("#import a::b c\n"),
    content="\"c=a::b::c\"",
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
  debug_inspect(
    parse_imports_snapshot(
      "#import a::b::{\n  c::{d, e},\n  f,\n  g::{\n    h as i,\n    j::k::l as m,\n  }\n}\n",
    ),
    content="\"d=a::b::c::d\\ne=a::b::c::e\\nf=a::b::f\\ni=a::b::g::h\\nm=a::b::g::j::k::l\"",
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
