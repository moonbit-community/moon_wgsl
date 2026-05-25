///|
pub(all) enum Token {
  STMT(@ast.WgslStatement)
  TYPE_ATOM(@ast.WgslTypeAtom)
  TYPE_ARGS((Array[@ast.WgslTypeArgument], Int))
  ARG_NAME(@ast.WgslIdent)
  ARG_TYPE(@ast.WgslTypeRef)
  MEMBER_NAME(@ast.WgslIdent)
  MEMBER_TYPE(@ast.WgslTypeRef)
  DECL_TYPE(@ast.WgslTypeRef)
  INIT_EXPR(@ast.WgslExprRef)
  EXPR_REF(@ast.WgslExprRef)
  AT(Int)
  ATTR_NAME(@ast.WgslIdent)
  ATTR_ARGS((@ast.WgslExprRef?, Int))
  KW_ENABLE(@ast.WgslIdent)
  KW_REQUIRES(@ast.WgslIdent)
  KW_DIAGNOSTIC(@ast.WgslIdent)
  DIRECTIVE_TAIL((String, Int, Int))
  SOURCE_TEXT(String)
  ARROW(Int)
  LPAREN
  RPAREN
  LBRACE(Int)
  RBRACE(Int)
  COLON
  EQUAL
  TYPE_LT(Int)
  TYPE_GT(Int)
  COMMA
  SEMI
  EOF
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    STMT(_) => TK_STMT
    TYPE_ATOM(_) => TK_TYPE_ATOM
    TYPE_ARGS(_) => TK_TYPE_ARGS
    ARG_NAME(_) => TK_ARG_NAME
    ARG_TYPE(_) => TK_ARG_TYPE
    MEMBER_NAME(_) => TK_MEMBER_NAME
    MEMBER_TYPE(_) => TK_MEMBER_TYPE
    DECL_TYPE(_) => TK_DECL_TYPE
    INIT_EXPR(_) => TK_INIT_EXPR
    EXPR_REF(_) => TK_EXPR_REF
    AT(_) => TK_AT
    ATTR_NAME(_) => TK_ATTR_NAME
    ATTR_ARGS(_) => TK_ATTR_ARGS
    KW_ENABLE(_) => TK_KW_ENABLE
    KW_REQUIRES(_) => TK_KW_REQUIRES
    KW_DIAGNOSTIC(_) => TK_KW_DIAGNOSTIC
    DIRECTIVE_TAIL(_) => TK_DIRECTIVE_TAIL
    SOURCE_TEXT(_) => TK_SOURCE_TEXT
    ARROW(_) => TK_ARROW
    LPAREN => TK_LPAREN
    RPAREN => TK_RPAREN
    LBRACE(_) => TK_LBRACE
    RBRACE(_) => TK_RBRACE
    COLON => TK_COLON
    EQUAL => TK_EQUAL
    TYPE_LT(_) => TK_TYPE_LT
    TYPE_GT(_) => TK_TYPE_GT
    COMMA => TK_COMMA
    SEMI => TK_SEMI
    EOF => TK_EOF
  }
}

///|
pub(all) enum TokenKind {
  TK_STMT
  TK_TYPE_ATOM
  TK_TYPE_ARGS
  TK_ARG_NAME
  TK_ARG_TYPE
  TK_MEMBER_NAME
  TK_MEMBER_TYPE
  TK_DECL_TYPE
  TK_INIT_EXPR
  TK_EXPR_REF
  TK_AT
  TK_ATTR_NAME
  TK_ATTR_ARGS
  TK_KW_ENABLE
  TK_KW_REQUIRES
  TK_KW_DIAGNOSTIC
  TK_DIRECTIVE_TAIL
  TK_SOURCE_TEXT
  TK_ARROW
  TK_LPAREN
  TK_RPAREN
  TK_LBRACE
  TK_RBRACE
  TK_COLON
  TK_EQUAL
  TK_TYPE_LT
  TK_TYPE_GT
  TK_COMMA
  TK_SEMI
  TK_EOF
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_STMT => "STMT"
      TK_TYPE_ATOM => "TYPE_ATOM"
      TK_TYPE_ARGS => "TYPE_ARGS"
      TK_ARG_NAME => "ARG_NAME"
      TK_ARG_TYPE => "ARG_TYPE"
      TK_MEMBER_NAME => "MEMBER_NAME"
      TK_MEMBER_TYPE => "MEMBER_TYPE"
      TK_DECL_TYPE => "DECL_TYPE"
      TK_INIT_EXPR => "INIT_EXPR"
      TK_EXPR_REF => "EXPR_REF"
      TK_AT => "\"@\""
      TK_ATTR_NAME => "ATTR_NAME"
      TK_ATTR_ARGS => "ATTR_ARGS"
      TK_KW_ENABLE => "KW_ENABLE"
      TK_KW_REQUIRES => "KW_REQUIRES"
      TK_KW_DIAGNOSTIC => "KW_DIAGNOSTIC"
      TK_DIRECTIVE_TAIL => "DIRECTIVE_TAIL"
      TK_SOURCE_TEXT => "SOURCE_TEXT"
      TK_ARROW => "\"->\""
      TK_LPAREN => "\"(\""
      TK_RPAREN => "\")\""
      TK_LBRACE => "\"{\""
      TK_RBRACE => "\"}\""
      TK_COLON => "\":\""
      TK_EQUAL => "\"=\""
      TK_TYPE_LT => "\"<\""
      TK_TYPE_GT => "\">\""
      TK_COMMA => "\",\""
      TK_SEMI => "\";\""
      TK_EOF => "EOF"
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_STMT => to_repr("STMT")
    TK_TYPE_ATOM => to_repr("TYPE_ATOM")
    TK_TYPE_ARGS => to_repr("TYPE_ARGS")
    TK_ARG_NAME => to_repr("ARG_NAME")
    TK_ARG_TYPE => to_repr("ARG_TYPE")
    TK_MEMBER_NAME => to_repr("MEMBER_NAME")
    TK_MEMBER_TYPE => to_repr("MEMBER_TYPE")
    TK_DECL_TYPE => to_repr("DECL_TYPE")
    TK_INIT_EXPR => to_repr("INIT_EXPR")
    TK_EXPR_REF => to_repr("EXPR_REF")
    TK_AT => to_repr("@")
    TK_ATTR_NAME => to_repr("ATTR_NAME")
    TK_ATTR_ARGS => to_repr("ATTR_ARGS")
    TK_KW_ENABLE => to_repr("KW_ENABLE")
    TK_KW_REQUIRES => to_repr("KW_REQUIRES")
    TK_KW_DIAGNOSTIC => to_repr("KW_DIAGNOSTIC")
    TK_DIRECTIVE_TAIL => to_repr("DIRECTIVE_TAIL")
    TK_SOURCE_TEXT => to_repr("SOURCE_TEXT")
    TK_ARROW => to_repr("->")
    TK_LPAREN => to_repr("(")
    TK_RPAREN => to_repr(")")
    TK_LBRACE => to_repr("{")
    TK_RBRACE => to_repr("}")
    TK_COLON => to_repr(":")
    TK_EQUAL => to_repr("=")
    TK_TYPE_LT => to_repr("<")
    TK_TYPE_GT => to_repr(">")
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
priv suberror YYObj_Array__ast_WgslTypeRef_ {
  YYObj_Array__ast_WgslTypeRef_(Array[@ast.WgslTypeRef])
}

///|
priv suberror YYObj_Array__ast_WgslAttribute_ {
  YYObj_Array__ast_WgslAttribute_(Array[@ast.WgslAttribute])
}

///|
priv suberror YYObj_Array__ast_WgslStatement_ {
  YYObj_Array__ast_WgslStatement_(Array[@ast.WgslStatement])
}

///|
priv suberror YYObj_Array__ast_WgslStructMember_ {
  YYObj_Array__ast_WgslStructMember_(Array[@ast.WgslStructMember])
}

///|
priv suberror YYObj_Array__ast_WgslFunctionArgument_ {
  YYObj_Array__ast_WgslFunctionArgument_(Array[@ast.WgslFunctionArgument])
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj__ast_WgslBlock {
  YYObj__ast_WgslBlock(@ast.WgslBlock)
}

///|
priv suberror YYObj__ast_WgslIdent {
  YYObj__ast_WgslIdent(@ast.WgslIdent)
}

///|
priv suberror YYObj__ast_WgslExprRef {
  YYObj__ast_WgslExprRef(@ast.WgslExprRef)
}

///|
priv suberror YYObj__ast_WgslTypeRef {
  YYObj__ast_WgslTypeRef(@ast.WgslTypeRef)
}

///|
priv suberror YYObj__ast_WgslTypeAtom {
  YYObj__ast_WgslTypeAtom(@ast.WgslTypeAtom)
}

///|
priv suberror YYObj__ast_WgslAttribute {
  YYObj__ast_WgslAttribute(@ast.WgslAttribute)
}

///|
priv suberror YYObj__ast_WgslDirective {
  YYObj__ast_WgslDirective(@ast.WgslDirective)
}

///|
priv suberror YYObj__ast_WgslStatement {
  YYObj__ast_WgslStatement(@ast.WgslStatement)
}

///|
priv suberror YYObj__ast_WgslStructMember {
  YYObj__ast_WgslStructMember(@ast.WgslStructMember)
}

///|
priv suberror YYObj__ast_WgslFunctionArgument {
  YYObj__ast_WgslFunctionArgument(@ast.WgslFunctionArgument)
}

///|
priv suberror YYObj__ast_WgslExprRef_ {
  YYObj__ast_WgslExprRef_(@ast.WgslExprRef?)
}

///|
priv suberror YYObj__ast_WgslFunctionResult_ {
  YYObj__ast_WgslFunctionResult_(@ast.WgslFunctionResult?)
}

///|
priv suberror YYObj__Array__ast_WgslTypeArgument___Int_ {
  YYObj__Array__ast_WgslTypeArgument___Int_((Array[@ast.WgslTypeArgument], Int))
}

///|
priv suberror YYObj___ast_WgslExprRef___Int_ {
  YYObj___ast_WgslExprRef___Int_((@ast.WgslExprRef?, Int))
}

///|
priv suberror YYObj___ast_WgslExprRef___Int__ {
  YYObj___ast_WgslExprRef___Int__((@ast.WgslExprRef?, Int?))
}

///|
priv suberror YYObj___ast_WgslTypeRef____ast_WgslExprRef__ {
  YYObj___ast_WgslTypeRef____ast_WgslExprRef__(
    (@ast.WgslTypeRef?, @ast.WgslExprRef?)
  )
}

///|
priv suberror YYObj__String__Int__Int_ {
  YYObj__String__Int__Int_((String, Int, Int))
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
  T_STMT
  T_TYPE_ATOM
  T_TYPE_ARGS
  T_ARG_NAME
  T_ARG_TYPE
  T_MEMBER_NAME
  T_MEMBER_TYPE
  T_DECL_TYPE
  T_INIT_EXPR
  T_EXPR_REF
  T_AT
  T_ATTR_NAME
  T_ATTR_ARGS
  T_KW_ENABLE
  T_KW_REQUIRES
  T_KW_DIAGNOSTIC
  T_DIRECTIVE_TAIL
  T_SOURCE_TEXT
  T_ARROW
  T_LPAREN
  T_RPAREN
  T_LBRACE
  T_RBRACE
  T_COLON
  T_EQUAL
  T_TYPE_LT
  T_TYPE_GT
  T_COMMA
  T_SEMI
  T_EOF
  NT_block
  NT_statements
  NT_attributes
  NT_attribute
  NT_attribute_args
  NT_directive_tail
  NT_type_ref
  NT_function_args
  NT_function_result
  NT_struct_members
  NT_struct_member_list
  NT_struct_member
  NT_typed_initializer_tail
  NT_type_alias_tail
  NT_source_directive
  NT_const_assert_expr
  NT_initializer_opt
  NT_initializer
  NT_member_separator
  NT_optional_member_separator
  NT_function_arg_list
  NT_function_arg
  NT_optional_comma
  NT_template_list
  NT_template_args
  NT_type_expr
  NT_type_ref_args
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

// file:///./wgsl_parser.mbty
// 102|    value=type_expr EOF { value }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj__ast_WgslTypeRef(
    {
      ()
      value
    },
  )
}

// file:///./wgsl_parser.mbty
// 273|    TYPE_LT args=template_args TYPE_GT EOF { args }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslTypeRef_(args)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 280|    args=template_args "," value=type_expr {
// 281|      args.push(value)
// 282|      args
// 283|    }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslTypeRef_(args)
  guard _args[2].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      args.push(value)
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 277|    value=type_expr {
// 278|      [value]
// 279|    }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 290|    atom=TYPE_ATOM args=TYPE_ARGS {
// 291|      wgsl_type_ref_from_template_arguments(atom, args)
// 292|    }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeAtom(atom)
  guard _args[1].0 is YYObj__Array__ast_WgslTypeArgument___Int_(args)
  YYObj__ast_WgslTypeRef(
    {
      ()
      wgsl_type_ref_from_template_arguments(atom, args)
    },
  )
}

// file:///./wgsl_parser.mbty
// 293|    atom=TYPE_ATOM TYPE_LT args=type_ref_args gt=TYPE_GT {
// 294|      wgsl_type_ref_from_atom(atom, args, gt)
// 295|    }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeAtom(atom)
  guard _args[2].0 is YYObj_Array__ast_WgslTypeRef_(args)
  guard _args[3].0 is YYObj_Int(gt)
  YYObj__ast_WgslTypeRef(
    {
      ()
      wgsl_type_ref_from_atom(atom, args, gt)
    },
  )
}

// file:///./wgsl_parser.mbty
// 302|    args=type_ref_args "," value=type_expr {
// 303|      args.push(value)
// 304|      args
// 305|    }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslTypeRef_(args)
  guard _args[2].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      args.push(value)
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 299|    value=type_expr {
// 300|      [value]
// 301|    }

///|
fn yy_action_7(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 287|    atom=TYPE_ATOM {
// 288|      wgsl_type_ref_from_atom(atom, [], atom.end())
// 289|    }

///|
fn yy_action_8(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeAtom(atom)
  YYObj__ast_WgslTypeRef(
    {
      ()
      wgsl_type_ref_from_atom(atom, [], atom.end())
    },
  )
}

// file:///./wgsl_parser.mbty
// 106|    "(" ")" EOF { [] }

///|
fn yy_action_9(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 107|    "(" args=function_arg_list optional_comma ")" EOF { args }

///|
fn yy_action_10(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslFunctionArgument_(args)
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 255|    attrs=attributes name=ARG_NAME ":" ty=ARG_TYPE {
// 256|      let start = if attrs.length() > 0 { attrs[0].start() } else { name.start() }
// 257|      @ast.WgslFunctionArgument(
// 258|        attrs,
// 259|        name,
// 260|        start,
// 261|        ty.end(),
// 262|        Some(ty),
// 263|      )
// 264|    }

///|
fn yy_action_11(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(name)
  guard _args[3].0 is YYObj__ast_WgslTypeRef(ty)
  YYObj__ast_WgslFunctionArgument(
    {
      ()
      let start = if attrs.length() > 0 {
        attrs[0].start()
      } else {
        name.start()
      }
      @ast.WgslFunctionArgument(attrs, name, start, ty.end(), Some(ty))
    },
  )
}

// file:///./wgsl_parser.mbty
// 248|    args=function_arg_list "," value=function_arg {
// 249|      args.push(value)
// 250|      args
// 251|    }

///|
fn yy_action_12(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslFunctionArgument_(args)
  guard _args[2].0 is YYObj__ast_WgslFunctionArgument(value)
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      args.push(value)
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 269|    "," { () }

///|
fn yy_action_13(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 268|    { () }

///|
fn yy_action_14(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 245|    value=function_arg {
// 246|      [value]
// 247|    }

///|
fn yy_action_15(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslFunctionArgument(value)
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 111|    arrow=ARROW attrs=attributes ty=ARG_TYPE EOF {
// 112|      Some(@ast.WgslFunctionResult(attrs, arrow, ty.end(), Some(ty)))
// 113|    }

///|
fn yy_action_16(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(arrow)
  guard _args[1].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[2].0 is YYObj__ast_WgslTypeRef(ty)
  YYObj__ast_WgslFunctionResult_(
    {
      ()
      Some(@ast.WgslFunctionResult(attrs, arrow, ty.end(), Some(ty)))
    },
  )
}

// file:///./wgsl_parser.mbty
// 117|    "{" "}" EOF { [] }

///|
fn yy_action_17(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 118|    "{" members=struct_member_list optional_member_separator "}" EOF {
// 119|      members
// 120|    }

///|
fn yy_action_18(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslStructMember_(members)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      members
    },
  )
}

// file:///./wgsl_parser.mbty
// 65|    attributes attribute {
// 66|      let attributes = $1
// 67|      attributes.push($2)
// 68|      attributes
// 69|    }

///|
fn yy_action_19(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(_dollar1)
  guard _args[1].0 is YYObj__ast_WgslAttribute(_dollar2)
  YYObj_Array__ast_WgslAttribute_(
    {
      ()
      let attributes = _dollar1
      attributes.push(_dollar2)
      attributes
    },
  )
}

// file:///./wgsl_parser.mbty
// 73|    at=AT name=ATTR_NAME args=attribute_args {
// 74|      let (arguments_ref, args_end) = args
// 75|      let end = match args_end {
// 76|        Some(value) => value
// 77|        None => name.end()
// 78|      }
// 79|      @ast.WgslAttribute(
// 80|        name,
// 81|        at,
// 82|        end,
// 83|        arguments_ref,
// 84|      )
// 85|    }

///|
fn yy_action_20(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(at)
  guard _args[1].0 is YYObj__ast_WgslIdent(name)
  guard _args[2].0 is YYObj___ast_WgslExprRef___Int__(args)
  YYObj__ast_WgslAttribute(
    {
      ()
      let (arguments_ref, args_end) = args
      let end = match args_end {
        Some(value) => value
        None => name.end()
      }
      @ast.WgslAttribute(name, at, end, arguments_ref)
    },
  )
}

// file:///./wgsl_parser.mbty
// 90|    ATTR_ARGS {
// 91|      let (arguments_ref, end) = $1
// 92|      (arguments_ref, Some(end))
// 93|    }

///|
fn yy_action_21(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj___ast_WgslExprRef___Int_(_dollar1)
  YYObj___ast_WgslExprRef___Int__(
    {
      ()
      let (arguments_ref, end) = _dollar1
      (arguments_ref, Some(end))
    },
  )
}

// file:///./wgsl_parser.mbty
// 89|    { (None, None) }

///|
fn yy_action_22(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj___ast_WgslExprRef___Int__(
    {
      ()
      (None, None)
    },
  )
}

// file:///./wgsl_parser.mbty
// 134|    attrs=attributes name=MEMBER_NAME ":" ty=MEMBER_TYPE {
// 135|      let start = if attrs.length() > 0 { attrs[0].start() } else { name.start() }
// 136|      @ast.WgslStructMember(
// 137|        attrs,
// 138|        name,
// 139|        start,
// 140|        ty.end(),
// 141|        Some(ty),
// 142|      )
// 143|    }

///|
fn yy_action_23(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(name)
  guard _args[3].0 is YYObj__ast_WgslTypeRef(ty)
  YYObj__ast_WgslStructMember(
    {
      ()
      let start = if attrs.length() > 0 {
        attrs[0].start()
      } else {
        name.start()
      }
      @ast.WgslStructMember(attrs, name, start, ty.end(), Some(ty))
    },
  )
}

// file:///./wgsl_parser.mbty
// 127|    members=struct_member_list member_separator value=struct_member {
// 128|      members.push(value)
// 129|      members
// 130|    }

///|
fn yy_action_24(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslStructMember_(members)
  guard _args[2].0 is YYObj__ast_WgslStructMember(value)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      members.push(value)
      members
    },
  )
}

// file:///./wgsl_parser.mbty
// 241|    member_separator { () }

///|
fn yy_action_25(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 235|    "," { () }

///|
fn yy_action_26(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 236|    ";" { () }

///|
fn yy_action_27(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 240|    { () }

///|
fn yy_action_28(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 124|    value=struct_member {
// 125|      [value]
// 126|    }

///|
fn yy_action_29(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslStructMember(value)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 64|    { [] }

///|
fn yy_action_30(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslAttribute_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 147|    EOF { (None, None) }

///|
fn yy_action_31(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj___ast_WgslTypeRef____ast_WgslExprRef__(
    {
      ()
      (None, None)
    },
  )
}

// file:///./wgsl_parser.mbty
// 148|    ":" ty=DECL_TYPE init=initializer_opt EOF {
// 149|      (Some(ty), init)
// 150|    }

///|
fn yy_action_32(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__ast_WgslTypeRef(ty)
  guard _args[2].0 is YYObj__ast_WgslExprRef_(init)
  YYObj___ast_WgslTypeRef____ast_WgslExprRef__(
    {
      ()
      (Some(ty), init)
    },
  )
}

// file:///./wgsl_parser.mbty
// 225|    initializer { $1 }

///|
fn yy_action_33(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslExprRef_(_dollar1)
  YYObj__ast_WgslExprRef_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 224|    { None }

///|
fn yy_action_34(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__ast_WgslExprRef_(
    {
      ()
      None
    },
  )
}

// file:///./wgsl_parser.mbty
// 151|    init=initializer EOF {
// 152|      (None, init)
// 153|    }

///|
fn yy_action_35(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslExprRef_(init)
  YYObj___ast_WgslTypeRef____ast_WgslExprRef__(
    {
      ()
      (None, init)
    },
  )
}

// file:///./wgsl_parser.mbty
// 229|    "=" expr=INIT_EXPR {
// 230|      Some(expr)
// 231|    }

///|
fn yy_action_36(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__ast_WgslExprRef(expr)
  YYObj__ast_WgslExprRef_(
    {
      ()
      Some(expr)
    },
  )
}

// file:///./wgsl_parser.mbty
// 157|    "=" ty=DECL_TYPE EOF {
// 158|      ty
// 159|    }

///|
fn yy_action_37(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__ast_WgslTypeRef(ty)
  YYObj__ast_WgslTypeRef(
    {
      ()
      ty
    },
  )
}

// file:///./wgsl_parser.mbty
// 163|    text=SOURCE_TEXT keyword=KW_ENABLE tail=directive_tail EOF {
// 164|      let (tail, raw_tail_start, raw_tail_end) = tail
// 165|      let tail_start = if tail == "" { keyword.end() } else { raw_tail_start }
// 166|      let tail_end = if tail == "" { keyword.end() } else { raw_tail_end }
// 167|      let has_required_separator = tail != "" && tail_start > keyword.end()
// 168|      @ast.WgslDirective(
// 169|        @ast.WgslDirectiveKind::Enable,
// 170|        keyword,
// 171|        @ast.WgslDirectiveTail(
// 172|          tail,
// 173|          tail_start,
// 174|          tail_end,
// 175|          has_required_separator,
// 176|        ),
// 177|        0,
// 178|        text.length(),
// 179|      )
// 180|    }

///|
fn yy_action_38(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(text)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  guard _args[2].0 is YYObj__String__Int__Int_(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      let (tail, raw_tail_start, raw_tail_end) = tail
      let tail_start = if tail == "" { keyword.end() } else { raw_tail_start }
      let tail_end = if tail == "" { keyword.end() } else { raw_tail_end }
      let has_required_separator = tail != "" && tail_start > keyword.end()
      @ast.WgslDirective(
        @ast.WgslDirectiveKind::Enable,
        keyword,
        @ast.WgslDirectiveTail(
          tail, tail_start, tail_end, has_required_separator,
        ),
        0,
        text.length(),
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 181|    text=SOURCE_TEXT keyword=KW_REQUIRES tail=directive_tail EOF {
// 182|      let (tail, raw_tail_start, raw_tail_end) = tail
// 183|      let tail_start = if tail == "" { keyword.end() } else { raw_tail_start }
// 184|      let tail_end = if tail == "" { keyword.end() } else { raw_tail_end }
// 185|      let has_required_separator = tail != "" && tail_start > keyword.end()
// 186|      @ast.WgslDirective(
// 187|        @ast.WgslDirectiveKind::Requires,
// 188|        keyword,
// 189|        @ast.WgslDirectiveTail(
// 190|          tail,
// 191|          tail_start,
// 192|          tail_end,
// 193|          has_required_separator,
// 194|        ),
// 195|        0,
// 196|        text.length(),
// 197|      )
// 198|    }

///|
fn yy_action_39(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(text)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  guard _args[2].0 is YYObj__String__Int__Int_(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      let (tail, raw_tail_start, raw_tail_end) = tail
      let tail_start = if tail == "" { keyword.end() } else { raw_tail_start }
      let tail_end = if tail == "" { keyword.end() } else { raw_tail_end }
      let has_required_separator = tail != "" && tail_start > keyword.end()
      @ast.WgslDirective(
        @ast.WgslDirectiveKind::Requires,
        keyword,
        @ast.WgslDirectiveTail(
          tail, tail_start, tail_end, has_required_separator,
        ),
        0,
        text.length(),
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 98|    DIRECTIVE_TAIL { $1 }

///|
fn yy_action_40(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String__Int__Int_(_dollar1)
  YYObj__String__Int__Int_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 199|    text=SOURCE_TEXT keyword=KW_DIAGNOSTIC tail=directive_tail EOF {
// 200|      let (tail, raw_tail_start, raw_tail_end) = tail
// 201|      let tail_start = if tail == "" { keyword.end() } else { raw_tail_start }
// 202|      let tail_end = if tail == "" { keyword.end() } else { raw_tail_end }
// 203|      let has_required_separator = tail != "" && tail_start > keyword.end()
// 204|      @ast.WgslDirective(
// 205|        @ast.WgslDirectiveKind::Diagnostic,
// 206|        keyword,
// 207|        @ast.WgslDirectiveTail(
// 208|          tail,
// 209|          tail_start,
// 210|          tail_end,
// 211|          has_required_separator,
// 212|        ),
// 213|        0,
// 214|        text.length(),
// 215|      )
// 216|    }

///|
fn yy_action_41(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(text)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  guard _args[2].0 is YYObj__String__Int__Int_(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      let (tail, raw_tail_start, raw_tail_end) = tail
      let tail_start = if tail == "" { keyword.end() } else { raw_tail_start }
      let tail_end = if tail == "" { keyword.end() } else { raw_tail_end }
      let has_required_separator = tail != "" && tail_start > keyword.end()
      @ast.WgslDirective(
        @ast.WgslDirectiveKind::Diagnostic,
        keyword,
        @ast.WgslDirectiveTail(
          tail, tail_start, tail_end, has_required_separator,
        ),
        0,
        text.length(),
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 97|    { ("", 0, 0) }

///|
fn yy_action_42(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__String__Int__Int_(
    {
      ()
      ("", 0, 0)
    },
  )
}

// file:///./wgsl_parser.mbty
// 220|    EXPR_REF EOF { $1 }

///|
fn yy_action_43(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslExprRef(_dollar1)
  YYObj__ast_WgslExprRef(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 49|    open=LBRACE statements close=RBRACE EOF {
// 50|      @ast.WgslBlock(open, close + 1, $2)
// 51|    }

///|
fn yy_action_44(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(open)
  guard _args[2].0 is YYObj_Int(close)
  guard _args[1].0 is YYObj_Array__ast_WgslStatement_(_dollar2)
  YYObj__ast_WgslBlock(
    {
      ()
      @ast.WgslBlock(open, close + 1, _dollar2)
    },
  )
}

// file:///./wgsl_parser.mbty
// 56|    statements STMT {
// 57|      let statements = $1
// 58|      statements.push($2)
// 59|      statements
// 60|    }

///|
fn yy_action_45(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslStatement_(_dollar1)
  guard _args[1].0 is YYObj__ast_WgslStatement(_dollar2)
  YYObj_Array__ast_WgslStatement_(
    {
      ()
      let statements = _dollar1
      statements.push(_dollar2)
      statements
    },
  )
}

// file:///./wgsl_parser.mbty
// 55|    { [] }

///|
fn yy_action_46(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslStatement_(
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
    STMT(data) => (T_STMT, YYObj__ast_WgslStatement(data))
    TYPE_ATOM(data) => (T_TYPE_ATOM, YYObj__ast_WgslTypeAtom(data))
    TYPE_ARGS(data) =>
      (T_TYPE_ARGS, YYObj__Array__ast_WgslTypeArgument___Int_(data))
    ARG_NAME(data) => (T_ARG_NAME, YYObj__ast_WgslIdent(data))
    ARG_TYPE(data) => (T_ARG_TYPE, YYObj__ast_WgslTypeRef(data))
    MEMBER_NAME(data) => (T_MEMBER_NAME, YYObj__ast_WgslIdent(data))
    MEMBER_TYPE(data) => (T_MEMBER_TYPE, YYObj__ast_WgslTypeRef(data))
    DECL_TYPE(data) => (T_DECL_TYPE, YYObj__ast_WgslTypeRef(data))
    INIT_EXPR(data) => (T_INIT_EXPR, YYObj__ast_WgslExprRef(data))
    EXPR_REF(data) => (T_EXPR_REF, YYObj__ast_WgslExprRef(data))
    AT(data) => (T_AT, YYObj_Int(data))
    ATTR_NAME(data) => (T_ATTR_NAME, YYObj__ast_WgslIdent(data))
    ATTR_ARGS(data) => (T_ATTR_ARGS, YYObj___ast_WgslExprRef___Int_(data))
    KW_ENABLE(data) => (T_KW_ENABLE, YYObj__ast_WgslIdent(data))
    KW_REQUIRES(data) => (T_KW_REQUIRES, YYObj__ast_WgslIdent(data))
    KW_DIAGNOSTIC(data) => (T_KW_DIAGNOSTIC, YYObj__ast_WgslIdent(data))
    DIRECTIVE_TAIL(data) => (T_DIRECTIVE_TAIL, YYObj__String__Int__Int_(data))
    SOURCE_TEXT(data) => (T_SOURCE_TEXT, YYObj_String(data))
    ARROW(data) => (T_ARROW, YYObj_Int(data))
    LPAREN => (T_LPAREN, YYObj_Void)
    RPAREN => (T_RPAREN, YYObj_Void)
    LBRACE(data) => (T_LBRACE, YYObj_Int(data))
    RBRACE(data) => (T_RBRACE, YYObj_Int(data))
    COLON => (T_COLON, YYObj_Void)
    EQUAL => (T_EQUAL, YYObj_Void)
    TYPE_LT(data) => (T_TYPE_LT, YYObj_Int(data))
    TYPE_GT(data) => (T_TYPE_GT, YYObj_Int(data))
    COMMA => (T_COMMA, YYObj_Void)
    SEMI => (T_SEMI, YYObj_Void)
    EOF => (T_EOF, YYObj_Void)
  }
}

// [0, block → • LBRACE statements RBRACE EOF, $]
// [56, block_prime → • block, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_block => Shift(yy_state_1)
    T_LBRACE => Shift(yy_state_2)
    _ => Error
  }
}

// [56, block_prime → block •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [0, block → LBRACE • statements RBRACE EOF, $]
// [1, statements → •, STMT / RBRACE]
// [2, statements → • statements STMT, STMT / RBRACE]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_statements => Shift(yy_state_3)
    T_STMT | T_RBRACE => Reduce(0, NT_statements, yy_action_46)
    _ => Error
  }
}

// [0, block → LBRACE statements • RBRACE EOF, $]
// [2, statements → statements • STMT, STMT / RBRACE]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STMT => Shift(yy_state_4)
    T_RBRACE => Shift(yy_state_5)
    _ => Error
  }
}

// [2, statements → statements STMT •, STMT / RBRACE]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_statements, yy_action_45)
}

// [0, block → LBRACE statements RBRACE • EOF, $]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_6)
    _ => Error
  }
}

// [0, block → LBRACE statements RBRACE EOF •, $]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_block, yy_action_44)
}

// [26, const_assert_expr → • EXPR_REF EOF, $]
// [55, const_assert_expr_prime → • const_assert_expr, $]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_const_assert_expr => Shift(yy_state_8)
    T_EXPR_REF => Shift(yy_state_9)
    _ => Error
  }
}

// [55, const_assert_expr_prime → const_assert_expr •, $]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [26, const_assert_expr → EXPR_REF • EOF, $]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_10)
    _ => Error
  }
}

// [26, const_assert_expr → EXPR_REF EOF •, $]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_const_assert_expr, yy_action_43)
}

// [23, source_directive → • SOURCE_TEXT KW_ENABLE directive_tail EOF, $]
// [24, source_directive → • SOURCE_TEXT KW_REQUIRES directive_tail EOF, $]
// [25, source_directive → • SOURCE_TEXT KW_DIAGNOSTIC directive_tail EOF, $]
// [54, source_directive_prime → • source_directive, $]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_source_directive => Shift(yy_state_12)
    T_SOURCE_TEXT => Shift(yy_state_13)
    _ => Error
  }
}

// [54, source_directive_prime → source_directive •, $]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [23, source_directive → SOURCE_TEXT • KW_ENABLE directive_tail EOF, $]
// [24, source_directive → SOURCE_TEXT • KW_REQUIRES directive_tail EOF, $]
// [25, source_directive → SOURCE_TEXT • KW_DIAGNOSTIC directive_tail EOF, $]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KW_DIAGNOSTIC => Shift(yy_state_14)
    T_KW_REQUIRES => Shift(yy_state_18)
    T_KW_ENABLE => Shift(yy_state_21)
    _ => Error
  }
}

// [8, directive_tail → •, EOF]
// [9, directive_tail → • DIRECTIVE_TAIL, EOF]
// [25, source_directive → SOURCE_TEXT KW_DIAGNOSTIC • directive_tail EOF, $]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_tail => Shift(yy_state_15)
    T_DIRECTIVE_TAIL => Shift(yy_state_17)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_42)
    _ => Error
  }
}

// [25, source_directive → SOURCE_TEXT KW_DIAGNOSTIC directive_tail • EOF, $]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_16)
    _ => Error
  }
}

// [25, source_directive → SOURCE_TEXT KW_DIAGNOSTIC directive_tail EOF •, $]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_41)
}

// [9, directive_tail → DIRECTIVE_TAIL •, EOF]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_directive_tail, yy_action_40)
}

// [8, directive_tail → •, EOF]
// [9, directive_tail → • DIRECTIVE_TAIL, EOF]
// [24, source_directive → SOURCE_TEXT KW_REQUIRES • directive_tail EOF, $]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_17)
    NT_directive_tail => Shift(yy_state_19)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_42)
    _ => Error
  }
}

// [24, source_directive → SOURCE_TEXT KW_REQUIRES directive_tail • EOF, $]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_20)
    _ => Error
  }
}

// [24, source_directive → SOURCE_TEXT KW_REQUIRES directive_tail EOF •, $]

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_39)
}

// [8, directive_tail → •, EOF]
// [9, directive_tail → • DIRECTIVE_TAIL, EOF]
// [23, source_directive → SOURCE_TEXT KW_ENABLE • directive_tail EOF, $]

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_17)
    NT_directive_tail => Shift(yy_state_22)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_42)
    _ => Error
  }
}

// [23, source_directive → SOURCE_TEXT KW_ENABLE directive_tail • EOF, $]

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_23)
    _ => Error
  }
}

// [23, source_directive → SOURCE_TEXT KW_ENABLE directive_tail EOF •, $]

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_38)
}

// [22, type_alias_tail → • EQUAL DECL_TYPE EOF, $]
// [53, type_alias_tail_prime → • type_alias_tail, $]

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_alias_tail => Shift(yy_state_25)
    T_EQUAL => Shift(yy_state_26)
    _ => Error
  }
}

// [53, type_alias_tail_prime → type_alias_tail •, $]

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [22, type_alias_tail → EQUAL • DECL_TYPE EOF, $]

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_TYPE => Shift(yy_state_27)
    _ => Error
  }
}

// [22, type_alias_tail → EQUAL DECL_TYPE • EOF, $]

///|
fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_28)
    _ => Error
  }
}

// [22, type_alias_tail → EQUAL DECL_TYPE EOF •, $]

///|
fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_alias_tail, yy_action_37)
}

// [19, typed_initializer_tail → • EOF, $]
// [20, typed_initializer_tail → • COLON DECL_TYPE initializer_opt EOF, $]
// [21, typed_initializer_tail → • initializer EOF, $]
// [29, initializer → • EQUAL INIT_EXPR, EOF]
// [52, typed_initializer_tail_prime → • typed_initializer_tail, $]

///|
fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_typed_initializer_tail => Shift(yy_state_30)
    T_EQUAL => Shift(yy_state_31)
    NT_initializer => Shift(yy_state_33)
    T_COLON => Shift(yy_state_35)
    T_EOF => Shift(yy_state_40)
    _ => Error
  }
}

// [52, typed_initializer_tail_prime → typed_initializer_tail •, $]

///|
fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [29, initializer → EQUAL • INIT_EXPR, EOF]

///|
fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INIT_EXPR => Shift(yy_state_32)
    _ => Error
  }
}

// [29, initializer → EQUAL INIT_EXPR •, EOF]

///|
fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_initializer, yy_action_36)
}

// [21, typed_initializer_tail → initializer • EOF, $]

///|
fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_34)
    _ => Error
  }
}

// [21, typed_initializer_tail → initializer EOF •, $]

///|
fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_typed_initializer_tail, yy_action_35)
}

// [20, typed_initializer_tail → COLON • DECL_TYPE initializer_opt EOF, $]

///|
fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_TYPE => Shift(yy_state_36)
    _ => Error
  }
}

// [20, typed_initializer_tail → COLON DECL_TYPE • initializer_opt EOF, $]
// [27, initializer_opt → •, EOF]
// [28, initializer_opt → • initializer, EOF]
// [29, initializer → • EQUAL INIT_EXPR, EOF]

///|
fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_31)
    NT_initializer => Shift(yy_state_37)
    NT_initializer_opt => Shift(yy_state_38)
    T_EOF => Reduce(0, NT_initializer_opt, yy_action_34)
    _ => Error
  }
}

// [28, initializer_opt → initializer •, EOF]

///|
fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_initializer_opt, yy_action_33)
}

// [20, typed_initializer_tail → COLON DECL_TYPE initializer_opt • EOF, $]

///|
fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_39)
    _ => Error
  }
}

// [20, typed_initializer_tail → COLON DECL_TYPE initializer_opt EOF •, $]

///|
fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_typed_initializer_tail, yy_action_32)
}

// [19, typed_initializer_tail → EOF •, $]

///|
fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_typed_initializer_tail, yy_action_31)
}

// [14, struct_members → • LBRACE RBRACE EOF, $]
// [15, struct_members → • LBRACE struct_member_list optional_member_separator RBRACE EOF, $]
// [51, struct_members_prime → • struct_members, $]

///|
fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_42)
    T_LBRACE => Shift(yy_state_43)
    _ => Error
  }
}

// [51, struct_members_prime → struct_members •, $]

///|
fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [3, attributes → •, MEMBER_NAME / AT]
// [4, attributes → • attributes attribute, MEMBER_NAME / AT]
// [14, struct_members → LBRACE • RBRACE EOF, $]
// [15, struct_members → LBRACE • struct_member_list optional_member_separator RBRACE EOF, $]
// [16, struct_member_list → • struct_member, RBRACE / COMMA / SEMI]
// [17, struct_member_list → • struct_member_list member_separator struct_member, RBRACE / COMMA / SEMI]
// [18, struct_member → • attributes MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_member => Shift(yy_state_44)
    NT_struct_member_list => Shift(yy_state_45)
    NT_attributes => Shift(yy_state_50)
    T_RBRACE => Shift(yy_state_62)
    T_MEMBER_NAME | T_AT => Reduce(0, NT_attributes, yy_action_30)
    _ => Error
  }
}

// [16, struct_member_list → struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member_list, yy_action_29)
}

// [15, struct_members → LBRACE struct_member_list • optional_member_separator RBRACE EOF, $]
// [17, struct_member_list → struct_member_list • member_separator struct_member, RBRACE / COMMA / SEMI]
// [30, member_separator → • COMMA, MEMBER_NAME / AT / RBRACE]
// [31, member_separator → • SEMI, MEMBER_NAME / AT / RBRACE]
// [32, optional_member_separator → •, RBRACE]
// [33, optional_member_separator → • member_separator, RBRACE]

///|
fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_46)
    T_COMMA => Shift(yy_state_47)
    NT_member_separator => Shift(yy_state_48)
    NT_optional_member_separator => Shift(yy_state_59)
    T_RBRACE => Reduce(0, NT_optional_member_separator, yy_action_28)
    _ => Error
  }
}

// [31, member_separator → SEMI •, MEMBER_NAME / AT / RBRACE]

///|
fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_27)
}

// [30, member_separator → COMMA •, MEMBER_NAME / AT / RBRACE]

///|
fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_26)
}

// [3, attributes → •, MEMBER_NAME / AT]
// [4, attributes → • attributes attribute, MEMBER_NAME / AT]
// [17, struct_member_list → struct_member_list member_separator • struct_member, RBRACE / COMMA / SEMI]
// [18, struct_member → • attributes MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]
// [33, optional_member_separator → member_separator •, RBRACE]

///|
fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_member => Shift(yy_state_49)
    NT_attributes => Shift(yy_state_50)
    T_MEMBER_NAME | T_AT => Reduce(0, NT_attributes, yy_action_30)
    T_RBRACE => Reduce(1, NT_optional_member_separator, yy_action_25)
    _ => Error
  }
}

// [17, struct_member_list → struct_member_list member_separator struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_member_list, yy_action_24)
}

// [4, attributes → attributes • attribute, MEMBER_NAME / AT]
// [5, attribute → • AT ATTR_NAME attribute_args, MEMBER_NAME / AT]
// [18, struct_member → attributes • MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_NAME => Shift(yy_state_51)
    T_AT => Shift(yy_state_54)
    NT_attribute => Shift(yy_state_58)
    _ => Error
  }
}

// [18, struct_member → attributes MEMBER_NAME • COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_52)
    _ => Error
  }
}

// [18, struct_member → attributes MEMBER_NAME COLON • MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_TYPE => Shift(yy_state_53)
    _ => Error
  }
}

// [18, struct_member → attributes MEMBER_NAME COLON MEMBER_TYPE •, RBRACE / COMMA / SEMI]

///|
fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_struct_member, yy_action_23)
}

// [5, attribute → AT • ATTR_NAME attribute_args, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT]

///|
fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ATTR_NAME => Shift(yy_state_55)
    _ => Error
  }
}

// [5, attribute → AT ATTR_NAME • attribute_args, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT]
// [6, attribute_args → •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT]
// [7, attribute_args → • ATTR_ARGS, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT]

///|
fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ATTR_ARGS => Shift(yy_state_56)
    NT_attribute_args => Shift(yy_state_57)
    T_ARG_NAME | T_ARG_TYPE | T_MEMBER_NAME | T_AT =>
      Reduce(0, NT_attribute_args, yy_action_22)
    _ => Error
  }
}

// [7, attribute_args → ATTR_ARGS •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT]

///|
fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_attribute_args, yy_action_21)
}

// [5, attribute → AT ATTR_NAME attribute_args •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT]

///|
fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_attribute, yy_action_20)
}

// [4, attributes → attributes attribute •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT]

///|
fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_attributes, yy_action_19)
}

// [15, struct_members → LBRACE struct_member_list optional_member_separator • RBRACE EOF, $]

///|
fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_60)
    _ => Error
  }
}

// [15, struct_members → LBRACE struct_member_list optional_member_separator RBRACE • EOF, $]

///|
fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_61)
    _ => Error
  }
}

// [15, struct_members → LBRACE struct_member_list optional_member_separator RBRACE EOF •, $]

///|
fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_members, yy_action_18)
}

// [14, struct_members → LBRACE RBRACE • EOF, $]

///|
fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_63)
    _ => Error
  }
}

// [14, struct_members → LBRACE RBRACE EOF •, $]

///|
fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_members, yy_action_17)
}

// [13, function_result → • ARROW attributes ARG_TYPE EOF, $]
// [50, function_result_prime → • function_result, $]

///|
fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_result => Shift(yy_state_65)
    T_ARROW => Shift(yy_state_66)
    _ => Error
  }
}

// [50, function_result_prime → function_result •, $]

///|
fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [3, attributes → •, ARG_TYPE / AT]
// [4, attributes → • attributes attribute, ARG_TYPE / AT]
// [13, function_result → ARROW • attributes ARG_TYPE EOF, $]

///|
fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attributes => Shift(yy_state_67)
    T_ARG_TYPE | T_AT => Reduce(0, NT_attributes, yy_action_30)
    _ => Error
  }
}

// [4, attributes → attributes • attribute, ARG_TYPE / AT]
// [5, attribute → • AT ATTR_NAME attribute_args, ARG_TYPE / AT]
// [13, function_result → ARROW attributes • ARG_TYPE EOF, $]

///|
fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_54)
    NT_attribute => Shift(yy_state_58)
    T_ARG_TYPE => Shift(yy_state_68)
    _ => Error
  }
}

// [13, function_result → ARROW attributes ARG_TYPE • EOF, $]

///|
fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_69)
    _ => Error
  }
}

// [13, function_result → ARROW attributes ARG_TYPE EOF •, $]

///|
fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_result, yy_action_16)
}

// [11, function_args → • LPAREN RPAREN EOF, $]
// [12, function_args → • LPAREN function_arg_list optional_comma RPAREN EOF, $]
// [49, function_args_prime → • function_args, $]

///|
fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_args => Shift(yy_state_71)
    T_LPAREN => Shift(yy_state_72)
    _ => Error
  }
}

// [49, function_args_prime → function_args •, $]

///|
fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [3, attributes → •, ARG_NAME / AT]
// [4, attributes → • attributes attribute, ARG_NAME / AT]
// [11, function_args → LPAREN • RPAREN EOF, $]
// [12, function_args → LPAREN • function_arg_list optional_comma RPAREN EOF, $]
// [34, function_arg_list → • function_arg, RPAREN / COMMA]
// [35, function_arg_list → • function_arg_list COMMA function_arg, RPAREN / COMMA]
// [36, function_arg → • attributes ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_arg => Shift(yy_state_73)
    NT_function_arg_list => Shift(yy_state_74)
    NT_attributes => Shift(yy_state_77)
    T_RPAREN => Shift(yy_state_84)
    T_ARG_NAME | T_AT => Reduce(0, NT_attributes, yy_action_30)
    _ => Error
  }
}

// [34, function_arg_list → function_arg •, RPAREN / COMMA]

///|
fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_arg_list, yy_action_15)
}

// [12, function_args → LPAREN function_arg_list • optional_comma RPAREN EOF, $]
// [35, function_arg_list → function_arg_list • COMMA function_arg, RPAREN / COMMA]
// [37, optional_comma → •, RPAREN]
// [38, optional_comma → • COMMA, RPAREN]

///|
fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_75)
    NT_optional_comma => Shift(yy_state_81)
    T_RPAREN => Reduce(0, NT_optional_comma, yy_action_14)
    _ => Error
  }
}

// [3, attributes → •, ARG_NAME / AT]
// [4, attributes → • attributes attribute, ARG_NAME / AT]
// [35, function_arg_list → function_arg_list COMMA • function_arg, RPAREN / COMMA]
// [36, function_arg → • attributes ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]
// [38, optional_comma → COMMA •, RPAREN]

///|
fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_arg => Shift(yy_state_76)
    NT_attributes => Shift(yy_state_77)
    T_ARG_NAME | T_AT => Reduce(0, NT_attributes, yy_action_30)
    T_RPAREN => Reduce(1, NT_optional_comma, yy_action_13)
    _ => Error
  }
}

// [35, function_arg_list → function_arg_list COMMA function_arg •, RPAREN / COMMA]

///|
fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_arg_list, yy_action_12)
}

// [4, attributes → attributes • attribute, ARG_NAME / AT]
// [5, attribute → • AT ATTR_NAME attribute_args, ARG_NAME / AT]
// [36, function_arg → attributes • ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_54)
    NT_attribute => Shift(yy_state_58)
    T_ARG_NAME => Shift(yy_state_78)
    _ => Error
  }
}

// [36, function_arg → attributes ARG_NAME • COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_79)
    _ => Error
  }
}

// [36, function_arg → attributes ARG_NAME COLON • ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_TYPE => Shift(yy_state_80)
    _ => Error
  }
}

// [36, function_arg → attributes ARG_NAME COLON ARG_TYPE •, RPAREN / COMMA]

///|
fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_arg, yy_action_11)
}

// [12, function_args → LPAREN function_arg_list optional_comma • RPAREN EOF, $]

///|
fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_82)
    _ => Error
  }
}

// [12, function_args → LPAREN function_arg_list optional_comma RPAREN • EOF, $]

///|
fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_83)
    _ => Error
  }
}

// [12, function_args → LPAREN function_arg_list optional_comma RPAREN EOF •, $]

///|
fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_args, yy_action_10)
}

// [11, function_args → LPAREN RPAREN • EOF, $]

///|
fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_85)
    _ => Error
  }
}

// [11, function_args → LPAREN RPAREN EOF •, $]

///|
fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_args, yy_action_9)
}

// [39, template_list → • TYPE_LT template_args TYPE_GT EOF, $]
// [48, template_list_prime → • template_list, $]

///|
fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_template_list => Shift(yy_state_87)
    T_TYPE_LT => Shift(yy_state_88)
    _ => Error
  }
}

// [48, template_list_prime → template_list •, $]

///|
fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [39, template_list → TYPE_LT • template_args TYPE_GT EOF, $]
// [40, template_args → • type_expr, TYPE_GT / COMMA]
// [41, template_args → • template_args COMMA type_expr, TYPE_GT / COMMA]
// [42, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [43, type_expr → • TYPE_ATOM TYPE_ARGS, TYPE_GT / COMMA]
// [44, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_97)
    NT_template_args => Shift(yy_state_98)
    _ => Error
  }
}

// [42, type_expr → TYPE_ATOM •, TYPE_GT / COMMA / EOF]
// [43, type_expr → TYPE_ATOM • TYPE_ARGS, TYPE_GT / COMMA / EOF]
// [44, type_expr → TYPE_ATOM • TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]

///|
fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_LT => Shift(yy_state_90)
    T_TYPE_ARGS => Shift(yy_state_96)
    T_TYPE_GT | T_COMMA | T_EOF => Reduce(1, NT_type_expr, yy_action_8)
    _ => Error
  }
}

// [42, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [43, type_expr → • TYPE_ATOM TYPE_ARGS, TYPE_GT / COMMA]
// [44, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [44, type_expr → TYPE_ATOM TYPE_LT • type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]
// [45, type_ref_args → • type_expr, TYPE_GT / COMMA]
// [46, type_ref_args → • type_ref_args COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_91)
    NT_type_ref_args => Shift(yy_state_92)
    _ => Error
  }
}

// [45, type_ref_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_ref_args, yy_action_7)
}

// [44, type_expr → TYPE_ATOM TYPE_LT type_ref_args • TYPE_GT, TYPE_GT / COMMA / EOF]
// [46, type_ref_args → type_ref_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_93)
    T_TYPE_GT => Shift(yy_state_95)
    _ => Error
  }
}

// [42, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [43, type_expr → • TYPE_ATOM TYPE_ARGS, TYPE_GT / COMMA]
// [44, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [46, type_ref_args → type_ref_args COMMA • type_expr, TYPE_GT / COMMA]

///|
fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_94)
    _ => Error
  }
}

// [46, type_ref_args → type_ref_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_ref_args, yy_action_6)
}

// [44, type_expr → TYPE_ATOM TYPE_LT type_ref_args TYPE_GT •, TYPE_GT / COMMA / EOF]

///|
fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_expr, yy_action_5)
}

// [43, type_expr → TYPE_ATOM TYPE_ARGS •, TYPE_GT / COMMA / EOF]

///|
fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_expr, yy_action_4)
}

// [40, template_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_template_args, yy_action_3)
}

// [39, template_list → TYPE_LT template_args • TYPE_GT EOF, $]
// [41, template_args → template_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_99)
    T_TYPE_GT => Shift(yy_state_101)
    _ => Error
  }
}

// [41, template_args → template_args COMMA • type_expr, TYPE_GT / COMMA]
// [42, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [43, type_expr → • TYPE_ATOM TYPE_ARGS, TYPE_GT / COMMA]
// [44, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_100)
    _ => Error
  }
}

// [41, template_args → template_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_template_args, yy_action_2)
}

// [39, template_list → TYPE_LT template_args TYPE_GT • EOF, $]

///|
fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_102)
    _ => Error
  }
}

// [39, template_list → TYPE_LT template_args TYPE_GT EOF •, $]

///|
fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_template_list, yy_action_1)
}

// [10, type_ref → • type_expr EOF, $]
// [42, type_expr → • TYPE_ATOM, EOF]
// [43, type_expr → • TYPE_ATOM TYPE_ARGS, EOF]
// [44, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, EOF]
// [47, type_ref_prime → • type_ref, $]

///|
fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_ref => Shift(yy_state_104)
    NT_type_expr => Shift(yy_state_105)
    _ => Error
  }
}

// [47, type_ref_prime → type_ref •, $]

///|
fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [10, type_ref → type_expr • EOF, $]

///|
fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_106)
    _ => Error
  }
}

// [10, type_ref → type_expr EOF •, $]

///|
fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_ref, yy_action_0)
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
        (T_STMT, TK_STMT),
        (T_TYPE_ATOM, TK_TYPE_ATOM),
        (T_TYPE_ARGS, TK_TYPE_ARGS),
        (T_ARG_NAME, TK_ARG_NAME),
        (T_ARG_TYPE, TK_ARG_TYPE),
        (T_MEMBER_NAME, TK_MEMBER_NAME),
        (T_MEMBER_TYPE, TK_MEMBER_TYPE),
        (T_DECL_TYPE, TK_DECL_TYPE),
        (T_INIT_EXPR, TK_INIT_EXPR),
        (T_EXPR_REF, TK_EXPR_REF),
        (T_AT, TK_AT),
        (T_ATTR_NAME, TK_ATTR_NAME),
        (T_ATTR_ARGS, TK_ATTR_ARGS),
        (T_KW_ENABLE, TK_KW_ENABLE),
        (T_KW_REQUIRES, TK_KW_REQUIRES),
        (T_KW_DIAGNOSTIC, TK_KW_DIAGNOSTIC),
        (T_DIRECTIVE_TAIL, TK_DIRECTIVE_TAIL),
        (T_SOURCE_TEXT, TK_SOURCE_TEXT),
        (T_ARROW, TK_ARROW),
        (T_LPAREN, TK_LPAREN),
        (T_RPAREN, TK_RPAREN),
        (T_LBRACE, TK_LBRACE),
        (T_RBRACE, TK_RBRACE),
        (T_COLON, TK_COLON),
        (T_EQUAL, TK_EQUAL),
        (T_TYPE_LT, TK_TYPE_LT),
        (T_TYPE_GT, TK_TYPE_GT),
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
pub fn type_ref(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslTypeRef raise ParseError {
  yy_parse(
    tokens,
    yy_state_103,
    it => {
      guard it is YYObj__ast_WgslTypeRef(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn template_list(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[@ast.WgslTypeRef] raise ParseError {
  yy_parse(
    tokens,
    yy_state_86,
    it => {
      guard it is YYObj_Array__ast_WgslTypeRef_(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn function_args(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[@ast.WgslFunctionArgument] raise ParseError {
  yy_parse(
    tokens,
    yy_state_70,
    it => {
      guard it is YYObj_Array__ast_WgslFunctionArgument_(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn function_result(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslFunctionResult? raise ParseError {
  yy_parse(
    tokens,
    yy_state_64,
    it => {
      guard it is YYObj__ast_WgslFunctionResult_(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn struct_members(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[@ast.WgslStructMember] raise ParseError {
  yy_parse(
    tokens,
    yy_state_41,
    it => {
      guard it is YYObj_Array__ast_WgslStructMember_(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn typed_initializer_tail(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> (@ast.WgslTypeRef?, @ast.WgslExprRef?) raise ParseError {
  yy_parse(
    tokens,
    yy_state_29,
    it => {
      guard it is YYObj___ast_WgslTypeRef____ast_WgslExprRef__(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn type_alias_tail(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslTypeRef raise ParseError {
  yy_parse(
    tokens,
    yy_state_24,
    it => {
      guard it is YYObj__ast_WgslTypeRef(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn source_directive(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslDirective raise ParseError {
  yy_parse(
    tokens,
    yy_state_11,
    it => {
      guard it is YYObj__ast_WgslDirective(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn const_assert_expr(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslExprRef raise ParseError {
  yy_parse(
    tokens,
    yy_state_7,
    it => {
      guard it is YYObj__ast_WgslExprRef(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn block(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslBlock raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj__ast_WgslBlock(result)
      result
    },
    initial_pos?,
  )
}

///|
fn wgsl_type_ref_from_atom(
  atom : @ast.WgslTypeAtom,
  arguments : Array[@ast.WgslTypeRef],
  end_ : Int,
) -> @ast.WgslTypeRef {
  @ast.WgslTypeRef(atom, arguments, atom.start(), end_.max(atom.end()))
}

///|
fn wgsl_type_ref_from_template_arguments(
  atom : @ast.WgslTypeAtom,
  args : (Array[@ast.WgslTypeArgument], Int),
) -> @ast.WgslTypeRef {
  let (arguments, end_) = args
  @ast.WgslTypeRef::new_with_template_arguments(
    atom,
    arguments,
    atom.start(),
    end_,
  )
}
