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
priv suberror YYObj_Unit {
  YYObj_Unit(Unit)
}

///|
priv suberror YYObj_Array_StructMemberParseNode_ {
  YYObj_Array_StructMemberParseNode_(Array[StructMemberParseNode])
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_StructParseNode {
  YYObj_StructParseNode(StructParseNode)
}

///|
priv suberror YYObj_StructMemberParseNode {
  YYObj_StructMemberParseNode(StructMemberParseNode)
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
  T_MEMBER
  T_STRUCT
  T_LEFT_BRACE
  T_RIGHT_BRACE
  T_SEMI
  NT_parse_struct_decl
  NT_members
  NT_opt_semi
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
// 19|    "struct" IDENT "{" members "}" opt_semi
// 20|                                { { name: $2, members: $4 } }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Array_StructMemberParseNode_(_dollar4)
  YYObj_StructParseNode(
    {
      ()
      { name: _dollar2, members: _dollar4 }
    },
  )
}

// file:///./parser.mbty
// 30|    ";"                         { () }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./parser.mbty
// 29|                                { () }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./parser.mbty
// 25|    members MEMBER              { $1.push($2); $1 }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_StructMemberParseNode_(_dollar1)
  guard _args[1].0 is YYObj_StructMemberParseNode(_dollar2)
  YYObj_Array_StructMemberParseNode_(
    {
      ()
      _dollar1.push(_dollar2)
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 24|                                { [] }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array_StructMemberParseNode_(
    {
      ()
      []
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
    MEMBER(data) => (T_MEMBER, YYObj_StructMemberParseNode(data))
    STRUCT => (T_STRUCT, YYObj_Void)
    LEFT_BRACE => (T_LEFT_BRACE, YYObj_Void)
    RIGHT_BRACE => (T_RIGHT_BRACE, YYObj_Void)
    SEMI => (T_SEMI, YYObj_Void)
  }
}

// [0, parse_struct_decl → • STRUCT IDENT LEFT_BRACE members RIGHT_BRACE opt_semi, $]
// [5, parse_struct_decl_prime → • parse_struct_decl, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_parse_struct_decl => Shift(yy_state_1)
    T_STRUCT => Shift(yy_state_2)
    _ => Error
  }
}

// [5, parse_struct_decl_prime → parse_struct_decl •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [0, parse_struct_decl → STRUCT • IDENT LEFT_BRACE members RIGHT_BRACE opt_semi, $]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_3)
    _ => Error
  }
}

// [0, parse_struct_decl → STRUCT IDENT • LEFT_BRACE members RIGHT_BRACE opt_semi, $]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LEFT_BRACE => Shift(yy_state_4)
    _ => Error
  }
}

// [0, parse_struct_decl → STRUCT IDENT LEFT_BRACE • members RIGHT_BRACE opt_semi, $]
// [1, members → •, MEMBER / RIGHT_BRACE]
// [2, members → • members MEMBER, MEMBER / RIGHT_BRACE]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_members => Shift(yy_state_5)
    T_MEMBER | T_RIGHT_BRACE => Reduce(0, NT_members, yy_action_4)
    _ => Error
  }
}

// [0, parse_struct_decl → STRUCT IDENT LEFT_BRACE members • RIGHT_BRACE opt_semi, $]
// [2, members → members • MEMBER, MEMBER / RIGHT_BRACE]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER => Shift(yy_state_6)
    T_RIGHT_BRACE => Shift(yy_state_7)
    _ => Error
  }
}

// [2, members → members MEMBER •, MEMBER / RIGHT_BRACE]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_members, yy_action_3)
}

// [0, parse_struct_decl → STRUCT IDENT LEFT_BRACE members RIGHT_BRACE • opt_semi, $]
// [3, opt_semi → •, $]
// [4, opt_semi → • SEMI, $]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_8)
    NT_opt_semi => Shift(yy_state_9)
    EOI => Reduce(0, NT_opt_semi, yy_action_2)
    _ => Error
  }
}

// [4, opt_semi → SEMI •, $]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_opt_semi, yy_action_1)
}

// [0, parse_struct_decl → STRUCT IDENT LEFT_BRACE members RIGHT_BRACE opt_semi •, $]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_parse_struct_decl, yy_action_0)
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
        (T_MEMBER, TK_MEMBER),
        (T_STRUCT, TK_STRUCT),
        (T_LEFT_BRACE, TK_LEFT_BRACE),
        (T_RIGHT_BRACE, TK_RIGHT_BRACE),
        (T_SEMI, TK_SEMI),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn parse_struct_decl(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> StructParseNode raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_StructParseNode(result)
      result
    },
    initial_pos?,
  )
}
