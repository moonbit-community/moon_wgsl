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
pub(all) suberror WeslCompileError {
  Resolve(ResolveError)
  Parse(String)
  Validation(String)
  Validate(ValidateError)
  InvalidExpression(String)
  Artifact(String)
  DuplicateSymbol(String)
  CircularDecl(String)
  MissingDecl(ModulePath, String)
  Private(String, ModulePath)
}

///|
pub fn WeslCompileError::message(self : WeslCompileError) -> String {
  match self {
    Resolve(err) => err.message()
    Parse(reason) => reason
    Validation(reason) => reason
    Validate(err) => err.message()
    InvalidExpression(expr) => "invalid if attribute expression: `\{expr}`"
    Artifact(reason) => reason
    DuplicateSymbol(symbol) => "duplicate declaration of `\{symbol}`"
    CircularDecl(symbol) => "circular declaration of `\{symbol}`"
    MissingDecl(path, item) =>
      "module `\{path.to_string()}` has no declaration `\{item}`"
    Private(item, path) =>
      "import of `\{item}` in module `\{path.to_string()}` is not `@publish`, but another module tried to import it"
  }
}

///|
pub(all) suberror ValidateError {
  UndefinedSymbol(String)
  ParamCount(String, Int, Int)
  NotCallable(String)
  Duplicate(String)
  Cycle(String, String)
}

///|
pub fn ValidateError::message(self : ValidateError) -> String {
  match self {
    UndefinedSymbol(name) => "cannot find declaration of `\{name}`"
    ParamCount(name, expected, got) =>
      "incorrect number of arguments to `\{name}`, expected `\{expected}`, got `\{got}`"
    NotCallable(name) => "`\{name}` is not callable"
    Duplicate(name) => "duplicate declaration of `\{name}`"
    Cycle(name, via) => "declaration of `\{name}` is cyclic via `\{via}`"
  }
}

///|
pub(all) struct SourcePosition {
  line : Int
  column : Int
  offset : Int
} derive(Eq, Debug)

///|
pub fn SourcePosition::new(
  line : Int,
  column : Int,
  offset : Int,
) -> SourcePosition {
  { line, column, offset }
}

///|
pub(all) struct SourceSpan {
  start : SourcePosition
  end : SourcePosition
} derive(Eq, Debug)

///|
pub fn SourceSpan::new(
  start : SourcePosition,
  end : SourcePosition,
) -> SourceSpan {
  { start, end }
}

///|
fn diagnostic_is_newline(code : Int) -> Bool {
  code == 10 || code == 13
}

///|
fn diagnostic_line_start(source : String, line : Int) -> Int {
  if line <= 1 {
    return 0
  }
  let mut current_line = 1
  let mut index = 0
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if code == 13 {
      current_line += 1
      index += 1
      if index < source.length() && source.code_unit_at(index).to_int() == 10 {
        index += 1
      }
      if current_line == line {
        return index
      }
      continue
    } else if code == 10 {
      current_line += 1
      index += 1
      if current_line == line {
        return index
      }
      continue
    }
    index += 1
  }
  source.length()
}

///|
fn diagnostic_line_end(source : String, line_start : Int) -> Int {
  let mut index = line_start
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if diagnostic_is_newline(code) {
      return index
    }
    index += 1
  }
  source.length()
}

///|
fn diagnostic_repeat(ch : String, count : Int) -> String {
  let parts : Array[String] = []
  let mut index = 0
  while index < count {
    parts.push(ch)
    index += 1
  }
  parts.join("")
}

///|
pub fn SourceSpan::from_line_range(
  source : String,
  start_line : Int,
  end_line : Int,
) -> SourceSpan {
  let bounded_start_line = if start_line < 1 { 1 } else { start_line }
  let bounded_end_line = if end_line < bounded_start_line {
    bounded_start_line
  } else {
    end_line
  }
  let start_offset = diagnostic_line_start(source, bounded_start_line)
  let end_line_start = diagnostic_line_start(source, bounded_end_line)
  let end_offset = diagnostic_line_end(source, end_line_start)
  {
    start: { line: bounded_start_line, column: 1, offset: start_offset },
    end: {
      line: bounded_end_line,
      column: end_offset - end_line_start + 1,
      offset: end_offset,
    },
  }
}

///|
pub(all) struct DiagnosticDetail {
  source : String?
  output : String?
  module_path : ModulePath?
  display_name : String?
  declaration : String?
  span : SourceSpan?
  message : String?
} derive(Eq, Debug)

///|
pub fn DiagnosticDetail::default() -> DiagnosticDetail {
  {
    source: None,
    output: None,
    module_path: None,
    display_name: None,
    declaration: None,
    span: None,
    message: None,
  }
}

///|
pub(all) struct Diagnostic {
  error : WeslCompileError
  detail : DiagnosticDetail
}

///|
pub(all) suberror WeslDiagnosticError {
  Diagnostic(Diagnostic)
}

///|
pub fn WeslDiagnosticError::message(self : WeslDiagnosticError) -> String {
  match self {
    Diagnostic(diagnostic) => diagnostic.to_string()
  }
}

///|
pub fn Diagnostic::new(error : WeslCompileError) -> Diagnostic {
  { error, detail: DiagnosticDetail::default() }
}

///|
pub fn WeslCompileError::diagnostic(self : WeslCompileError) -> Diagnostic {
  Diagnostic::new(self)
}

///|
pub fn Diagnostic::message(self : Diagnostic) -> String {
  match self.detail.message {
    Some(message) => message
    None => self.error.message()
  }
}

///|
pub fn Diagnostic::with_source(
  self : Diagnostic,
  source : String,
) -> Diagnostic {
  match self.detail.source {
    Some(_) => self
    None => { ..self, detail: { ..self.detail, source: Some(source) } }
  }
}

///|
pub fn Diagnostic::with_output(
  self : Diagnostic,
  output : String,
) -> Diagnostic {
  match self.detail.output {
    Some(_) => self
    None => { ..self, detail: { ..self.detail, output: Some(output) } }
  }
}

///|
pub fn Diagnostic::with_span(
  self : Diagnostic,
  span : SourceSpan,
) -> Diagnostic {
  match self.detail.span {
    Some(_) => self
    None => { ..self, detail: { ..self.detail, span: Some(span) } }
  }
}

///|
pub fn Diagnostic::with_syntax_span(
  self : Diagnostic,
  span : SyntaxSpan,
) -> Diagnostic {
  match self.detail.source {
    Some(source) =>
      self.with_span(
        SourceSpan::from_line_range(source, span.start_line, span.end_line),
      )
    None => self
  }
}

///|
pub fn Diagnostic::with_declaration(
  self : Diagnostic,
  declaration : String,
) -> Diagnostic {
  match self.detail.declaration {
    Some(_) => self
    None =>
      { ..self, detail: { ..self.detail, declaration: Some(declaration) } }
  }
}

///|
pub fn Diagnostic::with_module_path(
  self : Diagnostic,
  path : ModulePath,
  display_name : String?,
) -> Diagnostic {
  match self.detail.module_path {
    Some(_) => self
    None =>
      {
        ..self,
        detail: { ..self.detail, module_path: Some(path), display_name },
      }
  }
}

///|
pub fn[S : SourceMap] Diagnostic::with_sourcemap(
  self : Diagnostic,
  sourcemap : S,
) -> Diagnostic {
  let mut diagnostic = self
  match diagnostic.detail.declaration {
    Some(decl) =>
      match S::get_decl(sourcemap, decl) {
        Some((path, original_decl)) => {
          diagnostic = {
            ..diagnostic,
            detail: {
              ..diagnostic.detail,
              module_path: Some(path),
              declaration: Some(original_decl),
              display_name: S::get_display_name(sourcemap, path),
            },
          }
          match S::get_source(sourcemap, path) {
            Some(source) =>
              diagnostic = {
                ..diagnostic,
                detail: { ..diagnostic.detail, source: Some(source) },
              }
            None => ()
          }
        }
        None => ()
      }
    None => ()
  }
  match diagnostic.detail.source {
    Some(_) => diagnostic
    None =>
      match diagnostic.detail.module_path {
        Some(path) =>
          match S::get_source(sourcemap, path) {
            Some(source) =>
              {
                ..diagnostic,
                detail: { ..diagnostic.detail, source: Some(source) },
              }
            None => diagnostic
          }
        None =>
          match S::get_default_source(sourcemap) {
            Some(source) =>
              {
                ..diagnostic,
                detail: { ..diagnostic.detail, source: Some(source) },
              }
            None => diagnostic
          }
      }
  }
}

///|
pub fn[S : SourceMap] Diagnostic::unmangle_with_sourcemap(
  self : Diagnostic,
  sourcemap : S,
) -> Diagnostic {
  let message = S::unmangle_text(sourcemap, self.message())
  Diagnostic::{ ..self, detail: { ..self.detail, message: Some(message) } }
  .with_sourcemap(sourcemap)
  .infer_span_from_message()
}

///|
pub fn Diagnostic::unmangle_with_mangler(
  self : Diagnostic,
  mangler : ManglerKind,
) -> Diagnostic {
  let text = self.message()
  let parts : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < text.length() {
    let code = text.code_unit_at(index).to_int()
    if diagnostic_is_identifier_char(code) {
      if start < index {
        parts.push(text[start:index].to_owned())
      }
      let ident_start = index
      index += 1
      while index < text.length() &&
            diagnostic_is_identifier_char(text.code_unit_at(index).to_int()) {
        index += 1
      }
      let ident = text[ident_start:index].to_owned()
      match ManglerKind::unmangle(mangler, ident) {
        Some((path, item)) => parts.push("\{path.to_string()}::\{item}")
        None => parts.push(ident)
      }
      start = index
    } else {
      index += 1
    }
  }
  if start < text.length() {
    parts.push(text[start:text.length()].to_owned())
  }
  { ..self, detail: { ..self.detail, message: Some(parts.join("")) } }
}

///|
fn diagnostic_is_identifier_char(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
pub fn Diagnostic::display_origin(self : Diagnostic) -> String {
  match (self.detail.module_path, self.detail.display_name) {
    (Some(path), Some(name)) => "\{path.to_string()} (\{name})"
    (Some(path), None) => path.to_string()
    (None, Some(name)) => name
    (None, None) => "unknown module"
  }
}

///|
pub fn Diagnostic::display_short_origin(self : Diagnostic) -> String? {
  match self.detail.display_name {
    Some(name) => Some(name)
    None =>
      match self.detail.module_path {
        Some(path) => Some(path.to_string())
        None => None
      }
  }
}

///|
fn diagnostic_parse_decimal_at(text : String, start : Int) -> (Int, Int)? {
  let mut index = start
  let mut value = 0
  let mut saw_digit = false
  while index < text.length() {
    let code = text.code_unit_at(index).to_int()
    if code < 48 || code > 57 {
      break
    }
    saw_digit = true
    value = value * 10 + code - 48
    index += 1
  }
  if saw_digit {
    Some((value, index))
  } else {
    None
  }
}

///|
fn diagnostic_line_from_origin(message : String, origin : String) -> Int? {
  match message.find(origin + ":") {
    Some(start) =>
      match diagnostic_parse_decimal_at(message, start + origin.length() + 1) {
        Some((line, _)) => Some(line)
        None => None
      }
    None => None
  }
}

///|
pub fn Diagnostic::infer_span_from_message(self : Diagnostic) -> Diagnostic {
  match (self.detail.source, self.detail.span) {
    (Some(source), None) => {
      let message = self.message()
      let mut inferred_line : Int? = None
      match self.detail.module_path {
        Some(path) =>
          inferred_line = diagnostic_line_from_origin(message, path.to_string())
        None => ()
      }
      match inferred_line {
        None =>
          match self.detail.display_name {
            Some(name) =>
              inferred_line = diagnostic_line_from_origin(message, name)
            None => ()
          }
        Some(_) => ()
      }
      match inferred_line {
        Some(line) =>
          self.with_span(SourceSpan::from_line_range(source, line, line))
        None => self
      }
    }
    _ => self
  }
}

///|
fn Diagnostic::snippet_line(self : Diagnostic) -> String? {
  match (self.detail.source, self.detail.span) {
    (Some(source), Some(span)) => {
      let line_start = diagnostic_line_start(source, span.start.line)
      let line_end = diagnostic_line_end(source, line_start)
      Some(source[line_start:line_end].to_owned())
    }
    _ => None
  }
}

///|
fn Diagnostic::snippet_caret(self : Diagnostic) -> String? {
  match self.detail.span {
    Some(span) => {
      let start_column = if span.start.column < 1 {
        1
      } else {
        span.start.column
      }
      let end_column = if span.end.line == span.start.line &&
        span.end.column > start_column {
        span.end.column
      } else {
        start_column + 1
      }
      Some(
        diagnostic_repeat(" ", start_column - 1) +
        diagnostic_repeat("^", end_column - start_column),
      )
    }
    None => None
  }
}

///|
pub fn Diagnostic::to_string(self : Diagnostic) -> String {
  let message = self.message()
  let origin = self.display_origin()
  let note = match self.detail.declaration {
    Some(decl) => "in declaration of `\{decl}` in \{origin}"
    None => "in \{origin}"
  }
  let parts : Array[String] = ["error: \{message}"]
  match self.detail.span {
    Some(span) => {
      match self.display_short_origin() {
        Some(path) =>
          parts.push(" --> \{path}:\{span.start.line}:\{span.start.column}")
        None =>
          parts.push(" --> <unknown>:\{span.start.line}:\{span.start.column}")
      }
      match self.snippet_line() {
        Some(line) => {
          parts.push("  |")
          parts.push("\{span.start.line} | \{line}")
          match self.snippet_caret() {
            Some(caret) => parts.push("  | \{caret} \{message}")
            None => ()
          }
        }
        None =>
          match self.detail.source {
            Some(_) =>
              parts.push(
                "note: cannot display snippet: invalid source location",
              )
            None =>
              parts.push("note: cannot display snippet: missing source file")
          }
      }
    }
    None => ()
  }
  parts.push("note: \{note}")
  parts.join("\n")
}
