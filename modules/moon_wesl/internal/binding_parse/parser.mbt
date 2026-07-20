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
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_BindingParseKind {
  YYObj_BindingParseKind(BindingParseKind)
}

///|
priv suberror YYObj_BindingParseNode {
  YYObj_BindingParseNode(BindingParseNode)
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
  T_VAR_TEMPLATE
  T_TYPE_TEXT
  T_INIT_TEXT
  T_ALIAS
  T_CONST
  T_OVERRIDE
  T_LET
  T_VAR
  T_COLON
  T_EQ
  T_SEMI
  NT_parse_binding_decl
  NT_binding_kind
  NT_opt_var_template
  NT_opt_type
  NT_opt_init
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
// 28|    "alias" IDENT "=" TYPE_TEXT opt_semi
// 29|                                  { { kind: Alias, name: Some($2), var_template: None, type_text: Some($4), initializer: None } }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_String(_dollar4)
  YYObj_BindingParseNode(
    {
      ()
      {
        kind: Alias,
        name: Some(_dollar2),
        var_template: None,
        type_text: Some(_dollar4),
        initializer: None,
      }
    },
  )
}

// file:///./parser.mbty
// 30|    binding_kind IDENT opt_type opt_init opt_semi
// 31|                                  { { kind: $1, name: Some($2), var_template: None, type_text: $3, initializer: $4 } }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_BindingParseKind(_dollar1)
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[2].0 is YYObj_String_(_dollar3)
  guard _args[3].0 is YYObj_String_(_dollar4)
  YYObj_BindingParseNode(
    {
      ()
      {
        kind: _dollar1,
        name: Some(_dollar2),
        var_template: None,
        type_text: _dollar3,
        initializer: _dollar4,
      }
    },
  )
}

// file:///./parser.mbty
// 32|    "var" opt_var_template IDENT opt_type opt_init opt_semi
// 33|                                  { { kind: Var, name: Some($3), var_template: $2, type_text: $4, initializer: $5 } }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[1].0 is YYObj_String_(_dollar2)
  guard _args[3].0 is YYObj_String_(_dollar4)
  guard _args[4].0 is YYObj_String_(_dollar5)
  YYObj_BindingParseNode(
    {
      ()
      {
        kind: Var,
        name: Some(_dollar3),
        var_template: _dollar2,
        type_text: _dollar4,
        initializer: _dollar5,
      }
    },
  )
}

// file:///./parser.mbty
// 59|    ";"                           { () }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./parser.mbty
// 58|                                  { () }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./parser.mbty
// 54|    "=" INIT_TEXT                 { Some($2) }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  YYObj_String_(
    {
      ()
      Some(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 53|                                  { None }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_String_(
    {
      ()
      None
    },
  )
}

// file:///./parser.mbty
// 49|    ":" TYPE_TEXT                 { Some($2) }

///|
fn yy_action_7(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  YYObj_String_(
    {
      ()
      Some(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 48|                                  { None }

///|
fn yy_action_8(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_String_(
    {
      ()
      None
    },
  )
}

// file:///./parser.mbty
// 44|    VAR_TEMPLATE                  { Some($1) }

///|
fn yy_action_9(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String_(
    {
      ()
      Some(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 43|                                  { None }

///|
fn yy_action_10(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_String_(
    {
      ()
      None
    },
  )
}

// file:///./parser.mbty
// 37|    "const"                       { Const }

///|
fn yy_action_11(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_BindingParseKind(
    {
      ()
      Const
    },
  )
}

// file:///./parser.mbty
// 38|    "override"                    { Override }

///|
fn yy_action_12(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_BindingParseKind(
    {
      ()
      Override
    },
  )
}

// file:///./parser.mbty
// 39|    "let"                         { Let }

///|
fn yy_action_13(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_BindingParseKind(
    {
      ()
      Let
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
    VAR_TEMPLATE(data) => (T_VAR_TEMPLATE, YYObj_String(data))
    TYPE_TEXT(data) => (T_TYPE_TEXT, YYObj_String(data))
    INIT_TEXT(data) => (T_INIT_TEXT, YYObj_String(data))
    ALIAS => (T_ALIAS, YYObj_Void)
    CONST => (T_CONST, YYObj_Void)
    OVERRIDE => (T_OVERRIDE, YYObj_Void)
    LET => (T_LET, YYObj_Void)
    VAR => (T_VAR, YYObj_Void)
    COLON => (T_COLON, YYObj_Void)
    EQ => (T_EQ, YYObj_Void)
    SEMI => (T_SEMI, YYObj_Void)
  }
}

// [0, parse_binding_decl → • ALIAS IDENT EQ TYPE_TEXT opt_semi, $]
// [1, parse_binding_decl → • binding_kind IDENT opt_type opt_init opt_semi, $]
// [2, parse_binding_decl → • VAR opt_var_template IDENT opt_type opt_init opt_semi, $]
// [3, binding_kind → • CONST, IDENT]
// [4, binding_kind → • OVERRIDE, IDENT]
// [5, binding_kind → • LET, IDENT]
// [14, parse_binding_decl_prime → • parse_binding_decl, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_parse_binding_decl => Shift(yy_state_1)
    T_LET => Shift(yy_state_2)
    T_OVERRIDE => Shift(yy_state_3)
    T_CONST => Shift(yy_state_4)
    T_VAR => Shift(yy_state_5)
    NT_binding_kind => Shift(yy_state_17)
    T_ALIAS => Shift(yy_state_22)
    _ => Error
  }
}

// [14, parse_binding_decl_prime → parse_binding_decl •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [5, binding_kind → LET •, IDENT]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_binding_kind, yy_action_13)
}

// [4, binding_kind → OVERRIDE •, IDENT]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_binding_kind, yy_action_12)
}

// [3, binding_kind → CONST •, IDENT]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_binding_kind, yy_action_11)
}

// [2, parse_binding_decl → VAR • opt_var_template IDENT opt_type opt_init opt_semi, $]
// [6, opt_var_template → •, IDENT]
// [7, opt_var_template → • VAR_TEMPLATE, IDENT]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_VAR_TEMPLATE => Shift(yy_state_6)
    NT_opt_var_template => Shift(yy_state_7)
    T_IDENT => Reduce(0, NT_opt_var_template, yy_action_10)
    _ => Error
  }
}

// [7, opt_var_template → VAR_TEMPLATE •, IDENT]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_opt_var_template, yy_action_9)
}

// [2, parse_binding_decl → VAR opt_var_template • IDENT opt_type opt_init opt_semi, $]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_8)
    _ => Error
  }
}

// [2, parse_binding_decl → VAR opt_var_template IDENT • opt_type opt_init opt_semi, $]
// [8, opt_type → •, $ / EQ / SEMI]
// [9, opt_type → • COLON TYPE_TEXT, $ / EQ / SEMI]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_9)
    NT_opt_type => Shift(yy_state_11)
    T_EQ | T_SEMI | EOI => Reduce(0, NT_opt_type, yy_action_8)
    _ => Error
  }
}

// [9, opt_type → COLON • TYPE_TEXT, $ / EQ / SEMI]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_TEXT => Shift(yy_state_10)
    _ => Error
  }
}

// [9, opt_type → COLON TYPE_TEXT •, $ / EQ / SEMI]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_opt_type, yy_action_7)
}

// [2, parse_binding_decl → VAR opt_var_template IDENT opt_type • opt_init opt_semi, $]
// [10, opt_init → •, $ / SEMI]
// [11, opt_init → • EQ INIT_TEXT, $ / SEMI]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQ => Shift(yy_state_12)
    NT_opt_init => Shift(yy_state_14)
    T_SEMI | EOI => Reduce(0, NT_opt_init, yy_action_6)
    _ => Error
  }
}

// [11, opt_init → EQ • INIT_TEXT, $ / SEMI]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INIT_TEXT => Shift(yy_state_13)
    _ => Error
  }
}

// [11, opt_init → EQ INIT_TEXT •, $ / SEMI]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_opt_init, yy_action_5)
}

// [2, parse_binding_decl → VAR opt_var_template IDENT opt_type opt_init • opt_semi, $]
// [12, opt_semi → •, $]
// [13, opt_semi → • SEMI, $]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_15)
    NT_opt_semi => Shift(yy_state_16)
    EOI => Reduce(0, NT_opt_semi, yy_action_4)
    _ => Error
  }
}

// [13, opt_semi → SEMI •, $]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_opt_semi, yy_action_3)
}

// [2, parse_binding_decl → VAR opt_var_template IDENT opt_type opt_init opt_semi •, $]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_parse_binding_decl, yy_action_2)
}

// [1, parse_binding_decl → binding_kind • IDENT opt_type opt_init opt_semi, $]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_18)
    _ => Error
  }
}

// [1, parse_binding_decl → binding_kind IDENT • opt_type opt_init opt_semi, $]
// [8, opt_type → •, $ / EQ / SEMI]
// [9, opt_type → • COLON TYPE_TEXT, $ / EQ / SEMI]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_9)
    NT_opt_type => Shift(yy_state_19)
    T_EQ | T_SEMI | EOI => Reduce(0, NT_opt_type, yy_action_8)
    _ => Error
  }
}

// [1, parse_binding_decl → binding_kind IDENT opt_type • opt_init opt_semi, $]
// [10, opt_init → •, $ / SEMI]
// [11, opt_init → • EQ INIT_TEXT, $ / SEMI]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQ => Shift(yy_state_12)
    NT_opt_init => Shift(yy_state_20)
    T_SEMI | EOI => Reduce(0, NT_opt_init, yy_action_6)
    _ => Error
  }
}

// [1, parse_binding_decl → binding_kind IDENT opt_type opt_init • opt_semi, $]
// [12, opt_semi → •, $]
// [13, opt_semi → • SEMI, $]

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_15)
    NT_opt_semi => Shift(yy_state_21)
    EOI => Reduce(0, NT_opt_semi, yy_action_4)
    _ => Error
  }
}

// [1, parse_binding_decl → binding_kind IDENT opt_type opt_init opt_semi •, $]

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_parse_binding_decl, yy_action_1)
}

// [0, parse_binding_decl → ALIAS • IDENT EQ TYPE_TEXT opt_semi, $]

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_23)
    _ => Error
  }
}

// [0, parse_binding_decl → ALIAS IDENT • EQ TYPE_TEXT opt_semi, $]

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQ => Shift(yy_state_24)
    _ => Error
  }
}

// [0, parse_binding_decl → ALIAS IDENT EQ • TYPE_TEXT opt_semi, $]

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_TEXT => Shift(yy_state_25)
    _ => Error
  }
}

// [0, parse_binding_decl → ALIAS IDENT EQ TYPE_TEXT • opt_semi, $]
// [12, opt_semi → •, $]
// [13, opt_semi → • SEMI, $]

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_15)
    NT_opt_semi => Shift(yy_state_26)
    EOI => Reduce(0, NT_opt_semi, yy_action_4)
    _ => Error
  }
}

// [0, parse_binding_decl → ALIAS IDENT EQ TYPE_TEXT opt_semi •, $]

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_parse_binding_decl, yy_action_0)
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
        (T_VAR_TEMPLATE, TK_VAR_TEMPLATE),
        (T_TYPE_TEXT, TK_TYPE_TEXT),
        (T_INIT_TEXT, TK_INIT_TEXT),
        (T_ALIAS, TK_ALIAS),
        (T_CONST, TK_CONST),
        (T_OVERRIDE, TK_OVERRIDE),
        (T_LET, TK_LET),
        (T_VAR, TK_VAR),
        (T_COLON, TK_COLON),
        (T_EQ, TK_EQ),
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
pub fn parse_binding_decl(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> BindingParseNode raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_BindingParseNode(result)
      result
    },
    initial_pos?,
  )
}
