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
priv suberror YYObj_Array_ExpressionParseNode_ {
  YYObj_Array_ExpressionParseNode_(Array[ExpressionParseNode])
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_ExpressionParseNode {
  YYObj_ExpressionParseNode(ExpressionParseNode)
}

///|
priv suberror YYObj_ExpressionPostfixSuffix {
  YYObj_ExpressionPostfixSuffix(ExpressionPostfixSuffix)
}

///|
priv suberror YYObj_ExpressionTypeParseNode {
  YYObj_ExpressionTypeParseNode(ExpressionTypeParseNode)
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
  T_TEMPLATE
  T_TRUE
  T_FALSE
  T_LEFT_PAREN
  T_RIGHT_PAREN
  T_LEFT_BRACKET
  T_RIGHT_BRACKET
  T_DOT
  T_COMMA
  T_DOUBLE_COLON
  T_LESS
  T_LESS_EQUAL
  T_SHIFT_LEFT
  T_GREATER
  T_GREATER_EQUAL
  T_SHIFT_RIGHT
  T_PLUS
  T_MINUS
  T_MINUS_MINUS
  T_STAR
  T_SLASH
  T_PERCENT
  T_BANG
  T_TILDE
  T_AMP
  T_AMP_AMP
  T_PIPE
  T_PIPE_PIPE
  T_CARET
  T_EQUAL_EQUAL
  T_BANG_EQUAL
  NT_parse_expression
  NT_expression
  NT_short_circuit_or
  NT_short_circuit_and
  NT_bitwise_or
  NT_bitwise_xor
  NT_bitwise_and
  NT_equality
  NT_relational
  NT_shift
  NT_additive
  NT_multiplicative
  NT_unary
  NT_postfix
  NT_postfix_suffix
  NT_primary
  NT_path_ident
  NT_opt_arguments
  NT_argument_list
  NT_literal
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
// 63|    expression                    { $1 }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 153|    path_ident "(" opt_arguments ")"
// 154|                                  { ExpressionParseNode::FunctionCall(ExpressionFunctionCallParseNode::{ callee: $1, arguments: $3 }) }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionTypeParseNode(_dollar1)
  guard _args[2].0 is YYObj_Array_ExpressionParseNode_(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::FunctionCall(ExpressionFunctionCallParseNode::{
        callee: _dollar1,
        arguments: _dollar3,
      })
    },
  )
}

// file:///./parser.mbty
// 155|    path_ident TEMPLATE "(" opt_arguments ")"
// 156|                                  { ExpressionParseNode::FunctionCall(ExpressionFunctionCallParseNode::{ callee: $1.with_template($2), arguments: $4 }) }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionTypeParseNode(_dollar1)
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Array_ExpressionParseNode_(_dollar4)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::FunctionCall(ExpressionFunctionCallParseNode::{
        callee: _dollar1.with_template(_dollar2),
        arguments: _dollar4,
      })
    },
  )
}

// file:///./parser.mbty
// 142|    postfix postfix_suffix        { $1.apply_postfix($2) }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[1].0 is YYObj_ExpressionPostfixSuffix(_dollar2)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1.apply_postfix(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 72|    short_circuit_or "||" short_circuit_and
// 73|                                  { ExpressionParseNode::Binary(ExpressionBinaryOperator::ShortCircuitOr, $1, $3) }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::ShortCircuitOr,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 67|    short_circuit_or              { $1 }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 78|    short_circuit_and "&&" bitwise_or
// 79|                                  { ExpressionParseNode::Binary(ExpressionBinaryOperator::ShortCircuitAnd, $1, $3) }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::ShortCircuitAnd,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 71|    short_circuit_and             { $1 }

///|
fn yy_action_7(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 84|    bitwise_or "|" bitwise_xor    { ExpressionParseNode::Binary(ExpressionBinaryOperator::BitwiseOr, $1, $3) }

///|
fn yy_action_8(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::BitwiseOr,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 77|    bitwise_or                    { $1 }

///|
fn yy_action_9(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 89|    bitwise_xor "^" bitwise_and   { ExpressionParseNode::Binary(ExpressionBinaryOperator::BitwiseXor, $1, $3) }

///|
fn yy_action_10(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::BitwiseXor,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 83|    bitwise_xor                   { $1 }

///|
fn yy_action_11(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 94|    bitwise_and "&" equality      { ExpressionParseNode::Binary(ExpressionBinaryOperator::BitwiseAnd, $1, $3) }

///|
fn yy_action_12(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::BitwiseAnd,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 88|    bitwise_and                   { $1 }

///|
fn yy_action_13(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 99|    equality "==" relational      { ExpressionParseNode::Binary(ExpressionBinaryOperator::Equality, $1, $3) }

///|
fn yy_action_14(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::Equality,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 100|    equality "!=" relational      { ExpressionParseNode::Binary(ExpressionBinaryOperator::Inequality, $1, $3) }

///|
fn yy_action_15(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::Inequality,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 93|    equality                      { $1 }

///|
fn yy_action_16(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 105|    relational "<" shift          { ExpressionParseNode::Binary(ExpressionBinaryOperator::LessThan, $1, $3) }

///|
fn yy_action_17(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::LessThan,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 106|    relational "<=" shift         { ExpressionParseNode::Binary(ExpressionBinaryOperator::LessThanEqual, $1, $3) }

///|
fn yy_action_18(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::LessThanEqual,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 107|    relational ">" shift          { ExpressionParseNode::Binary(ExpressionBinaryOperator::GreaterThan, $1, $3) }

///|
fn yy_action_19(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::GreaterThan,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 108|    relational ">=" shift         { ExpressionParseNode::Binary(ExpressionBinaryOperator::GreaterThanEqual, $1, $3) }

///|
fn yy_action_20(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::GreaterThanEqual,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 98|    relational                    { $1 }

///|
fn yy_action_21(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 113|    shift "<<" additive           { ExpressionParseNode::Binary(ExpressionBinaryOperator::ShiftLeft, $1, $3) }

///|
fn yy_action_22(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::ShiftLeft,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 114|    shift ">>" additive           { ExpressionParseNode::Binary(ExpressionBinaryOperator::ShiftRight, $1, $3) }

///|
fn yy_action_23(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::ShiftRight,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 104|    shift                         { $1 }

///|
fn yy_action_24(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 119|    additive "+" multiplicative   { ExpressionParseNode::Binary(ExpressionBinaryOperator::Addition, $1, $3) }

///|
fn yy_action_25(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::Addition,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 120|    additive "-" multiplicative   { ExpressionParseNode::Binary(ExpressionBinaryOperator::Subtraction, $1, $3) }

///|
fn yy_action_26(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::Subtraction,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 121|    additive "--" multiplicative  { ExpressionParseNode::Binary(ExpressionBinaryOperator::Subtraction, $1, ExpressionParseNode::Unary(ExpressionUnaryOperator::Negation, $3)) }

///|
fn yy_action_27(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::Subtraction,
        _dollar1,
        ExpressionParseNode::Unary(ExpressionUnaryOperator::Negation, _dollar3),
      )
    },
  )
}

// file:///./parser.mbty
// 112|    additive                      { $1 }

///|
fn yy_action_28(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 126|    multiplicative "*" unary      { ExpressionParseNode::Binary(ExpressionBinaryOperator::Multiplication, $1, $3) }

///|
fn yy_action_29(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::Multiplication,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 127|    multiplicative "/" unary      { ExpressionParseNode::Binary(ExpressionBinaryOperator::Division, $1, $3) }

///|
fn yy_action_30(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::Division,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 128|    multiplicative "%" unary      { ExpressionParseNode::Binary(ExpressionBinaryOperator::Remainder, $1, $3) }

///|
fn yy_action_31(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Binary(
        ExpressionBinaryOperator::Remainder,
        _dollar1,
        _dollar3,
      )
    },
  )
}

// file:///./parser.mbty
// 118|    multiplicative                { $1 }

///|
fn yy_action_32(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 125|    unary                         { $1 }

///|
fn yy_action_33(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 146|    "[" expression "]"            { ExpressionPostfixSuffix::Indexing($2) }

///|
fn yy_action_34(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_ExpressionParseNode(_dollar2)
  YYObj_ExpressionPostfixSuffix(
    {
      ()
      ExpressionPostfixSuffix::Indexing(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 147|    "." IDENT                     { ExpressionPostfixSuffix::NamedComponent($2) }

///|
fn yy_action_35(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  YYObj_ExpressionPostfixSuffix(
    {
      ()
      ExpressionPostfixSuffix::NamedComponent(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 132|    postfix                       { $1 }

///|
fn yy_action_36(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 133|    "-" unary                     { ExpressionParseNode::Unary(ExpressionUnaryOperator::Negation, $2) }

///|
fn yy_action_37(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_ExpressionParseNode(_dollar2)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Unary(ExpressionUnaryOperator::Negation, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 134|    "!" unary                     { ExpressionParseNode::Unary(ExpressionUnaryOperator::LogicalNegation, $2) }

///|
fn yy_action_38(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_ExpressionParseNode(_dollar2)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Unary(
        ExpressionUnaryOperator::LogicalNegation,
        _dollar2,
      )
    },
  )
}

// file:///./parser.mbty
// 135|    "~" unary                     { ExpressionParseNode::Unary(ExpressionUnaryOperator::BitwiseComplement, $2) }

///|
fn yy_action_39(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_ExpressionParseNode(_dollar2)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Unary(
        ExpressionUnaryOperator::BitwiseComplement,
        _dollar2,
      )
    },
  )
}

// file:///./parser.mbty
// 136|    "*" unary                     { ExpressionParseNode::Unary(ExpressionUnaryOperator::Indirection, $2) }

///|
fn yy_action_40(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_ExpressionParseNode(_dollar2)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Unary(ExpressionUnaryOperator::Indirection, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 137|    "&" unary                     { ExpressionParseNode::Unary(ExpressionUnaryOperator::AddressOf, $2) }

///|
fn yy_action_41(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_ExpressionParseNode(_dollar2)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Unary(ExpressionUnaryOperator::AddressOf, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 141|    primary                       { $1 }

///|
fn yy_action_42(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 151|    literal                       { $1 }

///|
fn yy_action_43(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 173|    argument_list "," expression { $1.push($3); $1 }

///|
fn yy_action_44(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ExpressionParseNode_(_dollar1)
  guard _args[2].0 is YYObj_ExpressionParseNode(_dollar3)
  YYObj_Array_ExpressionParseNode_(
    {
      ()
      _dollar1.push(_dollar3)
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 168|    argument_list ","            { $1 }

///|
fn yy_action_45(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ExpressionParseNode_(_dollar1)
  YYObj_Array_ExpressionParseNode_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 167|    argument_list                { $1 }

///|
fn yy_action_46(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ExpressionParseNode_(_dollar1)
  YYObj_Array_ExpressionParseNode_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 172|    expression                   { [$1] }

///|
fn yy_action_47(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionParseNode(_dollar1)
  YYObj_Array_ExpressionParseNode_(
    {
      ()
      [_dollar1]
    },
  )
}

// file:///./parser.mbty
// 166|                                 { [] }

///|
fn yy_action_48(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array_ExpressionParseNode_(
    {
      ()
      []
    },
  )
}

// file:///./parser.mbty
// 162|    path_ident "::" IDENT         { $1.qualified_child($3) }

///|
fn yy_action_49(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionTypeParseNode(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_ExpressionTypeParseNode(
    {
      ()
      _dollar1.qualified_child(_dollar3)
    },
  )
}

// file:///./parser.mbty
// 152|    path_ident                    { ExpressionParseNode::TypeOrIdentifier($1) }

///|
fn yy_action_50(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_ExpressionTypeParseNode(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::TypeOrIdentifier(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 157|    "(" expression ")"            { ExpressionParseNode::Parenthesized($2) }

///|
fn yy_action_51(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_ExpressionParseNode(_dollar2)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Parenthesized(_dollar2)
    },
  )
}

// file:///./parser.mbty
// 161|    IDENT                         { ExpressionTypeParseNode::from_path([$1]) }

///|
fn yy_action_52(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_ExpressionTypeParseNode(
    {
      ()
      ExpressionTypeParseNode::from_path([_dollar1])
    },
  )
}

// file:///./parser.mbty
// 177|    NUMBER                       { ExpressionParseNode::Literal($1) }

///|
fn yy_action_53(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Literal(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 178|    "true"                       { ExpressionParseNode::Bool(true) }

///|
fn yy_action_54(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Bool(true)
    },
  )
}

// file:///./parser.mbty
// 179|    "false"                      { ExpressionParseNode::Bool(false) }

///|
fn yy_action_55(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_ExpressionParseNode(
    {
      ()
      ExpressionParseNode::Bool(false)
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
    TEMPLATE(data) => (T_TEMPLATE, YYObj_String(data))
    TRUE => (T_TRUE, YYObj_Void)
    FALSE => (T_FALSE, YYObj_Void)
    LEFT_PAREN => (T_LEFT_PAREN, YYObj_Void)
    RIGHT_PAREN => (T_RIGHT_PAREN, YYObj_Void)
    LEFT_BRACKET => (T_LEFT_BRACKET, YYObj_Void)
    RIGHT_BRACKET => (T_RIGHT_BRACKET, YYObj_Void)
    DOT => (T_DOT, YYObj_Void)
    COMMA => (T_COMMA, YYObj_Void)
    DOUBLE_COLON => (T_DOUBLE_COLON, YYObj_Void)
    LESS => (T_LESS, YYObj_Void)
    LESS_EQUAL => (T_LESS_EQUAL, YYObj_Void)
    SHIFT_LEFT => (T_SHIFT_LEFT, YYObj_Void)
    GREATER => (T_GREATER, YYObj_Void)
    GREATER_EQUAL => (T_GREATER_EQUAL, YYObj_Void)
    SHIFT_RIGHT => (T_SHIFT_RIGHT, YYObj_Void)
    PLUS => (T_PLUS, YYObj_Void)
    MINUS => (T_MINUS, YYObj_Void)
    MINUS_MINUS => (T_MINUS_MINUS, YYObj_Void)
    STAR => (T_STAR, YYObj_Void)
    SLASH => (T_SLASH, YYObj_Void)
    PERCENT => (T_PERCENT, YYObj_Void)
    BANG => (T_BANG, YYObj_Void)
    TILDE => (T_TILDE, YYObj_Void)
    AMP => (T_AMP, YYObj_Void)
    AMP_AMP => (T_AMP_AMP, YYObj_Void)
    PIPE => (T_PIPE, YYObj_Void)
    PIPE_PIPE => (T_PIPE_PIPE, YYObj_Void)
    CARET => (T_CARET, YYObj_Void)
    EQUAL_EQUAL => (T_EQUAL_EQUAL, YYObj_Void)
    BANG_EQUAL => (T_BANG_EQUAL, YYObj_Void)
  }
}

// [0, parse_expression → • expression, $]
// [1, expression → • short_circuit_or, $]
// [2, short_circuit_or → • short_circuit_and, $ / PIPE_PIPE]
// [3, short_circuit_or → • short_circuit_or PIPE_PIPE short_circuit_and, $ / PIPE_PIPE]
// [4, short_circuit_and → • bitwise_or, $ / AMP_AMP / PIPE_PIPE]
// [5, short_circuit_and → • short_circuit_and AMP_AMP bitwise_or, $ / AMP_AMP / PIPE_PIPE]
// [6, bitwise_or → • bitwise_xor, $ / AMP_AMP / PIPE / PIPE_PIPE]
// [7, bitwise_or → • bitwise_or PIPE bitwise_xor, $ / AMP_AMP / PIPE / PIPE_PIPE]
// [8, bitwise_xor → • bitwise_and, $ / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [9, bitwise_xor → • bitwise_xor CARET bitwise_and, $ / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [10, bitwise_and → • equality, $ / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → • bitwise_and AMP equality, $ / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, $ / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, $ / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, $ / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, $ / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, $ / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, $ / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, $ / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, $ / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / LEFT_BRACKET / DOT / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / LEFT_BRACKET / DOT / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [56, parse_expression_prime → • parse_expression, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_parse_expression => Shift(yy_state_1)
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_65)
    NT_bitwise_and => Shift(yy_state_70)
    NT_bitwise_xor => Shift(yy_state_73)
    NT_bitwise_or => Shift(yy_state_76)
    NT_short_circuit_and => Shift(yy_state_79)
    NT_short_circuit_or => Shift(yy_state_82)
    NT_expression => Shift(yy_state_91)
    _ => Error
  }
}

// [56, parse_expression_prime → parse_expression •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [55, literal → FALSE •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_literal, yy_action_55)
}

// [54, literal → TRUE •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_literal, yy_action_54)
}

// [53, literal → NUMBER •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_literal, yy_action_53)
}

// [46, path_ident → IDENT •, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_path_ident, yy_action_52)
}

// [1, expression → • short_circuit_or, RIGHT_PAREN]
// [2, short_circuit_or → • short_circuit_and, RIGHT_PAREN / PIPE_PIPE]
// [3, short_circuit_or → • short_circuit_or PIPE_PIPE short_circuit_and, RIGHT_PAREN / PIPE_PIPE]
// [4, short_circuit_and → • bitwise_or, RIGHT_PAREN / AMP_AMP / PIPE_PIPE]
// [5, short_circuit_and → • short_circuit_and AMP_AMP bitwise_or, RIGHT_PAREN / AMP_AMP / PIPE_PIPE]
// [6, bitwise_or → • bitwise_xor, RIGHT_PAREN / AMP_AMP / PIPE / PIPE_PIPE]
// [7, bitwise_or → • bitwise_or PIPE bitwise_xor, RIGHT_PAREN / AMP_AMP / PIPE / PIPE_PIPE]
// [8, bitwise_xor → • bitwise_and, RIGHT_PAREN / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [9, bitwise_xor → • bitwise_xor CARET bitwise_and, RIGHT_PAREN / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [10, bitwise_and → • equality, RIGHT_PAREN / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → • bitwise_and AMP equality, RIGHT_PAREN / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, RIGHT_PAREN / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, RIGHT_PAREN / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, RIGHT_PAREN / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, RIGHT_PAREN / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, RIGHT_PAREN / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, RIGHT_PAREN / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, RIGHT_PAREN / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, RIGHT_PAREN / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, RIGHT_PAREN / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, RIGHT_PAREN / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, RIGHT_PAREN / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, RIGHT_PAREN / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, RIGHT_PAREN / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → LEFT_PAREN • expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / DOT / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / DOT / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, RIGHT_PAREN / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, RIGHT_PAREN / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, RIGHT_PAREN / LEFT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_expression => Shift(yy_state_7)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_65)
    NT_bitwise_and => Shift(yy_state_70)
    NT_bitwise_xor => Shift(yy_state_73)
    NT_bitwise_or => Shift(yy_state_76)
    NT_short_circuit_and => Shift(yy_state_79)
    NT_short_circuit_or => Shift(yy_state_82)
    _ => Error
  }
}

// [45, primary → LEFT_PAREN expression • RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RIGHT_PAREN => Shift(yy_state_8)
    _ => Error
  }
}

// [45, primary → LEFT_PAREN expression RIGHT_PAREN •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_primary, yy_action_51)
}

// [42, primary → path_ident •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → path_ident • LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → path_ident • TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → path_ident • DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOUBLE_COLON => Shift(yy_state_10)
    T_TEMPLATE => Shift(yy_state_12)
    T_LEFT_PAREN => Shift(yy_state_88)
    T_RIGHT_PAREN
    | T_LEFT_BRACKET
    | T_RIGHT_BRACKET
    | T_DOT
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_SHIFT_LEFT
    | T_GREATER
    | T_GREATER_EQUAL
    | T_SHIFT_RIGHT
    | T_PLUS
    | T_MINUS
    | T_MINUS_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(1, NT_primary, yy_action_50)
    _ => Error
  }
}

// [47, path_ident → path_ident DOUBLE_COLON • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_11)
    _ => Error
  }
}

// [47, path_ident → path_ident DOUBLE_COLON IDENT •, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_path_ident, yy_action_49)
}

// [44, primary → path_ident TEMPLATE • LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LEFT_PAREN => Shift(yy_state_13)
    _ => Error
  }
}

// [1, expression → • short_circuit_or, RIGHT_PAREN / COMMA]
// [2, short_circuit_or → • short_circuit_and, RIGHT_PAREN / COMMA / PIPE_PIPE]
// [3, short_circuit_or → • short_circuit_or PIPE_PIPE short_circuit_and, RIGHT_PAREN / COMMA / PIPE_PIPE]
// [4, short_circuit_and → • bitwise_or, RIGHT_PAREN / COMMA / AMP_AMP / PIPE_PIPE]
// [5, short_circuit_and → • short_circuit_and AMP_AMP bitwise_or, RIGHT_PAREN / COMMA / AMP_AMP / PIPE_PIPE]
// [6, bitwise_or → • bitwise_xor, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [7, bitwise_or → • bitwise_or PIPE bitwise_xor, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [8, bitwise_xor → • bitwise_and, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [9, bitwise_xor → • bitwise_xor CARET bitwise_and, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [10, bitwise_and → • equality, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → • bitwise_and AMP equality, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → path_ident TEMPLATE LEFT_PAREN • opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [48, opt_arguments → •, RIGHT_PAREN]
// [49, opt_arguments → • argument_list, RIGHT_PAREN]
// [50, opt_arguments → • argument_list COMMA, RIGHT_PAREN]
// [51, argument_list → • expression, RIGHT_PAREN / COMMA]
// [52, argument_list → • argument_list COMMA expression, RIGHT_PAREN / COMMA]
// [53, literal → • NUMBER, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_expression => Shift(yy_state_14)
    NT_argument_list => Shift(yy_state_15)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_65)
    NT_bitwise_and => Shift(yy_state_70)
    NT_bitwise_xor => Shift(yy_state_73)
    NT_bitwise_or => Shift(yy_state_76)
    NT_short_circuit_and => Shift(yy_state_79)
    NT_short_circuit_or => Shift(yy_state_82)
    NT_opt_arguments => Shift(yy_state_86)
    T_RIGHT_PAREN => Reduce(0, NT_opt_arguments, yy_action_48)
    _ => Error
  }
}

// [51, argument_list → expression •, RIGHT_PAREN / COMMA]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_argument_list, yy_action_47)
}

// [49, opt_arguments → argument_list •, RIGHT_PAREN]
// [50, opt_arguments → argument_list • COMMA, RIGHT_PAREN]
// [52, argument_list → argument_list • COMMA expression, RIGHT_PAREN / COMMA]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_16)
    T_RIGHT_PAREN => Reduce(1, NT_opt_arguments, yy_action_46)
    _ => Error
  }
}

// [1, expression → • short_circuit_or, RIGHT_PAREN / COMMA]
// [2, short_circuit_or → • short_circuit_and, RIGHT_PAREN / COMMA / PIPE_PIPE]
// [3, short_circuit_or → • short_circuit_or PIPE_PIPE short_circuit_and, RIGHT_PAREN / COMMA / PIPE_PIPE]
// [4, short_circuit_and → • bitwise_or, RIGHT_PAREN / COMMA / AMP_AMP / PIPE_PIPE]
// [5, short_circuit_and → • short_circuit_and AMP_AMP bitwise_or, RIGHT_PAREN / COMMA / AMP_AMP / PIPE_PIPE]
// [6, bitwise_or → • bitwise_xor, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [7, bitwise_or → • bitwise_or PIPE bitwise_xor, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [8, bitwise_xor → • bitwise_and, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [9, bitwise_xor → • bitwise_xor CARET bitwise_and, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [10, bitwise_and → • equality, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → • bitwise_and AMP equality, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [50, opt_arguments → argument_list COMMA •, RIGHT_PAREN]
// [52, argument_list → argument_list COMMA • expression, RIGHT_PAREN / COMMA]
// [53, literal → • NUMBER, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_expression => Shift(yy_state_17)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_65)
    NT_bitwise_and => Shift(yy_state_70)
    NT_bitwise_xor => Shift(yy_state_73)
    NT_bitwise_or => Shift(yy_state_76)
    NT_short_circuit_and => Shift(yy_state_79)
    NT_short_circuit_or => Shift(yy_state_82)
    T_RIGHT_PAREN => Reduce(2, NT_opt_arguments, yy_action_45)
    _ => Error
  }
}

// [52, argument_list → argument_list COMMA expression •, RIGHT_PAREN / COMMA]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_argument_list, yy_action_44)
}

// [41, primary → literal •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_primary, yy_action_43)
}

// [37, postfix → primary •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_postfix, yy_action_42)
}

// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → AMP • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    NT_unary => Shift(yy_state_21)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    _ => Error
  }
}

// [36, unary → AMP unary •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary, yy_action_41)
}

// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → STAR • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    NT_unary => Shift(yy_state_23)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    _ => Error
  }
}

// [35, unary → STAR unary •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary, yy_action_40)
}

// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → TILDE • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    NT_unary => Shift(yy_state_25)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    _ => Error
  }
}

// [34, unary → TILDE unary •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary, yy_action_39)
}

// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → BANG • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    NT_unary => Shift(yy_state_27)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    _ => Error
  }
}

// [33, unary → BANG unary •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary, yy_action_38)
}

// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → MINUS • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_unary => Shift(yy_state_29)
    NT_postfix => Shift(yy_state_30)
    _ => Error
  }
}

// [32, unary → MINUS unary •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_unary, yy_action_37)
}

// [31, unary → postfix •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → postfix • postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [39, postfix_suffix → • LEFT_BRACKET expression RIGHT_BRACKET, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [40, postfix_suffix → • DOT IDENT, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_31)
    T_LEFT_BRACKET => Shift(yy_state_33)
    NT_postfix_suffix => Shift(yy_state_85)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_SHIFT_LEFT
    | T_GREATER
    | T_GREATER_EQUAL
    | T_SHIFT_RIGHT
    | T_PLUS
    | T_MINUS
    | T_MINUS_MINUS
    | T_STAR
    | T_SLASH
    | T_PERCENT
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(1, NT_unary, yy_action_36)
    _ => Error
  }
}

// [40, postfix_suffix → DOT • IDENT, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_32)
    _ => Error
  }
}

// [40, postfix_suffix → DOT IDENT •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_postfix_suffix, yy_action_35)
}

// [1, expression → • short_circuit_or, RIGHT_BRACKET]
// [2, short_circuit_or → • short_circuit_and, RIGHT_BRACKET / PIPE_PIPE]
// [3, short_circuit_or → • short_circuit_or PIPE_PIPE short_circuit_and, RIGHT_BRACKET / PIPE_PIPE]
// [4, short_circuit_and → • bitwise_or, RIGHT_BRACKET / AMP_AMP / PIPE_PIPE]
// [5, short_circuit_and → • short_circuit_and AMP_AMP bitwise_or, RIGHT_BRACKET / AMP_AMP / PIPE_PIPE]
// [6, bitwise_or → • bitwise_xor, RIGHT_BRACKET / AMP_AMP / PIPE / PIPE_PIPE]
// [7, bitwise_or → • bitwise_or PIPE bitwise_xor, RIGHT_BRACKET / AMP_AMP / PIPE / PIPE_PIPE]
// [8, bitwise_xor → • bitwise_and, RIGHT_BRACKET / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [9, bitwise_xor → • bitwise_xor CARET bitwise_and, RIGHT_BRACKET / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [10, bitwise_and → • equality, RIGHT_BRACKET / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → • bitwise_and AMP equality, RIGHT_BRACKET / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, RIGHT_BRACKET / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, RIGHT_BRACKET / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, RIGHT_BRACKET / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, RIGHT_BRACKET / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, RIGHT_BRACKET / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, RIGHT_BRACKET / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, RIGHT_BRACKET / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, RIGHT_BRACKET / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, RIGHT_BRACKET / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, LEFT_BRACKET / RIGHT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, LEFT_BRACKET / RIGHT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [39, postfix_suffix → LEFT_BRACKET • expression RIGHT_BRACKET, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, LEFT_BRACKET / RIGHT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, LEFT_BRACKET / RIGHT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, LEFT_BRACKET / RIGHT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, LEFT_BRACKET / RIGHT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, LEFT_BRACKET / RIGHT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, TEMPLATE / LEFT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, TEMPLATE / LEFT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, LEFT_BRACKET / RIGHT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, LEFT_BRACKET / RIGHT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, LEFT_BRACKET / RIGHT_BRACKET / DOT / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_expression => Shift(yy_state_34)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_65)
    NT_bitwise_and => Shift(yy_state_70)
    NT_bitwise_xor => Shift(yy_state_73)
    NT_bitwise_or => Shift(yy_state_76)
    NT_short_circuit_and => Shift(yy_state_79)
    NT_short_circuit_or => Shift(yy_state_82)
    _ => Error
  }
}

// [39, postfix_suffix → LEFT_BRACKET expression • RIGHT_BRACKET, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RIGHT_BRACKET => Shift(yy_state_35)
    _ => Error
  }
}

// [39, postfix_suffix → LEFT_BRACKET expression RIGHT_BRACKET •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_postfix_suffix, yy_action_34)
}

// [27, multiplicative → unary •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_multiplicative, yy_action_33)
}

// [23, additive → multiplicative •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → multiplicative • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → multiplicative • SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → multiplicative • PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_38)
    T_SLASH => Shift(yy_state_40)
    T_STAR => Shift(yy_state_42)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_SHIFT_LEFT
    | T_GREATER
    | T_GREATER_EQUAL
    | T_SHIFT_RIGHT
    | T_PLUS
    | T_MINUS
    | T_MINUS_MINUS
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(1, NT_additive, yy_action_32)
    _ => Error
  }
}

// [30, multiplicative → multiplicative PERCENT • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_39)
    _ => Error
  }
}

// [30, multiplicative → multiplicative PERCENT unary •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_multiplicative, yy_action_31)
}

// [29, multiplicative → multiplicative SLASH • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_41)
    _ => Error
  }
}

// [29, multiplicative → multiplicative SLASH unary •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_multiplicative, yy_action_30)
}

// [28, multiplicative → multiplicative STAR • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_43)
    _ => Error
  }
}

// [28, multiplicative → multiplicative STAR unary •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_multiplicative, yy_action_29)
}

// [20, shift → additive •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → additive • PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → additive • MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → additive • MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MINUS_MINUS => Shift(yy_state_45)
    T_MINUS => Shift(yy_state_47)
    T_PLUS => Shift(yy_state_49)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_SHIFT_LEFT
    | T_GREATER
    | T_GREATER_EQUAL
    | T_SHIFT_RIGHT
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(1, NT_shift, yy_action_28)
    _ => Error
  }
}

// [26, additive → additive MINUS_MINUS • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_46)
    _ => Error
  }
}

// [26, additive → additive MINUS_MINUS multiplicative •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → multiplicative • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → multiplicative • SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → multiplicative • PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_38)
    T_SLASH => Shift(yy_state_40)
    T_STAR => Shift(yy_state_42)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_SHIFT_LEFT
    | T_GREATER
    | T_GREATER_EQUAL
    | T_SHIFT_RIGHT
    | T_PLUS
    | T_MINUS
    | T_MINUS_MINUS
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_additive, yy_action_27)
    _ => Error
  }
}

// [25, additive → additive MINUS • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_48)
    _ => Error
  }
}

// [25, additive → additive MINUS multiplicative •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → multiplicative • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → multiplicative • SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → multiplicative • PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_38)
    T_SLASH => Shift(yy_state_40)
    T_STAR => Shift(yy_state_42)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_SHIFT_LEFT
    | T_GREATER
    | T_GREATER_EQUAL
    | T_SHIFT_RIGHT
    | T_PLUS
    | T_MINUS
    | T_MINUS_MINUS
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_additive, yy_action_26)
    _ => Error
  }
}

// [24, additive → additive PLUS • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_50)
    _ => Error
  }
}

// [24, additive → additive PLUS multiplicative •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → multiplicative • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → multiplicative • SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → multiplicative • PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PERCENT => Shift(yy_state_38)
    T_SLASH => Shift(yy_state_40)
    T_STAR => Shift(yy_state_42)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_SHIFT_LEFT
    | T_GREATER
    | T_GREATER_EQUAL
    | T_SHIFT_RIGHT
    | T_PLUS
    | T_MINUS
    | T_MINUS_MINUS
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_additive, yy_action_25)
    _ => Error
  }
}

// [15, relational → shift •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → shift • SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → shift • SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHIFT_RIGHT => Shift(yy_state_52)
    T_SHIFT_LEFT => Shift(yy_state_54)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_GREATER
    | T_GREATER_EQUAL
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(1, NT_relational, yy_action_24)
    _ => Error
  }
}

// [22, shift → shift SHIFT_RIGHT • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_53)
    _ => Error
  }
}

// [22, shift → shift SHIFT_RIGHT additive •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → additive • PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → additive • MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → additive • MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MINUS_MINUS => Shift(yy_state_45)
    T_MINUS => Shift(yy_state_47)
    T_PLUS => Shift(yy_state_49)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_SHIFT_LEFT
    | T_GREATER
    | T_GREATER_EQUAL
    | T_SHIFT_RIGHT
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_shift, yy_action_23)
    _ => Error
  }
}

// [21, shift → shift SHIFT_LEFT • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_55)
    _ => Error
  }
}

// [21, shift → shift SHIFT_LEFT additive •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → additive • PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → additive • MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → additive • MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MINUS_MINUS => Shift(yy_state_45)
    T_MINUS => Shift(yy_state_47)
    T_PLUS => Shift(yy_state_49)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_SHIFT_LEFT
    | T_GREATER
    | T_GREATER_EQUAL
    | T_SHIFT_RIGHT
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_shift, yy_action_22)
    _ => Error
  }
}

// [12, equality → relational •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → relational • LESS shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → relational • LESS_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → relational • GREATER shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → relational • GREATER_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_GREATER_EQUAL => Shift(yy_state_57)
    T_GREATER => Shift(yy_state_59)
    T_LESS_EQUAL => Shift(yy_state_61)
    T_LESS => Shift(yy_state_63)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(1, NT_equality, yy_action_21)
    _ => Error
  }
}

// [19, relational → relational GREATER_EQUAL • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_58)
    _ => Error
  }
}

// [19, relational → relational GREATER_EQUAL shift •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → shift • SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → shift • SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHIFT_RIGHT => Shift(yy_state_52)
    T_SHIFT_LEFT => Shift(yy_state_54)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_GREATER
    | T_GREATER_EQUAL
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_relational, yy_action_20)
    _ => Error
  }
}

// [18, relational → relational GREATER • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_60)
    _ => Error
  }
}

// [18, relational → relational GREATER shift •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → shift • SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → shift • SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHIFT_RIGHT => Shift(yy_state_52)
    T_SHIFT_LEFT => Shift(yy_state_54)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_GREATER
    | T_GREATER_EQUAL
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_relational, yy_action_19)
    _ => Error
  }
}

// [17, relational → relational LESS_EQUAL • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_62)
    _ => Error
  }
}

// [17, relational → relational LESS_EQUAL shift •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → shift • SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → shift • SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHIFT_RIGHT => Shift(yy_state_52)
    T_SHIFT_LEFT => Shift(yy_state_54)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_GREATER
    | T_GREATER_EQUAL
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_relational, yy_action_18)
    _ => Error
  }
}

// [16, relational → relational LESS • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_64)
    _ => Error
  }
}

// [16, relational → relational LESS shift •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → shift • SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → shift • SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHIFT_RIGHT => Shift(yy_state_52)
    T_SHIFT_LEFT => Shift(yy_state_54)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_LESS
    | T_LESS_EQUAL
    | T_GREATER
    | T_GREATER_EQUAL
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_relational, yy_action_17)
    _ => Error
  }
}

// [10, bitwise_and → equality •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [13, equality → equality • EQUAL_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → equality • BANG_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG_EQUAL => Shift(yy_state_66)
    T_EQUAL_EQUAL => Shift(yy_state_68)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | EOI => Reduce(1, NT_bitwise_and, yy_action_16)
    _ => Error
  }
}

// [14, equality → equality BANG_EQUAL • relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_67)
    _ => Error
  }
}

// [14, equality → equality BANG_EQUAL relational •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → relational • LESS shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → relational • LESS_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → relational • GREATER shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → relational • GREATER_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_GREATER_EQUAL => Shift(yy_state_57)
    T_GREATER => Shift(yy_state_59)
    T_LESS_EQUAL => Shift(yy_state_61)
    T_LESS => Shift(yy_state_63)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_equality, yy_action_15)
    _ => Error
  }
}

// [13, equality → equality EQUAL_EQUAL • relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_69)
    _ => Error
  }
}

// [13, equality → equality EQUAL_EQUAL relational •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → relational • LESS shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → relational • LESS_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → relational • GREATER shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → relational • GREATER_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_GREATER_EQUAL => Shift(yy_state_57)
    T_GREATER => Shift(yy_state_59)
    T_LESS_EQUAL => Shift(yy_state_61)
    T_LESS => Shift(yy_state_63)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | T_EQUAL_EQUAL
    | T_BANG_EQUAL
    | EOI => Reduce(3, NT_equality, yy_action_14)
    _ => Error
  }
}

// [8, bitwise_xor → bitwise_and •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → bitwise_and • AMP equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]

///|
fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMP => Shift(yy_state_71)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | EOI => Reduce(1, NT_bitwise_xor, yy_action_13)
    _ => Error
  }
}

// [11, bitwise_and → bitwise_and AMP • equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_72)
    _ => Error
  }
}

// [11, bitwise_and → bitwise_and AMP equality •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [13, equality → equality • EQUAL_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → equality • BANG_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG_EQUAL => Shift(yy_state_66)
    T_EQUAL_EQUAL => Shift(yy_state_68)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_AMP
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | EOI => Reduce(3, NT_bitwise_and, yy_action_12)
    _ => Error
  }
}

// [6, bitwise_or → bitwise_xor •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [9, bitwise_xor → bitwise_xor • CARET bitwise_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]

///|
fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_CARET => Shift(yy_state_74)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | EOI => Reduce(1, NT_bitwise_or, yy_action_11)
    _ => Error
  }
}

// [9, bitwise_xor → bitwise_xor CARET • bitwise_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [10, bitwise_and → • equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → • bitwise_and AMP equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_65)
    NT_bitwise_and => Shift(yy_state_75)
    _ => Error
  }
}

// [9, bitwise_xor → bitwise_xor CARET bitwise_and •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → bitwise_and • AMP equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]

///|
fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMP => Shift(yy_state_71)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | T_CARET
    | EOI => Reduce(3, NT_bitwise_xor, yy_action_10)
    _ => Error
  }
}

// [4, short_circuit_and → bitwise_or •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE_PIPE]
// [7, bitwise_or → bitwise_or • PIPE bitwise_xor, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE]

///|
fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PIPE => Shift(yy_state_77)
    T_RIGHT_PAREN | T_RIGHT_BRACKET | T_COMMA | T_AMP_AMP | T_PIPE_PIPE | EOI =>
      Reduce(1, NT_short_circuit_and, yy_action_9)
    _ => Error
  }
}

// [7, bitwise_or → bitwise_or PIPE • bitwise_xor, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [8, bitwise_xor → • bitwise_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [9, bitwise_xor → • bitwise_xor CARET bitwise_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [10, bitwise_and → • equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → • bitwise_and AMP equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_65)
    NT_bitwise_and => Shift(yy_state_70)
    NT_bitwise_xor => Shift(yy_state_78)
    _ => Error
  }
}

// [7, bitwise_or → bitwise_or PIPE bitwise_xor •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [9, bitwise_xor → bitwise_xor • CARET bitwise_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]

///|
fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_CARET => Shift(yy_state_74)
    T_RIGHT_PAREN
    | T_RIGHT_BRACKET
    | T_COMMA
    | T_AMP_AMP
    | T_PIPE
    | T_PIPE_PIPE
    | EOI => Reduce(3, NT_bitwise_or, yy_action_8)
    _ => Error
  }
}

// [2, short_circuit_or → short_circuit_and •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / PIPE_PIPE]
// [5, short_circuit_and → short_circuit_and • AMP_AMP bitwise_or, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE_PIPE]

///|
fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMP_AMP => Shift(yy_state_80)
    T_RIGHT_PAREN | T_RIGHT_BRACKET | T_COMMA | T_PIPE_PIPE | EOI =>
      Reduce(1, NT_short_circuit_or, yy_action_7)
    _ => Error
  }
}

// [5, short_circuit_and → short_circuit_and AMP_AMP • bitwise_or, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE_PIPE]
// [6, bitwise_or → • bitwise_xor, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [7, bitwise_or → • bitwise_or PIPE bitwise_xor, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [8, bitwise_xor → • bitwise_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [9, bitwise_xor → • bitwise_xor CARET bitwise_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [10, bitwise_and → • equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → • bitwise_and AMP equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_65)
    NT_bitwise_and => Shift(yy_state_70)
    NT_bitwise_xor => Shift(yy_state_73)
    NT_bitwise_or => Shift(yy_state_81)
    _ => Error
  }
}

// [5, short_circuit_and → short_circuit_and AMP_AMP bitwise_or •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE_PIPE]
// [7, bitwise_or → bitwise_or • PIPE bitwise_xor, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE]

///|
fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PIPE => Shift(yy_state_77)
    T_RIGHT_PAREN | T_RIGHT_BRACKET | T_COMMA | T_AMP_AMP | T_PIPE_PIPE | EOI =>
      Reduce(3, NT_short_circuit_and, yy_action_6)
    _ => Error
  }
}

// [1, expression → short_circuit_or •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA]
// [3, short_circuit_or → short_circuit_or • PIPE_PIPE short_circuit_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / PIPE_PIPE]

///|
fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PIPE_PIPE => Shift(yy_state_83)
    T_RIGHT_PAREN | T_RIGHT_BRACKET | T_COMMA | EOI =>
      Reduce(1, NT_expression, yy_action_5)
    _ => Error
  }
}

// [3, short_circuit_or → short_circuit_or PIPE_PIPE • short_circuit_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / PIPE_PIPE]
// [4, short_circuit_and → • bitwise_or, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE_PIPE]
// [5, short_circuit_and → • short_circuit_and AMP_AMP bitwise_or, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE_PIPE]
// [6, bitwise_or → • bitwise_xor, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [7, bitwise_or → • bitwise_or PIPE bitwise_xor, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [8, bitwise_xor → • bitwise_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [9, bitwise_xor → • bitwise_xor CARET bitwise_and, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [10, bitwise_and → • equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → • bitwise_and AMP equality, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, $ / TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [53, literal → • NUMBER, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_65)
    NT_bitwise_and => Shift(yy_state_70)
    NT_bitwise_xor => Shift(yy_state_73)
    NT_bitwise_or => Shift(yy_state_76)
    NT_short_circuit_and => Shift(yy_state_84)
    _ => Error
  }
}

// [3, short_circuit_or → short_circuit_or PIPE_PIPE short_circuit_and •, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / PIPE_PIPE]
// [5, short_circuit_and → short_circuit_and • AMP_AMP bitwise_or, $ / RIGHT_PAREN / RIGHT_BRACKET / COMMA / AMP_AMP / PIPE_PIPE]

///|
fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMP_AMP => Shift(yy_state_80)
    T_RIGHT_PAREN | T_RIGHT_BRACKET | T_COMMA | T_PIPE_PIPE | EOI =>
      Reduce(3, NT_short_circuit_or, yy_action_4)
    _ => Error
  }
}

// [38, postfix → postfix postfix_suffix •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_postfix, yy_action_3)
}

// [44, primary → path_ident TEMPLATE LEFT_PAREN opt_arguments • RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RIGHT_PAREN => Shift(yy_state_87)
    _ => Error
  }
}

// [44, primary → path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_primary, yy_action_2)
}

// [1, expression → • short_circuit_or, RIGHT_PAREN / COMMA]
// [2, short_circuit_or → • short_circuit_and, RIGHT_PAREN / COMMA / PIPE_PIPE]
// [3, short_circuit_or → • short_circuit_or PIPE_PIPE short_circuit_and, RIGHT_PAREN / COMMA / PIPE_PIPE]
// [4, short_circuit_and → • bitwise_or, RIGHT_PAREN / COMMA / AMP_AMP / PIPE_PIPE]
// [5, short_circuit_and → • short_circuit_and AMP_AMP bitwise_or, RIGHT_PAREN / COMMA / AMP_AMP / PIPE_PIPE]
// [6, bitwise_or → • bitwise_xor, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [7, bitwise_or → • bitwise_or PIPE bitwise_xor, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE]
// [8, bitwise_xor → • bitwise_and, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [9, bitwise_xor → • bitwise_xor CARET bitwise_and, RIGHT_PAREN / COMMA / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [10, bitwise_and → • equality, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [11, bitwise_and → • bitwise_and AMP equality, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET]
// [12, equality → • relational, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [13, equality → • equality EQUAL_EQUAL relational, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [14, equality → • equality BANG_EQUAL relational, RIGHT_PAREN / COMMA / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [15, relational → • shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [16, relational → • relational LESS shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [17, relational → • relational LESS_EQUAL shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [18, relational → • relational GREATER shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [19, relational → • relational GREATER_EQUAL shift, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / GREATER / GREATER_EQUAL / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [20, shift → • additive, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [21, shift → • shift SHIFT_LEFT additive, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [22, shift → • shift SHIFT_RIGHT additive, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [23, additive → • multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [24, additive → • additive PLUS multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [25, additive → • additive MINUS multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [26, additive → • additive MINUS_MINUS multiplicative, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [27, multiplicative → • unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [28, multiplicative → • multiplicative STAR unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [29, multiplicative → • multiplicative SLASH unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [30, multiplicative → • multiplicative PERCENT unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [31, unary → • postfix, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [32, unary → • MINUS unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [33, unary → • BANG unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [34, unary → • TILDE unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [35, unary → • STAR unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [36, unary → • AMP unary, RIGHT_PAREN / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [37, postfix → • primary, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [38, postfix → • postfix postfix_suffix, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [41, primary → • literal, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [42, primary → • path_ident, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → • path_ident LEFT_PAREN opt_arguments RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [43, primary → path_ident LEFT_PAREN • opt_arguments RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [44, primary → • path_ident TEMPLATE LEFT_PAREN opt_arguments RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [45, primary → • LEFT_PAREN expression RIGHT_PAREN, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [46, path_ident → • IDENT, TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [47, path_ident → • path_ident DOUBLE_COLON IDENT, TEMPLATE / LEFT_PAREN / RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / DOUBLE_COLON / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [48, opt_arguments → •, RIGHT_PAREN]
// [49, opt_arguments → • argument_list, RIGHT_PAREN]
// [50, opt_arguments → • argument_list COMMA, RIGHT_PAREN]
// [51, argument_list → • expression, RIGHT_PAREN / COMMA]
// [52, argument_list → • argument_list COMMA expression, RIGHT_PAREN / COMMA]
// [53, literal → • NUMBER, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [54, literal → • TRUE, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]
// [55, literal → • FALSE, RIGHT_PAREN / LEFT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FALSE => Shift(yy_state_2)
    T_TRUE => Shift(yy_state_3)
    T_NUMBER => Shift(yy_state_4)
    T_IDENT => Shift(yy_state_5)
    T_LEFT_PAREN => Shift(yy_state_6)
    NT_path_ident => Shift(yy_state_9)
    NT_expression => Shift(yy_state_14)
    NT_argument_list => Shift(yy_state_15)
    NT_literal => Shift(yy_state_18)
    NT_primary => Shift(yy_state_19)
    T_AMP => Shift(yy_state_20)
    T_STAR => Shift(yy_state_22)
    T_TILDE => Shift(yy_state_24)
    T_BANG => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    NT_postfix => Shift(yy_state_30)
    NT_unary => Shift(yy_state_36)
    NT_multiplicative => Shift(yy_state_37)
    NT_additive => Shift(yy_state_44)
    NT_shift => Shift(yy_state_51)
    NT_relational => Shift(yy_state_56)
    NT_equality => Shift(yy_state_65)
    NT_bitwise_and => Shift(yy_state_70)
    NT_bitwise_xor => Shift(yy_state_73)
    NT_bitwise_or => Shift(yy_state_76)
    NT_short_circuit_and => Shift(yy_state_79)
    NT_short_circuit_or => Shift(yy_state_82)
    NT_opt_arguments => Shift(yy_state_89)
    T_RIGHT_PAREN => Reduce(0, NT_opt_arguments, yy_action_48)
    _ => Error
  }
}

// [43, primary → path_ident LEFT_PAREN opt_arguments • RIGHT_PAREN, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RIGHT_PAREN => Shift(yy_state_90)
    _ => Error
  }
}

// [43, primary → path_ident LEFT_PAREN opt_arguments RIGHT_PAREN •, $ / RIGHT_PAREN / LEFT_BRACKET / RIGHT_BRACKET / DOT / COMMA / LESS / LESS_EQUAL / SHIFT_LEFT / GREATER / GREATER_EQUAL / SHIFT_RIGHT / PLUS / MINUS / MINUS_MINUS / STAR / SLASH / PERCENT / AMP / AMP_AMP / PIPE / PIPE_PIPE / CARET / EQUAL_EQUAL / BANG_EQUAL]

///|
fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_primary, yy_action_1)
}

// [0, parse_expression → expression •, $]

///|
fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_parse_expression, yy_action_0)
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
        (T_TEMPLATE, TK_TEMPLATE),
        (T_TRUE, TK_TRUE),
        (T_FALSE, TK_FALSE),
        (T_LEFT_PAREN, TK_LEFT_PAREN),
        (T_RIGHT_PAREN, TK_RIGHT_PAREN),
        (T_LEFT_BRACKET, TK_LEFT_BRACKET),
        (T_RIGHT_BRACKET, TK_RIGHT_BRACKET),
        (T_DOT, TK_DOT),
        (T_COMMA, TK_COMMA),
        (T_DOUBLE_COLON, TK_DOUBLE_COLON),
        (T_LESS, TK_LESS),
        (T_LESS_EQUAL, TK_LESS_EQUAL),
        (T_SHIFT_LEFT, TK_SHIFT_LEFT),
        (T_GREATER, TK_GREATER),
        (T_GREATER_EQUAL, TK_GREATER_EQUAL),
        (T_SHIFT_RIGHT, TK_SHIFT_RIGHT),
        (T_PLUS, TK_PLUS),
        (T_MINUS, TK_MINUS),
        (T_MINUS_MINUS, TK_MINUS_MINUS),
        (T_STAR, TK_STAR),
        (T_SLASH, TK_SLASH),
        (T_PERCENT, TK_PERCENT),
        (T_BANG, TK_BANG),
        (T_TILDE, TK_TILDE),
        (T_AMP, TK_AMP),
        (T_AMP_AMP, TK_AMP_AMP),
        (T_PIPE, TK_PIPE),
        (T_PIPE_PIPE, TK_PIPE_PIPE),
        (T_CARET, TK_CARET),
        (T_EQUAL_EQUAL, TK_EQUAL_EQUAL),
        (T_BANG_EQUAL, TK_BANG_EQUAL),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn parse_expression(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> ExpressionParseNode raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_ExpressionParseNode(result)
      result
    },
    initial_pos?,
  )
}
