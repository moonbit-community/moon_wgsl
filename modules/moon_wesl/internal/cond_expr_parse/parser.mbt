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
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_CondExprNode {
  YYObj_CondExprNode(CondExprNode)
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
  T_TRUE
  T_FALSE
  T_BANG
  T_AMP_AMP
  T_PIPE_PIPE
  T_LEFT_PAREN
  T_RIGHT_PAREN
  NT_parse_cond_expr
  NT_or_expr
  NT_and_expr
  NT_not_expr
  NT_primary_expr
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
// 23|    or_expr                      { $1 }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_CondExprNode(_dollar1)
  YYObj_CondExprNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 27|    and_expr                     { $1 }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_CondExprNode(_dollar1)
  YYObj_CondExprNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 33|    and_expr "&&" not_expr       { And($1, $3) }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_CondExprNode(_dollar1)
  guard _args[2].0 is YYObj_CondExprNode(_dollar3)
  YYObj_CondExprNode(
    {
      ()
      And(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 28|    or_expr "||" and_expr        { Or($1, $3) }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_CondExprNode(_dollar1)
  guard _args[2].0 is YYObj_CondExprNode(_dollar3)
  YYObj_CondExprNode(
    {
      ()
      Or(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 45|    "(" or_expr ")"             { $2 }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_CondExprNode(_dollar2)
  YYObj_CondExprNode(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 32|    not_expr                     { $1 }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_CondExprNode(_dollar1)
  YYObj_CondExprNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 37|    primary_expr                 { $1 }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_CondExprNode(_dollar1)
  YYObj_CondExprNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 38|    "!" not_expr                 { Not($2) }

///|
fn yy_action_7(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_CondExprNode(_dollar2)
  YYObj_CondExprNode(
    {
      ()
      Not(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 42|    IDENT                        { Feature($1) }

///|
fn yy_action_8(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_CondExprNode(
    {
      ()
      Feature(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 43|    "true"                       { Literal(true) }

///|
fn yy_action_9(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_CondExprNode(
    {
      ()
      Literal(true)
    },
  )
}

// file:///./parser.mbty
// 44|    "false"                      { Literal(false) }

///|
fn yy_action_10(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_CondExprNode(
    {
      ()
      Literal(false)
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
    TRUE => (T_TRUE, YYObj_Void)
    FALSE => (T_FALSE, YYObj_Void)
    BANG => (T_BANG, YYObj_Void)
    AMP_AMP => (T_AMP_AMP, YYObj_Void)
    PIPE_PIPE => (T_PIPE_PIPE, YYObj_Void)
    LEFT_PAREN => (T_LEFT_PAREN, YYObj_Void)
    RIGHT_PAREN => (T_RIGHT_PAREN, YYObj_Void)
  }
}

// [0, parse_cond_expr → • or_expr, $]
// [1, or_expr → • and_expr, $ / PIPE_PIPE]
// [2, or_expr → • or_expr PIPE_PIPE and_expr, $ / PIPE_PIPE]
// [3, and_expr → • not_expr, $ / AMP_AMP / PIPE_PIPE]
// [4, and_expr → • and_expr AMP_AMP not_expr, $ / AMP_AMP / PIPE_PIPE]
// [5, not_expr → • primary_expr, $ / AMP_AMP / PIPE_PIPE]
// [6, not_expr → • BANG not_expr, $ / AMP_AMP / PIPE_PIPE]
// [7, primary_expr → • IDENT, $ / AMP_AMP / PIPE_PIPE]
// [8, primary_expr → • TRUE, $ / AMP_AMP / PIPE_PIPE]
// [9, primary_expr → • FALSE, $ / AMP_AMP / PIPE_PIPE]
// [10, primary_expr → • LEFT_PAREN or_expr RIGHT_PAREN, $ / AMP_AMP / PIPE_PIPE]
// [11, parse_cond_expr_prime → • parse_cond_expr, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_parse_cond_expr => Shift(yy_state_1)
    T_LEFT_PAREN => Shift(yy_state_2)
    T_FALSE => Shift(yy_state_3)
    T_TRUE => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_BANG => Shift(yy_state_6)
    NT_primary_expr => Shift(yy_state_8)
    NT_not_expr => Shift(yy_state_9)
    NT_and_expr => Shift(yy_state_16)
    NT_or_expr => Shift(yy_state_17)
    _ => Error
  }
}

// [11, parse_cond_expr_prime → parse_cond_expr •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [1, or_expr → • and_expr, PIPE_PIPE / RIGHT_PAREN]
// [2, or_expr → • or_expr PIPE_PIPE and_expr, PIPE_PIPE / RIGHT_PAREN]
// [3, and_expr → • not_expr, AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [4, and_expr → • and_expr AMP_AMP not_expr, AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [5, not_expr → • primary_expr, AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [6, not_expr → • BANG not_expr, AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [7, primary_expr → • IDENT, AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [8, primary_expr → • TRUE, AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [9, primary_expr → • FALSE, AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [10, primary_expr → • LEFT_PAREN or_expr RIGHT_PAREN, AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [10, primary_expr → LEFT_PAREN • or_expr RIGHT_PAREN, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LEFT_PAREN => Shift(yy_state_2)
    T_FALSE => Shift(yy_state_3)
    T_TRUE => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_BANG => Shift(yy_state_6)
    NT_primary_expr => Shift(yy_state_8)
    NT_not_expr => Shift(yy_state_9)
    NT_or_expr => Shift(yy_state_10)
    NT_and_expr => Shift(yy_state_16)
    _ => Error
  }
}

// [9, primary_expr → FALSE •, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expr, yy_action_10)
}

// [8, primary_expr → TRUE •, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expr, yy_action_9)
}

// [7, primary_expr → IDENT •, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary_expr, yy_action_8)
}

// [5, not_expr → • primary_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [6, not_expr → • BANG not_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [6, not_expr → BANG • not_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [7, primary_expr → • IDENT, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [8, primary_expr → • TRUE, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [9, primary_expr → • FALSE, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [10, primary_expr → • LEFT_PAREN or_expr RIGHT_PAREN, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LEFT_PAREN => Shift(yy_state_2)
    T_FALSE => Shift(yy_state_3)
    T_TRUE => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_BANG => Shift(yy_state_6)
    NT_not_expr => Shift(yy_state_7)
    NT_primary_expr => Shift(yy_state_8)
    _ => Error
  }
}

// [6, not_expr → BANG not_expr •, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_not_expr, yy_action_7)
}

// [5, not_expr → primary_expr •, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_not_expr, yy_action_6)
}

// [3, and_expr → not_expr •, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_and_expr, yy_action_5)
}

// [2, or_expr → or_expr • PIPE_PIPE and_expr, PIPE_PIPE / RIGHT_PAREN]
// [10, primary_expr → LEFT_PAREN or_expr • RIGHT_PAREN, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RIGHT_PAREN => Shift(yy_state_11)
    T_PIPE_PIPE => Shift(yy_state_12)
    _ => Error
  }
}

// [10, primary_expr → LEFT_PAREN or_expr RIGHT_PAREN •, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_primary_expr, yy_action_4)
}

// [2, or_expr → or_expr PIPE_PIPE • and_expr, $ / PIPE_PIPE / RIGHT_PAREN]
// [3, and_expr → • not_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [4, and_expr → • and_expr AMP_AMP not_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [5, not_expr → • primary_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [6, not_expr → • BANG not_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [7, primary_expr → • IDENT, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [8, primary_expr → • TRUE, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [9, primary_expr → • FALSE, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [10, primary_expr → • LEFT_PAREN or_expr RIGHT_PAREN, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LEFT_PAREN => Shift(yy_state_2)
    T_FALSE => Shift(yy_state_3)
    T_TRUE => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_BANG => Shift(yy_state_6)
    NT_primary_expr => Shift(yy_state_8)
    NT_not_expr => Shift(yy_state_9)
    NT_and_expr => Shift(yy_state_13)
    _ => Error
  }
}

// [2, or_expr → or_expr PIPE_PIPE and_expr •, $ / PIPE_PIPE / RIGHT_PAREN]
// [4, and_expr → and_expr • AMP_AMP not_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMP_AMP => Shift(yy_state_14)
    T_PIPE_PIPE | T_RIGHT_PAREN | EOI => Reduce(3, NT_or_expr, yy_action_3)
    _ => Error
  }
}

// [4, and_expr → and_expr AMP_AMP • not_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [5, not_expr → • primary_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [6, not_expr → • BANG not_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [7, primary_expr → • IDENT, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [8, primary_expr → • TRUE, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [9, primary_expr → • FALSE, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]
// [10, primary_expr → • LEFT_PAREN or_expr RIGHT_PAREN, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LEFT_PAREN => Shift(yy_state_2)
    T_FALSE => Shift(yy_state_3)
    T_TRUE => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_BANG => Shift(yy_state_6)
    NT_primary_expr => Shift(yy_state_8)
    NT_not_expr => Shift(yy_state_15)
    _ => Error
  }
}

// [4, and_expr → and_expr AMP_AMP not_expr •, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_and_expr, yy_action_2)
}

// [1, or_expr → and_expr •, $ / PIPE_PIPE / RIGHT_PAREN]
// [4, and_expr → and_expr • AMP_AMP not_expr, $ / AMP_AMP / PIPE_PIPE / RIGHT_PAREN]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMP_AMP => Shift(yy_state_14)
    T_PIPE_PIPE | T_RIGHT_PAREN | EOI => Reduce(1, NT_or_expr, yy_action_1)
    _ => Error
  }
}

// [0, parse_cond_expr → or_expr •, $]
// [2, or_expr → or_expr • PIPE_PIPE and_expr, $ / PIPE_PIPE]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PIPE_PIPE => Shift(yy_state_12)
    EOI => Reduce(1, NT_parse_cond_expr, yy_action_0)
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
        (T_TRUE, TK_TRUE),
        (T_FALSE, TK_FALSE),
        (T_BANG, TK_BANG),
        (T_AMP_AMP, TK_AMP_AMP),
        (T_PIPE_PIPE, TK_PIPE_PIPE),
        (T_LEFT_PAREN, TK_LEFT_PAREN),
        (T_RIGHT_PAREN, TK_RIGHT_PAREN),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn parse_cond_expr(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> CondExprNode raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_CondExprNode(result)
      result
    },
    initial_pos?,
  )
}
