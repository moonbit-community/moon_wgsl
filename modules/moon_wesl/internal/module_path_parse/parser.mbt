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
priv suberror YYObj_Array_String_ {
  YYObj_Array_String_(Array[String])
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_ModulePathParseNode {
  YYObj_ModulePathParseNode(ModulePathParseNode)
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
  T_SEGMENT
  T_PACKAGE
  T_SELF
  T_SUPER
  T_DOUBLE_COLON
  NT_parse_module_path
  NT_absolute_path
  NT_self_path
  NT_super_path
  NT_package_path
  NT_super_prefix
  NT_tail_segments
  NT_segment_list
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
// 23|    absolute_path                { $1 }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ModulePathParseNode(_dollar1)
  YYObj_ModulePathParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 24|    self_path                    { $1 }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ModulePathParseNode(_dollar1)
  YYObj_ModulePathParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 25|    super_path                   { $1 }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ModulePathParseNode(_dollar1)
  YYObj_ModulePathParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 26|    package_path                 { $1 }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ModulePathParseNode(_dollar1)
  YYObj_ModulePathParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 30|    "package" tail_segments      { ModulePathParseNode::{ origin: ModulePathParseOrigin::Absolute, components: $2 } }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_String_(_dollar2)
  YYObj_ModulePathParseNode(
    {
      ()
      ModulePathParseNode::{
        origin: ModulePathParseOrigin::Absolute,
        components: _dollar2,
      }
    },
  )
}

// file:///./parser.mbty
// 34|    "self" tail_segments         { ModulePathParseNode::{ origin: ModulePathParseOrigin::Relative(0), components: $2 } }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_String_(_dollar2)
  YYObj_ModulePathParseNode(
    {
      ()
      ModulePathParseNode::{
        origin: ModulePathParseOrigin::Relative(0),
        components: _dollar2,
      }
    },
  )
}

// file:///./parser.mbty
// 38|    super_prefix tail_segments   { ModulePathParseNode::{ origin: ModulePathParseOrigin::Relative($1), components: $2 } }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  guard _args[1].0 is YYObj_Array_String_(_dollar2)
  YYObj_ModulePathParseNode(
    {
      ()
      ModulePathParseNode::{
        origin: ModulePathParseOrigin::Relative(_dollar1),
        components: _dollar2,
      }
    },
  )
}

// file:///./parser.mbty
// 47|    super_prefix "::" "super"    { $1 + 1 }

///|
fn yy_action_7(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_Int(
    {
      ()
      _dollar1 + 1
    },
  )
}

// file:///./parser.mbty
// 42|    SEGMENT tail_segments        { ModulePathParseNode::{ origin: ModulePathParseOrigin::Package($1), components: $2 } }

///|
fn yy_action_8(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[1].0 is YYObj_Array_String_(_dollar2)
  YYObj_ModulePathParseNode(
    {
      ()
      ModulePathParseNode::{
        origin: ModulePathParseOrigin::Package(_dollar1),
        components: _dollar2,
      }
    },
  )
}

// file:///./parser.mbty
// 57|    segment_list "::" SEGMENT    { $1.push($3); $1 }

///|
fn yy_action_9(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 52|    "::" segment_list            { $2 }

///|
fn yy_action_10(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_String_(_dollar2)
  YYObj_Array_String_(
    {
      ()
      _dollar2
    },
  )
}

// file:///./parser.mbty
// 56|    SEGMENT                      { [$1] }

///|
fn yy_action_11(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Array_String_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 51|                                 { [] }

///|
fn yy_action_12(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array_String_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 46|    "super"                      { 1 }

///|
fn yy_action_13(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Int(
    {
      ()
      1
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
    SEGMENT(data) => (T_SEGMENT, YYObj_String(data))
    PACKAGE => (T_PACKAGE, YYObj_Void)
    SELF => (T_SELF, YYObj_Void)
    SUPER => (T_SUPER, YYObj_Void)
    DOUBLE_COLON => (T_DOUBLE_COLON, YYObj_Void)
  }
}

// [0, parse_module_path → • absolute_path, $]
// [1, parse_module_path → • self_path, $]
// [2, parse_module_path → • super_path, $]
// [3, parse_module_path → • package_path, $]
// [4, absolute_path → • PACKAGE tail_segments, $]
// [5, self_path → • SELF tail_segments, $]
// [6, super_path → • super_prefix tail_segments, $]
// [7, package_path → • SEGMENT tail_segments, $]
// [8, super_prefix → • SUPER, $ / DOUBLE_COLON]
// [9, super_prefix → • super_prefix DOUBLE_COLON SUPER, $ / DOUBLE_COLON]
// [14, parse_module_path_prime → • parse_module_path, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_parse_module_path => Shift(yy_state_1)
    T_SUPER => Shift(yy_state_2)
    T_SEGMENT => Shift(yy_state_3)
    NT_super_prefix => Shift(yy_state_10)
    T_SELF => Shift(yy_state_14)
    T_PACKAGE => Shift(yy_state_16)
    NT_package_path => Shift(yy_state_18)
    NT_super_path => Shift(yy_state_19)
    NT_self_path => Shift(yy_state_20)
    NT_absolute_path => Shift(yy_state_21)
    _ => Error
  }
}

// [14, parse_module_path_prime → parse_module_path •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [8, super_prefix → SUPER •, $ / DOUBLE_COLON]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_super_prefix, yy_action_13)
}

// [7, package_path → SEGMENT • tail_segments, $]
// [10, tail_segments → •, $]
// [11, tail_segments → • DOUBLE_COLON segment_list, $]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOUBLE_COLON => Shift(yy_state_4)
    NT_tail_segments => Shift(yy_state_9)
    EOI => Reduce(0, NT_tail_segments, yy_action_12)
    _ => Error
  }
}

// [11, tail_segments → DOUBLE_COLON • segment_list, $]
// [12, segment_list → • SEGMENT, $ / DOUBLE_COLON]
// [13, segment_list → • segment_list DOUBLE_COLON SEGMENT, $ / DOUBLE_COLON]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEGMENT => Shift(yy_state_5)
    NT_segment_list => Shift(yy_state_6)
    _ => Error
  }
}

// [12, segment_list → SEGMENT •, $ / DOUBLE_COLON]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_segment_list, yy_action_11)
}

// [11, tail_segments → DOUBLE_COLON segment_list •, $]
// [13, segment_list → segment_list • DOUBLE_COLON SEGMENT, $ / DOUBLE_COLON]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOUBLE_COLON => Shift(yy_state_7)
    EOI => Reduce(2, NT_tail_segments, yy_action_10)
    _ => Error
  }
}

// [13, segment_list → segment_list DOUBLE_COLON • SEGMENT, $ / DOUBLE_COLON]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEGMENT => Shift(yy_state_8)
    _ => Error
  }
}

// [13, segment_list → segment_list DOUBLE_COLON SEGMENT •, $ / DOUBLE_COLON]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_segment_list, yy_action_9)
}

// [7, package_path → SEGMENT tail_segments •, $]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_package_path, yy_action_8)
}

// [6, super_path → super_prefix • tail_segments, $]
// [9, super_prefix → super_prefix • DOUBLE_COLON SUPER, $ / DOUBLE_COLON]
// [10, tail_segments → •, $]
// [11, tail_segments → • DOUBLE_COLON segment_list, $]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOUBLE_COLON => Shift(yy_state_11)
    NT_tail_segments => Shift(yy_state_13)
    EOI => Reduce(0, NT_tail_segments, yy_action_12)
    _ => Error
  }
}

// [9, super_prefix → super_prefix DOUBLE_COLON • SUPER, $ / DOUBLE_COLON]
// [11, tail_segments → DOUBLE_COLON • segment_list, $]
// [12, segment_list → • SEGMENT, $ / DOUBLE_COLON]
// [13, segment_list → • segment_list DOUBLE_COLON SEGMENT, $ / DOUBLE_COLON]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEGMENT => Shift(yy_state_5)
    NT_segment_list => Shift(yy_state_6)
    T_SUPER => Shift(yy_state_12)
    _ => Error
  }
}

// [9, super_prefix → super_prefix DOUBLE_COLON SUPER •, $ / DOUBLE_COLON]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_super_prefix, yy_action_7)
}

// [6, super_path → super_prefix tail_segments •, $]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_super_path, yy_action_6)
}

// [5, self_path → SELF • tail_segments, $]
// [10, tail_segments → •, $]
// [11, tail_segments → • DOUBLE_COLON segment_list, $]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOUBLE_COLON => Shift(yy_state_4)
    NT_tail_segments => Shift(yy_state_15)
    EOI => Reduce(0, NT_tail_segments, yy_action_12)
    _ => Error
  }
}

// [5, self_path → SELF tail_segments •, $]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_self_path, yy_action_5)
}

// [4, absolute_path → PACKAGE • tail_segments, $]
// [10, tail_segments → •, $]
// [11, tail_segments → • DOUBLE_COLON segment_list, $]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOUBLE_COLON => Shift(yy_state_4)
    NT_tail_segments => Shift(yy_state_17)
    EOI => Reduce(0, NT_tail_segments, yy_action_12)
    _ => Error
  }
}

// [4, absolute_path → PACKAGE tail_segments •, $]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_absolute_path, yy_action_4)
}

// [3, parse_module_path → package_path •, $]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_parse_module_path, yy_action_3)
}

// [2, parse_module_path → super_path •, $]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_parse_module_path, yy_action_2)
}

// [1, parse_module_path → self_path •, $]

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_parse_module_path, yy_action_1)
}

// [0, parse_module_path → absolute_path •, $]

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_parse_module_path, yy_action_0)
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
        (T_SEGMENT, TK_SEGMENT),
        (T_PACKAGE, TK_PACKAGE),
        (T_SELF, TK_SELF),
        (T_SUPER, TK_SUPER),
        (T_DOUBLE_COLON, TK_DOUBLE_COLON),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn parse_module_path(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> ModulePathParseNode raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_ModulePathParseNode(result)
      result
    },
    initial_pos?,
  )
}
