///|
pub(all) enum Token {
  ITEM(@ast.WgslRawTopLevelItem)
  STMT(@ast.WgslStatement)
  IDENT(String)
  TYPE_ATOM((String, String, Int, Int, Int))
  DECL_ATTRS(Array[@ast.WgslAttribute])
  ARG_NAME(@ast.WgslIdent)
  ARG_TYPE((String, @ast.WgslTypeRef?))
  MEMBER_NAME(@ast.WgslIdent)
  MEMBER_TYPE((String, @ast.WgslTypeRef?))
  DECL_TYPE((String, @ast.WgslTypeRef?))
  INIT_EXPR((String, @ast.WgslExprRef?))
  EXPR_REF(@ast.WgslExprRef)
  ATTR_NAME(String)
  ATTR_ARGS((String, @ast.WgslExprRef?))
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
  DIRECTIVE_HEAD((String, String))
  DIRECTIVE_TAIL(String)
  SOURCE_TEXT(String)
  AT
  HASH
  PREFIX
  AS
  ARROW
  LPAREN
  RPAREN
  LBRACE
  RBRACE
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
    ITEM(_) => TK_ITEM
    STMT(_) => TK_STMT
    IDENT(_) => TK_IDENT
    TYPE_ATOM(_) => TK_TYPE_ATOM
    DECL_ATTRS(_) => TK_DECL_ATTRS
    ARG_NAME(_) => TK_ARG_NAME
    ARG_TYPE(_) => TK_ARG_TYPE
    MEMBER_NAME(_) => TK_MEMBER_NAME
    MEMBER_TYPE(_) => TK_MEMBER_TYPE
    DECL_TYPE(_) => TK_DECL_TYPE
    INIT_EXPR(_) => TK_INIT_EXPR
    EXPR_REF(_) => TK_EXPR_REF
    ATTR_NAME(_) => TK_ATTR_NAME
    ATTR_ARGS(_) => TK_ATTR_ARGS
    KW_VIRTUAL(_) => TK_KW_VIRTUAL
    KW_OVERRIDE(_) => TK_KW_OVERRIDE
    KW_FN(_) => TK_KW_FN
    KW_VAR(_) => TK_KW_VAR
    KW_STRUCT(_) => TK_KW_STRUCT
    KW_CONST(_) => TK_KW_CONST
    KW_CONST_ASSERT(_) => TK_KW_CONST_ASSERT
    KW_ALIAS(_) => TK_KW_ALIAS
    KW_TYPE(_) => TK_KW_TYPE
    KW_ENABLE(_) => TK_KW_ENABLE
    KW_REQUIRES(_) => TK_KW_REQUIRES
    KW_DIAGNOSTIC(_) => TK_KW_DIAGNOSTIC
    DIRECTIVE_HEAD(_) => TK_DIRECTIVE_HEAD
    DIRECTIVE_TAIL(_) => TK_DIRECTIVE_TAIL
    SOURCE_TEXT(_) => TK_SOURCE_TEXT
    AT => TK_AT
    HASH => TK_HASH
    PREFIX => TK_PREFIX
    AS => TK_AS
    ARROW => TK_ARROW
    LPAREN => TK_LPAREN
    RPAREN => TK_RPAREN
    LBRACE => TK_LBRACE
    RBRACE => TK_RBRACE
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
  TK_ITEM
  TK_STMT
  TK_IDENT
  TK_TYPE_ATOM
  TK_DECL_ATTRS
  TK_ARG_NAME
  TK_ARG_TYPE
  TK_MEMBER_NAME
  TK_MEMBER_TYPE
  TK_DECL_TYPE
  TK_INIT_EXPR
  TK_EXPR_REF
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
  TK_DIRECTIVE_HEAD
  TK_DIRECTIVE_TAIL
  TK_SOURCE_TEXT
  TK_AT
  TK_HASH
  TK_PREFIX
  TK_AS
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
pub impl Show for TokenKind with output(self, logger) {
  logger.write_string(
    match self {
      TK_ITEM => "ITEM"
      TK_STMT => "STMT"
      TK_IDENT => "IDENT"
      TK_TYPE_ATOM => "TYPE_ATOM"
      TK_DECL_ATTRS => "DECL_ATTRS"
      TK_ARG_NAME => "ARG_NAME"
      TK_ARG_TYPE => "ARG_TYPE"
      TK_MEMBER_NAME => "MEMBER_NAME"
      TK_MEMBER_TYPE => "MEMBER_TYPE"
      TK_DECL_TYPE => "DECL_TYPE"
      TK_INIT_EXPR => "INIT_EXPR"
      TK_EXPR_REF => "EXPR_REF"
      TK_ATTR_NAME => "ATTR_NAME"
      TK_ATTR_ARGS => "ATTR_ARGS"
      TK_KW_VIRTUAL => "KW_VIRTUAL"
      TK_KW_OVERRIDE => "KW_OVERRIDE"
      TK_KW_FN => "KW_FN"
      TK_KW_VAR => "KW_VAR"
      TK_KW_STRUCT => "KW_STRUCT"
      TK_KW_CONST => "KW_CONST"
      TK_KW_CONST_ASSERT => "KW_CONST_ASSERT"
      TK_KW_ALIAS => "KW_ALIAS"
      TK_KW_TYPE => "KW_TYPE"
      TK_KW_ENABLE => "KW_ENABLE"
      TK_KW_REQUIRES => "KW_REQUIRES"
      TK_KW_DIAGNOSTIC => "KW_DIAGNOSTIC"
      TK_DIRECTIVE_HEAD => "DIRECTIVE_HEAD"
      TK_DIRECTIVE_TAIL => "DIRECTIVE_TAIL"
      TK_SOURCE_TEXT => "SOURCE_TEXT"
      TK_AT => "\"@\""
      TK_HASH => "\"#\""
      TK_PREFIX => "PREFIX"
      TK_AS => "\"as\""
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
pub impl Debug for TokenKind with to_repr(self) {
  match self {
    TK_ITEM => to_repr("ITEM")
    TK_STMT => to_repr("STMT")
    TK_IDENT => to_repr("IDENT")
    TK_TYPE_ATOM => to_repr("TYPE_ATOM")
    TK_DECL_ATTRS => to_repr("DECL_ATTRS")
    TK_ARG_NAME => to_repr("ARG_NAME")
    TK_ARG_TYPE => to_repr("ARG_TYPE")
    TK_MEMBER_NAME => to_repr("MEMBER_NAME")
    TK_MEMBER_TYPE => to_repr("MEMBER_TYPE")
    TK_DECL_TYPE => to_repr("DECL_TYPE")
    TK_INIT_EXPR => to_repr("INIT_EXPR")
    TK_EXPR_REF => to_repr("EXPR_REF")
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
    TK_DIRECTIVE_HEAD => to_repr("DIRECTIVE_HEAD")
    TK_DIRECTIVE_TAIL => to_repr("DIRECTIVE_TAIL")
    TK_SOURCE_TEXT => to_repr("SOURCE_TEXT")
    TK_AT => to_repr("@")
    TK_HASH => to_repr("#")
    TK_PREFIX => to_repr("PREFIX")
    TK_AS => to_repr("as")
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
priv suberror YYObj_Array_String_ {
  YYObj_Array_String_(Array[String])
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
priv suberror YYObj_Array__ast_WgslRawTopLevelItem_ {
  YYObj_Array__ast_WgslRawTopLevelItem_(Array[@ast.WgslRawTopLevelItem])
}

///|
priv suberror YYObj_Array__ast_WgslFunctionArgument_ {
  YYObj_Array__ast_WgslFunctionArgument_(Array[@ast.WgslFunctionArgument])
}

///|
priv suberror YYObj_Array__common_WgslImportTarget_ {
  YYObj_Array__common_WgslImportTarget_(Array[@common.WgslImportTarget])
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
priv suberror YYObj__ast_WgslDeclHead {
  YYObj__ast_WgslDeclHead(@ast.WgslDeclHead)
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
priv suberror YYObj__ast_WgslRawTopLevelItem {
  YYObj__ast_WgslRawTopLevelItem(@ast.WgslRawTopLevelItem)
}

///|
priv suberror YYObj__ast_WgslFunctionArgument {
  YYObj__ast_WgslFunctionArgument(@ast.WgslFunctionArgument)
}

///|
priv suberror YYObj__ast_WgslFunctionResult_ {
  YYObj__ast_WgslFunctionResult_(@ast.WgslFunctionResult?)
}

///|
priv suberror YYObj__String__String_ {
  YYObj__String__String_((String, String))
}

///|
priv suberror YYObj__String___ast_WgslExprRef__ {
  YYObj__String___ast_WgslExprRef__((String, @ast.WgslExprRef?))
}

///|
priv suberror YYObj__String___ast_WgslTypeRef__ {
  YYObj__String___ast_WgslTypeRef__((String, @ast.WgslTypeRef?))
}

///|
priv suberror YYObj__String____ast_WgslExprRef__ {
  YYObj__String____ast_WgslExprRef__((String?, @ast.WgslExprRef?))
}

///|
priv suberror YYObj__String____ast_WgslTypeRef___String____ast_WgslExprRef__ {
  YYObj__String____ast_WgslTypeRef___String____ast_WgslExprRef__(
    (String?, @ast.WgslTypeRef?, String?, @ast.WgslExprRef?)
  )
}

///|
priv suberror YYObj__String__String__Int__Int__Int_ {
  YYObj__String__String__Int__Int__Int_((String, String, Int, Int, Int))
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
  T_IDENT
  T_TYPE_ATOM
  T_DECL_ATTRS
  T_ARG_NAME
  T_ARG_TYPE
  T_MEMBER_NAME
  T_MEMBER_TYPE
  T_DECL_TYPE
  T_INIT_EXPR
  T_EXPR_REF
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
  T_DIRECTIVE_HEAD
  T_DIRECTIVE_TAIL
  T_SOURCE_TEXT
  T_AT
  T_HASH
  T_PREFIX
  T_AS
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
  NT_attribute_list
  NT_block
  NT_statements
  NT_attributes
  NT_attribute
  NT_attribute_args
  NT_items
  NT_import_targets
  NT_semis
  NT_target_list
  NT_target
  NT_alias
  NT_directive_line
  NT_directive_prefix_tail
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
// 70|    items EOF { $1 }

///|
fn yy_action_0(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslRawTopLevelItem_(_dollar1)
  YYObj_Array__ast_WgslRawTopLevelItem_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 115|    items ITEM {
// 116|      let items = $1
// 117|      items.push($2)
// 118|      items
// 119|    }

///|
fn yy_action_1(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslRawTopLevelItem_(_dollar1)
  guard _args[1].0 is YYObj__ast_WgslRawTopLevelItem(_dollar2)
  YYObj_Array__ast_WgslRawTopLevelItem_(
    {
      ()
      let items = _dollar1
      items.push(_dollar2)
      items
    },
  )
}

// file:///./wgsl_parser.mbty
// 114|    { [] }

///|
fn yy_action_2(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslRawTopLevelItem_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 123|    target_list semis EOF { $1 }

///|
fn yy_action_3(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__common_WgslImportTarget_(_dollar1)
  YYObj_Array__common_WgslImportTarget_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 124|    module_path=IDENT targets=target_list semis EOF {
// 125|      let out : Array[@common.WgslImportTarget] = []
// 126|      for target in targets {
// 127|        let sep = if module_path.has_suffix("::") || target.raw_path == "" {
// 128|          ""
// 129|        } else {
// 130|          "::"
// 131|        }
// 132|        out.push(@common.WgslImportTarget::{
// 133|          raw_path: module_path + sep + target.raw_path,
// 134|          alias_name: target.alias_name,
// 135|        })
// 136|      }
// 137|      out
// 138|    }

///|
fn yy_action_4(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(module_path)
  guard _args[1].0 is YYObj_Array__common_WgslImportTarget_(targets)
  YYObj_Array__common_WgslImportTarget_(
    {
      ()
      let out : Array[@common.WgslImportTarget] = []
      for target in targets {
        let sep = if module_path.has_suffix("::") || target.raw_path == "" {
          ""
        } else {
          "::"
        }
        out.push(@common.WgslImportTarget::{
          raw_path: module_path + sep + target.raw_path,
          alias_name: target.alias_name,
        })
      }
      out
    },
  )
}

// file:///./wgsl_parser.mbty
// 143|    semis ";" { () }

///|
fn yy_action_5(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 142|    { () }

///|
fn yy_action_6(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 150|    target_list "," target {
// 151|      let targets = $1
// 152|      for target in $3 {
// 153|        targets.push(target)
// 154|      }
// 155|      targets
// 156|    }

///|
fn yy_action_7(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__common_WgslImportTarget_(_dollar1)
  guard _args[2].0 is YYObj_Array__common_WgslImportTarget_(_dollar3)
  YYObj_Array__common_WgslImportTarget_(
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

// file:///./wgsl_parser.mbty
// 157|    target_list "," {
// 158|      $1
// 159|    }

///|
fn yy_action_8(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__common_WgslImportTarget_(_dollar1)
  YYObj_Array__common_WgslImportTarget_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 166|    module_path=IDENT "{" targets=target_list "}" {
// 167|      let out : Array[@common.WgslImportTarget] = []
// 168|      for target in targets {
// 169|        let sep = if module_path.has_suffix("::") || target.raw_path == "" {
// 170|          ""
// 171|        } else {
// 172|          "::"
// 173|        }
// 174|        out.push(@common.WgslImportTarget::{
// 175|          raw_path: module_path + sep + target.raw_path,
// 176|          alias_name: target.alias_name,
// 177|        })
// 178|      }
// 179|      out
// 180|    }

///|
fn yy_action_9(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(module_path)
  guard _args[2].0 is YYObj_Array__common_WgslImportTarget_(targets)
  YYObj_Array__common_WgslImportTarget_(
    {
      ()
      let out : Array[@common.WgslImportTarget] = []
      for target in targets {
        let sep = if module_path.has_suffix("::") || target.raw_path == "" {
          ""
        } else {
          "::"
        }
        out.push(@common.WgslImportTarget::{
          raw_path: module_path + sep + target.raw_path,
          alias_name: target.alias_name,
        })
      }
      out
    },
  )
}

// file:///./wgsl_parser.mbty
// 163|    path=IDENT alias_name=alias {
// 164|      [@common.WgslImportTarget::{ raw_path: path, alias_name }]
// 165|    }

///|
fn yy_action_10(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(path)
  guard _args[1].0 is YYObj_String(alias_name)
  YYObj_Array__common_WgslImportTarget_(
    {
      ()
      [@common.WgslImportTarget::{ raw_path: path, alias_name }]
    },
  )
}

// file:///./wgsl_parser.mbty
// 185|    "as" name=IDENT { name }

///|
fn yy_action_11(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(name)
  YYObj_String(
    {
      ()
      name
    },
  )
}

// file:///./wgsl_parser.mbty
// 184|    { "" }

///|
fn yy_action_12(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_String(
    {
      ()
      ""
    },
  )
}

// file:///./wgsl_parser.mbty
// 147|    target {
// 148|      $1
// 149|    }

///|
fn yy_action_13(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__common_WgslImportTarget_(_dollar1)
  YYObj_Array__common_WgslImportTarget_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 189|    "#" head=DIRECTIVE_HEAD tail=directive_tail EOF {
// 190|      let (name, text) = head
// 191|      let kind = match name {
// 192|        "ifdef" => @ast.WgslDirectiveKind::Ifdef
// 193|        "ifndef" => @ast.WgslDirectiveKind::Ifndef
// 194|        "if" => @ast.WgslDirectiveKind::If
// 195|        "else" => @ast.WgslDirectiveKind::Else
// 196|        "endif" => @ast.WgslDirectiveKind::Endif
// 197|        "define_import_path" => @ast.WgslDirectiveKind::DefineImportPath
// 198|        "define" => @ast.WgslDirectiveKind::Define
// 199|        "import" => @ast.WgslDirectiveKind::Import
// 200|        "enable" => @ast.WgslDirectiveKind::Enable
// 201|        "requires" => @ast.WgslDirectiveKind::Requires
// 202|        "diagnostic" => @ast.WgslDirectiveKind::Diagnostic
// 203|        _ => @ast.WgslDirectiveKind::Other(name)
// 204|      }
// 205|      @ast.WgslDirective::{ kind, name, tail, text }
// 206|    }

///|
fn yy_action_14(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__String__String_(head)
  guard _args[2].0 is YYObj_String(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      let (name, text) = head
      let kind = match name {
        "ifdef" => @ast.WgslDirectiveKind::Ifdef
        "ifndef" => @ast.WgslDirectiveKind::Ifndef
        "if" => @ast.WgslDirectiveKind::If
        "else" => @ast.WgslDirectiveKind::Else
        "endif" => @ast.WgslDirectiveKind::Endif
        "define_import_path" => @ast.WgslDirectiveKind::DefineImportPath
        "define" => @ast.WgslDirectiveKind::Define
        "import" => @ast.WgslDirectiveKind::Import
        "enable" => @ast.WgslDirectiveKind::Enable
        "requires" => @ast.WgslDirectiveKind::Requires
        "diagnostic" => @ast.WgslDirectiveKind::Diagnostic
        _ => @ast.WgslDirectiveKind::Other(name)
      }
      @ast.WgslDirective::{ kind, name, tail, text }
    },
  )
}

// file:///./wgsl_parser.mbty
// 210|    "#" PREFIX tail=directive_tail EOF { tail }

///|
fn yy_action_15(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[2].0 is YYObj_String(tail)
  YYObj_String(
    {
      ()
      tail
    },
  )
}

// file:///./wgsl_parser.mbty
// 219|    attrs=DECL_ATTRS KW_VIRTUAL fn_kw=KW_FN EOF {
// 220|      @ast.WgslDeclHead::{
// 221|        kind: @ast.WgslDeclHeadKind::Function,
// 222|        attributes: attrs,
// 223|        keyword: Some(fn_kw),
// 224|        qualifier: "virtual",
// 225|        qualifier_start: Some($2.start),
// 226|        qualifier_end: Some($2.end),
// 227|        fn_keyword: Some(fn_kw),
// 228|        consumed: 2,
// 229|      }
// 230|    }

///|
fn yy_action_16(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[2].0 is YYObj__ast_WgslIdent(fn_kw)
  guard _args[1].0 is YYObj__ast_WgslIdent(_dollar2)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::Function,
        attributes: attrs,
        keyword: Some(fn_kw),
        qualifier: "virtual",
        qualifier_start: Some(_dollar2.start),
        qualifier_end: Some(_dollar2.end),
        fn_keyword: Some(fn_kw),
        consumed: 2,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 231|    attrs=DECL_ATTRS KW_OVERRIDE fn_kw=KW_FN EOF {
// 232|      @ast.WgslDeclHead::{
// 233|        kind: @ast.WgslDeclHeadKind::Function,
// 234|        attributes: attrs,
// 235|        keyword: Some(fn_kw),
// 236|        qualifier: "override",
// 237|        qualifier_start: Some($2.start),
// 238|        qualifier_end: Some($2.end),
// 239|        fn_keyword: Some(fn_kw),
// 240|        consumed: 2,
// 241|      }
// 242|    }

///|
fn yy_action_17(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[2].0 is YYObj__ast_WgslIdent(fn_kw)
  guard _args[1].0 is YYObj__ast_WgslIdent(_dollar2)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::Function,
        attributes: attrs,
        keyword: Some(fn_kw),
        qualifier: "override",
        qualifier_start: Some(_dollar2.start),
        qualifier_end: Some(_dollar2.end),
        fn_keyword: Some(fn_kw),
        consumed: 2,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 255|    attrs=DECL_ATTRS keyword=KW_OVERRIDE EOF {
// 256|      @ast.WgslDeclHead::{
// 257|        kind: @ast.WgslDeclHeadKind::Override,
// 258|        attributes: attrs,
// 259|        keyword: Some(keyword),
// 260|        qualifier: "",
// 261|        qualifier_start: None,
// 262|        qualifier_end: None,
// 263|        fn_keyword: None,
// 264|        consumed: 1,
// 265|      }
// 266|    }

///|
fn yy_action_18(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::Override,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 243|    attrs=DECL_ATTRS keyword=KW_FN EOF {
// 244|      @ast.WgslDeclHead::{
// 245|        kind: @ast.WgslDeclHeadKind::Function,
// 246|        attributes: attrs,
// 247|        keyword: Some(keyword),
// 248|        qualifier: "",
// 249|        qualifier_start: None,
// 250|        qualifier_end: None,
// 251|        fn_keyword: Some(keyword),
// 252|        consumed: 1,
// 253|      }
// 254|    }

///|
fn yy_action_19(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::Function,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: Some(keyword),
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 267|    attrs=DECL_ATTRS keyword=KW_VAR EOF {
// 268|      @ast.WgslDeclHead::{
// 269|        kind: @ast.WgslDeclHeadKind::GlobalVariable,
// 270|        attributes: attrs,
// 271|        keyword: Some(keyword),
// 272|        qualifier: "",
// 273|        qualifier_start: None,
// 274|        qualifier_end: None,
// 275|        fn_keyword: None,
// 276|        consumed: 1,
// 277|      }
// 278|    }

///|
fn yy_action_20(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::GlobalVariable,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 279|    attrs=DECL_ATTRS keyword=KW_STRUCT EOF {
// 280|      @ast.WgslDeclHead::{
// 281|        kind: @ast.WgslDeclHeadKind::Struct,
// 282|        attributes: attrs,
// 283|        keyword: Some(keyword),
// 284|        qualifier: "",
// 285|        qualifier_start: None,
// 286|        qualifier_end: None,
// 287|        fn_keyword: None,
// 288|        consumed: 1,
// 289|      }
// 290|    }

///|
fn yy_action_21(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::Struct,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 291|    attrs=DECL_ATTRS keyword=KW_CONST EOF {
// 292|      @ast.WgslDeclHead::{
// 293|        kind: @ast.WgslDeclHeadKind::Const,
// 294|        attributes: attrs,
// 295|        keyword: Some(keyword),
// 296|        qualifier: "",
// 297|        qualifier_start: None,
// 298|        qualifier_end: None,
// 299|        fn_keyword: None,
// 300|        consumed: 1,
// 301|      }
// 302|    }

///|
fn yy_action_22(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::Const,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 303|    attrs=DECL_ATTRS keyword=KW_CONST_ASSERT EOF {
// 304|      @ast.WgslDeclHead::{
// 305|        kind: @ast.WgslDeclHeadKind::ConstAssert,
// 306|        attributes: attrs,
// 307|        keyword: Some(keyword),
// 308|        qualifier: "",
// 309|        qualifier_start: None,
// 310|        qualifier_end: None,
// 311|        fn_keyword: None,
// 312|        consumed: 1,
// 313|      }
// 314|    }

///|
fn yy_action_23(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::ConstAssert,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 315|    attrs=DECL_ATTRS keyword=KW_ALIAS EOF {
// 316|      @ast.WgslDeclHead::{
// 317|        kind: @ast.WgslDeclHeadKind::TypeAlias,
// 318|        attributes: attrs,
// 319|        keyword: Some(keyword),
// 320|        qualifier: "",
// 321|        qualifier_start: None,
// 322|        qualifier_end: None,
// 323|        fn_keyword: None,
// 324|        consumed: 1,
// 325|      }
// 326|    }

///|
fn yy_action_24(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::TypeAlias,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 327|    attrs=DECL_ATTRS keyword=KW_TYPE EOF {
// 328|      @ast.WgslDeclHead::{
// 329|        kind: @ast.WgslDeclHeadKind::TypeAlias,
// 330|        attributes: attrs,
// 331|        keyword: Some(keyword),
// 332|        qualifier: "",
// 333|        qualifier_start: None,
// 334|        qualifier_end: None,
// 335|        fn_keyword: None,
// 336|        consumed: 1,
// 337|      }
// 338|    }

///|
fn yy_action_25(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::TypeAlias,
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 339|    attrs=DECL_ATTRS keyword=KW_ENABLE EOF {
// 340|      @ast.WgslDeclHead::{
// 341|        kind: @ast.WgslDeclHeadKind::SourceDirective(@ast.WgslDirectiveKind::Enable),
// 342|        attributes: attrs,
// 343|        keyword: Some(keyword),
// 344|        qualifier: "",
// 345|        qualifier_start: None,
// 346|        qualifier_end: None,
// 347|        fn_keyword: None,
// 348|        consumed: 1,
// 349|      }
// 350|    }

///|
fn yy_action_26(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::SourceDirective(
          @ast.WgslDirectiveKind::Enable,
        ),
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 351|    attrs=DECL_ATTRS keyword=KW_REQUIRES EOF {
// 352|      @ast.WgslDeclHead::{
// 353|        kind: @ast.WgslDeclHeadKind::SourceDirective(@ast.WgslDirectiveKind::Requires),
// 354|        attributes: attrs,
// 355|        keyword: Some(keyword),
// 356|        qualifier: "",
// 357|        qualifier_start: None,
// 358|        qualifier_end: None,
// 359|        fn_keyword: None,
// 360|        consumed: 1,
// 361|      }
// 362|    }

///|
fn yy_action_27(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::SourceDirective(
          @ast.WgslDirectiveKind::Requires,
        ),
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 363|    attrs=DECL_ATTRS keyword=KW_DIAGNOSTIC EOF {
// 364|      @ast.WgslDeclHead::{
// 365|        kind: @ast.WgslDeclHeadKind::SourceDirective(@ast.WgslDirectiveKind::Diagnostic),
// 366|        attributes: attrs,
// 367|        keyword: Some(keyword),
// 368|        qualifier: "",
// 369|        qualifier_start: None,
// 370|        qualifier_end: None,
// 371|        fn_keyword: None,
// 372|        consumed: 1,
// 373|      }
// 374|    }

///|
fn yy_action_28(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::{
        kind: @ast.WgslDeclHeadKind::SourceDirective(
          @ast.WgslDirectiveKind::Diagnostic,
        ),
        attributes: attrs,
        keyword: Some(keyword),
        qualifier: "",
        qualifier_start: None,
        qualifier_end: None,
        fn_keyword: None,
        consumed: 1,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 375|    attrs=DECL_ATTRS EOF {
// 376|      @ast.WgslDeclHead::raw(attrs)
// 377|    }

///|
fn yy_action_29(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::raw(attrs)
    },
  )
}

// file:///./wgsl_parser.mbty
// 381|    value=type_expr EOF { value }

///|
fn yy_action_30(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj__ast_WgslTypeRef(
    {
      ()
      value
    },
  )
}

// file:///./wgsl_parser.mbty
// 527|    TYPE_LT args=template_args TYPE_GT EOF { args }

///|
fn yy_action_31(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_String_(args)
  YYObj_Array_String_(
    {
      ()
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 534|    args=template_args "," value=type_expr {
// 535|      args.push(value.text)
// 536|      args
// 537|    }

///|
fn yy_action_32(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(args)
  guard _args[2].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array_String_(
    {
      ()
      args.push(value.text)
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 531|    value=type_expr {
// 532|      [value.text]
// 533|    }

///|
fn yy_action_33(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array_String_(
    {
      ()
      [value.text]
    },
  )
}

// file:///./wgsl_parser.mbty
// 544|    atom=TYPE_ATOM TYPE_LT args=type_ref_args gt=TYPE_GT {
// 545|      wgsl_type_ref_from_atom(atom, args, gt)
// 546|    }

///|
fn yy_action_34(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String__String__Int__Int__Int_(atom)
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
// 553|    args=type_ref_args "," value=type_expr {
// 554|      args.push(value)
// 555|      args
// 556|    }

///|
fn yy_action_35(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 550|    value=type_expr {
// 551|      [value]
// 552|    }

///|
fn yy_action_36(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 541|    atom=TYPE_ATOM {
// 542|      wgsl_type_ref_from_atom(atom, [], atom.4)
// 543|    }

///|
fn yy_action_37(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String__String__Int__Int__Int_(atom)
  YYObj__ast_WgslTypeRef(
    {
      ()
      wgsl_type_ref_from_atom(atom, [], atom.4)
    },
  )
}

// file:///./wgsl_parser.mbty
// 385|    "(" ")" EOF { [] }

///|
fn yy_action_38(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 386|    "(" args=function_arg_list optional_comma ")" EOF { args }

///|
fn yy_action_39(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslFunctionArgument_(args)
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 501|    args=function_arg_list "," value=function_arg {
// 502|      args.push(value)
// 503|      args
// 504|    }

///|
fn yy_action_40(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 523|    "," { () }

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
// 522|    { () }

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
// 498|    value=function_arg {
// 499|      [value]
// 500|    }

///|
fn yy_action_43(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslFunctionArgument(value)
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 508|    attrs=DECL_ATTRS name=ARG_NAME ":" ty=ARG_TYPE {
// 509|      let (ty_text, ty_ref) = ty
// 510|      @ast.WgslFunctionArgument::{
// 511|        attributes: attrs,
// 512|        name: name.name,
// 513|        name_start: name.start,
// 514|        name_end: name.end,
// 515|        ty: ty_text,
// 516|        ty_ref,
// 517|      }
// 518|    }

///|
fn yy_action_44(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(name)
  guard _args[3].0 is YYObj__String___ast_WgslTypeRef__(ty)
  YYObj__ast_WgslFunctionArgument(
    {
      ()
      let (ty_text, ty_ref) = ty
      @ast.WgslFunctionArgument::{
        attributes: attrs,
        name: name.name,
        name_start: name.start,
        name_end: name.end,
        ty: ty_text,
        ty_ref,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 390|    "->" attrs=DECL_ATTRS ty=ARG_TYPE EOF {
// 391|      let (ty_text, ty_ref) = ty
// 392|      Some(@ast.WgslFunctionResult::{ attributes: attrs, ty: ty_text, ty_ref })
// 393|    }

///|
fn yy_action_45(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[2].0 is YYObj__String___ast_WgslTypeRef__(ty)
  YYObj__ast_WgslFunctionResult_(
    {
      ()
      let (ty_text, ty_ref) = ty
      Some(@ast.WgslFunctionResult::{ attributes: attrs, ty: ty_text, ty_ref })
    },
  )
}

// file:///./wgsl_parser.mbty
// 397|    "{" "}" EOF { [] }

///|
fn yy_action_46(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 398|    "{" members=struct_member_list optional_member_separator "}" EOF {
// 399|      members
// 400|    }

///|
fn yy_action_47(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslStructMember_(members)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      members
    },
  )
}

// file:///./wgsl_parser.mbty
// 407|    members=struct_member_list member_separator value=struct_member {
// 408|      members.push(value)
// 409|      members
// 410|    }

///|
fn yy_action_48(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 494|    member_separator { () }

///|
fn yy_action_49(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 488|    "," { () }

///|
fn yy_action_50(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 489|    ";" { () }

///|
fn yy_action_51(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 493|    { () }

///|
fn yy_action_52(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 404|    value=struct_member {
// 405|      [value]
// 406|    }

///|
fn yy_action_53(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslStructMember(value)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 414|    attrs=DECL_ATTRS name=MEMBER_NAME ":" ty=MEMBER_TYPE {
// 415|      let (ty_text, ty_ref) = ty
// 416|      @ast.WgslStructMember::{
// 417|        attributes: attrs,
// 418|        name: name.name,
// 419|        name_start: name.start,
// 420|        name_end: name.end,
// 421|        ty: ty_text,
// 422|        ty_ref,
// 423|      }
// 424|    }

///|
fn yy_action_54(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(name)
  guard _args[3].0 is YYObj__String___ast_WgslTypeRef__(ty)
  YYObj__ast_WgslStructMember(
    {
      ()
      let (ty_text, ty_ref) = ty
      @ast.WgslStructMember::{
        attributes: attrs,
        name: name.name,
        name_start: name.start,
        name_end: name.end,
        ty: ty_text,
        ty_ref,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 428|    EOF { (None, None, None, None) }

///|
fn yy_action_55(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__String____ast_WgslTypeRef___String____ast_WgslExprRef__(
    {
      ()
      (None, None, None, None)
    },
  )
}

// file:///./wgsl_parser.mbty
// 429|    ":" ty=DECL_TYPE init=initializer_opt EOF {
// 430|      let (ty_text, ty_ref) = ty
// 431|      let (init_text, init_ref) = init
// 432|      (Some(ty_text), ty_ref, init_text, init_ref)
// 433|    }

///|
fn yy_action_56(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__String___ast_WgslTypeRef__(ty)
  guard _args[2].0 is YYObj__String____ast_WgslExprRef__(init)
  YYObj__String____ast_WgslTypeRef___String____ast_WgslExprRef__(
    {
      ()
      let (ty_text, ty_ref) = ty
      let (init_text, init_ref) = init
      (Some(ty_text), ty_ref, init_text, init_ref)
    },
  )
}

// file:///./wgsl_parser.mbty
// 477|    initializer { $1 }

///|
fn yy_action_57(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String____ast_WgslExprRef__(_dollar1)
  YYObj__String____ast_WgslExprRef__(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 476|    { (None, None) }

///|
fn yy_action_58(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__String____ast_WgslExprRef__(
    {
      ()
      (None, None)
    },
  )
}

// file:///./wgsl_parser.mbty
// 434|    init=initializer EOF {
// 435|      let (init_text, init_ref) = init
// 436|      (None, None, init_text, init_ref)
// 437|    }

///|
fn yy_action_59(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String____ast_WgslExprRef__(init)
  YYObj__String____ast_WgslTypeRef___String____ast_WgslExprRef__(
    {
      ()
      let (init_text, init_ref) = init
      (None, None, init_text, init_ref)
    },
  )
}

// file:///./wgsl_parser.mbty
// 481|    "=" expr=INIT_EXPR {
// 482|      let (text, expr_ref) = expr
// 483|      (Some(text), expr_ref)
// 484|    }

///|
fn yy_action_60(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__String___ast_WgslExprRef__(expr)
  YYObj__String____ast_WgslExprRef__(
    {
      ()
      let (text, expr_ref) = expr
      (Some(text), expr_ref)
    },
  )
}

// file:///./wgsl_parser.mbty
// 441|    "=" ty=DECL_TYPE EOF { ty }

///|
fn yy_action_61(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__String___ast_WgslTypeRef__(ty)
  YYObj__String___ast_WgslTypeRef__(
    {
      ()
      ty
    },
  )
}

// file:///./wgsl_parser.mbty
// 445|    text=SOURCE_TEXT keyword=KW_ENABLE tail=directive_tail EOF {
// 446|      @ast.WgslDirective::{
// 447|        kind: @ast.WgslDirectiveKind::Enable,
// 448|        name: keyword.name,
// 449|        tail,
// 450|        text,
// 451|      }
// 452|    }

///|
fn yy_action_62(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(text)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  guard _args[2].0 is YYObj_String(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      @ast.WgslDirective::{
        kind: @ast.WgslDirectiveKind::Enable,
        name: keyword.name,
        tail,
        text,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 453|    text=SOURCE_TEXT keyword=KW_REQUIRES tail=directive_tail EOF {
// 454|      @ast.WgslDirective::{
// 455|        kind: @ast.WgslDirectiveKind::Requires,
// 456|        name: keyword.name,
// 457|        tail,
// 458|        text,
// 459|      }
// 460|    }

///|
fn yy_action_63(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(text)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  guard _args[2].0 is YYObj_String(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      @ast.WgslDirective::{
        kind: @ast.WgslDirectiveKind::Requires,
        name: keyword.name,
        tail,
        text,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 215|    DIRECTIVE_TAIL { $1 }

///|
fn yy_action_64(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 461|    text=SOURCE_TEXT keyword=KW_DIAGNOSTIC tail=directive_tail EOF {
// 462|      @ast.WgslDirective::{
// 463|        kind: @ast.WgslDirectiveKind::Diagnostic,
// 464|        name: keyword.name,
// 465|        tail,
// 466|        text,
// 467|      }
// 468|    }

///|
fn yy_action_65(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(text)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  guard _args[2].0 is YYObj_String(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      @ast.WgslDirective::{
        kind: @ast.WgslDirectiveKind::Diagnostic,
        name: keyword.name,
        tail,
        text,
      }
    },
  )
}

// file:///./wgsl_parser.mbty
// 214|    { "" }

///|
fn yy_action_66(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_String(
    {
      ()
      ""
    },
  )
}

// file:///./wgsl_parser.mbty
// 472|    EXPR_REF EOF { $1 }

///|
fn yy_action_67(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslExprRef(_dollar1)
  YYObj__ast_WgslExprRef(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 74|    attributes EOF { $1 }

///|
fn yy_action_68(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(_dollar1)
  YYObj_Array__ast_WgslAttribute_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 94|    attributes attribute {
// 95|      let attributes = $1
// 96|      attributes.push($2)
// 97|      attributes
// 98|    }

///|
fn yy_action_69(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 102|    "@" name=ATTR_NAME args=attribute_args {
// 103|      let (arguments, arguments_ref) = args
// 104|      @ast.WgslAttribute::{ name, arguments, arguments_ref }
// 105|    }

///|
fn yy_action_70(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_String(name)
  guard _args[2].0 is YYObj__String___ast_WgslExprRef__(args)
  YYObj__ast_WgslAttribute(
    {
      ()
      let (arguments, arguments_ref) = args
      @ast.WgslAttribute::{ name, arguments, arguments_ref }
    },
  )
}

// file:///./wgsl_parser.mbty
// 110|    ATTR_ARGS { $1 }

///|
fn yy_action_71(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String___ast_WgslExprRef__(_dollar1)
  YYObj__String___ast_WgslExprRef__(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 109|    { ("", None) }

///|
fn yy_action_72(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__String___ast_WgslExprRef__(
    {
      ()
      ("", None)
    },
  )
}

// file:///./wgsl_parser.mbty
// 93|    { [] }

///|
fn yy_action_73(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslAttribute_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 78|    "{" statements "}" EOF {
// 79|      @ast.WgslBlock::{ statements: $2 }
// 80|    }

///|
fn yy_action_74(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslStatement_(_dollar2)
  YYObj__ast_WgslBlock(
    {
      ()
      @ast.WgslBlock::{ statements: _dollar2 }
    },
  )
}

// file:///./wgsl_parser.mbty
// 85|    statements STMT {
// 86|      let statements = $1
// 87|      statements.push($2)
// 88|      statements
// 89|    }

///|
fn yy_action_75(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 84|    { [] }

///|
fn yy_action_76(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
    ITEM(data) => (T_ITEM, YYObj__ast_WgslRawTopLevelItem(data))
    STMT(data) => (T_STMT, YYObj__ast_WgslStatement(data))
    IDENT(data) => (T_IDENT, YYObj_String(data))
    TYPE_ATOM(data) =>
      (T_TYPE_ATOM, YYObj__String__String__Int__Int__Int_(data))
    DECL_ATTRS(data) => (T_DECL_ATTRS, YYObj_Array__ast_WgslAttribute_(data))
    ARG_NAME(data) => (T_ARG_NAME, YYObj__ast_WgslIdent(data))
    ARG_TYPE(data) => (T_ARG_TYPE, YYObj__String___ast_WgslTypeRef__(data))
    MEMBER_NAME(data) => (T_MEMBER_NAME, YYObj__ast_WgslIdent(data))
    MEMBER_TYPE(data) =>
      (T_MEMBER_TYPE, YYObj__String___ast_WgslTypeRef__(data))
    DECL_TYPE(data) => (T_DECL_TYPE, YYObj__String___ast_WgslTypeRef__(data))
    INIT_EXPR(data) => (T_INIT_EXPR, YYObj__String___ast_WgslExprRef__(data))
    EXPR_REF(data) => (T_EXPR_REF, YYObj__ast_WgslExprRef(data))
    ATTR_NAME(data) => (T_ATTR_NAME, YYObj_String(data))
    ATTR_ARGS(data) => (T_ATTR_ARGS, YYObj__String___ast_WgslExprRef__(data))
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
    DIRECTIVE_HEAD(data) => (T_DIRECTIVE_HEAD, YYObj__String__String_(data))
    DIRECTIVE_TAIL(data) => (T_DIRECTIVE_TAIL, YYObj_String(data))
    SOURCE_TEXT(data) => (T_SOURCE_TEXT, YYObj_String(data))
    AT => (T_AT, YYObj_Void)
    HASH => (T_HASH, YYObj_Void)
    PREFIX => (T_PREFIX, YYObj_Void)
    AS => (T_AS, YYObj_Void)
    ARROW => (T_ARROW, YYObj_Void)
    LPAREN => (T_LPAREN, YYObj_Void)
    RPAREN => (T_RPAREN, YYObj_Void)
    LBRACE => (T_LBRACE, YYObj_Void)
    RBRACE => (T_RBRACE, YYObj_Void)
    COLON => (T_COLON, YYObj_Void)
    EQUAL => (T_EQUAL, YYObj_Void)
    TYPE_LT(data) => (T_TYPE_LT, YYObj_Int(data))
    TYPE_GT(data) => (T_TYPE_GT, YYObj_Int(data))
    COMMA => (T_COMMA, YYObj_Void)
    SEMI => (T_SEMI, YYObj_Void)
    EOF => (T_EOF, YYObj_Void)
  }
}

// [2, block → • LBRACE statements RBRACE EOF, $]
// [92, block_prime → • block, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_block => Shift(yy_state_1)
    T_LBRACE => Shift(yy_state_2)
    _ => Error
  }
}

// [92, block_prime → block •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [2, block → LBRACE • statements RBRACE EOF, $]
// [3, statements → •, STMT / RBRACE]
// [4, statements → • statements STMT, STMT / RBRACE]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_statements => Shift(yy_state_3)
    T_STMT | T_RBRACE => Reduce(0, NT_statements, yy_action_76)
    _ => Error
  }
}

// [2, block → LBRACE statements • RBRACE EOF, $]
// [4, statements → statements • STMT, STMT / RBRACE]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STMT => Shift(yy_state_4)
    T_RBRACE => Shift(yy_state_5)
    _ => Error
  }
}

// [4, statements → statements STMT •, STMT / RBRACE]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_statements, yy_action_75)
}

// [2, block → LBRACE statements RBRACE • EOF, $]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_6)
    _ => Error
  }
}

// [2, block → LBRACE statements RBRACE EOF •, $]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_block, yy_action_74)
}

// [1, attribute_list → • attributes EOF, $]
// [5, attributes → •, AT / EOF]
// [6, attributes → • attributes attribute, AT / EOF]
// [91, attribute_list_prime → • attribute_list, $]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute_list => Shift(yy_state_8)
    NT_attributes => Shift(yy_state_9)
    T_AT | T_EOF => Reduce(0, NT_attributes, yy_action_73)
    _ => Error
  }
}

// [91, attribute_list_prime → attribute_list •, $]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [1, attribute_list → attributes • EOF, $]
// [6, attributes → attributes • attribute, AT / EOF]
// [7, attribute → • AT ATTR_NAME attribute_args, AT / EOF]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_10)
    NT_attribute => Shift(yy_state_14)
    T_EOF => Shift(yy_state_15)
    _ => Error
  }
}

// [7, attribute → AT • ATTR_NAME attribute_args, AT / EOF]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ATTR_NAME => Shift(yy_state_11)
    _ => Error
  }
}

// [7, attribute → AT ATTR_NAME • attribute_args, AT / EOF]
// [8, attribute_args → •, AT / EOF]
// [9, attribute_args → • ATTR_ARGS, AT / EOF]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ATTR_ARGS => Shift(yy_state_12)
    NT_attribute_args => Shift(yy_state_13)
    T_AT | T_EOF => Reduce(0, NT_attribute_args, yy_action_72)
    _ => Error
  }
}

// [9, attribute_args → ATTR_ARGS •, AT / EOF]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_attribute_args, yy_action_71)
}

// [7, attribute → AT ATTR_NAME attribute_args •, AT / EOF]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_attribute, yy_action_70)
}

// [6, attributes → attributes attribute •, AT / EOF]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_attributes, yy_action_69)
}

// [1, attribute_list → attributes EOF •, $]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_attribute_list, yy_action_68)
}

// [57, const_assert_expr → • EXPR_REF EOF, $]
// [90, const_assert_expr_prime → • const_assert_expr, $]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_const_assert_expr => Shift(yy_state_17)
    T_EXPR_REF => Shift(yy_state_18)
    _ => Error
  }
}

// [90, const_assert_expr_prime → const_assert_expr •, $]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [57, const_assert_expr → EXPR_REF • EOF, $]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_19)
    _ => Error
  }
}

// [57, const_assert_expr → EXPR_REF EOF •, $]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_const_assert_expr, yy_action_67)
}

// [54, source_directive → • SOURCE_TEXT KW_ENABLE directive_tail EOF, $]
// [55, source_directive → • SOURCE_TEXT KW_REQUIRES directive_tail EOF, $]
// [56, source_directive → • SOURCE_TEXT KW_DIAGNOSTIC directive_tail EOF, $]
// [89, source_directive_prime → • source_directive, $]

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_source_directive => Shift(yy_state_21)
    T_SOURCE_TEXT => Shift(yy_state_22)
    _ => Error
  }
}

// [89, source_directive_prime → source_directive •, $]

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [54, source_directive → SOURCE_TEXT • KW_ENABLE directive_tail EOF, $]
// [55, source_directive → SOURCE_TEXT • KW_REQUIRES directive_tail EOF, $]
// [56, source_directive → SOURCE_TEXT • KW_DIAGNOSTIC directive_tail EOF, $]

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KW_DIAGNOSTIC => Shift(yy_state_23)
    T_KW_REQUIRES => Shift(yy_state_27)
    T_KW_ENABLE => Shift(yy_state_30)
    _ => Error
  }
}

// [25, directive_tail → •, EOF]
// [26, directive_tail → • DIRECTIVE_TAIL, EOF]
// [56, source_directive → SOURCE_TEXT KW_DIAGNOSTIC • directive_tail EOF, $]

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_tail => Shift(yy_state_24)
    T_DIRECTIVE_TAIL => Shift(yy_state_26)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_66)
    _ => Error
  }
}

// [56, source_directive → SOURCE_TEXT KW_DIAGNOSTIC directive_tail • EOF, $]

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_25)
    _ => Error
  }
}

// [56, source_directive → SOURCE_TEXT KW_DIAGNOSTIC directive_tail EOF •, $]

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_65)
}

// [26, directive_tail → DIRECTIVE_TAIL •, EOF]

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_directive_tail, yy_action_64)
}

// [25, directive_tail → •, EOF]
// [26, directive_tail → • DIRECTIVE_TAIL, EOF]
// [55, source_directive → SOURCE_TEXT KW_REQUIRES • directive_tail EOF, $]

///|
fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_26)
    NT_directive_tail => Shift(yy_state_28)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_66)
    _ => Error
  }
}

// [55, source_directive → SOURCE_TEXT KW_REQUIRES directive_tail • EOF, $]

///|
fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_29)
    _ => Error
  }
}

// [55, source_directive → SOURCE_TEXT KW_REQUIRES directive_tail EOF •, $]

///|
fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_63)
}

// [25, directive_tail → •, EOF]
// [26, directive_tail → • DIRECTIVE_TAIL, EOF]
// [54, source_directive → SOURCE_TEXT KW_ENABLE • directive_tail EOF, $]

///|
fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_26)
    NT_directive_tail => Shift(yy_state_31)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_66)
    _ => Error
  }
}

// [54, source_directive → SOURCE_TEXT KW_ENABLE directive_tail • EOF, $]

///|
fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_32)
    _ => Error
  }
}

// [54, source_directive → SOURCE_TEXT KW_ENABLE directive_tail EOF •, $]

///|
fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_62)
}

// [53, type_alias_tail → • EQUAL DECL_TYPE EOF, $]
// [88, type_alias_tail_prime → • type_alias_tail, $]

///|
fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_alias_tail => Shift(yy_state_34)
    T_EQUAL => Shift(yy_state_35)
    _ => Error
  }
}

// [88, type_alias_tail_prime → type_alias_tail •, $]

///|
fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [53, type_alias_tail → EQUAL • DECL_TYPE EOF, $]

///|
fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_TYPE => Shift(yy_state_36)
    _ => Error
  }
}

// [53, type_alias_tail → EQUAL DECL_TYPE • EOF, $]

///|
fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_37)
    _ => Error
  }
}

// [53, type_alias_tail → EQUAL DECL_TYPE EOF •, $]

///|
fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_alias_tail, yy_action_61)
}

// [50, typed_initializer_tail → • EOF, $]
// [51, typed_initializer_tail → • COLON DECL_TYPE initializer_opt EOF, $]
// [52, typed_initializer_tail → • initializer EOF, $]
// [60, initializer → • EQUAL INIT_EXPR, EOF]
// [87, typed_initializer_tail_prime → • typed_initializer_tail, $]

///|
fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_typed_initializer_tail => Shift(yy_state_39)
    T_EQUAL => Shift(yy_state_40)
    NT_initializer => Shift(yy_state_42)
    T_COLON => Shift(yy_state_44)
    T_EOF => Shift(yy_state_49)
    _ => Error
  }
}

// [87, typed_initializer_tail_prime → typed_initializer_tail •, $]

///|
fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [60, initializer → EQUAL • INIT_EXPR, EOF]

///|
fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INIT_EXPR => Shift(yy_state_41)
    _ => Error
  }
}

// [60, initializer → EQUAL INIT_EXPR •, EOF]

///|
fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_initializer, yy_action_60)
}

// [52, typed_initializer_tail → initializer • EOF, $]

///|
fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_43)
    _ => Error
  }
}

// [52, typed_initializer_tail → initializer EOF •, $]

///|
fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_typed_initializer_tail, yy_action_59)
}

// [51, typed_initializer_tail → COLON • DECL_TYPE initializer_opt EOF, $]

///|
fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_TYPE => Shift(yy_state_45)
    _ => Error
  }
}

// [51, typed_initializer_tail → COLON DECL_TYPE • initializer_opt EOF, $]
// [58, initializer_opt → •, EOF]
// [59, initializer_opt → • initializer, EOF]
// [60, initializer → • EQUAL INIT_EXPR, EOF]

///|
fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_40)
    NT_initializer => Shift(yy_state_46)
    NT_initializer_opt => Shift(yy_state_47)
    T_EOF => Reduce(0, NT_initializer_opt, yy_action_58)
    _ => Error
  }
}

// [59, initializer_opt → initializer •, EOF]

///|
fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_initializer_opt, yy_action_57)
}

// [51, typed_initializer_tail → COLON DECL_TYPE initializer_opt • EOF, $]

///|
fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_48)
    _ => Error
  }
}

// [51, typed_initializer_tail → COLON DECL_TYPE initializer_opt EOF •, $]

///|
fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_typed_initializer_tail, yy_action_56)
}

// [50, typed_initializer_tail → EOF •, $]

///|
fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_typed_initializer_tail, yy_action_55)
}

// [45, struct_members → • LBRACE RBRACE EOF, $]
// [46, struct_members → • LBRACE struct_member_list optional_member_separator RBRACE EOF, $]
// [86, struct_members_prime → • struct_members, $]

///|
fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_51)
    T_LBRACE => Shift(yy_state_52)
    _ => Error
  }
}

// [86, struct_members_prime → struct_members •, $]

///|
fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [45, struct_members → LBRACE • RBRACE EOF, $]
// [46, struct_members → LBRACE • struct_member_list optional_member_separator RBRACE EOF, $]
// [47, struct_member_list → • struct_member, RBRACE / COMMA / SEMI]
// [48, struct_member_list → • struct_member_list member_separator struct_member, RBRACE / COMMA / SEMI]
// [49, struct_member → • DECL_ATTRS MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_53)
    NT_struct_member => Shift(yy_state_57)
    NT_struct_member_list => Shift(yy_state_58)
    T_RBRACE => Shift(yy_state_66)
    _ => Error
  }
}

// [49, struct_member → DECL_ATTRS • MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_NAME => Shift(yy_state_54)
    _ => Error
  }
}

// [49, struct_member → DECL_ATTRS MEMBER_NAME • COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_55)
    _ => Error
  }
}

// [49, struct_member → DECL_ATTRS MEMBER_NAME COLON • MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_TYPE => Shift(yy_state_56)
    _ => Error
  }
}

// [49, struct_member → DECL_ATTRS MEMBER_NAME COLON MEMBER_TYPE •, RBRACE / COMMA / SEMI]

///|
fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_struct_member, yy_action_54)
}

// [47, struct_member_list → struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member_list, yy_action_53)
}

// [46, struct_members → LBRACE struct_member_list • optional_member_separator RBRACE EOF, $]
// [48, struct_member_list → struct_member_list • member_separator struct_member, RBRACE / COMMA / SEMI]
// [61, member_separator → • COMMA, DECL_ATTRS / RBRACE]
// [62, member_separator → • SEMI, DECL_ATTRS / RBRACE]
// [63, optional_member_separator → •, RBRACE]
// [64, optional_member_separator → • member_separator, RBRACE]

///|
fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_59)
    T_COMMA => Shift(yy_state_60)
    NT_member_separator => Shift(yy_state_61)
    NT_optional_member_separator => Shift(yy_state_63)
    T_RBRACE => Reduce(0, NT_optional_member_separator, yy_action_52)
    _ => Error
  }
}

// [62, member_separator → SEMI •, DECL_ATTRS / RBRACE]

///|
fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_51)
}

// [61, member_separator → COMMA •, DECL_ATTRS / RBRACE]

///|
fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_50)
}

// [48, struct_member_list → struct_member_list member_separator • struct_member, RBRACE / COMMA / SEMI]
// [49, struct_member → • DECL_ATTRS MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]
// [64, optional_member_separator → member_separator •, RBRACE]

///|
fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_53)
    NT_struct_member => Shift(yy_state_62)
    T_RBRACE => Reduce(1, NT_optional_member_separator, yy_action_49)
    _ => Error
  }
}

// [48, struct_member_list → struct_member_list member_separator struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_member_list, yy_action_48)
}

// [46, struct_members → LBRACE struct_member_list optional_member_separator • RBRACE EOF, $]

///|
fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_64)
    _ => Error
  }
}

// [46, struct_members → LBRACE struct_member_list optional_member_separator RBRACE • EOF, $]

///|
fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_65)
    _ => Error
  }
}

// [46, struct_members → LBRACE struct_member_list optional_member_separator RBRACE EOF •, $]

///|
fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_members, yy_action_47)
}

// [45, struct_members → LBRACE RBRACE • EOF, $]

///|
fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_67)
    _ => Error
  }
}

// [45, struct_members → LBRACE RBRACE EOF •, $]

///|
fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_members, yy_action_46)
}

// [44, function_result → • ARROW DECL_ATTRS ARG_TYPE EOF, $]
// [85, function_result_prime → • function_result, $]

///|
fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_result => Shift(yy_state_69)
    T_ARROW => Shift(yy_state_70)
    _ => Error
  }
}

// [85, function_result_prime → function_result •, $]

///|
fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [44, function_result → ARROW • DECL_ATTRS ARG_TYPE EOF, $]

///|
fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_71)
    _ => Error
  }
}

// [44, function_result → ARROW DECL_ATTRS • ARG_TYPE EOF, $]

///|
fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_TYPE => Shift(yy_state_72)
    _ => Error
  }
}

// [44, function_result → ARROW DECL_ATTRS ARG_TYPE • EOF, $]

///|
fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_73)
    _ => Error
  }
}

// [44, function_result → ARROW DECL_ATTRS ARG_TYPE EOF •, $]

///|
fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_result, yy_action_45)
}

// [42, function_args → • LPAREN RPAREN EOF, $]
// [43, function_args → • LPAREN function_arg_list optional_comma RPAREN EOF, $]
// [84, function_args_prime → • function_args, $]

///|
fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_args => Shift(yy_state_75)
    T_LPAREN => Shift(yy_state_76)
    _ => Error
  }
}

// [84, function_args_prime → function_args •, $]

///|
fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [42, function_args → LPAREN • RPAREN EOF, $]
// [43, function_args → LPAREN • function_arg_list optional_comma RPAREN EOF, $]
// [65, function_arg_list → • function_arg, RPAREN / COMMA]
// [66, function_arg_list → • function_arg_list COMMA function_arg, RPAREN / COMMA]
// [67, function_arg → • DECL_ATTRS ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_77)
    NT_function_arg => Shift(yy_state_81)
    NT_function_arg_list => Shift(yy_state_82)
    T_RPAREN => Shift(yy_state_88)
    _ => Error
  }
}

// [67, function_arg → DECL_ATTRS • ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_NAME => Shift(yy_state_78)
    _ => Error
  }
}

// [67, function_arg → DECL_ATTRS ARG_NAME • COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_79)
    _ => Error
  }
}

// [67, function_arg → DECL_ATTRS ARG_NAME COLON • ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_TYPE => Shift(yy_state_80)
    _ => Error
  }
}

// [67, function_arg → DECL_ATTRS ARG_NAME COLON ARG_TYPE •, RPAREN / COMMA]

///|
fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_arg, yy_action_44)
}

// [65, function_arg_list → function_arg •, RPAREN / COMMA]

///|
fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_arg_list, yy_action_43)
}

// [43, function_args → LPAREN function_arg_list • optional_comma RPAREN EOF, $]
// [66, function_arg_list → function_arg_list • COMMA function_arg, RPAREN / COMMA]
// [68, optional_comma → •, RPAREN]
// [69, optional_comma → • COMMA, RPAREN]

///|
fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_83)
    NT_optional_comma => Shift(yy_state_85)
    T_RPAREN => Reduce(0, NT_optional_comma, yy_action_42)
    _ => Error
  }
}

// [66, function_arg_list → function_arg_list COMMA • function_arg, RPAREN / COMMA]
// [67, function_arg → • DECL_ATTRS ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]
// [69, optional_comma → COMMA •, RPAREN]

///|
fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_77)
    NT_function_arg => Shift(yy_state_84)
    T_RPAREN => Reduce(1, NT_optional_comma, yy_action_41)
    _ => Error
  }
}

// [66, function_arg_list → function_arg_list COMMA function_arg •, RPAREN / COMMA]

///|
fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_arg_list, yy_action_40)
}

// [43, function_args → LPAREN function_arg_list optional_comma • RPAREN EOF, $]

///|
fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_86)
    _ => Error
  }
}

// [43, function_args → LPAREN function_arg_list optional_comma RPAREN • EOF, $]

///|
fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_87)
    _ => Error
  }
}

// [43, function_args → LPAREN function_arg_list optional_comma RPAREN EOF •, $]

///|
fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_args, yy_action_39)
}

// [42, function_args → LPAREN RPAREN • EOF, $]

///|
fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_89)
    _ => Error
  }
}

// [42, function_args → LPAREN RPAREN EOF •, $]

///|
fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_args, yy_action_38)
}

// [70, template_list → • TYPE_LT template_args TYPE_GT EOF, $]
// [83, template_list_prime → • template_list, $]

///|
fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_template_list => Shift(yy_state_91)
    T_TYPE_LT => Shift(yy_state_92)
    _ => Error
  }
}

// [83, template_list_prime → template_list •, $]

///|
fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [70, template_list → TYPE_LT • template_args TYPE_GT EOF, $]
// [71, template_args → • type_expr, TYPE_GT / COMMA]
// [72, template_args → • template_args COMMA type_expr, TYPE_GT / COMMA]
// [73, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [74, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_93)
    NT_type_expr => Shift(yy_state_100)
    NT_template_args => Shift(yy_state_101)
    _ => Error
  }
}

// [73, type_expr → TYPE_ATOM •, TYPE_GT / COMMA / EOF]
// [74, type_expr → TYPE_ATOM • TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]

///|
fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_LT => Shift(yy_state_94)
    T_TYPE_GT | T_COMMA | T_EOF => Reduce(1, NT_type_expr, yy_action_37)
    _ => Error
  }
}

// [73, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [74, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [74, type_expr → TYPE_ATOM TYPE_LT • type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]
// [75, type_ref_args → • type_expr, TYPE_GT / COMMA]
// [76, type_ref_args → • type_ref_args COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_93)
    NT_type_expr => Shift(yy_state_95)
    NT_type_ref_args => Shift(yy_state_96)
    _ => Error
  }
}

// [75, type_ref_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_ref_args, yy_action_36)
}

// [74, type_expr → TYPE_ATOM TYPE_LT type_ref_args • TYPE_GT, TYPE_GT / COMMA / EOF]
// [76, type_ref_args → type_ref_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_97)
    T_TYPE_GT => Shift(yy_state_99)
    _ => Error
  }
}

// [73, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [74, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [76, type_ref_args → type_ref_args COMMA • type_expr, TYPE_GT / COMMA]

///|
fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_93)
    NT_type_expr => Shift(yy_state_98)
    _ => Error
  }
}

// [76, type_ref_args → type_ref_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_ref_args, yy_action_35)
}

// [74, type_expr → TYPE_ATOM TYPE_LT type_ref_args TYPE_GT •, TYPE_GT / COMMA / EOF]

///|
fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_expr, yy_action_34)
}

// [71, template_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_template_args, yy_action_33)
}

// [70, template_list → TYPE_LT template_args • TYPE_GT EOF, $]
// [72, template_args → template_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_102)
    T_TYPE_GT => Shift(yy_state_104)
    _ => Error
  }
}

// [72, template_args → template_args COMMA • type_expr, TYPE_GT / COMMA]
// [73, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [74, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_93)
    NT_type_expr => Shift(yy_state_103)
    _ => Error
  }
}

// [72, template_args → template_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_template_args, yy_action_32)
}

// [70, template_list → TYPE_LT template_args TYPE_GT • EOF, $]

///|
fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_105)
    _ => Error
  }
}

// [70, template_list → TYPE_LT template_args TYPE_GT EOF •, $]

///|
fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_template_list, yy_action_31)
}

// [41, type_ref → • type_expr EOF, $]
// [73, type_expr → • TYPE_ATOM, EOF]
// [74, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, EOF]
// [82, type_ref_prime → • type_ref, $]

///|
fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_93)
    NT_type_ref => Shift(yy_state_107)
    NT_type_expr => Shift(yy_state_108)
    _ => Error
  }
}

// [82, type_ref_prime → type_ref •, $]

///|
fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [41, type_ref → type_expr • EOF, $]

///|
fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_109)
    _ => Error
  }
}

// [41, type_ref → type_expr EOF •, $]

///|
fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_ref, yy_action_30)
}

// [27, decl_head → • DECL_ATTRS KW_VIRTUAL KW_FN EOF, $]
// [28, decl_head → • DECL_ATTRS KW_OVERRIDE KW_FN EOF, $]
// [29, decl_head → • DECL_ATTRS KW_FN EOF, $]
// [30, decl_head → • DECL_ATTRS KW_OVERRIDE EOF, $]
// [31, decl_head → • DECL_ATTRS KW_VAR EOF, $]
// [32, decl_head → • DECL_ATTRS KW_STRUCT EOF, $]
// [33, decl_head → • DECL_ATTRS KW_CONST EOF, $]
// [34, decl_head → • DECL_ATTRS KW_CONST_ASSERT EOF, $]
// [35, decl_head → • DECL_ATTRS KW_ALIAS EOF, $]
// [36, decl_head → • DECL_ATTRS KW_TYPE EOF, $]
// [37, decl_head → • DECL_ATTRS KW_ENABLE EOF, $]
// [38, decl_head → • DECL_ATTRS KW_REQUIRES EOF, $]
// [39, decl_head → • DECL_ATTRS KW_DIAGNOSTIC EOF, $]
// [40, decl_head → • DECL_ATTRS EOF, $]
// [81, decl_head_prime → • decl_head, $]

///|
fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_decl_head => Shift(yy_state_111)
    T_DECL_ATTRS => Shift(yy_state_112)
    _ => Error
  }
}

// [81, decl_head_prime → decl_head •, $]

///|
fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [27, decl_head → DECL_ATTRS • KW_VIRTUAL KW_FN EOF, $]
// [28, decl_head → DECL_ATTRS • KW_OVERRIDE KW_FN EOF, $]
// [29, decl_head → DECL_ATTRS • KW_FN EOF, $]
// [30, decl_head → DECL_ATTRS • KW_OVERRIDE EOF, $]
// [31, decl_head → DECL_ATTRS • KW_VAR EOF, $]
// [32, decl_head → DECL_ATTRS • KW_STRUCT EOF, $]
// [33, decl_head → DECL_ATTRS • KW_CONST EOF, $]
// [34, decl_head → DECL_ATTRS • KW_CONST_ASSERT EOF, $]
// [35, decl_head → DECL_ATTRS • KW_ALIAS EOF, $]
// [36, decl_head → DECL_ATTRS • KW_TYPE EOF, $]
// [37, decl_head → DECL_ATTRS • KW_ENABLE EOF, $]
// [38, decl_head → DECL_ATTRS • KW_REQUIRES EOF, $]
// [39, decl_head → DECL_ATTRS • KW_DIAGNOSTIC EOF, $]
// [40, decl_head → DECL_ATTRS • EOF, $]

///|
fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_113)
    T_KW_DIAGNOSTIC => Shift(yy_state_114)
    T_KW_REQUIRES => Shift(yy_state_116)
    T_KW_ENABLE => Shift(yy_state_118)
    T_KW_TYPE => Shift(yy_state_120)
    T_KW_ALIAS => Shift(yy_state_122)
    T_KW_CONST_ASSERT => Shift(yy_state_124)
    T_KW_CONST => Shift(yy_state_126)
    T_KW_STRUCT => Shift(yy_state_128)
    T_KW_VAR => Shift(yy_state_130)
    T_KW_FN => Shift(yy_state_132)
    T_KW_OVERRIDE => Shift(yy_state_134)
    T_KW_VIRTUAL => Shift(yy_state_138)
    _ => Error
  }
}

// [40, decl_head → DECL_ATTRS EOF •, $]

///|
fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_decl_head, yy_action_29)
}

// [39, decl_head → DECL_ATTRS KW_DIAGNOSTIC • EOF, $]

///|
fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_115)
    _ => Error
  }
}

// [39, decl_head → DECL_ATTRS KW_DIAGNOSTIC EOF •, $]

///|
fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_28)
}

// [38, decl_head → DECL_ATTRS KW_REQUIRES • EOF, $]

///|
fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_117)
    _ => Error
  }
}

// [38, decl_head → DECL_ATTRS KW_REQUIRES EOF •, $]

///|
fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_27)
}

// [37, decl_head → DECL_ATTRS KW_ENABLE • EOF, $]

///|
fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_119)
    _ => Error
  }
}

// [37, decl_head → DECL_ATTRS KW_ENABLE EOF •, $]

///|
fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_26)
}

// [36, decl_head → DECL_ATTRS KW_TYPE • EOF, $]

///|
fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_121)
    _ => Error
  }
}

// [36, decl_head → DECL_ATTRS KW_TYPE EOF •, $]

///|
fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_25)
}

// [35, decl_head → DECL_ATTRS KW_ALIAS • EOF, $]

///|
fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_123)
    _ => Error
  }
}

// [35, decl_head → DECL_ATTRS KW_ALIAS EOF •, $]

///|
fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_24)
}

// [34, decl_head → DECL_ATTRS KW_CONST_ASSERT • EOF, $]

///|
fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_125)
    _ => Error
  }
}

// [34, decl_head → DECL_ATTRS KW_CONST_ASSERT EOF •, $]

///|
fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_23)
}

// [33, decl_head → DECL_ATTRS KW_CONST • EOF, $]

///|
fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_127)
    _ => Error
  }
}

// [33, decl_head → DECL_ATTRS KW_CONST EOF •, $]

///|
fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_22)
}

// [32, decl_head → DECL_ATTRS KW_STRUCT • EOF, $]

///|
fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_129)
    _ => Error
  }
}

// [32, decl_head → DECL_ATTRS KW_STRUCT EOF •, $]

///|
fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_21)
}

// [31, decl_head → DECL_ATTRS KW_VAR • EOF, $]

///|
fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_131)
    _ => Error
  }
}

// [31, decl_head → DECL_ATTRS KW_VAR EOF •, $]

///|
fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_20)
}

// [29, decl_head → DECL_ATTRS KW_FN • EOF, $]

///|
fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_133)
    _ => Error
  }
}

// [29, decl_head → DECL_ATTRS KW_FN EOF •, $]

///|
fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_19)
}

// [28, decl_head → DECL_ATTRS KW_OVERRIDE • KW_FN EOF, $]
// [30, decl_head → DECL_ATTRS KW_OVERRIDE • EOF, $]

///|
fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_135)
    T_KW_FN => Shift(yy_state_136)
    _ => Error
  }
}

// [30, decl_head → DECL_ATTRS KW_OVERRIDE EOF •, $]

///|
fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_18)
}

// [28, decl_head → DECL_ATTRS KW_OVERRIDE KW_FN • EOF, $]

///|
fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_137)
    _ => Error
  }
}

// [28, decl_head → DECL_ATTRS KW_OVERRIDE KW_FN EOF •, $]

///|
fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_decl_head, yy_action_17)
}

// [27, decl_head → DECL_ATTRS KW_VIRTUAL • KW_FN EOF, $]

///|
fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KW_FN => Shift(yy_state_139)
    _ => Error
  }
}

// [27, decl_head → DECL_ATTRS KW_VIRTUAL KW_FN • EOF, $]

///|
fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_140)
    _ => Error
  }
}

// [27, decl_head → DECL_ATTRS KW_VIRTUAL KW_FN EOF •, $]

///|
fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_decl_head, yy_action_16)
}

// [24, directive_prefix_tail → • HASH PREFIX directive_tail EOF, $]
// [80, directive_prefix_tail_prime → • directive_prefix_tail, $]

///|
fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_prefix_tail => Shift(yy_state_142)
    T_HASH => Shift(yy_state_143)
    _ => Error
  }
}

// [80, directive_prefix_tail_prime → directive_prefix_tail •, $]

///|
fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [24, directive_prefix_tail → HASH • PREFIX directive_tail EOF, $]

///|
fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PREFIX => Shift(yy_state_144)
    _ => Error
  }
}

// [24, directive_prefix_tail → HASH PREFIX • directive_tail EOF, $]
// [25, directive_tail → •, EOF]
// [26, directive_tail → • DIRECTIVE_TAIL, EOF]

///|
fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_26)
    NT_directive_tail => Shift(yy_state_145)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_66)
    _ => Error
  }
}

// [24, directive_prefix_tail → HASH PREFIX directive_tail • EOF, $]

///|
fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_146)
    _ => Error
  }
}

// [24, directive_prefix_tail → HASH PREFIX directive_tail EOF •, $]

///|
fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_directive_prefix_tail, yy_action_15)
}

// [23, directive_line → • HASH DIRECTIVE_HEAD directive_tail EOF, $]
// [79, directive_line_prime → • directive_line, $]

///|
fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_line => Shift(yy_state_148)
    T_HASH => Shift(yy_state_149)
    _ => Error
  }
}

// [79, directive_line_prime → directive_line •, $]

///|
fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [23, directive_line → HASH • DIRECTIVE_HEAD directive_tail EOF, $]

///|
fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_HEAD => Shift(yy_state_150)
    _ => Error
  }
}

// [23, directive_line → HASH DIRECTIVE_HEAD • directive_tail EOF, $]
// [25, directive_tail → •, EOF]
// [26, directive_tail → • DIRECTIVE_TAIL, EOF]

///|
fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_26)
    NT_directive_tail => Shift(yy_state_151)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_66)
    _ => Error
  }
}

// [23, directive_line → HASH DIRECTIVE_HEAD directive_tail • EOF, $]

///|
fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_152)
    _ => Error
  }
}

// [23, directive_line → HASH DIRECTIVE_HEAD directive_tail EOF •, $]

///|
fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_directive_line, yy_action_14)
}

// [12, import_targets → • target_list semis EOF, $]
// [13, import_targets → • IDENT target_list semis EOF, $]
// [16, target_list → • target, COMMA / SEMI / EOF]
// [17, target_list → • target_list COMMA target, COMMA / SEMI / EOF]
// [18, target_list → • target_list COMMA, COMMA / SEMI / EOF]
// [19, target → • IDENT alias, COMMA / SEMI / EOF]
// [20, target → • IDENT LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [78, import_targets_prime → • import_targets, $]

///|
fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_import_targets => Shift(yy_state_154)
    NT_target => Shift(yy_state_155)
    T_IDENT => Shift(yy_state_156)
    NT_target_list => Shift(yy_state_170)
    _ => Error
  }
}

// [78, import_targets_prime → import_targets •, $]

///|
fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [16, target_list → target •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_target_list, yy_action_13)
}

// [13, import_targets → IDENT • target_list semis EOF, $]
// [16, target_list → • target, COMMA / SEMI / EOF]
// [17, target_list → • target_list COMMA target, COMMA / SEMI / EOF]
// [18, target_list → • target_list COMMA, COMMA / SEMI / EOF]
// [19, target → • IDENT alias, COMMA / SEMI / EOF]
// [19, target → IDENT • alias, COMMA / SEMI / EOF]
// [20, target → • IDENT LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [20, target → IDENT • LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [21, alias → •, COMMA / SEMI / EOF]
// [22, alias → • AS IDENT, COMMA / SEMI / EOF]

///|
fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_target => Shift(yy_state_155)
    T_AS => Shift(yy_state_157)
    T_LBRACE => Shift(yy_state_159)
    T_IDENT => Shift(yy_state_160)
    NT_alias => Shift(yy_state_161)
    NT_target_list => Shift(yy_state_166)
    T_COMMA | T_SEMI | T_EOF => Reduce(0, NT_alias, yy_action_12)
    _ => Error
  }
}

// [22, alias → AS • IDENT, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_158)
    _ => Error
  }
}

// [22, alias → AS IDENT •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_alias, yy_action_11)
}

// [16, target_list → • target, RBRACE / COMMA]
// [17, target_list → • target_list COMMA target, RBRACE / COMMA]
// [18, target_list → • target_list COMMA, RBRACE / COMMA]
// [19, target → • IDENT alias, RBRACE / COMMA]
// [20, target → • IDENT LBRACE target_list RBRACE, RBRACE / COMMA]
// [20, target → IDENT LBRACE • target_list RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_target => Shift(yy_state_155)
    T_IDENT => Shift(yy_state_160)
    NT_target_list => Shift(yy_state_162)
    _ => Error
  }
}

// [19, target → IDENT • alias, RBRACE / COMMA / SEMI / EOF]
// [20, target → IDENT • LBRACE target_list RBRACE, RBRACE / COMMA / SEMI / EOF]
// [21, alias → •, RBRACE / COMMA / SEMI / EOF]
// [22, alias → • AS IDENT, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AS => Shift(yy_state_157)
    T_LBRACE => Shift(yy_state_159)
    NT_alias => Shift(yy_state_161)
    T_RBRACE | T_COMMA | T_SEMI | T_EOF => Reduce(0, NT_alias, yy_action_12)
    _ => Error
  }
}

// [19, target → IDENT alias •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_target, yy_action_10)
}

// [17, target_list → target_list • COMMA target, RBRACE / COMMA]
// [18, target_list → target_list • COMMA, RBRACE / COMMA]
// [20, target → IDENT LBRACE target_list • RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_163)
    T_COMMA => Shift(yy_state_164)
    _ => Error
  }
}

// [20, target → IDENT LBRACE target_list RBRACE •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_target, yy_action_9)
}

// [17, target_list → target_list COMMA • target, RBRACE / COMMA / SEMI / EOF]
// [18, target_list → target_list COMMA •, RBRACE / COMMA / SEMI / EOF]
// [19, target → • IDENT alias, RBRACE / COMMA / SEMI / EOF]
// [20, target → • IDENT LBRACE target_list RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_160)
    NT_target => Shift(yy_state_165)
    T_RBRACE | T_COMMA | T_SEMI | T_EOF =>
      Reduce(2, NT_target_list, yy_action_8)
    _ => Error
  }
}

// [17, target_list → target_list COMMA target •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_target_list, yy_action_7)
}

// [13, import_targets → IDENT target_list • semis EOF, $]
// [14, semis → •, SEMI / EOF]
// [15, semis → • semis SEMI, SEMI / EOF]
// [17, target_list → target_list • COMMA target, COMMA / SEMI / EOF]
// [18, target_list → target_list • COMMA, COMMA / SEMI / EOF]

///|
fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_164)
    NT_semis => Shift(yy_state_167)
    T_SEMI | T_EOF => Reduce(0, NT_semis, yy_action_6)
    _ => Error
  }
}

// [13, import_targets → IDENT target_list semis • EOF, $]
// [15, semis → semis • SEMI, SEMI / EOF]

///|
fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_168)
    T_EOF => Shift(yy_state_169)
    _ => Error
  }
}

// [15, semis → semis SEMI •, SEMI / EOF]

///|
fn yy_state_168(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semis, yy_action_5)
}

// [13, import_targets → IDENT target_list semis EOF •, $]

///|
fn yy_state_169(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_import_targets, yy_action_4)
}

// [12, import_targets → target_list • semis EOF, $]
// [14, semis → •, SEMI / EOF]
// [15, semis → • semis SEMI, SEMI / EOF]
// [17, target_list → target_list • COMMA target, COMMA / SEMI / EOF]
// [18, target_list → target_list • COMMA, COMMA / SEMI / EOF]

///|
fn yy_state_170(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_164)
    NT_semis => Shift(yy_state_171)
    T_SEMI | T_EOF => Reduce(0, NT_semis, yy_action_6)
    _ => Error
  }
}

// [12, import_targets → target_list semis • EOF, $]
// [15, semis → semis • SEMI, SEMI / EOF]

///|
fn yy_state_171(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_168)
    T_EOF => Shift(yy_state_172)
    _ => Error
  }
}

// [12, import_targets → target_list semis EOF •, $]

///|
fn yy_state_172(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_targets, yy_action_3)
}

// [0, raw_top_level_items → • items EOF, $]
// [10, items → •, ITEM / EOF]
// [11, items → • items ITEM, ITEM / EOF]
// [77, raw_top_level_items_prime → • raw_top_level_items, $]

///|
fn yy_state_173(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_raw_top_level_items => Shift(yy_state_174)
    NT_items => Shift(yy_state_175)
    T_ITEM | T_EOF => Reduce(0, NT_items, yy_action_2)
    _ => Error
  }
}

// [77, raw_top_level_items_prime → raw_top_level_items •, $]

///|
fn yy_state_174(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [0, raw_top_level_items → items • EOF, $]
// [11, items → items • ITEM, ITEM / EOF]

///|
fn yy_state_175(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ITEM => Shift(yy_state_176)
    T_EOF => Shift(yy_state_177)
    _ => Error
  }
}

// [11, items → items ITEM •, ITEM / EOF]

///|
fn yy_state_176(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_items, yy_action_1)
}

// [0, raw_top_level_items → items EOF •, $]

///|
fn yy_state_177(_lookahead : YYSymbol) -> YYDecision {
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
        (T_IDENT, TK_IDENT),
        (T_TYPE_ATOM, TK_TYPE_ATOM),
        (T_DECL_ATTRS, TK_DECL_ATTRS),
        (T_ARG_NAME, TK_ARG_NAME),
        (T_ARG_TYPE, TK_ARG_TYPE),
        (T_MEMBER_NAME, TK_MEMBER_NAME),
        (T_MEMBER_TYPE, TK_MEMBER_TYPE),
        (T_DECL_TYPE, TK_DECL_TYPE),
        (T_INIT_EXPR, TK_INIT_EXPR),
        (T_EXPR_REF, TK_EXPR_REF),
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
        (T_DIRECTIVE_HEAD, TK_DIRECTIVE_HEAD),
        (T_DIRECTIVE_TAIL, TK_DIRECTIVE_TAIL),
        (T_SOURCE_TEXT, TK_SOURCE_TEXT),
        (T_AT, TK_AT),
        (T_HASH, TK_HASH),
        (T_PREFIX, TK_PREFIX),
        (T_AS, TK_AS),
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
pub fn raw_top_level_items(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[@ast.WgslRawTopLevelItem] raise ParseError {
  yy_parse(
    tokens,
    yy_state_173,
    it => {
      guard it is YYObj_Array__ast_WgslRawTopLevelItem_(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn import_targets(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[@common.WgslImportTarget] raise ParseError {
  yy_parse(
    tokens,
    yy_state_153,
    it => {
      guard it is YYObj_Array__common_WgslImportTarget_(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn directive_line(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslDirective raise ParseError {
  yy_parse(
    tokens,
    yy_state_147,
    it => {
      guard it is YYObj__ast_WgslDirective(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn directive_prefix_tail(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> String raise ParseError {
  yy_parse(
    tokens,
    yy_state_141,
    it => {
      guard it is YYObj_String(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn decl_head(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslDeclHead raise ParseError {
  yy_parse(
    tokens,
    yy_state_110,
    it => {
      guard it is YYObj__ast_WgslDeclHead(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn type_ref(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslTypeRef raise ParseError {
  yy_parse(
    tokens,
    yy_state_106,
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
) -> Array[String] raise ParseError {
  yy_parse(
    tokens,
    yy_state_90,
    it => {
      guard it is YYObj_Array_String_(result)
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
    yy_state_74,
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
    yy_state_68,
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
    yy_state_50,
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
) -> (String?, @ast.WgslTypeRef?, String?, @ast.WgslExprRef?) raise ParseError {
  yy_parse(
    tokens,
    yy_state_38,
    it => {
      guard it
        is YYObj__String____ast_WgslTypeRef___String____ast_WgslExprRef__(
          result
        )
      result
    },
    initial_pos?,
  )
}

///|
pub fn type_alias_tail(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> (String, @ast.WgslTypeRef?) raise ParseError {
  yy_parse(
    tokens,
    yy_state_33,
    it => {
      guard it is YYObj__String___ast_WgslTypeRef__(result)
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
    yy_state_20,
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
    yy_state_16,
    it => {
      guard it is YYObj__ast_WgslExprRef(result)
      result
    },
    initial_pos?,
  )
}

///|
pub fn attribute_list(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[@ast.WgslAttribute] raise ParseError {
  yy_parse(
    tokens,
    yy_state_7,
    it => {
      guard it is YYObj_Array__ast_WgslAttribute_(result)
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
fn wgsl_type_ref_text(
  source : String,
  source_start : Int,
  start : Int,
  end_ : Int,
) -> String {
  let local_start = start - source_start
  let local_end = end_ - source_start
  if local_start < 0 || local_end < local_start || local_end > source.length() {
    return ""
  }
  source[local_start:local_end].to_owned()
}

///|
fn wgsl_type_ref_from_atom(
  atom : (String, String, Int, Int, Int),
  arguments : Array[@ast.WgslTypeRef],
  end_ : Int,
) -> @ast.WgslTypeRef {
  let (name, source, source_start, start, _) = atom
  @ast.WgslTypeRef::{
    name,
    arguments,
    text: wgsl_type_ref_text(source, source_start, start, end_),
    start,
    end: end_,
  }
}
