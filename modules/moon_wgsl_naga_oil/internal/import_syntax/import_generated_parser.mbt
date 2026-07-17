///|
pub(all) enum Token {
  IDENT(String)
  AS
  LBRACE(Int)
  RBRACE(Int)
  COMMA
  SEMI
  EOF
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    AS => TK_AS
    LBRACE(_) => TK_LBRACE
    RBRACE(_) => TK_RBRACE
    COMMA => TK_COMMA
    SEMI => TK_SEMI
    EOF => TK_EOF
  }
}

///|
pub(all) enum TokenKind {
  TK_IDENT
  TK_AS
  TK_LBRACE
  TK_RBRACE
  TK_COMMA
  TK_SEMI
  TK_EOF
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_AS => "\"as\""
      TK_LBRACE => "\"{\""
      TK_RBRACE => "\"}\""
      TK_COMMA => "\",\""
      TK_SEMI => "\";\""
      TK_EOF => "EOF"
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => to_repr("IDENT")
    TK_AS => to_repr("as")
    TK_LBRACE => to_repr("{")
    TK_RBRACE => to_repr("}")
    TK_COMMA => to_repr(",")
    TK_SEMI => to_repr(";")
    TK_EOF => to_repr("EOF")
  }
}

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
priv suberror YYObj_Int {
  YYObj_Int(Int)
}

///|
priv suberror YYObj_Unit {
  YYObj_Unit(Unit)
}

///|
priv suberror YYObj_Array__contract_WgslImportTarget_ {
  YYObj_Array__contract_WgslImportTarget_(Array[@contract.WgslImportTarget])
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
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
  T_LBRACE
  T_RBRACE
  T_COMMA
  T_SEMI
  T_EOF
  NT_import_targets
  NT_semis
  NT_target_list
  NT_target
  NT_alias
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

// file:///./import_parser.mbty
// 17|    target_list semis EOF { $1 }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__contract_WgslImportTarget_(_dollar1)
  YYObj_Array__contract_WgslImportTarget_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./import_parser.mbty
// 18|    module_path=IDENT targets=target_list semis EOF {
// 19|      let out : Array[@contract.WgslImportTarget] = []
// 20|      for target in targets {
// 21|        out.push({
// 22|          raw_path: module_path + "::" + target.raw_path,
// 23|          alias_name: target.alias_name,
// 24|        })
// 25|      }
// 26|      out
// 27|    }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(module_path)
  guard _args[1].0 is YYObj_Array__contract_WgslImportTarget_(targets)
  YYObj_Array__contract_WgslImportTarget_(
    {
      ()
      let out : Array[@contract.WgslImportTarget] = []
      for target in targets {
        out.push({
          raw_path: module_path + "::" + target.raw_path,
          alias_name: target.alias_name,
        })
      }
      out
    },
  )
}

// file:///./import_parser.mbty
// 32|    semis ";" { () }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./import_parser.mbty
// 31|    { () }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./import_parser.mbty
// 39|    target_list "," target {
// 40|      let targets = $1
// 41|      for target in $3 {
// 42|        targets.push(target)
// 43|      }
// 44|      targets
// 45|    }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__contract_WgslImportTarget_(_dollar1)
  guard _args[2].0 is YYObj_Array__contract_WgslImportTarget_(_dollar3)
  YYObj_Array__contract_WgslImportTarget_(
    {
      ()
      let targets = _dollar1
      for target in _dollar3 {
        targets.push(target)
      }
      targets
    },
  )
}

// file:///./import_parser.mbty
// 46|    target_list "," {
// 47|      $1
// 48|    }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__contract_WgslImportTarget_(_dollar1)
  YYObj_Array__contract_WgslImportTarget_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./import_parser.mbty
// 55|    module_path=IDENT "{" targets=target_list "}" {
// 56|      let out : Array[@contract.WgslImportTarget] = []
// 57|      for target in targets {
// 58|        let sep = if module_path.has_suffix("::") || target.raw_path == "" {
// 59|          ""
// 60|        } else {
// 61|          "::"
// 62|        }
// 63|        out.push({
// 64|          raw_path: module_path + sep + target.raw_path,
// 65|          alias_name: target.alias_name,
// 66|        })
// 67|      }
// 68|      out
// 69|    }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(module_path)
  guard _args[2].0 is YYObj_Array__contract_WgslImportTarget_(targets)
  YYObj_Array__contract_WgslImportTarget_(
    {
      ()
      let out : Array[@contract.WgslImportTarget] = []
      for target in targets {
        let sep = if module_path.has_suffix("::") || target.raw_path == "" {
          ""
        } else {
          "::"
        }
        out.push({
          raw_path: module_path + sep + target.raw_path,
          alias_name: target.alias_name,
        })
      }
      out
    },
  )
}

// file:///./import_parser.mbty
// 52|    path=IDENT alias_name=alias {
// 53|      [{ raw_path: path, alias_name }]
// 54|    }

///|
fn yy_action_7(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(path)
  guard _args[1].0 is YYObj_String(alias_name)
  YYObj_Array__contract_WgslImportTarget_(
    {
      ()
      [{ raw_path: path, alias_name }]
    },
  )
}

// file:///./import_parser.mbty
// 74|    "as" name=IDENT { name }

///|
fn yy_action_8(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(name)
  YYObj_String(
    {
      ()
      name
    },
  )
}

// file:///./import_parser.mbty
// 73|    { "" }

///|
fn yy_action_9(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_String(
    {
      ()
      ""
    },
  )
}

// file:///./import_parser.mbty
// 36|    target {
// 37|      $1
// 38|    }

///|
fn yy_action_10(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__contract_WgslImportTarget_(_dollar1)
  YYObj_Array__contract_WgslImportTarget_(
    {
      ()
      _dollar1
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
    LBRACE(data) => (T_LBRACE, YYObj_Int(data))
    RBRACE(data) => (T_RBRACE, YYObj_Int(data))
    COMMA => (T_COMMA, YYObj_Void)
    SEMI => (T_SEMI, YYObj_Void)
    EOF => (T_EOF, YYObj_Void)
  }
}

// [0, import_targets → • target_list semis EOF, $]
// [1, import_targets → • IDENT target_list semis EOF, $]
// [4, target_list → • target, COMMA / SEMI / EOF]
// [5, target_list → • target_list COMMA target, COMMA / SEMI / EOF]
// [6, target_list → • target_list COMMA, COMMA / SEMI / EOF]
// [7, target → • IDENT alias, COMMA / SEMI / EOF]
// [8, target → • IDENT LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [11, import_targets_prime → • import_targets, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_import_targets => Shift(yy_state_1)
    NT_target => Shift(yy_state_2)
    T_IDENT => Shift(yy_state_3)
    NT_target_list => Shift(yy_state_17)
    _ => Error
  }
}

// [11, import_targets_prime → import_targets •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [4, target_list → target •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_target_list, yy_action_10)
}

// [1, import_targets → IDENT • target_list semis EOF, $]
// [4, target_list → • target, COMMA / SEMI / EOF]
// [5, target_list → • target_list COMMA target, COMMA / SEMI / EOF]
// [6, target_list → • target_list COMMA, COMMA / SEMI / EOF]
// [7, target → • IDENT alias, COMMA / SEMI / EOF]
// [7, target → IDENT • alias, COMMA / SEMI / EOF]
// [8, target → • IDENT LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [8, target → IDENT • LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [9, alias → •, COMMA / SEMI / EOF]
// [10, alias → • AS IDENT, COMMA / SEMI / EOF]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_target => Shift(yy_state_2)
    T_AS => Shift(yy_state_4)
    T_LBRACE => Shift(yy_state_6)
    T_IDENT => Shift(yy_state_7)
    NT_alias => Shift(yy_state_8)
    NT_target_list => Shift(yy_state_13)
    T_COMMA | T_SEMI | T_EOF => Reduce(0, NT_alias, yy_action_9)
    _ => Error
  }
}

// [10, alias → AS • IDENT, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_5)
    _ => Error
  }
}

// [10, alias → AS IDENT •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_alias, yy_action_8)
}

// [4, target_list → • target, RBRACE / COMMA]
// [5, target_list → • target_list COMMA target, RBRACE / COMMA]
// [6, target_list → • target_list COMMA, RBRACE / COMMA]
// [7, target → • IDENT alias, RBRACE / COMMA]
// [8, target → • IDENT LBRACE target_list RBRACE, RBRACE / COMMA]
// [8, target → IDENT LBRACE • target_list RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_target => Shift(yy_state_2)
    T_IDENT => Shift(yy_state_7)
    NT_target_list => Shift(yy_state_9)
    _ => Error
  }
}

// [7, target → IDENT • alias, RBRACE / COMMA / SEMI / EOF]
// [8, target → IDENT • LBRACE target_list RBRACE, RBRACE / COMMA / SEMI / EOF]
// [9, alias → •, RBRACE / COMMA / SEMI / EOF]
// [10, alias → • AS IDENT, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AS => Shift(yy_state_4)
    T_LBRACE => Shift(yy_state_6)
    NT_alias => Shift(yy_state_8)
    T_RBRACE | T_COMMA | T_SEMI | T_EOF => Reduce(0, NT_alias, yy_action_9)
    _ => Error
  }
}

// [7, target → IDENT alias •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_target, yy_action_7)
}

// [5, target_list → target_list • COMMA target, RBRACE / COMMA]
// [6, target_list → target_list • COMMA, RBRACE / COMMA]
// [8, target → IDENT LBRACE target_list • RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_10)
    T_COMMA => Shift(yy_state_11)
    _ => Error
  }
}

// [8, target → IDENT LBRACE target_list RBRACE •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_target, yy_action_6)
}

// [5, target_list → target_list COMMA • target, RBRACE / COMMA / SEMI / EOF]
// [6, target_list → target_list COMMA •, RBRACE / COMMA / SEMI / EOF]
// [7, target → • IDENT alias, RBRACE / COMMA / SEMI / EOF]
// [8, target → • IDENT LBRACE target_list RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_7)
    NT_target => Shift(yy_state_12)
    T_RBRACE | T_COMMA | T_SEMI | T_EOF =>
      Reduce(2, NT_target_list, yy_action_5)
    _ => Error
  }
}

// [5, target_list → target_list COMMA target •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_target_list, yy_action_4)
}

// [1, import_targets → IDENT target_list • semis EOF, $]
// [2, semis → •, SEMI / EOF]
// [3, semis → • semis SEMI, SEMI / EOF]
// [5, target_list → target_list • COMMA target, COMMA / SEMI / EOF]
// [6, target_list → target_list • COMMA, COMMA / SEMI / EOF]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_11)
    NT_semis => Shift(yy_state_14)
    T_SEMI | T_EOF => Reduce(0, NT_semis, yy_action_3)
    _ => Error
  }
}

// [1, import_targets → IDENT target_list semis • EOF, $]
// [3, semis → semis • SEMI, SEMI / EOF]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_15)
    T_EOF => Shift(yy_state_16)
    _ => Error
  }
}

// [3, semis → semis SEMI •, SEMI / EOF]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semis, yy_action_2)
}

// [1, import_targets → IDENT target_list semis EOF •, $]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_import_targets, yy_action_1)
}

// [0, import_targets → target_list • semis EOF, $]
// [2, semis → •, SEMI / EOF]
// [3, semis → • semis SEMI, SEMI / EOF]
// [5, target_list → target_list • COMMA target, COMMA / SEMI / EOF]
// [6, target_list → target_list • COMMA, COMMA / SEMI / EOF]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_11)
    NT_semis => Shift(yy_state_18)
    T_SEMI | T_EOF => Reduce(0, NT_semis, yy_action_3)
    _ => Error
  }
}

// [0, import_targets → target_list semis • EOF, $]
// [3, semis → semis • SEMI, SEMI / EOF]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_15)
    T_EOF => Shift(yy_state_19)
    _ => Error
  }
}

// [0, import_targets → target_list semis EOF •, $]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_targets, yy_action_0)
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
        (T_LBRACE, TK_LBRACE),
        (T_RBRACE, TK_RBRACE),
        (T_COMMA, TK_COMMA),
        (T_SEMI, TK_SEMI),
        (T_EOF, TK_EOF),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn import_targets(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[@contract.WgslImportTarget] raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_Array__contract_WgslImportTarget_(result)
      result
    },
    initial_pos?,
  )
}
