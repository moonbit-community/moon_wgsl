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
priv suberror YYObj_Array_TypeTemplateArgumentParseNode_ {
  YYObj_Array_TypeTemplateArgumentParseNode_(
    Array[TypeTemplateArgumentParseNode]
  )
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_TypeSpecifierParseNode {
  YYObj_TypeSpecifierParseNode(TypeSpecifierParseNode)
}

///|
priv suberror YYObj_TypeTemplateArgumentParseNode {
  YYObj_TypeTemplateArgumentParseNode(TypeTemplateArgumentParseNode)
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
  T_NUMBER
  T_DOUBLE_COLON
  T_LESS
  T_GREATER
  T_SHIFT_LEFT
  T_COMMA
  T_MINUS
  NT_parse_type_specifier
  NT_type_specifier
  NT_path_ident
  NT_opt_template
  NT_template_arg_list
  NT_template_arg
  NT_shift_literal
  NT_signed_literal
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
// 26|    type_specifier                { $1 }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeSpecifierParseNode(_dollar1)
  YYObj_TypeSpecifierParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 30|    path_ident opt_template       { $1.with_template_args($2) }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeSpecifierParseNode(_dollar1)
  guard _args[1].0 is YYObj_Array_TypeTemplateArgumentParseNode_(_dollar2)
  YYObj_TypeSpecifierParseNode(
    {
      ()
      _dollar1.with_template_args(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 35|    path_ident "::" IDENT         { $1.qualified_child($3) }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeSpecifierParseNode(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_TypeSpecifierParseNode(
    {
      ()
      _dollar1.qualified_child(_dollar3)
    },
  )
}

// file:///./parser.mbty
// 40|    "<" template_arg_list ">"     { $2 }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeTemplateArgumentParseNode_(_dollar2)
  YYObj_Array_TypeTemplateArgumentParseNode_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 41|    "<" template_arg_list "," ">" { $2 }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TypeTemplateArgumentParseNode_(_dollar2)
  YYObj_Array_TypeTemplateArgumentParseNode_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 46|    template_arg_list "," template_arg
// 47|                                  { $1.push($3); $1 }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_TypeTemplateArgumentParseNode_(_dollar1)
  guard _args[2].0 is YYObj_TypeTemplateArgumentParseNode(_dollar3)
  YYObj_Array_TypeTemplateArgumentParseNode_(
    {
      ()
      _dollar1.push(_dollar3)
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 45|    template_arg                  { [$1] }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeTemplateArgumentParseNode(_dollar1)
  YYObj_Array_TypeTemplateArgumentParseNode_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 51|    type_specifier                { TypeTemplateArgumentParseNode::Type($1) }

///|
fn yy_action_7(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_TypeSpecifierParseNode(_dollar1)
  YYObj_TypeTemplateArgumentParseNode(
    {
      ()
      TypeTemplateArgumentParseNode::Type(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 52|    shift_literal                 { TypeTemplateArgumentParseNode::Literal($1) }

///|
fn yy_action_8(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_TypeTemplateArgumentParseNode(
    {
      ()
      TypeTemplateArgumentParseNode::Literal(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 57|    signed_literal "<<" signed_literal
// 58|                                  { $1 + " << " + $3 }

///|
fn yy_action_9(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_String(
    {
      ()
      _dollar1 + " << " + _dollar3
    },
  )
}

// file:///./parser.mbty
// 56|    signed_literal                { $1 }

///|
fn yy_action_10(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 62|    NUMBER                        { $1 }

///|
fn yy_action_11(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 63|    "-" NUMBER                    { "-" + $2 }

///|
fn yy_action_12(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  YYObj_String(
    {
      ()
      "-" + _dollar2
    },
  )
}

// file:///./parser.mbty
// 39|                                  { [] }

///|
fn yy_action_13(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array_TypeTemplateArgumentParseNode_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 34|    IDENT                         { TypeSpecifierParseNode::from_path([$1]) }

///|
fn yy_action_14(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_TypeSpecifierParseNode(
    {
      ()
      TypeSpecifierParseNode::from_path([_dollar1])
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
    NUMBER(data) => (T_NUMBER, YYObj_String(data))
    DOUBLE_COLON => (T_DOUBLE_COLON, YYObj_Void)
    LESS => (T_LESS, YYObj_Void)
    GREATER => (T_GREATER, YYObj_Void)
    SHIFT_LEFT => (T_SHIFT_LEFT, YYObj_Void)
    COMMA => (T_COMMA, YYObj_Void)
    MINUS => (T_MINUS, YYObj_Void)
  }
}

// [0, parse_type_specifier → • type_specifier, $]
// [1, type_specifier → • path_ident opt_template, $]
// [2, path_ident → • IDENT, $ / DOUBLE_COLON / LESS]
// [3, path_ident → • path_ident DOUBLE_COLON IDENT, $ / DOUBLE_COLON / LESS]
// [15, parse_type_specifier_prime → • parse_type_specifier, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_parse_type_specifier => Shift(yy_state_1)
    T_IDENT => Shift(yy_state_2)
    NT_path_ident => Shift(yy_state_3)
    NT_type_specifier => Shift(yy_state_22)
    _ => Error
  }
}

// [15, parse_type_specifier_prime → parse_type_specifier •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [2, path_ident → IDENT •, $ / DOUBLE_COLON / LESS / GREATER / COMMA]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_path_ident, yy_action_14)
}

// [1, type_specifier → path_ident • opt_template, $ / GREATER / COMMA]
// [3, path_ident → path_ident • DOUBLE_COLON IDENT, $ / DOUBLE_COLON / LESS / GREATER / COMMA]
// [4, opt_template → •, $ / GREATER / COMMA]
// [5, opt_template → • LESS template_arg_list GREATER, $ / GREATER / COMMA]
// [6, opt_template → • LESS template_arg_list COMMA GREATER, $ / GREATER / COMMA]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LESS => Shift(yy_state_4)
    T_DOUBLE_COLON => Shift(yy_state_19)
    NT_opt_template => Shift(yy_state_21)
    T_GREATER | T_COMMA | EOI => Reduce(0, NT_opt_template, yy_action_13)
    _ => Error
  }
}

// [1, type_specifier → • path_ident opt_template, GREATER / COMMA]
// [2, path_ident → • IDENT, DOUBLE_COLON / LESS / GREATER / COMMA]
// [3, path_ident → • path_ident DOUBLE_COLON IDENT, DOUBLE_COLON / LESS / GREATER / COMMA]
// [5, opt_template → LESS • template_arg_list GREATER, $ / GREATER / COMMA]
// [6, opt_template → LESS • template_arg_list COMMA GREATER, $ / GREATER / COMMA]
// [7, template_arg_list → • template_arg, GREATER / COMMA]
// [8, template_arg_list → • template_arg_list COMMA template_arg, GREATER / COMMA]
// [9, template_arg → • type_specifier, GREATER / COMMA]
// [10, template_arg → • shift_literal, GREATER / COMMA]
// [11, shift_literal → • signed_literal, GREATER / COMMA]
// [12, shift_literal → • signed_literal SHIFT_LEFT signed_literal, GREATER / COMMA]
// [13, signed_literal → • NUMBER, GREATER / SHIFT_LEFT / COMMA]
// [14, signed_literal → • MINUS NUMBER, GREATER / SHIFT_LEFT / COMMA]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_2)
    NT_path_ident => Shift(yy_state_3)
    T_MINUS => Shift(yy_state_5)
    T_NUMBER => Shift(yy_state_7)
    NT_signed_literal => Shift(yy_state_8)
    NT_shift_literal => Shift(yy_state_11)
    NT_type_specifier => Shift(yy_state_12)
    NT_template_arg => Shift(yy_state_13)
    NT_template_arg_list => Shift(yy_state_14)
    _ => Error
  }
}

// [14, signed_literal → MINUS • NUMBER, GREATER / SHIFT_LEFT / COMMA]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NUMBER => Shift(yy_state_6)
    _ => Error
  }
}

// [14, signed_literal → MINUS NUMBER •, GREATER / SHIFT_LEFT / COMMA]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_signed_literal, yy_action_12)
}

// [13, signed_literal → NUMBER •, GREATER / SHIFT_LEFT / COMMA]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_signed_literal, yy_action_11)
}

// [11, shift_literal → signed_literal •, GREATER / COMMA]
// [12, shift_literal → signed_literal • SHIFT_LEFT signed_literal, GREATER / COMMA]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHIFT_LEFT => Shift(yy_state_9)
    T_GREATER | T_COMMA => Reduce(1, NT_shift_literal, yy_action_10)
    _ => Error
  }
}

// [12, shift_literal → signed_literal SHIFT_LEFT • signed_literal, GREATER / COMMA]
// [13, signed_literal → • NUMBER, GREATER / COMMA]
// [14, signed_literal → • MINUS NUMBER, GREATER / COMMA]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MINUS => Shift(yy_state_5)
    T_NUMBER => Shift(yy_state_7)
    NT_signed_literal => Shift(yy_state_10)
    _ => Error
  }
}

// [12, shift_literal → signed_literal SHIFT_LEFT signed_literal •, GREATER / COMMA]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_shift_literal, yy_action_9)
}

// [10, template_arg → shift_literal •, GREATER / COMMA]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_template_arg, yy_action_8)
}

// [9, template_arg → type_specifier •, GREATER / COMMA]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_template_arg, yy_action_7)
}

// [7, template_arg_list → template_arg •, GREATER / COMMA]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_template_arg_list, yy_action_6)
}

// [5, opt_template → LESS template_arg_list • GREATER, $ / GREATER / COMMA]
// [6, opt_template → LESS template_arg_list • COMMA GREATER, $ / GREATER / COMMA]
// [8, template_arg_list → template_arg_list • COMMA template_arg, GREATER / COMMA]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_15)
    T_GREATER => Shift(yy_state_18)
    _ => Error
  }
}

// [1, type_specifier → • path_ident opt_template, GREATER / COMMA]
// [2, path_ident → • IDENT, DOUBLE_COLON / LESS / GREATER / COMMA]
// [3, path_ident → • path_ident DOUBLE_COLON IDENT, DOUBLE_COLON / LESS / GREATER / COMMA]
// [6, opt_template → LESS template_arg_list COMMA • GREATER, $ / GREATER / COMMA]
// [8, template_arg_list → template_arg_list COMMA • template_arg, GREATER / COMMA]
// [9, template_arg → • type_specifier, GREATER / COMMA]
// [10, template_arg → • shift_literal, GREATER / COMMA]
// [11, shift_literal → • signed_literal, GREATER / COMMA]
// [12, shift_literal → • signed_literal SHIFT_LEFT signed_literal, GREATER / COMMA]
// [13, signed_literal → • NUMBER, GREATER / SHIFT_LEFT / COMMA]
// [14, signed_literal → • MINUS NUMBER, GREATER / SHIFT_LEFT / COMMA]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_2)
    NT_path_ident => Shift(yy_state_3)
    T_MINUS => Shift(yy_state_5)
    T_NUMBER => Shift(yy_state_7)
    NT_signed_literal => Shift(yy_state_8)
    NT_shift_literal => Shift(yy_state_11)
    NT_type_specifier => Shift(yy_state_12)
    NT_template_arg => Shift(yy_state_16)
    T_GREATER => Shift(yy_state_17)
    _ => Error
  }
}

// [8, template_arg_list → template_arg_list COMMA template_arg •, GREATER / COMMA]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_template_arg_list, yy_action_5)
}

// [6, opt_template → LESS template_arg_list COMMA GREATER •, $ / GREATER / COMMA]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_opt_template, yy_action_4)
}

// [5, opt_template → LESS template_arg_list GREATER •, $ / GREATER / COMMA]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_opt_template, yy_action_3)
}

// [3, path_ident → path_ident DOUBLE_COLON • IDENT, $ / DOUBLE_COLON / LESS / GREATER / COMMA]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_20)
    _ => Error
  }
}

// [3, path_ident → path_ident DOUBLE_COLON IDENT •, $ / DOUBLE_COLON / LESS / GREATER / COMMA]

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_path_ident, yy_action_2)
}

// [1, type_specifier → path_ident opt_template •, $ / GREATER / COMMA]

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_specifier, yy_action_1)
}

// [0, parse_type_specifier → type_specifier •, $]

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_parse_type_specifier, yy_action_0)
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
        (T_NUMBER, TK_NUMBER),
        (T_DOUBLE_COLON, TK_DOUBLE_COLON),
        (T_LESS, TK_LESS),
        (T_GREATER, TK_GREATER),
        (T_SHIFT_LEFT, TK_SHIFT_LEFT),
        (T_COMMA, TK_COMMA),
        (T_MINUS, TK_MINUS),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn parse_type_specifier(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> TypeSpecifierParseNode raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_TypeSpecifierParseNode(result)
      result
    },
    initial_pos?,
  )
}
