///|
fn parse_wgsl_type_ref_text(text : String, base : Int) -> WgslTypeRef? {
  let cleaned = replace_comments(text)
  let (trimmed, local_start, _) = wgsl_trim_fragment_bounds(
    cleaned,
    0,
    cleaned.length(),
  )
  if trimmed == "" {
    return None
  }
  let source_start = base + local_start
  Some(
    type_ref(tokenize_wgsl_type_ref(trimmed, source_start)) catch {
      _ => return None
    },
  )
}

///|
fn wgsl_type_ref_space(code : Int) -> Bool {
  wgsl_blankspace_code_point(code)
}

///|
fn wgsl_type_ref_delimiter(code : Int) -> Bool {
  code == 60 || code == 62 || code == 44
}

///|
fn wgsl_type_atom_is_identifier_path(text : String) -> Bool {
  if text == "" {
    return false
  }
  let parts = text.split("::")
  for part in parts {
    let segment = part.to_owned()
    if !wgsl_identifier_text(segment) {
      return false
    }
  }
  true
}

///|
fn wgsl_type_atom_kind(text : String) -> WgslTypeAtomKind {
  if text.length() == 0 {
    return Unknown
  }
  let first = text.code_unit_at(0).to_int()
  if first >= 48 && first <= 57 {
    Numeric
  } else if wgsl_type_atom_is_identifier_path(text) {
    Identifier
  } else {
    Unknown
  }
}

///|
fn wgsl_type_ref_top_level_template_start(source : String) -> Int? {
  let mut paren = 0
  let mut bracket = 0
  let mut brace = 0
  for i in 0..<source.length() {
    let code = source.code_unit_at(i).to_int()
    match code {
      40 => paren = paren + 1
      41 => paren = paren - 1
      91 => bracket = bracket + 1
      93 => bracket = bracket - 1
      123 => brace = brace + 1
      125 => brace = brace - 1
      60 if paren == 0 && bracket == 0 && brace == 0 => return Some(i)
      _ => ()
    }
  }
  None
}

///|
fn wgsl_type_ref_matching_template_end(source : String, lt_index : Int) -> Int? {
  let mut angle = 0
  let mut paren = 0
  let mut bracket = 0
  let mut brace = 0
  for i in lt_index..<source.length() {
    let code = source.code_unit_at(i).to_int()
    match code {
      40 => paren = paren + 1
      41 => paren = paren - 1
      91 => bracket = bracket + 1
      93 => bracket = bracket - 1
      123 => brace = brace + 1
      125 => brace = brace - 1
      60 if paren == 0 && bracket == 0 && brace == 0 => angle = angle + 1
      62 if paren == 0 && bracket == 0 && brace == 0 => {
        angle = angle - 1
        if angle == 0 {
          return Some(i)
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn wgsl_template_arg_has_top_level_expression_operator(text : String) -> Bool {
  let mut angle = 0
  let mut paren = 0
  let mut bracket = 0
  let mut brace = 0
  let mut i = 0
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    match code {
      40 => paren = paren + 1
      41 => paren = paren - 1
      91 => bracket = bracket + 1
      93 => bracket = bracket - 1
      123 => brace = brace + 1
      125 => brace = brace - 1
      60 if paren == 0 && bracket == 0 && brace == 0 => angle = angle + 1
      62 if paren == 0 && bracket == 0 && brace == 0 && angle > 0 =>
        angle = angle - 1
      33 | 37 | 38 | 42 | 43 | 45 | 47 | 61 | 94 | 124 =>
        if angle == 0 && paren == 0 && bracket == 0 && brace == 0 {
          return true
        }
      _ => ()
    }
    i = i + 1
  }
  false
}

///|
fn split_wgsl_template_argument_fragments(
  source : String,
  inner_start : Int,
  inner_end : Int,
) -> Array[WgslTextFragment] {
  let fragments : Array[WgslTextFragment] = []
  let mut angle = 0
  let mut paren = 0
  let mut bracket = 0
  let mut brace = 0
  let mut start = inner_start
  let mut i = inner_start
  while i < inner_end {
    let code = source.code_unit_at(i).to_int()
    match code {
      40 => paren = paren + 1
      41 => paren = paren - 1
      91 => bracket = bracket + 1
      93 => bracket = bracket - 1
      123 => brace = brace + 1
      125 => brace = brace - 1
      60 if paren == 0 && bracket == 0 && brace == 0 => angle = angle + 1
      62 if paren == 0 && bracket == 0 && brace == 0 && angle > 0 =>
        angle = angle - 1
      44 if angle == 0 && paren == 0 && bracket == 0 && brace == 0 => {
        let (trimmed, local_start, local_end) = wgsl_trim_fragment_bounds(
          source[start:i].to_owned(),
          0,
          i - start,
        )
        if trimmed != "" {
          fragments.push({
            text: trimmed,
            start: start + local_start,
            end: start + local_end,
          })
        }
        start = i + 1
      }
      _ => ()
    }
    i = i + 1
  }
  let (trimmed, local_start, local_end) = wgsl_trim_fragment_bounds(
    source[start:inner_end].to_owned(),
    0,
    inner_end - start,
  )
  if trimmed != "" {
    fragments.push({
      text: trimmed,
      start: start + local_start,
      end: start + local_end,
    })
  }
  fragments
}

///|
fn parse_wgsl_type_template_argument(
  fragment : WgslTextFragment,
  source_start : Int,
) -> WgslTypeArgument? {
  let absolute_start = source_start + fragment.start
  if !wgsl_template_arg_has_top_level_expression_operator(fragment.text) {
    match parse_wgsl_type_ref_text(fragment.text, absolute_start) {
      Some(ty) => return Some(Type(ty))
      None => ()
    }
  }
  match parse_wgsl_expr_ref_text(fragment.text, absolute_start) {
    Some(expr) => Some(Expression(expr))
    None => None
  }
}

///|
fn parse_wgsl_type_template_arguments(
  source : String,
  source_start : Int,
  lt_index : Int,
  gt_index : Int,
) -> Array[WgslTypeArgument] {
  let arguments : Array[WgslTypeArgument] = []
  for
    fragment in split_wgsl_template_argument_fragments(
      source,
      lt_index + 1,
      gt_index,
    ) {
    match parse_wgsl_type_template_argument(fragment, source_start) {
      Some(argument) => arguments.push(argument)
      None => ()
    }
  }
  arguments
}

///|
fn tokenize_wgsl_type_ref(
  source : String,
  source_start : Int,
) -> Array[(Token, Int, Int)] {
  let tokens : Array[(Token, Int, Int)] = []
  match wgsl_type_ref_top_level_template_start(source) {
    Some(lt_index) if lt_index > 0 =>
      match wgsl_type_ref_matching_template_end(source, lt_index) {
        Some(gt_index) if gt_index == source.length() - 1 => {
          let (atom_text, atom_local_start, atom_local_end) = wgsl_trim_fragment_bounds(
            source[0:lt_index].to_owned(),
            0,
            lt_index,
          )
          let atom_start = source_start + atom_local_start
          let atom_end = source_start + atom_local_end
          tokens.push(
            (
              TYPE_ATOM(
                WgslTypeAtom(
                  wgsl_type_atom_kind(atom_text),
                  atom_text,
                  atom_start,
                  atom_end,
                ),
              ),
              atom_start,
              atom_end,
            ),
          )
          tokens.push(
            (
              TYPE_ARGS(
                (
                  parse_wgsl_type_template_arguments(
                    source, source_start, lt_index, gt_index,
                  ),
                  source_start + gt_index + 1,
                ),
              ),
              source_start + lt_index,
              source_start + gt_index + 1,
            ),
          )
          tokens.push(
            (
              EOF,
              source_start + source.length(),
              source_start + source.length(),
            ),
          )
          return tokens
        }
        _ => ()
      }
    _ => ()
  }
  let mut i = 0
  while i < source.length() {
    let code = source.code_unit_at(i).to_int()
    if wgsl_type_ref_space(code) {
      i = i + 1
      continue
    }
    let start = i
    let absolute_start = source_start + start
    if code == 60 {
      tokens.push(
        (TYPE_LT(source_start + start + 1), absolute_start, absolute_start + 1),
      )
      i = i + 1
      continue
    }
    if code == 62 {
      tokens.push(
        (TYPE_GT(source_start + start + 1), absolute_start, absolute_start + 1),
      )
      i = i + 1
      continue
    }
    if code == 44 {
      tokens.push((COMMA, absolute_start, absolute_start + 1))
      i = i + 1
      continue
    }
    while i < source.length() {
      let next = source.code_unit_at(i).to_int()
      if wgsl_type_ref_space(next) || wgsl_type_ref_delimiter(next) {
        break
      }
      i = i + 1
    }
    let absolute_end = source_start + i
    let text = source[start:i].to_owned()
    tokens.push(
      (
        TYPE_ATOM(
          WgslTypeAtom(
            wgsl_type_atom_kind(text),
            text,
            absolute_start,
            absolute_end,
          ),
        ),
        absolute_start,
        absolute_end,
      ),
    )
  }
  tokens.push(
    (EOF, source_start + source.length(), source_start + source.length()),
  )
  tokens
}

///|
fn parse_wgsl_type_ref_fragment(fragment : WgslTextFragment) -> WgslTypeRef? {
  if fragment.start < 0 || fragment.end < fragment.start {
    return None
  }
  parse_wgsl_type_ref_text(fragment.text, fragment.start)
}

///|
priv struct WgslTemplateListFragment {
  text : String
  start : Int
  consumed : Int
}

///|
fn WgslDeclParser::collect_template_list_fragment(
  self : WgslDeclParser,
) -> WgslTemplateListFragment? {
  let view = self.view()
  guard view is [open_token, ..] && open_token.is_punctuation(60) else {
    return None
  }
  let open_pos = open_token.pos()
  let mut depth = 0
  let mut consumed = 0
  let mut end_pos = -1
  while consumed < view.length() {
    if view[consumed].is_punctuation(60) {
      depth = depth + 1
    } else if view[consumed].is_punctuation(62) {
      let pos = view[consumed].pos()
      depth = depth - 1
      if depth == 0 {
        end_pos = pos + 1
        consumed = consumed + 1
        break
      }
    }
    consumed = consumed + 1
  }
  guard end_pos >= open_pos else { return None }
  Some({ text: self.slice(open_pos, end_pos), start: open_pos, consumed })
}

///|
fn WgslDeclParser::parse_template_list(
  self : WgslDeclParser,
) -> Array[WgslTypeRef] {
  match self.collect_template_list_fragment() {
    Some(fragment) => {
      let parsed = template_list(
        tokenize_wgsl_type_ref(fragment.text, fragment.start),
      ) catch {
        _ => return []
      }
      self.drop_tokens(fragment.consumed)
      parsed
    }
    None => []
  }
}

///|
