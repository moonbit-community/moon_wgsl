///|
pub suberror ParseError {
  UnexpectedToken(Token, (Int, Int), Array[TokenKind])
  UnexpectedEndOfInput(Int, Array[TokenKind])
} derive(Debug)

///|
type YYObj = Error

///|
priv suberror YYObj_Void

///|
priv suberror YYObj_Array_String_ {
  YYObj_Array_String_(Array[String])
}

///|
priv suberror YYObj_Array_ImportParseNode_ {
  YYObj_Array_ImportParseNode_(Array[ImportParseNode])
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_ImportParseNode {
  YYObj_ImportParseNode(ImportParseNode)
}

///|
priv suberror YYObj_String_ {
  YYObj_String_(String?)
}

///|
type YYState = (YYSymbol) -> YYDecision

///|
type YYAction = (Int, ArrayView[(YYObj, Int, Int)]) -> YYObj

///|
priv enum YYDecision {
  Accept
  Shift(YYState)
  Reduce(Int, YYSymbol, YYAction)
  ReduceNoLookahead(Int, YYSymbol, YYAction)
  Error
}

///|
priv enum YYSymbol {
  T_IDENT
  T_AS
  T_DOUBLE_COLON
  T_COMMA
  T_LEFT_BRACE
  T_RIGHT_BRACE
  NT_parse_import_tree
  NT_import_item_list
  NT_import_item
  NT_path_segments
  NT_opt_alias
  EOI
}

// Workaround for EOI unused warning

///|
fn init {
  match (EOI : YYSymbol) {
    EOI => ()
    _ => ()
  }
}

// file:///./parser.mbty
// 22|    import_item_list             { $1 }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportParseNode_(_dollar1)
  YYObj_Array_ImportParseNode_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 23|    "{" import_item_list "}"     { $2 }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_ImportParseNode_(_dollar2)
  YYObj_Array_ImportParseNode_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 34|    path_segments opt_alias
// 35|                                 { { path_segments: $1, rename: $2, children: [] } }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  guard _args[1].0 is YYObj_String_(_dollar2)
  YYObj_ImportParseNode(
    {
      ()
      { path_segments: _dollar1, rename: _dollar2, children: [] }
    },
  )
}

// file:///./parser.mbty
// 27|    import_item                  { [$1] }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ImportParseNode(_dollar1)
  YYObj_Array_ImportParseNode_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 28|    import_item_list "," import_item
// 29|                                 { $1.push($3); $1 }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportParseNode_(_dollar1)
  guard _args[2].0 is YYObj_ImportParseNode(_dollar3)
  YYObj_Array_ImportParseNode_(
    {
      ()
      _dollar1.push(_dollar3)
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 30|    import_item_list ","         { $1 }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ImportParseNode_(_dollar1)
  YYObj_Array_ImportParseNode_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 36|    path_segments "::" "{" import_item_list "}"
// 37|                                 { { path_segments: $1, rename: None, children: $4 } }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  guard _args[3].0 is YYObj_Array_ImportParseNode_(_dollar4)
  YYObj_ImportParseNode(
    {
      ()
      { path_segments: _dollar1, rename: None, children: _dollar4 }
    },
  )
}

// file:///./parser.mbty
// 42|    path_segments "::" IDENT     { $1.push($3); $1 }

///|
fn yy_action_7(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_Array_String_(
    {
      ()
      _dollar1.push(_dollar3)
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 47|    "as" IDENT                   { Some($2) }

///|
fn yy_action_8(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  YYObj_String_(
    {
      ()
      Some(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 46|                                 { None }

///|
fn yy_action_9(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_String_(
    {
      ()
      None
    },
  )
}

// file:///./parser.mbty
// 41|    IDENT                        { [$1] }

///|
fn yy_action_10(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Array_String_(
    {
      ()
      [_dollar1]
    },
  )
}

///|
fn yy_input(
  token : Token,
  _start_pos : Int,
  _end_pos : Int,
) -> (YYSymbol, YYObj) {
  match token {
    IDENT(data) => (T_IDENT, YYObj_String(data))
    AS => (T_AS, YYObj_Void)
    DOUBLE_COLON => (T_DOUBLE_COLON, YYObj_Void)
    COMMA => (T_COMMA, YYObj_Void)
    LEFT_BRACE => (T_LEFT_BRACE, YYObj_Void)
    RIGHT_BRACE => (T_RIGHT_BRACE, YYObj_Void)
  }
}

// [0, parse_import_tree → • import_item_list, $]
// [1, parse_import_tree → • LEFT_BRACE import_item_list RIGHT_BRACE, $]
// [2, import_item_list → • import_item, $ / COMMA]
// [3, import_item_list → • import_item_list COMMA import_item, $ / COMMA]
// [4, import_item_list → • import_item_list COMMA, $ / COMMA]
// [5, import_item → • path_segments opt_alias, $ / COMMA]
// [6, import_item → • path_segments DOUBLE_COLON LEFT_BRACE import_item_list RIGHT_BRACE, $ / COMMA]
// [7, path_segments → • IDENT, $ / AS / DOUBLE_COLON / COMMA]
// [8, path_segments → • path_segments DOUBLE_COLON IDENT, $ / AS / DOUBLE_COLON / COMMA]
// [11, parse_import_tree_prime → • parse_import_tree, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_parse_import_tree => Shift(yy_state_1)
    T_IDENT => Shift(yy_state_2)
    NT_path_segments => Shift(yy_state_3)
    NT_import_item => Shift(yy_state_13)
    T_LEFT_BRACE => Shift(yy_state_15)
    NT_import_item_list => Shift(yy_state_18)
    _ => Error
  }
}

// [11, parse_import_tree_prime → parse_import_tree •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [7, path_segments → IDENT •, $ / AS / DOUBLE_COLON / COMMA / RIGHT_BRACE]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_path_segments, yy_action_10)
}

// [5, import_item → path_segments • opt_alias, $ / COMMA / RIGHT_BRACE]
// [6, import_item → path_segments • DOUBLE_COLON LEFT_BRACE import_item_list RIGHT_BRACE, $ / COMMA / RIGHT_BRACE]
// [8, path_segments → path_segments • DOUBLE_COLON IDENT, $ / AS / DOUBLE_COLON / COMMA / RIGHT_BRACE]
// [9, opt_alias → •, $ / COMMA / RIGHT_BRACE]
// [10, opt_alias → • AS IDENT, $ / COMMA / RIGHT_BRACE]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AS => Shift(yy_state_4)
    T_DOUBLE_COLON => Shift(yy_state_6)
    NT_opt_alias => Shift(yy_state_14)
    T_COMMA | T_RIGHT_BRACE | EOI => Reduce(0, NT_opt_alias, yy_action_9)
    _ => Error
  }
}

// [10, opt_alias → AS • IDENT, $ / COMMA / RIGHT_BRACE]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_5)
    _ => Error
  }
}

// [10, opt_alias → AS IDENT •, $ / COMMA / RIGHT_BRACE]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_opt_alias, yy_action_8)
}

// [6, import_item → path_segments DOUBLE_COLON • LEFT_BRACE import_item_list RIGHT_BRACE, $ / COMMA / RIGHT_BRACE]
// [8, path_segments → path_segments DOUBLE_COLON • IDENT, $ / AS / DOUBLE_COLON / COMMA / RIGHT_BRACE]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_7)
    T_LEFT_BRACE => Shift(yy_state_8)
    _ => Error
  }
}

// [8, path_segments → path_segments DOUBLE_COLON IDENT •, $ / AS / DOUBLE_COLON / COMMA / RIGHT_BRACE]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_path_segments, yy_action_7)
}

// [2, import_item_list → • import_item, COMMA / RIGHT_BRACE]
// [3, import_item_list → • import_item_list COMMA import_item, COMMA / RIGHT_BRACE]
// [4, import_item_list → • import_item_list COMMA, COMMA / RIGHT_BRACE]
// [5, import_item → • path_segments opt_alias, COMMA / RIGHT_BRACE]
// [6, import_item → • path_segments DOUBLE_COLON LEFT_BRACE import_item_list RIGHT_BRACE, COMMA / RIGHT_BRACE]
// [6, import_item → path_segments DOUBLE_COLON LEFT_BRACE • import_item_list RIGHT_BRACE, $ / COMMA / RIGHT_BRACE]
// [7, path_segments → • IDENT, AS / DOUBLE_COLON / COMMA / RIGHT_BRACE]
// [8, path_segments → • path_segments DOUBLE_COLON IDENT, AS / DOUBLE_COLON / COMMA / RIGHT_BRACE]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_2)
    NT_path_segments => Shift(yy_state_3)
    NT_import_item_list => Shift(yy_state_9)
    NT_import_item => Shift(yy_state_13)
    _ => Error
  }
}

// [3, import_item_list → import_item_list • COMMA import_item, COMMA / RIGHT_BRACE]
// [4, import_item_list → import_item_list • COMMA, COMMA / RIGHT_BRACE]
// [6, import_item → path_segments DOUBLE_COLON LEFT_BRACE import_item_list • RIGHT_BRACE, $ / COMMA / RIGHT_BRACE]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RIGHT_BRACE => Shift(yy_state_10)
    T_COMMA => Shift(yy_state_11)
    _ => Error
  }
}

// [6, import_item → path_segments DOUBLE_COLON LEFT_BRACE import_item_list RIGHT_BRACE •, $ / COMMA / RIGHT_BRACE]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_import_item, yy_action_6)
}

// [3, import_item_list → import_item_list COMMA • import_item, $ / COMMA / RIGHT_BRACE]
// [4, import_item_list → import_item_list COMMA •, $ / COMMA / RIGHT_BRACE]
// [5, import_item → • path_segments opt_alias, $ / COMMA / RIGHT_BRACE]
// [6, import_item → • path_segments DOUBLE_COLON LEFT_BRACE import_item_list RIGHT_BRACE, $ / COMMA / RIGHT_BRACE]
// [7, path_segments → • IDENT, $ / AS / DOUBLE_COLON / COMMA / RIGHT_BRACE]
// [8, path_segments → • path_segments DOUBLE_COLON IDENT, $ / AS / DOUBLE_COLON / COMMA / RIGHT_BRACE]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_2)
    NT_path_segments => Shift(yy_state_3)
    NT_import_item => Shift(yy_state_12)
    T_COMMA | T_RIGHT_BRACE | EOI => Reduce(2, NT_import_item_list, yy_action_5)
    _ => Error
  }
}

// [3, import_item_list → import_item_list COMMA import_item •, $ / COMMA / RIGHT_BRACE]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_item_list, yy_action_4)
}

// [2, import_item_list → import_item •, $ / COMMA / RIGHT_BRACE]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_import_item_list, yy_action_3)
}

// [5, import_item → path_segments opt_alias •, $ / COMMA / RIGHT_BRACE]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_import_item, yy_action_2)
}

// [1, parse_import_tree → LEFT_BRACE • import_item_list RIGHT_BRACE, $]
// [2, import_item_list → • import_item, COMMA / RIGHT_BRACE]
// [3, import_item_list → • import_item_list COMMA import_item, COMMA / RIGHT_BRACE]
// [4, import_item_list → • import_item_list COMMA, COMMA / RIGHT_BRACE]
// [5, import_item → • path_segments opt_alias, COMMA / RIGHT_BRACE]
// [6, import_item → • path_segments DOUBLE_COLON LEFT_BRACE import_item_list RIGHT_BRACE, COMMA / RIGHT_BRACE]
// [7, path_segments → • IDENT, AS / DOUBLE_COLON / COMMA / RIGHT_BRACE]
// [8, path_segments → • path_segments DOUBLE_COLON IDENT, AS / DOUBLE_COLON / COMMA / RIGHT_BRACE]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_2)
    NT_path_segments => Shift(yy_state_3)
    NT_import_item => Shift(yy_state_13)
    NT_import_item_list => Shift(yy_state_16)
    _ => Error
  }
}

// [1, parse_import_tree → LEFT_BRACE import_item_list • RIGHT_BRACE, $]
// [3, import_item_list → import_item_list • COMMA import_item, COMMA / RIGHT_BRACE]
// [4, import_item_list → import_item_list • COMMA, COMMA / RIGHT_BRACE]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_11)
    T_RIGHT_BRACE => Shift(yy_state_17)
    _ => Error
  }
}

// [1, parse_import_tree → LEFT_BRACE import_item_list RIGHT_BRACE •, $]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_parse_import_tree, yy_action_1)
}

// [0, parse_import_tree → import_item_list •, $]
// [3, import_item_list → import_item_list • COMMA import_item, $ / COMMA]
// [4, import_item_list → import_item_list • COMMA, $ / COMMA]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_11)
    EOI => Reduce(1, NT_parse_import_tree, yy_action_0)
    _ => Error
  }
}

///|
fn[T] yy_parse(
  tokens : Array[(Token, Int, Int)],
  start : YYState,
  return_ : (YYObj) -> T,
  initial_pos? : Int,
) -> T raise ParseError {
  let mut cursor = 0
  let mut state_stack : @list.List[YYState] = @list.cons(start, @list.empty())
  let data_stack : Array[(YYObj, Int, Int)] = []
  let mut last_pos = initial_pos.unwrap_or(tokens[0].1)
  let mut state = start
  let mut lookahead : (YYSymbol, (YYObj, Int, Int), Token?)? = None
  let mut last_shifted_state_stack = state_stack
  while true {
    let decision = match state(EOI) {
      ReduceNoLookahead(_) | Accept as t => t
      _ =>
        match lookahead {
          Some(la) => state(la.0)
          None =>
            if cursor < tokens.length() {
              let (token, start_pos, end_pos) = tokens[cursor]
              cursor += 1
              let (symbol, data) = yy_input(token, start_pos, end_pos)
              lookahead = Some(
                (symbol, (data, start_pos, end_pos), Some(token)),
              )
              state(symbol)
            } else {
              lookahead = Some((EOI, (YYObj_Void, last_pos, last_pos), None))
              state(EOI)
            }
        }
    }
    match decision {
      Accept => return return_(data_stack.unsafe_pop().0)
      Shift(next_state) => {
        guard lookahead is Some(la)
        data_stack.push(la.1)
        state_stack = @list.cons(next_state, state_stack)
        last_shifted_state_stack = state_stack
        state = next_state
        last_pos = la.1.2
        lookahead = None
      }
      Reduce(count, symbol, action)
      | ReduceNoLookahead(count, symbol, action) =>
        for count = count, symbol = symbol, action = action {
          let args = data_stack[data_stack.length() - count:]
          let data = action(last_pos, args)
          let (start_pos, end_pos) = if args.length() == 0 {
            (last_pos, last_pos)
          } else {
            (args[0].1, args[args.length() - 1].2)
          }
          for _ in 0..<count {
            ignore(data_stack.unsafe_pop())
            state_stack = state_stack.unsafe_tail()
          }
          state = state_stack.unsafe_head()
          data_stack.push((data, start_pos, end_pos))
          match state(symbol) {
            Accept => return return_(data_stack.unsafe_pop().0)
            Shift(next_state) => {
              state_stack = @list.cons(next_state, state_stack)
              state = next_state
              break ()
            }
            Reduce(count, symbol, action)
            | ReduceNoLookahead(count, symbol, action) =>
              continue count, symbol, action
            _ => panic()
          }
        }
      Error => {
        let (_, (_, start_pos, end_pos), token) = lookahead.unwrap()
        error(last_shifted_state_stack, token, (start_pos, end_pos))
      }
    }
  }
  panic()
}

///|
fn error(
  stack : @list.List[YYState],
  token : Token?,
  loc : (Int, Int),
) -> Unit raise ParseError {
  let expected = []
  fn try_add(symbol : YYSymbol, kind : TokenKind) {
    fn go(stack : @list.List[YYState]) {
      match stack {
        Empty => ()
        More(state, ..) =>
          match state(symbol) {
            Accept | Shift(_) => expected.push(kind)
            Reduce(count, symbol, _) | ReduceNoLookahead(count, symbol, _) => {
              fn inner_go(stack : @list.List[YYState], count, symbol) {
                let stack = stack.drop(count)
                guard stack is More(state, ..)
                match state(symbol) {
                  Shift(state) => go(@list.cons(state, stack))
                  Reduce(count, symbol, _)
                  | ReduceNoLookahead(count, symbol, _) =>
                    inner_go(stack, count, symbol)
                  _ => panic()
                }
              }
              inner_go(stack, count, symbol)
            }
            Error => ()
          }
      }
    }
    go(stack)
  }
  for
    term in (
      [
        (T_IDENT, TK_IDENT),
        (T_AS, TK_AS),
        (T_DOUBLE_COLON, TK_DOUBLE_COLON),
        (T_COMMA, TK_COMMA),
        (T_LEFT_BRACE, TK_LEFT_BRACE),
        (T_RIGHT_BRACE, TK_RIGHT_BRACE),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn parse_import_tree(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[ImportParseNode] raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_Array_ImportParseNode_(result)
      result
    },
    initial_pos?,
  )
}
