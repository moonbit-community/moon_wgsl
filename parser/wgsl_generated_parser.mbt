///|
priv enum Token {
  ITEM(WgslRawTopLevelItem)
  STMT(@ast.WgslStatement)
  TYPE_ATOM(@ast.WgslTypeAtom)
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
  KW_VIRTUAL(@ast.WgslIdent)
  KW_OVERRIDE(@ast.WgslIdent)
  KW_FN(@ast.WgslIdent)
  KW_VAR(@ast.WgslIdent)
  KW_STRUCT(@ast.WgslIdent)
  KW_CONST(@ast.WgslIdent)
  KW_CONST_ASSERT(@ast.WgslIdent)
  KW_ALIAS(@ast.WgslIdent)
  KW_TYPE(@ast.WgslIdent)
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
priv enum TokenKind {
  TK_ITEM
  TK_STMT
  TK_TYPE_ATOM
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
  TK_KW_VIRTUAL
  TK_KW_OVERRIDE
  TK_KW_FN
  TK_KW_VAR
  TK_KW_STRUCT
  TK_KW_CONST
  TK_KW_CONST_ASSERT
  TK_KW_ALIAS
  TK_KW_TYPE
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
impl Debug for TokenKind with to_repr(self) {
  match self {
    TK_ITEM => to_repr("ITEM")
    TK_STMT => to_repr("STMT")
    TK_TYPE_ATOM => to_repr("TYPE_ATOM")
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
    TK_KW_VIRTUAL => to_repr("KW_VIRTUAL")
    TK_KW_OVERRIDE => to_repr("KW_OVERRIDE")
    TK_KW_FN => to_repr("KW_FN")
    TK_KW_VAR => to_repr("KW_VAR")
    TK_KW_STRUCT => to_repr("KW_STRUCT")
    TK_KW_CONST => to_repr("KW_CONST")
    TK_KW_CONST_ASSERT => to_repr("KW_CONST_ASSERT")
    TK_KW_ALIAS => to_repr("KW_ALIAS")
    TK_KW_TYPE => to_repr("KW_TYPE")
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
priv suberror ParseError {
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
priv suberror YYObj_Array_WgslRawTopLevelItem_ {
  YYObj_Array_WgslRawTopLevelItem_(Array[WgslRawTopLevelItem])
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
priv suberror YYObj_WgslDeclHead {
  YYObj_WgslDeclHead(WgslDeclHead)
}

///|
priv suberror YYObj_WgslRawTopLevelItem {
  YYObj_WgslRawTopLevelItem(WgslRawTopLevelItem)
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
  T_ITEM
  T_STMT
  T_TYPE_ATOM
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
  T_KW_VIRTUAL
  T_KW_OVERRIDE
  T_KW_FN
  T_KW_VAR
  T_KW_STRUCT
  T_KW_CONST
  T_KW_CONST_ASSERT
  T_KW_ALIAS
  T_KW_TYPE
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
  NT_raw_top_level_items
  NT_block
  NT_statements
  NT_attributes
  NT_attribute
  NT_attribute_args
  NT_items
  NT_directive_tail
  NT_decl_head
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
// 60|    items EOF { $1 }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_WgslRawTopLevelItem_(_dollar1)
  YYObj_Array_WgslRawTopLevelItem_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 113|    items ITEM {
// 114|      let items = $1
// 115|      items.push($2)
// 116|      items
// 117|    }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_WgslRawTopLevelItem_(_dollar1)
  guard _args[1].0 is YYObj_WgslRawTopLevelItem(_dollar2)
  YYObj_Array_WgslRawTopLevelItem_(
    {
      ()
      let items = _dollar1
      items.push(_dollar2)
      items
    },
  )
}

// file:///./wgsl_parser.mbty
// 112|    { [] }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array_WgslRawTopLevelItem_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 126|    attrs=attributes KW_VIRTUAL fn_kw=KW_FN EOF {
// 127|      WgslDeclHead::{
// 128|        kind: WgslDeclHeadKind::Function,
// 129|        attributes: attrs,
// 130|        keyword: Some(fn_kw),
// 131|        qualifier: Some(@ast.WgslFunctionQualifier::Virtual),
// 132|        qualifier_start: Some($2.start()),
// 133|        qualifier_end: Some($2.end()),
// 134|        fn_keyword: Some(fn_kw),
// 135|        consumed: 2,
// 136|      }
// 137|    }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[2].0 is YYObj__ast_WgslIdent(fn_kw)
  guard _args[1].0 is YYObj__ast_WgslIdent(_dollar2)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::Function,
        attributes: attrs,
        keyword: Some(fn_kw),
        qualifier: Some(@ast.WgslFunctionQualifier::Virtual),
        qualifier_start: Some(_dollar2.start()),
        qualifier_end: Some(_dollar2.end()),
        fn_keyword: Some(fn_kw),
        consumed: 2,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 138|    attrs=attributes KW_OVERRIDE fn_kw=KW_FN EOF {
// 139|      WgslDeclHead::{
// 140|        kind: WgslDeclHeadKind::Function,
// 141|        attributes: attrs,
// 142|        keyword: Some(fn_kw),
// 143|        qualifier: Some(@ast.WgslFunctionQualifier::Override),
// 144|        qualifier_start: Some($2.start()),
// 145|        qualifier_end: Some($2.end()),
// 146|        fn_keyword: Some(fn_kw),
// 147|        consumed: 2,
// 148|      }
// 149|    }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[2].0 is YYObj__ast_WgslIdent(fn_kw)
  guard _args[1].0 is YYObj__ast_WgslIdent(_dollar2)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::Function,
        attributes: attrs,
        keyword: Some(fn_kw),
        qualifier: Some(@ast.WgslFunctionQualifier::Override),
        qualifier_start: Some(_dollar2.start()),
        qualifier_end: Some(_dollar2.end()),
        fn_keyword: Some(fn_kw),
        consumed: 2,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 162|    attrs=attributes keyword=KW_OVERRIDE EOF {
// 163|      WgslDeclHead::{
// 164|        kind: WgslDeclHeadKind::Override,
// 165|        attributes: attrs,
// 166|        keyword: Some(keyword),
// 167|        qualifier: None,
// 168|        qualifier_start: None,
// 169|        qualifier_end: None,
// 170|        fn_keyword: None,
// 171|        consumed: 1,
// 172|      }
// 173|    }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::Override,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 150|    attrs=attributes keyword=KW_FN EOF {
// 151|      WgslDeclHead::{
// 152|        kind: WgslDeclHeadKind::Function,
// 153|        attributes: attrs,
// 154|        keyword: Some(keyword),
// 155|        qualifier: None,
// 156|        qualifier_start: None,
// 157|        qualifier_end: None,
// 158|        fn_keyword: Some(keyword),
// 159|        consumed: 1,
// 160|      }
// 161|    }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::Function,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: Some(keyword),
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 174|    attrs=attributes keyword=KW_VAR EOF {
// 175|      WgslDeclHead::{
// 176|        kind: WgslDeclHeadKind::GlobalVariable,
// 177|        attributes: attrs,
// 178|        keyword: Some(keyword),
// 179|        qualifier: None,
// 180|        qualifier_start: None,
// 181|        qualifier_end: None,
// 182|        fn_keyword: None,
// 183|        consumed: 1,
// 184|      }
// 185|    }

///|
fn yy_action_7(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::GlobalVariable,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 186|    attrs=attributes keyword=KW_STRUCT EOF {
// 187|      WgslDeclHead::{
// 188|        kind: WgslDeclHeadKind::Struct,
// 189|        attributes: attrs,
// 190|        keyword: Some(keyword),
// 191|        qualifier: None,
// 192|        qualifier_start: None,
// 193|        qualifier_end: None,
// 194|        fn_keyword: None,
// 195|        consumed: 1,
// 196|      }
// 197|    }

///|
fn yy_action_8(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::Struct,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 198|    attrs=attributes keyword=KW_CONST EOF {
// 199|      WgslDeclHead::{
// 200|        kind: WgslDeclHeadKind::Const,
// 201|        attributes: attrs,
// 202|        keyword: Some(keyword),
// 203|        qualifier: None,
// 204|        qualifier_start: None,
// 205|        qualifier_end: None,
// 206|        fn_keyword: None,
// 207|        consumed: 1,
// 208|      }
// 209|    }

///|
fn yy_action_9(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::Const,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 210|    attrs=attributes keyword=KW_CONST_ASSERT EOF {
// 211|      WgslDeclHead::{
// 212|        kind: WgslDeclHeadKind::ConstAssert,
// 213|        attributes: attrs,
// 214|        keyword: Some(keyword),
// 215|        qualifier: None,
// 216|        qualifier_start: None,
// 217|        qualifier_end: None,
// 218|        fn_keyword: None,
// 219|        consumed: 1,
// 220|      }
// 221|    }

///|
fn yy_action_10(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::ConstAssert,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 222|    attrs=attributes keyword=KW_ALIAS EOF {
// 223|      WgslDeclHead::{
// 224|        kind: WgslDeclHeadKind::TypeAlias,
// 225|        attributes: attrs,
// 226|        keyword: Some(keyword),
// 227|        qualifier: None,
// 228|        qualifier_start: None,
// 229|        qualifier_end: None,
// 230|        fn_keyword: None,
// 231|        consumed: 1,
// 232|      }
// 233|    }

///|
fn yy_action_11(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::TypeAlias,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 234|    attrs=attributes keyword=KW_TYPE EOF {
// 235|      WgslDeclHead::{
// 236|        kind: WgslDeclHeadKind::TypeAlias,
// 237|        attributes: attrs,
// 238|        keyword: Some(keyword),
// 239|        qualifier: None,
// 240|        qualifier_start: None,
// 241|        qualifier_end: None,
// 242|        fn_keyword: None,
// 243|        consumed: 1,
// 244|      }
// 245|    }

///|
fn yy_action_12(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::TypeAlias,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 246|    attrs=attributes keyword=KW_ENABLE EOF {
// 247|      WgslDeclHead::{
// 248|        kind: WgslDeclHeadKind::SourceDirective,
// 249|        attributes: attrs,
// 250|        keyword: Some(keyword),
// 251|        qualifier: None,
// 252|        qualifier_start: None,
// 253|        qualifier_end: None,
// 254|        fn_keyword: None,
// 255|        consumed: 1,
// 256|      }
// 257|    }

///|
fn yy_action_13(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::SourceDirective,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 258|    attrs=attributes keyword=KW_REQUIRES EOF {
// 259|      WgslDeclHead::{
// 260|        kind: WgslDeclHeadKind::SourceDirective,
// 261|        attributes: attrs,
// 262|        keyword: Some(keyword),
// 263|        qualifier: None,
// 264|        qualifier_start: None,
// 265|        qualifier_end: None,
// 266|        fn_keyword: None,
// 267|        consumed: 1,
// 268|      }
// 269|    }

///|
fn yy_action_14(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::SourceDirective,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 270|    attrs=attributes keyword=KW_DIAGNOSTIC EOF {
// 271|      WgslDeclHead::{
// 272|        kind: WgslDeclHeadKind::SourceDirective,
// 273|        attributes: attrs,
// 274|        keyword: Some(keyword),
// 275|        qualifier: None,
// 276|        qualifier_start: None,
// 277|        qualifier_end: None,
// 278|        fn_keyword: None,
// 279|        consumed: 1,
// 280|      }
// 281|    }

///|
fn yy_action_15(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::SourceDirective,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: None,
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 282|    attrs=attributes EOF {
// 283|      WgslDeclHead::raw(attrs)
// 284|    }

///|
fn yy_action_16(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::raw(attrs)
    },
  )
}

// file:///./wgsl_parser.mbty
// 288|    value=type_expr EOF { value }

///|
fn yy_action_17(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj__ast_WgslTypeRef(
    {
      ()
      value
    },
  )
}

// file:///./wgsl_parser.mbty
// 459|    TYPE_LT args=template_args TYPE_GT EOF { args }

///|
fn yy_action_18(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslTypeRef_(args)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 466|    args=template_args "," value=type_expr {
// 467|      args.push(value)
// 468|      args
// 469|    }

///|
fn yy_action_19(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 463|    value=type_expr {
// 464|      [value]
// 465|    }

///|
fn yy_action_20(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 476|    atom=TYPE_ATOM TYPE_LT args=type_ref_args gt=TYPE_GT {
// 477|      wgsl_type_ref_from_atom(atom, args, gt)
// 478|    }

///|
fn yy_action_21(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 485|    args=type_ref_args "," value=type_expr {
// 486|      args.push(value)
// 487|      args
// 488|    }

///|
fn yy_action_22(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 482|    value=type_expr {
// 483|      [value]
// 484|    }

///|
fn yy_action_23(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 473|    atom=TYPE_ATOM {
// 474|      wgsl_type_ref_from_atom(atom, [], atom.end())
// 475|    }

///|
fn yy_action_24(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeAtom(atom)
  YYObj__ast_WgslTypeRef(
    {
      ()
      wgsl_type_ref_from_atom(atom, [], atom.end())
    },
  )
}

// file:///./wgsl_parser.mbty
// 292|    "(" ")" EOF { [] }

///|
fn yy_action_25(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 293|    "(" args=function_arg_list optional_comma ")" EOF { args }

///|
fn yy_action_26(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslFunctionArgument_(args)
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 441|    attrs=attributes name=ARG_NAME ":" ty=ARG_TYPE {
// 442|      let start = if attrs.length() > 0 { attrs[0].start() } else { name.start() }
// 443|      @ast.WgslFunctionArgument::new(
// 444|        attrs,
// 445|        name,
// 446|        start,
// 447|        ty.end(),
// 448|        Some(ty),
// 449|      )
// 450|    }

///|
fn yy_action_27(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
      @ast.WgslFunctionArgument::new(attrs, name, start, ty.end(), Some(ty))
    },
  )
}

// file:///./wgsl_parser.mbty
// 434|    args=function_arg_list "," value=function_arg {
// 435|      args.push(value)
// 436|      args
// 437|    }

///|
fn yy_action_28(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 455|    "," { () }

///|
fn yy_action_29(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 454|    { () }

///|
fn yy_action_30(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 431|    value=function_arg {
// 432|      [value]
// 433|    }

///|
fn yy_action_31(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslFunctionArgument(value)
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 297|    arrow=ARROW attrs=attributes ty=ARG_TYPE EOF {
// 298|      Some(@ast.WgslFunctionResult::new(attrs, arrow, ty.end(), Some(ty)))
// 299|    }

///|
fn yy_action_32(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(arrow)
  guard _args[1].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[2].0 is YYObj__ast_WgslTypeRef(ty)
  YYObj__ast_WgslFunctionResult_(
    {
      ()
      Some(@ast.WgslFunctionResult::new(attrs, arrow, ty.end(), Some(ty)))
    },
  )
}

// file:///./wgsl_parser.mbty
// 303|    "{" "}" EOF { [] }

///|
fn yy_action_33(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 304|    "{" members=struct_member_list optional_member_separator "}" EOF {
// 305|      members
// 306|    }

///|
fn yy_action_34(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslStructMember_(members)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      members
    },
  )
}

// file:///./wgsl_parser.mbty
// 80|    attributes attribute {
// 81|      let attributes = $1
// 82|      attributes.push($2)
// 83|      attributes
// 84|    }

///|
fn yy_action_35(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
//  88|    at=AT name=ATTR_NAME args=attribute_args {
//  89|      let (arguments_ref, args_end) = args
//  90|      let end = match args_end {
//  91|        Some(value) => value
//  92|        None => name.end()
//  93|      }
//  94|      @ast.WgslAttribute::new(
//  95|        name,
//  96|        at,
//  97|        end,
//  98|        arguments_ref,
//  99|      )
// 100|    }

///|
fn yy_action_36(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
      @ast.WgslAttribute::new(name, at, end, arguments_ref)
    },
  )
}

// file:///./wgsl_parser.mbty
// 105|    ATTR_ARGS {
// 106|      let (arguments_ref, end) = $1
// 107|      (arguments_ref, Some(end))
// 108|    }

///|
fn yy_action_37(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 104|    { (None, None) }

///|
fn yy_action_38(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj___ast_WgslExprRef___Int__(
    {
      ()
      (None, None)
    },
  )
}

// file:///./wgsl_parser.mbty
// 320|    attrs=attributes name=MEMBER_NAME ":" ty=MEMBER_TYPE {
// 321|      let start = if attrs.length() > 0 { attrs[0].start() } else { name.start() }
// 322|      @ast.WgslStructMember::new(
// 323|        attrs,
// 324|        name,
// 325|        start,
// 326|        ty.end(),
// 327|        Some(ty),
// 328|      )
// 329|    }

///|
fn yy_action_39(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
      @ast.WgslStructMember::new(attrs, name, start, ty.end(), Some(ty))
    },
  )
}

// file:///./wgsl_parser.mbty
// 313|    members=struct_member_list member_separator value=struct_member {
// 314|      members.push(value)
// 315|      members
// 316|    }

///|
fn yy_action_40(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 427|    member_separator { () }

///|
fn yy_action_41(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 421|    "," { () }

///|
fn yy_action_42(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 422|    ";" { () }

///|
fn yy_action_43(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 426|    { () }

///|
fn yy_action_44(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 310|    value=struct_member {
// 311|      [value]
// 312|    }

///|
fn yy_action_45(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslStructMember(value)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 79|    { [] }

///|
fn yy_action_46(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslAttribute_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 333|    EOF { (None, None) }

///|
fn yy_action_47(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj___ast_WgslTypeRef____ast_WgslExprRef__(
    {
      ()
      (None, None)
    },
  )
}

// file:///./wgsl_parser.mbty
// 334|    ":" ty=DECL_TYPE init=initializer_opt EOF {
// 335|      (Some(ty), init)
// 336|    }

///|
fn yy_action_48(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 411|    initializer { $1 }

///|
fn yy_action_49(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslExprRef_(_dollar1)
  YYObj__ast_WgslExprRef_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 410|    { None }

///|
fn yy_action_50(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__ast_WgslExprRef_(
    {
      ()
      None
    },
  )
}

// file:///./wgsl_parser.mbty
// 337|    init=initializer EOF {
// 338|      (None, init)
// 339|    }

///|
fn yy_action_51(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslExprRef_(init)
  YYObj___ast_WgslTypeRef____ast_WgslExprRef__(
    {
      ()
      (None, init)
    },
  )
}

// file:///./wgsl_parser.mbty
// 415|    "=" expr=INIT_EXPR {
// 416|      Some(expr)
// 417|    }

///|
fn yy_action_52(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__ast_WgslExprRef(expr)
  YYObj__ast_WgslExprRef_(
    {
      ()
      Some(expr)
    },
  )
}

// file:///./wgsl_parser.mbty
// 343|    "=" ty=DECL_TYPE EOF {
// 344|      ty
// 345|    }

///|
fn yy_action_53(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__ast_WgslTypeRef(ty)
  YYObj__ast_WgslTypeRef(
    {
      ()
      ty
    },
  )
}

// file:///./wgsl_parser.mbty
// 349|    text=SOURCE_TEXT keyword=KW_ENABLE tail=directive_tail EOF {
// 350|      let (tail, raw_tail_start, raw_tail_end) = tail
// 351|      let tail_start = if tail == "" { keyword.end() } else { raw_tail_start }
// 352|      let tail_end = if tail == "" { keyword.end() } else { raw_tail_end }
// 353|      let has_required_separator = tail != "" && tail_start > keyword.end()
// 354|      @ast.WgslDirective::new(
// 355|        @ast.WgslDirectiveKind::Enable,
// 356|        keyword,
// 357|        @ast.WgslDirectiveTail::new(
// 358|          tail,
// 359|          tail_start,
// 360|          tail_end,
// 361|          has_required_separator,
// 362|        ),
// 363|        0,
// 364|        text.length(),
// 365|      )
// 366|    }

///|
fn yy_action_54(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
      @ast.WgslDirective::new(
        @ast.WgslDirectiveKind::Enable,
        keyword,
        @ast.WgslDirectiveTail::new(
          tail, tail_start, tail_end, has_required_separator,
        ),
        0,
        text.length(),
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 367|    text=SOURCE_TEXT keyword=KW_REQUIRES tail=directive_tail EOF {
// 368|      let (tail, raw_tail_start, raw_tail_end) = tail
// 369|      let tail_start = if tail == "" { keyword.end() } else { raw_tail_start }
// 370|      let tail_end = if tail == "" { keyword.end() } else { raw_tail_end }
// 371|      let has_required_separator = tail != "" && tail_start > keyword.end()
// 372|      @ast.WgslDirective::new(
// 373|        @ast.WgslDirectiveKind::Requires,
// 374|        keyword,
// 375|        @ast.WgslDirectiveTail::new(
// 376|          tail,
// 377|          tail_start,
// 378|          tail_end,
// 379|          has_required_separator,
// 380|        ),
// 381|        0,
// 382|        text.length(),
// 383|      )
// 384|    }

///|
fn yy_action_55(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
      @ast.WgslDirective::new(
        @ast.WgslDirectiveKind::Requires,
        keyword,
        @ast.WgslDirectiveTail::new(
          tail, tail_start, tail_end, has_required_separator,
        ),
        0,
        text.length(),
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 122|    DIRECTIVE_TAIL { $1 }

///|
fn yy_action_56(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String__Int__Int_(_dollar1)
  YYObj__String__Int__Int_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 385|    text=SOURCE_TEXT keyword=KW_DIAGNOSTIC tail=directive_tail EOF {
// 386|      let (tail, raw_tail_start, raw_tail_end) = tail
// 387|      let tail_start = if tail == "" { keyword.end() } else { raw_tail_start }
// 388|      let tail_end = if tail == "" { keyword.end() } else { raw_tail_end }
// 389|      let has_required_separator = tail != "" && tail_start > keyword.end()
// 390|      @ast.WgslDirective::new(
// 391|        @ast.WgslDirectiveKind::Diagnostic,
// 392|        keyword,
// 393|        @ast.WgslDirectiveTail::new(
// 394|          tail,
// 395|          tail_start,
// 396|          tail_end,
// 397|          has_required_separator,
// 398|        ),
// 399|        0,
// 400|        text.length(),
// 401|      )
// 402|    }

///|
fn yy_action_57(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
      @ast.WgslDirective::new(
        @ast.WgslDirectiveKind::Diagnostic,
        keyword,
        @ast.WgslDirectiveTail::new(
          tail, tail_start, tail_end, has_required_separator,
        ),
        0,
        text.length(),
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 121|    { ("", 0, 0) }

///|
fn yy_action_58(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__String__Int__Int_(
    {
      ()
      ("", 0, 0)
    },
  )
}

// file:///./wgsl_parser.mbty
// 406|    EXPR_REF EOF { $1 }

///|
fn yy_action_59(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslExprRef(_dollar1)
  YYObj__ast_WgslExprRef(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 64|    open=LBRACE statements close=RBRACE EOF {
// 65|      @ast.WgslBlock::new(open, close + 1, $2)
// 66|    }

///|
fn yy_action_60(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(open)
  guard _args[2].0 is YYObj_Int(close)
  guard _args[1].0 is YYObj_Array__ast_WgslStatement_(_dollar2)
  YYObj__ast_WgslBlock(
    {
      ()
      @ast.WgslBlock::new(open, close + 1, _dollar2)
    },
  )
}

// file:///./wgsl_parser.mbty
// 71|    statements STMT {
// 72|      let statements = $1
// 73|      statements.push($2)
// 74|      statements
// 75|    }

///|
fn yy_action_61(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 70|    { [] }

///|
fn yy_action_62(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
    ITEM(data) => (T_ITEM, YYObj_WgslRawTopLevelItem(data))
    STMT(data) => (T_STMT, YYObj__ast_WgslStatement(data))
    TYPE_ATOM(data) => (T_TYPE_ATOM, YYObj__ast_WgslTypeAtom(data))
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
    KW_VIRTUAL(data) => (T_KW_VIRTUAL, YYObj__ast_WgslIdent(data))
    KW_OVERRIDE(data) => (T_KW_OVERRIDE, YYObj__ast_WgslIdent(data))
    KW_FN(data) => (T_KW_FN, YYObj__ast_WgslIdent(data))
    KW_VAR(data) => (T_KW_VAR, YYObj__ast_WgslIdent(data))
    KW_STRUCT(data) => (T_KW_STRUCT, YYObj__ast_WgslIdent(data))
    KW_CONST(data) => (T_KW_CONST, YYObj__ast_WgslIdent(data))
    KW_CONST_ASSERT(data) => (T_KW_CONST_ASSERT, YYObj__ast_WgslIdent(data))
    KW_ALIAS(data) => (T_KW_ALIAS, YYObj__ast_WgslIdent(data))
    KW_TYPE(data) => (T_KW_TYPE, YYObj__ast_WgslIdent(data))
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

// [1, block → • LBRACE statements RBRACE EOF, $]
// [74, block_prime → • block, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_block => Shift(yy_state_1)
    T_LBRACE => Shift(yy_state_2)
    _ => Error
  }
}

// [74, block_prime → block •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [1, block → LBRACE • statements RBRACE EOF, $]
// [2, statements → •, STMT / RBRACE]
// [3, statements → • statements STMT, STMT / RBRACE]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_statements => Shift(yy_state_3)
    T_STMT | T_RBRACE => Reduce(0, NT_statements, yy_action_62)
    _ => Error
  }
}

// [1, block → LBRACE statements • RBRACE EOF, $]
// [3, statements → statements • STMT, STMT / RBRACE]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STMT => Shift(yy_state_4)
    T_RBRACE => Shift(yy_state_5)
    _ => Error
  }
}

// [3, statements → statements STMT •, STMT / RBRACE]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_statements, yy_action_61)
}

// [1, block → LBRACE statements RBRACE • EOF, $]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_6)
    _ => Error
  }
}

// [1, block → LBRACE statements RBRACE EOF •, $]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_block, yy_action_60)
}

// [43, const_assert_expr → • EXPR_REF EOF, $]
// [73, const_assert_expr_prime → • const_assert_expr, $]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_const_assert_expr => Shift(yy_state_8)
    T_EXPR_REF => Shift(yy_state_9)
    _ => Error
  }
}

// [73, const_assert_expr_prime → const_assert_expr •, $]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [43, const_assert_expr → EXPR_REF • EOF, $]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_10)
    _ => Error
  }
}

// [43, const_assert_expr → EXPR_REF EOF •, $]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_const_assert_expr, yy_action_59)
}

// [40, source_directive → • SOURCE_TEXT KW_ENABLE directive_tail EOF, $]
// [41, source_directive → • SOURCE_TEXT KW_REQUIRES directive_tail EOF, $]
// [42, source_directive → • SOURCE_TEXT KW_DIAGNOSTIC directive_tail EOF, $]
// [72, source_directive_prime → • source_directive, $]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_source_directive => Shift(yy_state_12)
    T_SOURCE_TEXT => Shift(yy_state_13)
    _ => Error
  }
}

// [72, source_directive_prime → source_directive •, $]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [40, source_directive → SOURCE_TEXT • KW_ENABLE directive_tail EOF, $]
// [41, source_directive → SOURCE_TEXT • KW_REQUIRES directive_tail EOF, $]
// [42, source_directive → SOURCE_TEXT • KW_DIAGNOSTIC directive_tail EOF, $]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KW_DIAGNOSTIC => Shift(yy_state_14)
    T_KW_REQUIRES => Shift(yy_state_18)
    T_KW_ENABLE => Shift(yy_state_21)
    _ => Error
  }
}

// [11, directive_tail → •, EOF]
// [12, directive_tail → • DIRECTIVE_TAIL, EOF]
// [42, source_directive → SOURCE_TEXT KW_DIAGNOSTIC • directive_tail EOF, $]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_tail => Shift(yy_state_15)
    T_DIRECTIVE_TAIL => Shift(yy_state_17)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_58)
    _ => Error
  }
}

// [42, source_directive → SOURCE_TEXT KW_DIAGNOSTIC directive_tail • EOF, $]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_16)
    _ => Error
  }
}

// [42, source_directive → SOURCE_TEXT KW_DIAGNOSTIC directive_tail EOF •, $]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_57)
}

// [12, directive_tail → DIRECTIVE_TAIL •, EOF]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_directive_tail, yy_action_56)
}

// [11, directive_tail → •, EOF]
// [12, directive_tail → • DIRECTIVE_TAIL, EOF]
// [41, source_directive → SOURCE_TEXT KW_REQUIRES • directive_tail EOF, $]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_17)
    NT_directive_tail => Shift(yy_state_19)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_58)
    _ => Error
  }
}

// [41, source_directive → SOURCE_TEXT KW_REQUIRES directive_tail • EOF, $]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_20)
    _ => Error
  }
}

// [41, source_directive → SOURCE_TEXT KW_REQUIRES directive_tail EOF •, $]

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_55)
}

// [11, directive_tail → •, EOF]
// [12, directive_tail → • DIRECTIVE_TAIL, EOF]
// [40, source_directive → SOURCE_TEXT KW_ENABLE • directive_tail EOF, $]

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_17)
    NT_directive_tail => Shift(yy_state_22)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_58)
    _ => Error
  }
}

// [40, source_directive → SOURCE_TEXT KW_ENABLE directive_tail • EOF, $]

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_23)
    _ => Error
  }
}

// [40, source_directive → SOURCE_TEXT KW_ENABLE directive_tail EOF •, $]

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_54)
}

// [39, type_alias_tail → • EQUAL DECL_TYPE EOF, $]
// [71, type_alias_tail_prime → • type_alias_tail, $]

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_alias_tail => Shift(yy_state_25)
    T_EQUAL => Shift(yy_state_26)
    _ => Error
  }
}

// [71, type_alias_tail_prime → type_alias_tail •, $]

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [39, type_alias_tail → EQUAL • DECL_TYPE EOF, $]

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_TYPE => Shift(yy_state_27)
    _ => Error
  }
}

// [39, type_alias_tail → EQUAL DECL_TYPE • EOF, $]

///|
fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_28)
    _ => Error
  }
}

// [39, type_alias_tail → EQUAL DECL_TYPE EOF •, $]

///|
fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_alias_tail, yy_action_53)
}

// [36, typed_initializer_tail → • EOF, $]
// [37, typed_initializer_tail → • COLON DECL_TYPE initializer_opt EOF, $]
// [38, typed_initializer_tail → • initializer EOF, $]
// [46, initializer → • EQUAL INIT_EXPR, EOF]
// [70, typed_initializer_tail_prime → • typed_initializer_tail, $]

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

// [70, typed_initializer_tail_prime → typed_initializer_tail •, $]

///|
fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [46, initializer → EQUAL • INIT_EXPR, EOF]

///|
fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INIT_EXPR => Shift(yy_state_32)
    _ => Error
  }
}

// [46, initializer → EQUAL INIT_EXPR •, EOF]

///|
fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_initializer, yy_action_52)
}

// [38, typed_initializer_tail → initializer • EOF, $]

///|
fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_34)
    _ => Error
  }
}

// [38, typed_initializer_tail → initializer EOF •, $]

///|
fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_typed_initializer_tail, yy_action_51)
}

// [37, typed_initializer_tail → COLON • DECL_TYPE initializer_opt EOF, $]

///|
fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_TYPE => Shift(yy_state_36)
    _ => Error
  }
}

// [37, typed_initializer_tail → COLON DECL_TYPE • initializer_opt EOF, $]
// [44, initializer_opt → •, EOF]
// [45, initializer_opt → • initializer, EOF]
// [46, initializer → • EQUAL INIT_EXPR, EOF]

///|
fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_31)
    NT_initializer => Shift(yy_state_37)
    NT_initializer_opt => Shift(yy_state_38)
    T_EOF => Reduce(0, NT_initializer_opt, yy_action_50)
    _ => Error
  }
}

// [45, initializer_opt → initializer •, EOF]

///|
fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_initializer_opt, yy_action_49)
}

// [37, typed_initializer_tail → COLON DECL_TYPE initializer_opt • EOF, $]

///|
fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_39)
    _ => Error
  }
}

// [37, typed_initializer_tail → COLON DECL_TYPE initializer_opt EOF •, $]

///|
fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_typed_initializer_tail, yy_action_48)
}

// [36, typed_initializer_tail → EOF •, $]

///|
fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_typed_initializer_tail, yy_action_47)
}

// [31, struct_members → • LBRACE RBRACE EOF, $]
// [32, struct_members → • LBRACE struct_member_list optional_member_separator RBRACE EOF, $]
// [69, struct_members_prime → • struct_members, $]

///|
fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_42)
    T_LBRACE => Shift(yy_state_43)
    _ => Error
  }
}

// [69, struct_members_prime → struct_members •, $]

///|
fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [4, attributes → •, MEMBER_NAME / AT]
// [5, attributes → • attributes attribute, MEMBER_NAME / AT]
// [31, struct_members → LBRACE • RBRACE EOF, $]
// [32, struct_members → LBRACE • struct_member_list optional_member_separator RBRACE EOF, $]
// [33, struct_member_list → • struct_member, RBRACE / COMMA / SEMI]
// [34, struct_member_list → • struct_member_list member_separator struct_member, RBRACE / COMMA / SEMI]
// [35, struct_member → • attributes MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_member => Shift(yy_state_44)
    NT_struct_member_list => Shift(yy_state_45)
    NT_attributes => Shift(yy_state_50)
    T_RBRACE => Shift(yy_state_62)
    T_MEMBER_NAME | T_AT => Reduce(0, NT_attributes, yy_action_46)
    _ => Error
  }
}

// [33, struct_member_list → struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member_list, yy_action_45)
}

// [32, struct_members → LBRACE struct_member_list • optional_member_separator RBRACE EOF, $]
// [34, struct_member_list → struct_member_list • member_separator struct_member, RBRACE / COMMA / SEMI]
// [47, member_separator → • COMMA, MEMBER_NAME / AT / RBRACE]
// [48, member_separator → • SEMI, MEMBER_NAME / AT / RBRACE]
// [49, optional_member_separator → •, RBRACE]
// [50, optional_member_separator → • member_separator, RBRACE]

///|
fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_46)
    T_COMMA => Shift(yy_state_47)
    NT_member_separator => Shift(yy_state_48)
    NT_optional_member_separator => Shift(yy_state_59)
    T_RBRACE => Reduce(0, NT_optional_member_separator, yy_action_44)
    _ => Error
  }
}

// [48, member_separator → SEMI •, MEMBER_NAME / AT / RBRACE]

///|
fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_43)
}

// [47, member_separator → COMMA •, MEMBER_NAME / AT / RBRACE]

///|
fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_42)
}

// [4, attributes → •, MEMBER_NAME / AT]
// [5, attributes → • attributes attribute, MEMBER_NAME / AT]
// [34, struct_member_list → struct_member_list member_separator • struct_member, RBRACE / COMMA / SEMI]
// [35, struct_member → • attributes MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]
// [50, optional_member_separator → member_separator •, RBRACE]

///|
fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_member => Shift(yy_state_49)
    NT_attributes => Shift(yy_state_50)
    T_MEMBER_NAME | T_AT => Reduce(0, NT_attributes, yy_action_46)
    T_RBRACE => Reduce(1, NT_optional_member_separator, yy_action_41)
    _ => Error
  }
}

// [34, struct_member_list → struct_member_list member_separator struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_member_list, yy_action_40)
}

// [5, attributes → attributes • attribute, MEMBER_NAME / AT]
// [6, attribute → • AT ATTR_NAME attribute_args, MEMBER_NAME / AT]
// [35, struct_member → attributes • MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_NAME => Shift(yy_state_51)
    T_AT => Shift(yy_state_54)
    NT_attribute => Shift(yy_state_58)
    _ => Error
  }
}

// [35, struct_member → attributes MEMBER_NAME • COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_52)
    _ => Error
  }
}

// [35, struct_member → attributes MEMBER_NAME COLON • MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_TYPE => Shift(yy_state_53)
    _ => Error
  }
}

// [35, struct_member → attributes MEMBER_NAME COLON MEMBER_TYPE •, RBRACE / COMMA / SEMI]

///|
fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_struct_member, yy_action_39)
}

// [6, attribute → AT • ATTR_NAME attribute_args, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]

///|
fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ATTR_NAME => Shift(yy_state_55)
    _ => Error
  }
}

// [6, attribute → AT ATTR_NAME • attribute_args, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]
// [7, attribute_args → •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]
// [8, attribute_args → • ATTR_ARGS, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]

///|
fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ATTR_ARGS => Shift(yy_state_56)
    NT_attribute_args => Shift(yy_state_57)
    T_ARG_NAME
    | T_ARG_TYPE
    | T_MEMBER_NAME
    | T_AT
    | T_KW_VIRTUAL
    | T_KW_OVERRIDE
    | T_KW_FN
    | T_KW_VAR
    | T_KW_STRUCT
    | T_KW_CONST
    | T_KW_CONST_ASSERT
    | T_KW_ALIAS
    | T_KW_TYPE
    | T_KW_ENABLE
    | T_KW_REQUIRES
    | T_KW_DIAGNOSTIC
    | T_EOF => Reduce(0, NT_attribute_args, yy_action_38)
    _ => Error
  }
}

// [8, attribute_args → ATTR_ARGS •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]

///|
fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_attribute_args, yy_action_37)
}

// [6, attribute → AT ATTR_NAME attribute_args •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]

///|
fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_attribute, yy_action_36)
}

// [5, attributes → attributes attribute •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]

///|
fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_attributes, yy_action_35)
}

// [32, struct_members → LBRACE struct_member_list optional_member_separator • RBRACE EOF, $]

///|
fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_60)
    _ => Error
  }
}

// [32, struct_members → LBRACE struct_member_list optional_member_separator RBRACE • EOF, $]

///|
fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_61)
    _ => Error
  }
}

// [32, struct_members → LBRACE struct_member_list optional_member_separator RBRACE EOF •, $]

///|
fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_members, yy_action_34)
}

// [31, struct_members → LBRACE RBRACE • EOF, $]

///|
fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_63)
    _ => Error
  }
}

// [31, struct_members → LBRACE RBRACE EOF •, $]

///|
fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_members, yy_action_33)
}

// [30, function_result → • ARROW attributes ARG_TYPE EOF, $]
// [68, function_result_prime → • function_result, $]

///|
fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_result => Shift(yy_state_65)
    T_ARROW => Shift(yy_state_66)
    _ => Error
  }
}

// [68, function_result_prime → function_result •, $]

///|
fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [4, attributes → •, ARG_TYPE / AT]
// [5, attributes → • attributes attribute, ARG_TYPE / AT]
// [30, function_result → ARROW • attributes ARG_TYPE EOF, $]

///|
fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attributes => Shift(yy_state_67)
    T_ARG_TYPE | T_AT => Reduce(0, NT_attributes, yy_action_46)
    _ => Error
  }
}

// [5, attributes → attributes • attribute, ARG_TYPE / AT]
// [6, attribute → • AT ATTR_NAME attribute_args, ARG_TYPE / AT]
// [30, function_result → ARROW attributes • ARG_TYPE EOF, $]

///|
fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_54)
    NT_attribute => Shift(yy_state_58)
    T_ARG_TYPE => Shift(yy_state_68)
    _ => Error
  }
}

// [30, function_result → ARROW attributes ARG_TYPE • EOF, $]

///|
fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_69)
    _ => Error
  }
}

// [30, function_result → ARROW attributes ARG_TYPE EOF •, $]

///|
fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_result, yy_action_32)
}

// [28, function_args → • LPAREN RPAREN EOF, $]
// [29, function_args → • LPAREN function_arg_list optional_comma RPAREN EOF, $]
// [67, function_args_prime → • function_args, $]

///|
fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_args => Shift(yy_state_71)
    T_LPAREN => Shift(yy_state_72)
    _ => Error
  }
}

// [67, function_args_prime → function_args •, $]

///|
fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [4, attributes → •, ARG_NAME / AT]
// [5, attributes → • attributes attribute, ARG_NAME / AT]
// [28, function_args → LPAREN • RPAREN EOF, $]
// [29, function_args → LPAREN • function_arg_list optional_comma RPAREN EOF, $]
// [51, function_arg_list → • function_arg, RPAREN / COMMA]
// [52, function_arg_list → • function_arg_list COMMA function_arg, RPAREN / COMMA]
// [53, function_arg → • attributes ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_arg => Shift(yy_state_73)
    NT_function_arg_list => Shift(yy_state_74)
    NT_attributes => Shift(yy_state_77)
    T_RPAREN => Shift(yy_state_84)
    T_ARG_NAME | T_AT => Reduce(0, NT_attributes, yy_action_46)
    _ => Error
  }
}

// [51, function_arg_list → function_arg •, RPAREN / COMMA]

///|
fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_arg_list, yy_action_31)
}

// [29, function_args → LPAREN function_arg_list • optional_comma RPAREN EOF, $]
// [52, function_arg_list → function_arg_list • COMMA function_arg, RPAREN / COMMA]
// [54, optional_comma → •, RPAREN]
// [55, optional_comma → • COMMA, RPAREN]

///|
fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_75)
    NT_optional_comma => Shift(yy_state_81)
    T_RPAREN => Reduce(0, NT_optional_comma, yy_action_30)
    _ => Error
  }
}

// [4, attributes → •, ARG_NAME / AT]
// [5, attributes → • attributes attribute, ARG_NAME / AT]
// [52, function_arg_list → function_arg_list COMMA • function_arg, RPAREN / COMMA]
// [53, function_arg → • attributes ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]
// [55, optional_comma → COMMA •, RPAREN]

///|
fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_arg => Shift(yy_state_76)
    NT_attributes => Shift(yy_state_77)
    T_ARG_NAME | T_AT => Reduce(0, NT_attributes, yy_action_46)
    T_RPAREN => Reduce(1, NT_optional_comma, yy_action_29)
    _ => Error
  }
}

// [52, function_arg_list → function_arg_list COMMA function_arg •, RPAREN / COMMA]

///|
fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_arg_list, yy_action_28)
}

// [5, attributes → attributes • attribute, ARG_NAME / AT]
// [6, attribute → • AT ATTR_NAME attribute_args, ARG_NAME / AT]
// [53, function_arg → attributes • ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_54)
    NT_attribute => Shift(yy_state_58)
    T_ARG_NAME => Shift(yy_state_78)
    _ => Error
  }
}

// [53, function_arg → attributes ARG_NAME • COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_79)
    _ => Error
  }
}

// [53, function_arg → attributes ARG_NAME COLON • ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_TYPE => Shift(yy_state_80)
    _ => Error
  }
}

// [53, function_arg → attributes ARG_NAME COLON ARG_TYPE •, RPAREN / COMMA]

///|
fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_arg, yy_action_27)
}

// [29, function_args → LPAREN function_arg_list optional_comma • RPAREN EOF, $]

///|
fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_82)
    _ => Error
  }
}

// [29, function_args → LPAREN function_arg_list optional_comma RPAREN • EOF, $]

///|
fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_83)
    _ => Error
  }
}

// [29, function_args → LPAREN function_arg_list optional_comma RPAREN EOF •, $]

///|
fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_args, yy_action_26)
}

// [28, function_args → LPAREN RPAREN • EOF, $]

///|
fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_85)
    _ => Error
  }
}

// [28, function_args → LPAREN RPAREN EOF •, $]

///|
fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_args, yy_action_25)
}

// [56, template_list → • TYPE_LT template_args TYPE_GT EOF, $]
// [66, template_list_prime → • template_list, $]

///|
fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_template_list => Shift(yy_state_87)
    T_TYPE_LT => Shift(yy_state_88)
    _ => Error
  }
}

// [66, template_list_prime → template_list •, $]

///|
fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [56, template_list → TYPE_LT • template_args TYPE_GT EOF, $]
// [57, template_args → • type_expr, TYPE_GT / COMMA]
// [58, template_args → • template_args COMMA type_expr, TYPE_GT / COMMA]
// [59, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [60, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_96)
    NT_template_args => Shift(yy_state_97)
    _ => Error
  }
}

// [59, type_expr → TYPE_ATOM •, TYPE_GT / COMMA / EOF]
// [60, type_expr → TYPE_ATOM • TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]

///|
fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_LT => Shift(yy_state_90)
    T_TYPE_GT | T_COMMA | T_EOF => Reduce(1, NT_type_expr, yy_action_24)
    _ => Error
  }
}

// [59, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [60, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [60, type_expr → TYPE_ATOM TYPE_LT • type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]
// [61, type_ref_args → • type_expr, TYPE_GT / COMMA]
// [62, type_ref_args → • type_ref_args COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_91)
    NT_type_ref_args => Shift(yy_state_92)
    _ => Error
  }
}

// [61, type_ref_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_ref_args, yy_action_23)
}

// [60, type_expr → TYPE_ATOM TYPE_LT type_ref_args • TYPE_GT, TYPE_GT / COMMA / EOF]
// [62, type_ref_args → type_ref_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_93)
    T_TYPE_GT => Shift(yy_state_95)
    _ => Error
  }
}

// [59, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [60, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [62, type_ref_args → type_ref_args COMMA • type_expr, TYPE_GT / COMMA]

///|
fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_94)
    _ => Error
  }
}

// [62, type_ref_args → type_ref_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_ref_args, yy_action_22)
}

// [60, type_expr → TYPE_ATOM TYPE_LT type_ref_args TYPE_GT •, TYPE_GT / COMMA / EOF]

///|
fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_expr, yy_action_21)
}

// [57, template_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_template_args, yy_action_20)
}

// [56, template_list → TYPE_LT template_args • TYPE_GT EOF, $]
// [58, template_args → template_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_98)
    T_TYPE_GT => Shift(yy_state_100)
    _ => Error
  }
}

// [58, template_args → template_args COMMA • type_expr, TYPE_GT / COMMA]
// [59, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [60, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_99)
    _ => Error
  }
}

// [58, template_args → template_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_template_args, yy_action_19)
}

// [56, template_list → TYPE_LT template_args TYPE_GT • EOF, $]

///|
fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_101)
    _ => Error
  }
}

// [56, template_list → TYPE_LT template_args TYPE_GT EOF •, $]

///|
fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_template_list, yy_action_18)
}

// [27, type_ref → • type_expr EOF, $]
// [59, type_expr → • TYPE_ATOM, EOF]
// [60, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, EOF]
// [65, type_ref_prime → • type_ref, $]

///|
fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_ref => Shift(yy_state_103)
    NT_type_expr => Shift(yy_state_104)
    _ => Error
  }
}

// [65, type_ref_prime → type_ref •, $]

///|
fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [27, type_ref → type_expr • EOF, $]

///|
fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_105)
    _ => Error
  }
}

// [27, type_ref → type_expr EOF •, $]

///|
fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_ref, yy_action_17)
}

// [4, attributes → •, AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]
// [5, attributes → • attributes attribute, AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]
// [13, decl_head → • attributes KW_VIRTUAL KW_FN EOF, $]
// [14, decl_head → • attributes KW_OVERRIDE KW_FN EOF, $]
// [15, decl_head → • attributes KW_FN EOF, $]
// [16, decl_head → • attributes KW_OVERRIDE EOF, $]
// [17, decl_head → • attributes KW_VAR EOF, $]
// [18, decl_head → • attributes KW_STRUCT EOF, $]
// [19, decl_head → • attributes KW_CONST EOF, $]
// [20, decl_head → • attributes KW_CONST_ASSERT EOF, $]
// [21, decl_head → • attributes KW_ALIAS EOF, $]
// [22, decl_head → • attributes KW_TYPE EOF, $]
// [23, decl_head → • attributes KW_ENABLE EOF, $]
// [24, decl_head → • attributes KW_REQUIRES EOF, $]
// [25, decl_head → • attributes KW_DIAGNOSTIC EOF, $]
// [26, decl_head → • attributes EOF, $]
// [64, decl_head_prime → • decl_head, $]

///|
fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_decl_head => Shift(yy_state_107)
    NT_attributes => Shift(yy_state_108)
    T_AT
    | T_KW_VIRTUAL
    | T_KW_OVERRIDE
    | T_KW_FN
    | T_KW_VAR
    | T_KW_STRUCT
    | T_KW_CONST
    | T_KW_CONST_ASSERT
    | T_KW_ALIAS
    | T_KW_TYPE
    | T_KW_ENABLE
    | T_KW_REQUIRES
    | T_KW_DIAGNOSTIC
    | T_EOF => Reduce(0, NT_attributes, yy_action_46)
    _ => Error
  }
}

// [64, decl_head_prime → decl_head •, $]

///|
fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [5, attributes → attributes • attribute, AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]
// [6, attribute → • AT ATTR_NAME attribute_args, AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]
// [13, decl_head → attributes • KW_VIRTUAL KW_FN EOF, $]
// [14, decl_head → attributes • KW_OVERRIDE KW_FN EOF, $]
// [15, decl_head → attributes • KW_FN EOF, $]
// [16, decl_head → attributes • KW_OVERRIDE EOF, $]
// [17, decl_head → attributes • KW_VAR EOF, $]
// [18, decl_head → attributes • KW_STRUCT EOF, $]
// [19, decl_head → attributes • KW_CONST EOF, $]
// [20, decl_head → attributes • KW_CONST_ASSERT EOF, $]
// [21, decl_head → attributes • KW_ALIAS EOF, $]
// [22, decl_head → attributes • KW_TYPE EOF, $]
// [23, decl_head → attributes • KW_ENABLE EOF, $]
// [24, decl_head → attributes • KW_REQUIRES EOF, $]
// [25, decl_head → attributes • KW_DIAGNOSTIC EOF, $]
// [26, decl_head → attributes • EOF, $]

///|
fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_54)
    NT_attribute => Shift(yy_state_58)
    T_EOF => Shift(yy_state_109)
    T_KW_DIAGNOSTIC => Shift(yy_state_110)
    T_KW_REQUIRES => Shift(yy_state_112)
    T_KW_ENABLE => Shift(yy_state_114)
    T_KW_TYPE => Shift(yy_state_116)
    T_KW_ALIAS => Shift(yy_state_118)
    T_KW_CONST_ASSERT => Shift(yy_state_120)
    T_KW_CONST => Shift(yy_state_122)
    T_KW_STRUCT => Shift(yy_state_124)
    T_KW_VAR => Shift(yy_state_126)
    T_KW_FN => Shift(yy_state_128)
    T_KW_OVERRIDE => Shift(yy_state_130)
    T_KW_VIRTUAL => Shift(yy_state_134)
    _ => Error
  }
}

// [26, decl_head → attributes EOF •, $]

///|
fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_decl_head, yy_action_16)
}

// [25, decl_head → attributes KW_DIAGNOSTIC • EOF, $]

///|
fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_111)
    _ => Error
  }
}

// [25, decl_head → attributes KW_DIAGNOSTIC EOF •, $]

///|
fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_15)
}

// [24, decl_head → attributes KW_REQUIRES • EOF, $]

///|
fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_113)
    _ => Error
  }
}

// [24, decl_head → attributes KW_REQUIRES EOF •, $]

///|
fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_14)
}

// [23, decl_head → attributes KW_ENABLE • EOF, $]

///|
fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_115)
    _ => Error
  }
}

// [23, decl_head → attributes KW_ENABLE EOF •, $]

///|
fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_13)
}

// [22, decl_head → attributes KW_TYPE • EOF, $]

///|
fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_117)
    _ => Error
  }
}

// [22, decl_head → attributes KW_TYPE EOF •, $]

///|
fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_12)
}

// [21, decl_head → attributes KW_ALIAS • EOF, $]

///|
fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_119)
    _ => Error
  }
}

// [21, decl_head → attributes KW_ALIAS EOF •, $]

///|
fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_11)
}

// [20, decl_head → attributes KW_CONST_ASSERT • EOF, $]

///|
fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_121)
    _ => Error
  }
}

// [20, decl_head → attributes KW_CONST_ASSERT EOF •, $]

///|
fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_10)
}

// [19, decl_head → attributes KW_CONST • EOF, $]

///|
fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_123)
    _ => Error
  }
}

// [19, decl_head → attributes KW_CONST EOF •, $]

///|
fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_9)
}

// [18, decl_head → attributes KW_STRUCT • EOF, $]

///|
fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_125)
    _ => Error
  }
}

// [18, decl_head → attributes KW_STRUCT EOF •, $]

///|
fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_8)
}

// [17, decl_head → attributes KW_VAR • EOF, $]

///|
fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_127)
    _ => Error
  }
}

// [17, decl_head → attributes KW_VAR EOF •, $]

///|
fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_7)
}

// [15, decl_head → attributes KW_FN • EOF, $]

///|
fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_129)
    _ => Error
  }
}

// [15, decl_head → attributes KW_FN EOF •, $]

///|
fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_6)
}

// [14, decl_head → attributes KW_OVERRIDE • KW_FN EOF, $]
// [16, decl_head → attributes KW_OVERRIDE • EOF, $]

///|
fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_131)
    T_KW_FN => Shift(yy_state_132)
    _ => Error
  }
}

// [16, decl_head → attributes KW_OVERRIDE EOF •, $]

///|
fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_5)
}

// [14, decl_head → attributes KW_OVERRIDE KW_FN • EOF, $]

///|
fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_133)
    _ => Error
  }
}

// [14, decl_head → attributes KW_OVERRIDE KW_FN EOF •, $]

///|
fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_decl_head, yy_action_4)
}

// [13, decl_head → attributes KW_VIRTUAL • KW_FN EOF, $]

///|
fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KW_FN => Shift(yy_state_135)
    _ => Error
  }
}

// [13, decl_head → attributes KW_VIRTUAL KW_FN • EOF, $]

///|
fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_136)
    _ => Error
  }
}

// [13, decl_head → attributes KW_VIRTUAL KW_FN EOF •, $]

///|
fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_decl_head, yy_action_3)
}

// [0, raw_top_level_items → • items EOF, $]
// [9, items → •, ITEM / EOF]
// [10, items → • items ITEM, ITEM / EOF]
// [63, raw_top_level_items_prime → • raw_top_level_items, $]

///|
fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_raw_top_level_items => Shift(yy_state_138)
    NT_items => Shift(yy_state_139)
    T_ITEM | T_EOF => Reduce(0, NT_items, yy_action_2)
    _ => Error
  }
}

// [63, raw_top_level_items_prime → raw_top_level_items •, $]

///|
fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [0, raw_top_level_items → items • EOF, $]
// [10, items → items • ITEM, ITEM / EOF]

///|
fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ITEM => Shift(yy_state_140)
    T_EOF => Shift(yy_state_141)
    _ => Error
  }
}

// [10, items → items ITEM •, ITEM / EOF]

///|
fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_items, yy_action_1)
}

// [0, raw_top_level_items → items EOF •, $]

///|
fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_raw_top_level_items, yy_action_0)
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
        (T_ITEM, TK_ITEM),
        (T_STMT, TK_STMT),
        (T_TYPE_ATOM, TK_TYPE_ATOM),
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
        (T_KW_VIRTUAL, TK_KW_VIRTUAL),
        (T_KW_OVERRIDE, TK_KW_OVERRIDE),
        (T_KW_FN, TK_KW_FN),
        (T_KW_VAR, TK_KW_VAR),
        (T_KW_STRUCT, TK_KW_STRUCT),
        (T_KW_CONST, TK_KW_CONST),
        (T_KW_CONST_ASSERT, TK_KW_CONST_ASSERT),
        (T_KW_ALIAS, TK_KW_ALIAS),
        (T_KW_TYPE, TK_KW_TYPE),
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
fn raw_top_level_items(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[WgslRawTopLevelItem] raise ParseError {
  yy_parse(
    tokens,
    yy_state_137,
    it => {
      guard it is YYObj_Array_WgslRawTopLevelItem_(result)
      result
    },
    initial_pos?,
  )
}

///|
fn decl_head(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> WgslDeclHead raise ParseError {
  yy_parse(
    tokens,
    yy_state_106,
    it => {
      guard it is YYObj_WgslDeclHead(result)
      result
    },
    initial_pos?,
  )
}

///|
fn type_ref(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslTypeRef raise ParseError {
  yy_parse(
    tokens,
    yy_state_102,
    it => {
      guard it is YYObj__ast_WgslTypeRef(result)
      result
    },
    initial_pos?,
  )
}

///|
fn template_list(
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
fn function_args(
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
fn function_result(
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
fn struct_members(
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
fn typed_initializer_tail(
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
fn type_alias_tail(
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
fn source_directive(
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
fn const_assert_expr(
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
fn block(
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
  @ast.WgslTypeRef::new(atom, arguments, atom.start(), end_.max(atom.end()))
}
