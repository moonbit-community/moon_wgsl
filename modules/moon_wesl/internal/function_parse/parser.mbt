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
priv suberror YYObj_Array_FunctionParameterParseNode_ {
  YYObj_Array_FunctionParameterParseNode_(Array[FunctionParameterParseNode])
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_FunctionParseNode {
  YYObj_FunctionParseNode(FunctionParseNode)
}

///|
priv suberror YYObj_FunctionParameterParseNode {
  YYObj_FunctionParameterParseNode(FunctionParameterParseNode)
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
  T_GENERICS
  T_PARAM
  T_RETURN_TYPE
  T_FN
  T_LEFT_PAREN
  T_RIGHT_PAREN
  T_BODY
  NT_parse_function_decl
  NT_opt_generics
  NT_params
  NT_opt_return
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
// 22|    "fn" IDENT opt_generics "(" params ")" opt_return BODY
// 23|                                  { { name: $2, generic_parameters: $3, parameters: $5, return_type: $7, body_text: $8 } }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_String_(_dollar3)
  guard _args[4].0 is YYObj_Array_FunctionParameterParseNode_(_dollar5)
  guard _args[6].0 is YYObj_String_(_dollar7)
  guard _args[7].0 is YYObj_String(_dollar8)
  YYObj_FunctionParseNode(
    {
      ()
      {
        name: _dollar2,
        generic_parameters: _dollar3,
        parameters: _dollar5,
        return_type: _dollar7,
        body_text: _dollar8,
      }
    },
  )
}

// file:///./parser.mbty
// 38|    RETURN_TYPE                   { Some($1) }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String_(
    {
      ()
      Some(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 37|                                  { None }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_String_(
    {
      ()
      None
    },
  )
}

// file:///./parser.mbty
// 33|    params PARAM                  { $1.push($2); $1 }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_FunctionParameterParseNode_(_dollar1)
  guard _args[1].0 is YYObj_FunctionParameterParseNode(_dollar2)
  YYObj_Array_FunctionParameterParseNode_(
    {
      ()
      _dollar1.push(_dollar2)
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 32|                                  { [] }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array_FunctionParameterParseNode_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 28|    GENERICS                      { Some($1) }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String_(
    {
      ()
      Some(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 27|                                  { None }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_String_(
    {
      ()
      None
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
    GENERICS(data) => (T_GENERICS, YYObj_String(data))
    PARAM(data) => (T_PARAM, YYObj_FunctionParameterParseNode(data))
    RETURN_TYPE(data) => (T_RETURN_TYPE, YYObj_String(data))
    FN => (T_FN, YYObj_Void)
    LEFT_PAREN => (T_LEFT_PAREN, YYObj_Void)
    RIGHT_PAREN => (T_RIGHT_PAREN, YYObj_Void)
    BODY(data) => (T_BODY, YYObj_String(data))
  }
}

// [0, parse_function_decl → • FN IDENT opt_generics LEFT_PAREN params RIGHT_PAREN opt_return BODY, $]
// [7, parse_function_decl_prime → • parse_function_decl, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_parse_function_decl => Shift(yy_state_1)
    T_FN => Shift(yy_state_2)
    _ => Error
  }
}

// [7, parse_function_decl_prime → parse_function_decl •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [0, parse_function_decl → FN • IDENT opt_generics LEFT_PAREN params RIGHT_PAREN opt_return BODY, $]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_3)
    _ => Error
  }
}

// [0, parse_function_decl → FN IDENT • opt_generics LEFT_PAREN params RIGHT_PAREN opt_return BODY, $]
// [1, opt_generics → •, LEFT_PAREN]
// [2, opt_generics → • GENERICS, LEFT_PAREN]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_GENERICS => Shift(yy_state_4)
    NT_opt_generics => Shift(yy_state_5)
    T_LEFT_PAREN => Reduce(0, NT_opt_generics, yy_action_6)
    _ => Error
  }
}

// [2, opt_generics → GENERICS •, LEFT_PAREN]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_opt_generics, yy_action_5)
}

// [0, parse_function_decl → FN IDENT opt_generics • LEFT_PAREN params RIGHT_PAREN opt_return BODY, $]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LEFT_PAREN => Shift(yy_state_6)
    _ => Error
  }
}

// [0, parse_function_decl → FN IDENT opt_generics LEFT_PAREN • params RIGHT_PAREN opt_return BODY, $]
// [3, params → •, PARAM / RIGHT_PAREN]
// [4, params → • params PARAM, PARAM / RIGHT_PAREN]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_params => Shift(yy_state_7)
    T_PARAM | T_RIGHT_PAREN => Reduce(0, NT_params, yy_action_4)
    _ => Error
  }
}

// [0, parse_function_decl → FN IDENT opt_generics LEFT_PAREN params • RIGHT_PAREN opt_return BODY, $]
// [4, params → params • PARAM, PARAM / RIGHT_PAREN]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PARAM => Shift(yy_state_8)
    T_RIGHT_PAREN => Shift(yy_state_9)
    _ => Error
  }
}

// [4, params → params PARAM •, PARAM / RIGHT_PAREN]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_params, yy_action_3)
}

// [0, parse_function_decl → FN IDENT opt_generics LEFT_PAREN params RIGHT_PAREN • opt_return BODY, $]
// [5, opt_return → •, BODY]
// [6, opt_return → • RETURN_TYPE, BODY]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RETURN_TYPE => Shift(yy_state_10)
    NT_opt_return => Shift(yy_state_11)
    T_BODY => Reduce(0, NT_opt_return, yy_action_2)
    _ => Error
  }
}

// [6, opt_return → RETURN_TYPE •, BODY]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_opt_return, yy_action_1)
}

// [0, parse_function_decl → FN IDENT opt_generics LEFT_PAREN params RIGHT_PAREN opt_return • BODY, $]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BODY => Shift(yy_state_12)
    _ => Error
  }
}

// [0, parse_function_decl → FN IDENT opt_generics LEFT_PAREN params RIGHT_PAREN opt_return BODY •, $]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_parse_function_decl, yy_action_0)
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
        (T_GENERICS, TK_GENERICS),
        (T_PARAM, TK_PARAM),
        (T_RETURN_TYPE, TK_RETURN_TYPE),
        (T_FN, TK_FN),
        (T_LEFT_PAREN, TK_LEFT_PAREN),
        (T_RIGHT_PAREN, TK_RIGHT_PAREN),
        (T_BODY, TK_BODY),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn parse_function_decl(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> FunctionParseNode raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_FunctionParseNode(result)
      result
    },
    initial_pos?,
  )
}
