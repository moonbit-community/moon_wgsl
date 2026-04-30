///|
pub(all) enum Token {
  ITEM(@ast.WgslRawTopLevelItem)
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
priv suberror YYObj__ast_WgslDirective {
  YYObj__ast_WgslDirective(@ast.WgslDirective)
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
// 64|    items EOF { $1 }

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
// 69|    items ITEM {
// 70|      let items = $1
// 71|      items.push($2)
// 72|      items
// 73|    }

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
// 68|    { [] }

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
// 77|    target_list semis EOF { $1 }

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
// 78|    module_path=IDENT targets=target_list semis EOF {
// 79|      let out : Array[@common.WgslImportTarget] = []
// 80|      for target in targets {
// 81|        let sep = if module_path.has_suffix("::") || target.raw_path == "" {
// 82|          ""
// 83|        } else {
// 84|          "::"
// 85|        }
// 86|        out.push(@common.WgslImportTarget::{
// 87|          raw_path: module_path + sep + target.raw_path,
// 88|          alias_name: target.alias_name,
// 89|        })
// 90|      }
// 91|      out
// 92|    }

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
// 97|    semis ";" { () }

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
// 96|    { () }

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
// 104|    target_list "," target {
// 105|      let targets = $1
// 106|      for target in $3 {
// 107|        targets.push(target)
// 108|      }
// 109|      targets
// 110|    }

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
// 111|    target_list "," {
// 112|      $1
// 113|    }

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
// 120|    module_path=IDENT "{" targets=target_list "}" {
// 121|      let out : Array[@common.WgslImportTarget] = []
// 122|      for target in targets {
// 123|        let sep = if module_path.has_suffix("::") || target.raw_path == "" {
// 124|          ""
// 125|        } else {
// 126|          "::"
// 127|        }
// 128|        out.push(@common.WgslImportTarget::{
// 129|          raw_path: module_path + sep + target.raw_path,
// 130|          alias_name: target.alias_name,
// 131|        })
// 132|      }
// 133|      out
// 134|    }

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
// 117|    path=IDENT alias_name=alias {
// 118|      [@common.WgslImportTarget::{ raw_path: path, alias_name }]
// 119|    }

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
// 139|    "as" name=IDENT { name }

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
// 138|    { "" }

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
// 101|    target {
// 102|      $1
// 103|    }

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
// 143|    "#" head=DIRECTIVE_HEAD tail=directive_tail EOF {
// 144|      let (name, text) = head
// 145|      let kind = match name {
// 146|        "ifdef" => @ast.WgslDirectiveKind::Ifdef
// 147|        "ifndef" => @ast.WgslDirectiveKind::Ifndef
// 148|        "if" => @ast.WgslDirectiveKind::If
// 149|        "else" => @ast.WgslDirectiveKind::Else
// 150|        "endif" => @ast.WgslDirectiveKind::Endif
// 151|        "define_import_path" => @ast.WgslDirectiveKind::DefineImportPath
// 152|        "define" => @ast.WgslDirectiveKind::Define
// 153|        "import" => @ast.WgslDirectiveKind::Import
// 154|        "enable" => @ast.WgslDirectiveKind::Enable
// 155|        "requires" => @ast.WgslDirectiveKind::Requires
// 156|        "diagnostic" => @ast.WgslDirectiveKind::Diagnostic
// 157|        _ => @ast.WgslDirectiveKind::Other(name)
// 158|      }
// 159|      @ast.WgslDirective::{ kind, name, tail, text }
// 160|    }

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
// 164|    "#" PREFIX tail=directive_tail EOF { tail }

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
// 173|    attrs=DECL_ATTRS KW_VIRTUAL fn_kw=KW_FN EOF {
// 174|      @ast.WgslDeclHead::{
// 175|        kind: @ast.WgslDeclHeadKind::Function,
// 176|        attributes: attrs,
// 177|        keyword: Some(fn_kw),
// 178|        qualifier: "virtual",
// 179|        qualifier_start: Some($2.start),
// 180|        qualifier_end: Some($2.end),
// 181|        fn_keyword: Some(fn_kw),
// 182|        consumed: 2,
// 183|      }
// 184|    }

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
// 185|    attrs=DECL_ATTRS KW_OVERRIDE fn_kw=KW_FN EOF {
// 186|      @ast.WgslDeclHead::{
// 187|        kind: @ast.WgslDeclHeadKind::Function,
// 188|        attributes: attrs,
// 189|        keyword: Some(fn_kw),
// 190|        qualifier: "override",
// 191|        qualifier_start: Some($2.start),
// 192|        qualifier_end: Some($2.end),
// 193|        fn_keyword: Some(fn_kw),
// 194|        consumed: 2,
// 195|      }
// 196|    }

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
// 209|    attrs=DECL_ATTRS keyword=KW_OVERRIDE EOF {
// 210|      @ast.WgslDeclHead::{
// 211|        kind: @ast.WgslDeclHeadKind::Override,
// 212|        attributes: attrs,
// 213|        keyword: Some(keyword),
// 214|        qualifier: "",
// 215|        qualifier_start: None,
// 216|        qualifier_end: None,
// 217|        fn_keyword: None,
// 218|        consumed: 1,
// 219|      }
// 220|    }

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
// 197|    attrs=DECL_ATTRS keyword=KW_FN EOF {
// 198|      @ast.WgslDeclHead::{
// 199|        kind: @ast.WgslDeclHeadKind::Function,
// 200|        attributes: attrs,
// 201|        keyword: Some(keyword),
// 202|        qualifier: "",
// 203|        qualifier_start: None,
// 204|        qualifier_end: None,
// 205|        fn_keyword: Some(keyword),
// 206|        consumed: 1,
// 207|      }
// 208|    }

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
// 221|    attrs=DECL_ATTRS keyword=KW_VAR EOF {
// 222|      @ast.WgslDeclHead::{
// 223|        kind: @ast.WgslDeclHeadKind::GlobalVariable,
// 224|        attributes: attrs,
// 225|        keyword: Some(keyword),
// 226|        qualifier: "",
// 227|        qualifier_start: None,
// 228|        qualifier_end: None,
// 229|        fn_keyword: None,
// 230|        consumed: 1,
// 231|      }
// 232|    }

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
// 233|    attrs=DECL_ATTRS keyword=KW_STRUCT EOF {
// 234|      @ast.WgslDeclHead::{
// 235|        kind: @ast.WgslDeclHeadKind::Struct,
// 236|        attributes: attrs,
// 237|        keyword: Some(keyword),
// 238|        qualifier: "",
// 239|        qualifier_start: None,
// 240|        qualifier_end: None,
// 241|        fn_keyword: None,
// 242|        consumed: 1,
// 243|      }
// 244|    }

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
// 245|    attrs=DECL_ATTRS keyword=KW_CONST EOF {
// 246|      @ast.WgslDeclHead::{
// 247|        kind: @ast.WgslDeclHeadKind::Const,
// 248|        attributes: attrs,
// 249|        keyword: Some(keyword),
// 250|        qualifier: "",
// 251|        qualifier_start: None,
// 252|        qualifier_end: None,
// 253|        fn_keyword: None,
// 254|        consumed: 1,
// 255|      }
// 256|    }

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
// 257|    attrs=DECL_ATTRS keyword=KW_CONST_ASSERT EOF {
// 258|      @ast.WgslDeclHead::{
// 259|        kind: @ast.WgslDeclHeadKind::ConstAssert,
// 260|        attributes: attrs,
// 261|        keyword: Some(keyword),
// 262|        qualifier: "",
// 263|        qualifier_start: None,
// 264|        qualifier_end: None,
// 265|        fn_keyword: None,
// 266|        consumed: 1,
// 267|      }
// 268|    }

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
// 269|    attrs=DECL_ATTRS keyword=KW_ALIAS EOF {
// 270|      @ast.WgslDeclHead::{
// 271|        kind: @ast.WgslDeclHeadKind::TypeAlias,
// 272|        attributes: attrs,
// 273|        keyword: Some(keyword),
// 274|        qualifier: "",
// 275|        qualifier_start: None,
// 276|        qualifier_end: None,
// 277|        fn_keyword: None,
// 278|        consumed: 1,
// 279|      }
// 280|    }

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
// 281|    attrs=DECL_ATTRS keyword=KW_TYPE EOF {
// 282|      @ast.WgslDeclHead::{
// 283|        kind: @ast.WgslDeclHeadKind::TypeAlias,
// 284|        attributes: attrs,
// 285|        keyword: Some(keyword),
// 286|        qualifier: "",
// 287|        qualifier_start: None,
// 288|        qualifier_end: None,
// 289|        fn_keyword: None,
// 290|        consumed: 1,
// 291|      }
// 292|    }

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
// 293|    attrs=DECL_ATTRS keyword=KW_ENABLE EOF {
// 294|      @ast.WgslDeclHead::{
// 295|        kind: @ast.WgslDeclHeadKind::SourceDirective(@ast.WgslDirectiveKind::Enable),
// 296|        attributes: attrs,
// 297|        keyword: Some(keyword),
// 298|        qualifier: "",
// 299|        qualifier_start: None,
// 300|        qualifier_end: None,
// 301|        fn_keyword: None,
// 302|        consumed: 1,
// 303|      }
// 304|    }

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
// 305|    attrs=DECL_ATTRS keyword=KW_REQUIRES EOF {
// 306|      @ast.WgslDeclHead::{
// 307|        kind: @ast.WgslDeclHeadKind::SourceDirective(@ast.WgslDirectiveKind::Requires),
// 308|        attributes: attrs,
// 309|        keyword: Some(keyword),
// 310|        qualifier: "",
// 311|        qualifier_start: None,
// 312|        qualifier_end: None,
// 313|        fn_keyword: None,
// 314|        consumed: 1,
// 315|      }
// 316|    }

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
// 317|    attrs=DECL_ATTRS keyword=KW_DIAGNOSTIC EOF {
// 318|      @ast.WgslDeclHead::{
// 319|        kind: @ast.WgslDeclHeadKind::SourceDirective(@ast.WgslDirectiveKind::Diagnostic),
// 320|        attributes: attrs,
// 321|        keyword: Some(keyword),
// 322|        qualifier: "",
// 323|        qualifier_start: None,
// 324|        qualifier_end: None,
// 325|        fn_keyword: None,
// 326|        consumed: 1,
// 327|      }
// 328|    }

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
// 329|    attrs=DECL_ATTRS EOF {
// 330|      @ast.WgslDeclHead::raw(attrs)
// 331|    }

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
// 335|    value=type_expr EOF { value }

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
// 481|    TYPE_LT args=template_args TYPE_GT EOF { args }

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
// 488|    args=template_args "," value=type_expr {
// 489|      args.push(value.text)
// 490|      args
// 491|    }

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
// 485|    value=type_expr {
// 486|      [value.text]
// 487|    }

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
// 498|    atom=TYPE_ATOM TYPE_LT args=type_ref_args gt=TYPE_GT {
// 499|      wgsl_type_ref_from_atom(atom, args, gt)
// 500|    }

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
// 507|    args=type_ref_args "," value=type_expr {
// 508|      args.push(value)
// 509|      args
// 510|    }

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
// 504|    value=type_expr {
// 505|      [value]
// 506|    }

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
// 495|    atom=TYPE_ATOM {
// 496|      wgsl_type_ref_from_atom(atom, [], atom.4)
// 497|    }

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
// 339|    "(" ")" EOF { [] }

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
// 340|    "(" args=function_arg_list optional_comma ")" EOF { args }

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
// 455|    args=function_arg_list "," value=function_arg {
// 456|      args.push(value)
// 457|      args
// 458|    }

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
// 477|    "," { () }

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
// 476|    { () }

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
// 452|    value=function_arg {
// 453|      [value]
// 454|    }

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
// 462|    attrs=DECL_ATTRS name=ARG_NAME ":" ty=ARG_TYPE {
// 463|      let (ty_text, ty_ref) = ty
// 464|      @ast.WgslFunctionArgument::{
// 465|        attributes: attrs,
// 466|        name: name.name,
// 467|        name_start: name.start,
// 468|        name_end: name.end,
// 469|        ty: ty_text,
// 470|        ty_ref,
// 471|      }
// 472|    }

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
// 344|    "->" attrs=DECL_ATTRS ty=ARG_TYPE EOF {
// 345|      let (ty_text, ty_ref) = ty
// 346|      Some(@ast.WgslFunctionResult::{ attributes: attrs, ty: ty_text, ty_ref })
// 347|    }

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
// 351|    "{" "}" EOF { [] }

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
// 352|    "{" members=struct_member_list optional_member_separator "}" EOF {
// 353|      members
// 354|    }

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
// 361|    members=struct_member_list member_separator value=struct_member {
// 362|      members.push(value)
// 363|      members
// 364|    }

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
// 448|    member_separator { () }

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
// 442|    "," { () }

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
// 443|    ";" { () }

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
// 447|    { () }

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
// 358|    value=struct_member {
// 359|      [value]
// 360|    }

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
// 368|    attrs=DECL_ATTRS name=MEMBER_NAME ":" ty=MEMBER_TYPE {
// 369|      let (ty_text, ty_ref) = ty
// 370|      @ast.WgslStructMember::{
// 371|        attributes: attrs,
// 372|        name: name.name,
// 373|        name_start: name.start,
// 374|        name_end: name.end,
// 375|        ty: ty_text,
// 376|        ty_ref,
// 377|      }
// 378|    }

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
// 382|    EOF { (None, None, None, None) }

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
// 383|    ":" ty=DECL_TYPE init=initializer_opt EOF {
// 384|      let (ty_text, ty_ref) = ty
// 385|      let (init_text, init_ref) = init
// 386|      (Some(ty_text), ty_ref, init_text, init_ref)
// 387|    }

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
// 431|    initializer { $1 }

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
// 430|    { (None, None) }

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
// 388|    init=initializer EOF {
// 389|      let (init_text, init_ref) = init
// 390|      (None, None, init_text, init_ref)
// 391|    }

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
// 435|    "=" expr=INIT_EXPR {
// 436|      let (text, expr_ref) = expr
// 437|      (Some(text), expr_ref)
// 438|    }

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
// 395|    "=" ty=DECL_TYPE EOF { ty }

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
// 399|    text=SOURCE_TEXT keyword=KW_ENABLE tail=directive_tail EOF {
// 400|      @ast.WgslDirective::{
// 401|        kind: @ast.WgslDirectiveKind::Enable,
// 402|        name: keyword.name,
// 403|        tail,
// 404|        text,
// 405|      }
// 406|    }

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
// 407|    text=SOURCE_TEXT keyword=KW_REQUIRES tail=directive_tail EOF {
// 408|      @ast.WgslDirective::{
// 409|        kind: @ast.WgslDirectiveKind::Requires,
// 410|        name: keyword.name,
// 411|        tail,
// 412|        text,
// 413|      }
// 414|    }

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
// 169|    DIRECTIVE_TAIL { $1 }

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
// 415|    text=SOURCE_TEXT keyword=KW_DIAGNOSTIC tail=directive_tail EOF {
// 416|      @ast.WgslDirective::{
// 417|        kind: @ast.WgslDirectiveKind::Diagnostic,
// 418|        name: keyword.name,
// 419|        tail,
// 420|        text,
// 421|      }
// 422|    }

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
// 168|    { "" }

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
// 426|    EXPR_REF EOF { $1 }

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

///|
fn yy_input(
  token : Token,
  _start_pos : Int,
  _end_pos : Int,
) -> (YYSymbol, YYObj) {
  match token {
    ITEM(data) => (T_ITEM, YYObj__ast_WgslRawTopLevelItem(data))
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

// [48, const_assert_expr → • EXPR_REF EOF, $]
// [81, const_assert_expr_prime → • const_assert_expr, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_const_assert_expr => Shift(yy_state_1)
    T_EXPR_REF => Shift(yy_state_2)
    _ => Error
  }
}

// [81, const_assert_expr_prime → const_assert_expr •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [48, const_assert_expr → EXPR_REF • EOF, $]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_3)
    _ => Error
  }
}

// [48, const_assert_expr → EXPR_REF EOF •, $]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_const_assert_expr, yy_action_67)
}

// [45, source_directive → • SOURCE_TEXT KW_ENABLE directive_tail EOF, $]
// [46, source_directive → • SOURCE_TEXT KW_REQUIRES directive_tail EOF, $]
// [47, source_directive → • SOURCE_TEXT KW_DIAGNOSTIC directive_tail EOF, $]
// [80, source_directive_prime → • source_directive, $]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_source_directive => Shift(yy_state_5)
    T_SOURCE_TEXT => Shift(yy_state_6)
    _ => Error
  }
}

// [80, source_directive_prime → source_directive •, $]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [45, source_directive → SOURCE_TEXT • KW_ENABLE directive_tail EOF, $]
// [46, source_directive → SOURCE_TEXT • KW_REQUIRES directive_tail EOF, $]
// [47, source_directive → SOURCE_TEXT • KW_DIAGNOSTIC directive_tail EOF, $]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KW_DIAGNOSTIC => Shift(yy_state_7)
    T_KW_REQUIRES => Shift(yy_state_11)
    T_KW_ENABLE => Shift(yy_state_14)
    _ => Error
  }
}

// [16, directive_tail → •, EOF]
// [17, directive_tail → • DIRECTIVE_TAIL, EOF]
// [47, source_directive → SOURCE_TEXT KW_DIAGNOSTIC • directive_tail EOF, $]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_tail => Shift(yy_state_8)
    T_DIRECTIVE_TAIL => Shift(yy_state_10)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_66)
    _ => Error
  }
}

// [47, source_directive → SOURCE_TEXT KW_DIAGNOSTIC directive_tail • EOF, $]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_9)
    _ => Error
  }
}

// [47, source_directive → SOURCE_TEXT KW_DIAGNOSTIC directive_tail EOF •, $]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_65)
}

// [17, directive_tail → DIRECTIVE_TAIL •, EOF]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_directive_tail, yy_action_64)
}

// [16, directive_tail → •, EOF]
// [17, directive_tail → • DIRECTIVE_TAIL, EOF]
// [46, source_directive → SOURCE_TEXT KW_REQUIRES • directive_tail EOF, $]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_10)
    NT_directive_tail => Shift(yy_state_12)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_66)
    _ => Error
  }
}

// [46, source_directive → SOURCE_TEXT KW_REQUIRES directive_tail • EOF, $]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_13)
    _ => Error
  }
}

// [46, source_directive → SOURCE_TEXT KW_REQUIRES directive_tail EOF •, $]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_63)
}

// [16, directive_tail → •, EOF]
// [17, directive_tail → • DIRECTIVE_TAIL, EOF]
// [45, source_directive → SOURCE_TEXT KW_ENABLE • directive_tail EOF, $]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_10)
    NT_directive_tail => Shift(yy_state_15)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_66)
    _ => Error
  }
}

// [45, source_directive → SOURCE_TEXT KW_ENABLE directive_tail • EOF, $]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_16)
    _ => Error
  }
}

// [45, source_directive → SOURCE_TEXT KW_ENABLE directive_tail EOF •, $]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_62)
}

// [44, type_alias_tail → • EQUAL DECL_TYPE EOF, $]
// [79, type_alias_tail_prime → • type_alias_tail, $]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_alias_tail => Shift(yy_state_18)
    T_EQUAL => Shift(yy_state_19)
    _ => Error
  }
}

// [79, type_alias_tail_prime → type_alias_tail •, $]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [44, type_alias_tail → EQUAL • DECL_TYPE EOF, $]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_TYPE => Shift(yy_state_20)
    _ => Error
  }
}

// [44, type_alias_tail → EQUAL DECL_TYPE • EOF, $]

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_21)
    _ => Error
  }
}

// [44, type_alias_tail → EQUAL DECL_TYPE EOF •, $]

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_alias_tail, yy_action_61)
}

// [41, typed_initializer_tail → • EOF, $]
// [42, typed_initializer_tail → • COLON DECL_TYPE initializer_opt EOF, $]
// [43, typed_initializer_tail → • initializer EOF, $]
// [51, initializer → • EQUAL INIT_EXPR, EOF]
// [78, typed_initializer_tail_prime → • typed_initializer_tail, $]

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_typed_initializer_tail => Shift(yy_state_23)
    T_EQUAL => Shift(yy_state_24)
    NT_initializer => Shift(yy_state_26)
    T_COLON => Shift(yy_state_28)
    T_EOF => Shift(yy_state_33)
    _ => Error
  }
}

// [78, typed_initializer_tail_prime → typed_initializer_tail •, $]

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [51, initializer → EQUAL • INIT_EXPR, EOF]

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INIT_EXPR => Shift(yy_state_25)
    _ => Error
  }
}

// [51, initializer → EQUAL INIT_EXPR •, EOF]

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_initializer, yy_action_60)
}

// [43, typed_initializer_tail → initializer • EOF, $]

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_27)
    _ => Error
  }
}

// [43, typed_initializer_tail → initializer EOF •, $]

///|
fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_typed_initializer_tail, yy_action_59)
}

// [42, typed_initializer_tail → COLON • DECL_TYPE initializer_opt EOF, $]

///|
fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_TYPE => Shift(yy_state_29)
    _ => Error
  }
}

// [42, typed_initializer_tail → COLON DECL_TYPE • initializer_opt EOF, $]
// [49, initializer_opt → •, EOF]
// [50, initializer_opt → • initializer, EOF]
// [51, initializer → • EQUAL INIT_EXPR, EOF]

///|
fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_24)
    NT_initializer => Shift(yy_state_30)
    NT_initializer_opt => Shift(yy_state_31)
    T_EOF => Reduce(0, NT_initializer_opt, yy_action_58)
    _ => Error
  }
}

// [50, initializer_opt → initializer •, EOF]

///|
fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_initializer_opt, yy_action_57)
}

// [42, typed_initializer_tail → COLON DECL_TYPE initializer_opt • EOF, $]

///|
fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_32)
    _ => Error
  }
}

// [42, typed_initializer_tail → COLON DECL_TYPE initializer_opt EOF •, $]

///|
fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_typed_initializer_tail, yy_action_56)
}

// [41, typed_initializer_tail → EOF •, $]

///|
fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_typed_initializer_tail, yy_action_55)
}

// [36, struct_members → • LBRACE RBRACE EOF, $]
// [37, struct_members → • LBRACE struct_member_list optional_member_separator RBRACE EOF, $]
// [77, struct_members_prime → • struct_members, $]

///|
fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_35)
    T_LBRACE => Shift(yy_state_36)
    _ => Error
  }
}

// [77, struct_members_prime → struct_members •, $]

///|
fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [36, struct_members → LBRACE • RBRACE EOF, $]
// [37, struct_members → LBRACE • struct_member_list optional_member_separator RBRACE EOF, $]
// [38, struct_member_list → • struct_member, RBRACE / COMMA / SEMI]
// [39, struct_member_list → • struct_member_list member_separator struct_member, RBRACE / COMMA / SEMI]
// [40, struct_member → • DECL_ATTRS MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_37)
    NT_struct_member => Shift(yy_state_41)
    NT_struct_member_list => Shift(yy_state_42)
    T_RBRACE => Shift(yy_state_50)
    _ => Error
  }
}

// [40, struct_member → DECL_ATTRS • MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_NAME => Shift(yy_state_38)
    _ => Error
  }
}

// [40, struct_member → DECL_ATTRS MEMBER_NAME • COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_39)
    _ => Error
  }
}

// [40, struct_member → DECL_ATTRS MEMBER_NAME COLON • MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_TYPE => Shift(yy_state_40)
    _ => Error
  }
}

// [40, struct_member → DECL_ATTRS MEMBER_NAME COLON MEMBER_TYPE •, RBRACE / COMMA / SEMI]

///|
fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_struct_member, yy_action_54)
}

// [38, struct_member_list → struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member_list, yy_action_53)
}

// [37, struct_members → LBRACE struct_member_list • optional_member_separator RBRACE EOF, $]
// [39, struct_member_list → struct_member_list • member_separator struct_member, RBRACE / COMMA / SEMI]
// [52, member_separator → • COMMA, DECL_ATTRS / RBRACE]
// [53, member_separator → • SEMI, DECL_ATTRS / RBRACE]
// [54, optional_member_separator → •, RBRACE]
// [55, optional_member_separator → • member_separator, RBRACE]

///|
fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_43)
    T_COMMA => Shift(yy_state_44)
    NT_member_separator => Shift(yy_state_45)
    NT_optional_member_separator => Shift(yy_state_47)
    T_RBRACE => Reduce(0, NT_optional_member_separator, yy_action_52)
    _ => Error
  }
}

// [53, member_separator → SEMI •, DECL_ATTRS / RBRACE]

///|
fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_51)
}

// [52, member_separator → COMMA •, DECL_ATTRS / RBRACE]

///|
fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_50)
}

// [39, struct_member_list → struct_member_list member_separator • struct_member, RBRACE / COMMA / SEMI]
// [40, struct_member → • DECL_ATTRS MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]
// [55, optional_member_separator → member_separator •, RBRACE]

///|
fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_37)
    NT_struct_member => Shift(yy_state_46)
    T_RBRACE => Reduce(1, NT_optional_member_separator, yy_action_49)
    _ => Error
  }
}

// [39, struct_member_list → struct_member_list member_separator struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_member_list, yy_action_48)
}

// [37, struct_members → LBRACE struct_member_list optional_member_separator • RBRACE EOF, $]

///|
fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_48)
    _ => Error
  }
}

// [37, struct_members → LBRACE struct_member_list optional_member_separator RBRACE • EOF, $]

///|
fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_49)
    _ => Error
  }
}

// [37, struct_members → LBRACE struct_member_list optional_member_separator RBRACE EOF •, $]

///|
fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_members, yy_action_47)
}

// [36, struct_members → LBRACE RBRACE • EOF, $]

///|
fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_51)
    _ => Error
  }
}

// [36, struct_members → LBRACE RBRACE EOF •, $]

///|
fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_members, yy_action_46)
}

// [35, function_result → • ARROW DECL_ATTRS ARG_TYPE EOF, $]
// [76, function_result_prime → • function_result, $]

///|
fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_result => Shift(yy_state_53)
    T_ARROW => Shift(yy_state_54)
    _ => Error
  }
}

// [76, function_result_prime → function_result •, $]

///|
fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [35, function_result → ARROW • DECL_ATTRS ARG_TYPE EOF, $]

///|
fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_55)
    _ => Error
  }
}

// [35, function_result → ARROW DECL_ATTRS • ARG_TYPE EOF, $]

///|
fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_TYPE => Shift(yy_state_56)
    _ => Error
  }
}

// [35, function_result → ARROW DECL_ATTRS ARG_TYPE • EOF, $]

///|
fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_57)
    _ => Error
  }
}

// [35, function_result → ARROW DECL_ATTRS ARG_TYPE EOF •, $]

///|
fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_result, yy_action_45)
}

// [33, function_args → • LPAREN RPAREN EOF, $]
// [34, function_args → • LPAREN function_arg_list optional_comma RPAREN EOF, $]
// [75, function_args_prime → • function_args, $]

///|
fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_args => Shift(yy_state_59)
    T_LPAREN => Shift(yy_state_60)
    _ => Error
  }
}

// [75, function_args_prime → function_args •, $]

///|
fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [33, function_args → LPAREN • RPAREN EOF, $]
// [34, function_args → LPAREN • function_arg_list optional_comma RPAREN EOF, $]
// [56, function_arg_list → • function_arg, RPAREN / COMMA]
// [57, function_arg_list → • function_arg_list COMMA function_arg, RPAREN / COMMA]
// [58, function_arg → • DECL_ATTRS ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_61)
    NT_function_arg => Shift(yy_state_65)
    NT_function_arg_list => Shift(yy_state_66)
    T_RPAREN => Shift(yy_state_72)
    _ => Error
  }
}

// [58, function_arg → DECL_ATTRS • ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_NAME => Shift(yy_state_62)
    _ => Error
  }
}

// [58, function_arg → DECL_ATTRS ARG_NAME • COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_63)
    _ => Error
  }
}

// [58, function_arg → DECL_ATTRS ARG_NAME COLON • ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_TYPE => Shift(yy_state_64)
    _ => Error
  }
}

// [58, function_arg → DECL_ATTRS ARG_NAME COLON ARG_TYPE •, RPAREN / COMMA]

///|
fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_arg, yy_action_44)
}

// [56, function_arg_list → function_arg •, RPAREN / COMMA]

///|
fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_arg_list, yy_action_43)
}

// [34, function_args → LPAREN function_arg_list • optional_comma RPAREN EOF, $]
// [57, function_arg_list → function_arg_list • COMMA function_arg, RPAREN / COMMA]
// [59, optional_comma → •, RPAREN]
// [60, optional_comma → • COMMA, RPAREN]

///|
fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_67)
    NT_optional_comma => Shift(yy_state_69)
    T_RPAREN => Reduce(0, NT_optional_comma, yy_action_42)
    _ => Error
  }
}

// [57, function_arg_list → function_arg_list COMMA • function_arg, RPAREN / COMMA]
// [58, function_arg → • DECL_ATTRS ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]
// [60, optional_comma → COMMA •, RPAREN]

///|
fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_61)
    NT_function_arg => Shift(yy_state_68)
    T_RPAREN => Reduce(1, NT_optional_comma, yy_action_41)
    _ => Error
  }
}

// [57, function_arg_list → function_arg_list COMMA function_arg •, RPAREN / COMMA]

///|
fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_arg_list, yy_action_40)
}

// [34, function_args → LPAREN function_arg_list optional_comma • RPAREN EOF, $]

///|
fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_70)
    _ => Error
  }
}

// [34, function_args → LPAREN function_arg_list optional_comma RPAREN • EOF, $]

///|
fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_71)
    _ => Error
  }
}

// [34, function_args → LPAREN function_arg_list optional_comma RPAREN EOF •, $]

///|
fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_args, yy_action_39)
}

// [33, function_args → LPAREN RPAREN • EOF, $]

///|
fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_73)
    _ => Error
  }
}

// [33, function_args → LPAREN RPAREN EOF •, $]

///|
fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_args, yy_action_38)
}

// [61, template_list → • TYPE_LT template_args TYPE_GT EOF, $]
// [74, template_list_prime → • template_list, $]

///|
fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_template_list => Shift(yy_state_75)
    T_TYPE_LT => Shift(yy_state_76)
    _ => Error
  }
}

// [74, template_list_prime → template_list •, $]

///|
fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [61, template_list → TYPE_LT • template_args TYPE_GT EOF, $]
// [62, template_args → • type_expr, TYPE_GT / COMMA]
// [63, template_args → • template_args COMMA type_expr, TYPE_GT / COMMA]
// [64, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [65, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_77)
    NT_type_expr => Shift(yy_state_84)
    NT_template_args => Shift(yy_state_85)
    _ => Error
  }
}

// [64, type_expr → TYPE_ATOM •, TYPE_GT / COMMA / EOF]
// [65, type_expr → TYPE_ATOM • TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]

///|
fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_LT => Shift(yy_state_78)
    T_TYPE_GT | T_COMMA | T_EOF => Reduce(1, NT_type_expr, yy_action_37)
    _ => Error
  }
}

// [64, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [65, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [65, type_expr → TYPE_ATOM TYPE_LT • type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]
// [66, type_ref_args → • type_expr, TYPE_GT / COMMA]
// [67, type_ref_args → • type_ref_args COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_77)
    NT_type_expr => Shift(yy_state_79)
    NT_type_ref_args => Shift(yy_state_80)
    _ => Error
  }
}

// [66, type_ref_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_ref_args, yy_action_36)
}

// [65, type_expr → TYPE_ATOM TYPE_LT type_ref_args • TYPE_GT, TYPE_GT / COMMA / EOF]
// [67, type_ref_args → type_ref_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_81)
    T_TYPE_GT => Shift(yy_state_83)
    _ => Error
  }
}

// [64, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [65, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [67, type_ref_args → type_ref_args COMMA • type_expr, TYPE_GT / COMMA]

///|
fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_77)
    NT_type_expr => Shift(yy_state_82)
    _ => Error
  }
}

// [67, type_ref_args → type_ref_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_ref_args, yy_action_35)
}

// [65, type_expr → TYPE_ATOM TYPE_LT type_ref_args TYPE_GT •, TYPE_GT / COMMA / EOF]

///|
fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_expr, yy_action_34)
}

// [62, template_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_template_args, yy_action_33)
}

// [61, template_list → TYPE_LT template_args • TYPE_GT EOF, $]
// [63, template_args → template_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_86)
    T_TYPE_GT => Shift(yy_state_88)
    _ => Error
  }
}

// [63, template_args → template_args COMMA • type_expr, TYPE_GT / COMMA]
// [64, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [65, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_77)
    NT_type_expr => Shift(yy_state_87)
    _ => Error
  }
}

// [63, template_args → template_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_template_args, yy_action_32)
}

// [61, template_list → TYPE_LT template_args TYPE_GT • EOF, $]

///|
fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_89)
    _ => Error
  }
}

// [61, template_list → TYPE_LT template_args TYPE_GT EOF •, $]

///|
fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_template_list, yy_action_31)
}

// [32, type_ref → • type_expr EOF, $]
// [64, type_expr → • TYPE_ATOM, EOF]
// [65, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, EOF]
// [73, type_ref_prime → • type_ref, $]

///|
fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_77)
    NT_type_ref => Shift(yy_state_91)
    NT_type_expr => Shift(yy_state_92)
    _ => Error
  }
}

// [73, type_ref_prime → type_ref •, $]

///|
fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [32, type_ref → type_expr • EOF, $]

///|
fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_93)
    _ => Error
  }
}

// [32, type_ref → type_expr EOF •, $]

///|
fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_ref, yy_action_30)
}

// [18, decl_head → • DECL_ATTRS KW_VIRTUAL KW_FN EOF, $]
// [19, decl_head → • DECL_ATTRS KW_OVERRIDE KW_FN EOF, $]
// [20, decl_head → • DECL_ATTRS KW_FN EOF, $]
// [21, decl_head → • DECL_ATTRS KW_OVERRIDE EOF, $]
// [22, decl_head → • DECL_ATTRS KW_VAR EOF, $]
// [23, decl_head → • DECL_ATTRS KW_STRUCT EOF, $]
// [24, decl_head → • DECL_ATTRS KW_CONST EOF, $]
// [25, decl_head → • DECL_ATTRS KW_CONST_ASSERT EOF, $]
// [26, decl_head → • DECL_ATTRS KW_ALIAS EOF, $]
// [27, decl_head → • DECL_ATTRS KW_TYPE EOF, $]
// [28, decl_head → • DECL_ATTRS KW_ENABLE EOF, $]
// [29, decl_head → • DECL_ATTRS KW_REQUIRES EOF, $]
// [30, decl_head → • DECL_ATTRS KW_DIAGNOSTIC EOF, $]
// [31, decl_head → • DECL_ATTRS EOF, $]
// [72, decl_head_prime → • decl_head, $]

///|
fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_decl_head => Shift(yy_state_95)
    T_DECL_ATTRS => Shift(yy_state_96)
    _ => Error
  }
}

// [72, decl_head_prime → decl_head •, $]

///|
fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [18, decl_head → DECL_ATTRS • KW_VIRTUAL KW_FN EOF, $]
// [19, decl_head → DECL_ATTRS • KW_OVERRIDE KW_FN EOF, $]
// [20, decl_head → DECL_ATTRS • KW_FN EOF, $]
// [21, decl_head → DECL_ATTRS • KW_OVERRIDE EOF, $]
// [22, decl_head → DECL_ATTRS • KW_VAR EOF, $]
// [23, decl_head → DECL_ATTRS • KW_STRUCT EOF, $]
// [24, decl_head → DECL_ATTRS • KW_CONST EOF, $]
// [25, decl_head → DECL_ATTRS • KW_CONST_ASSERT EOF, $]
// [26, decl_head → DECL_ATTRS • KW_ALIAS EOF, $]
// [27, decl_head → DECL_ATTRS • KW_TYPE EOF, $]
// [28, decl_head → DECL_ATTRS • KW_ENABLE EOF, $]
// [29, decl_head → DECL_ATTRS • KW_REQUIRES EOF, $]
// [30, decl_head → DECL_ATTRS • KW_DIAGNOSTIC EOF, $]
// [31, decl_head → DECL_ATTRS • EOF, $]

///|
fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_97)
    T_KW_DIAGNOSTIC => Shift(yy_state_98)
    T_KW_REQUIRES => Shift(yy_state_100)
    T_KW_ENABLE => Shift(yy_state_102)
    T_KW_TYPE => Shift(yy_state_104)
    T_KW_ALIAS => Shift(yy_state_106)
    T_KW_CONST_ASSERT => Shift(yy_state_108)
    T_KW_CONST => Shift(yy_state_110)
    T_KW_STRUCT => Shift(yy_state_112)
    T_KW_VAR => Shift(yy_state_114)
    T_KW_FN => Shift(yy_state_116)
    T_KW_OVERRIDE => Shift(yy_state_118)
    T_KW_VIRTUAL => Shift(yy_state_122)
    _ => Error
  }
}

// [31, decl_head → DECL_ATTRS EOF •, $]

///|
fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_decl_head, yy_action_29)
}

// [30, decl_head → DECL_ATTRS KW_DIAGNOSTIC • EOF, $]

///|
fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_99)
    _ => Error
  }
}

// [30, decl_head → DECL_ATTRS KW_DIAGNOSTIC EOF •, $]

///|
fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_28)
}

// [29, decl_head → DECL_ATTRS KW_REQUIRES • EOF, $]

///|
fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_101)
    _ => Error
  }
}

// [29, decl_head → DECL_ATTRS KW_REQUIRES EOF •, $]

///|
fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_27)
}

// [28, decl_head → DECL_ATTRS KW_ENABLE • EOF, $]

///|
fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_103)
    _ => Error
  }
}

// [28, decl_head → DECL_ATTRS KW_ENABLE EOF •, $]

///|
fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_26)
}

// [27, decl_head → DECL_ATTRS KW_TYPE • EOF, $]

///|
fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_105)
    _ => Error
  }
}

// [27, decl_head → DECL_ATTRS KW_TYPE EOF •, $]

///|
fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_25)
}

// [26, decl_head → DECL_ATTRS KW_ALIAS • EOF, $]

///|
fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_107)
    _ => Error
  }
}

// [26, decl_head → DECL_ATTRS KW_ALIAS EOF •, $]

///|
fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_24)
}

// [25, decl_head → DECL_ATTRS KW_CONST_ASSERT • EOF, $]

///|
fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_109)
    _ => Error
  }
}

// [25, decl_head → DECL_ATTRS KW_CONST_ASSERT EOF •, $]

///|
fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_23)
}

// [24, decl_head → DECL_ATTRS KW_CONST • EOF, $]

///|
fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_111)
    _ => Error
  }
}

// [24, decl_head → DECL_ATTRS KW_CONST EOF •, $]

///|
fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_22)
}

// [23, decl_head → DECL_ATTRS KW_STRUCT • EOF, $]

///|
fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_113)
    _ => Error
  }
}

// [23, decl_head → DECL_ATTRS KW_STRUCT EOF •, $]

///|
fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_21)
}

// [22, decl_head → DECL_ATTRS KW_VAR • EOF, $]

///|
fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_115)
    _ => Error
  }
}

// [22, decl_head → DECL_ATTRS KW_VAR EOF •, $]

///|
fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_20)
}

// [20, decl_head → DECL_ATTRS KW_FN • EOF, $]

///|
fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_117)
    _ => Error
  }
}

// [20, decl_head → DECL_ATTRS KW_FN EOF •, $]

///|
fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_19)
}

// [19, decl_head → DECL_ATTRS KW_OVERRIDE • KW_FN EOF, $]
// [21, decl_head → DECL_ATTRS KW_OVERRIDE • EOF, $]

///|
fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_119)
    T_KW_FN => Shift(yy_state_120)
    _ => Error
  }
}

// [21, decl_head → DECL_ATTRS KW_OVERRIDE EOF •, $]

///|
fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_18)
}

// [19, decl_head → DECL_ATTRS KW_OVERRIDE KW_FN • EOF, $]

///|
fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_121)
    _ => Error
  }
}

// [19, decl_head → DECL_ATTRS KW_OVERRIDE KW_FN EOF •, $]

///|
fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_decl_head, yy_action_17)
}

// [18, decl_head → DECL_ATTRS KW_VIRTUAL • KW_FN EOF, $]

///|
fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KW_FN => Shift(yy_state_123)
    _ => Error
  }
}

// [18, decl_head → DECL_ATTRS KW_VIRTUAL KW_FN • EOF, $]

///|
fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_124)
    _ => Error
  }
}

// [18, decl_head → DECL_ATTRS KW_VIRTUAL KW_FN EOF •, $]

///|
fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_decl_head, yy_action_16)
}

// [15, directive_prefix_tail → • HASH PREFIX directive_tail EOF, $]
// [71, directive_prefix_tail_prime → • directive_prefix_tail, $]

///|
fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_prefix_tail => Shift(yy_state_126)
    T_HASH => Shift(yy_state_127)
    _ => Error
  }
}

// [71, directive_prefix_tail_prime → directive_prefix_tail •, $]

///|
fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [15, directive_prefix_tail → HASH • PREFIX directive_tail EOF, $]

///|
fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PREFIX => Shift(yy_state_128)
    _ => Error
  }
}

// [15, directive_prefix_tail → HASH PREFIX • directive_tail EOF, $]
// [16, directive_tail → •, EOF]
// [17, directive_tail → • DIRECTIVE_TAIL, EOF]

///|
fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_10)
    NT_directive_tail => Shift(yy_state_129)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_66)
    _ => Error
  }
}

// [15, directive_prefix_tail → HASH PREFIX directive_tail • EOF, $]

///|
fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_130)
    _ => Error
  }
}

// [15, directive_prefix_tail → HASH PREFIX directive_tail EOF •, $]

///|
fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_directive_prefix_tail, yy_action_15)
}

// [14, directive_line → • HASH DIRECTIVE_HEAD directive_tail EOF, $]
// [70, directive_line_prime → • directive_line, $]

///|
fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_line => Shift(yy_state_132)
    T_HASH => Shift(yy_state_133)
    _ => Error
  }
}

// [70, directive_line_prime → directive_line •, $]

///|
fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [14, directive_line → HASH • DIRECTIVE_HEAD directive_tail EOF, $]

///|
fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_HEAD => Shift(yy_state_134)
    _ => Error
  }
}

// [14, directive_line → HASH DIRECTIVE_HEAD • directive_tail EOF, $]
// [16, directive_tail → •, EOF]
// [17, directive_tail → • DIRECTIVE_TAIL, EOF]

///|
fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_10)
    NT_directive_tail => Shift(yy_state_135)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_66)
    _ => Error
  }
}

// [14, directive_line → HASH DIRECTIVE_HEAD directive_tail • EOF, $]

///|
fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_136)
    _ => Error
  }
}

// [14, directive_line → HASH DIRECTIVE_HEAD directive_tail EOF •, $]

///|
fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_directive_line, yy_action_14)
}

// [3, import_targets → • target_list semis EOF, $]
// [4, import_targets → • IDENT target_list semis EOF, $]
// [7, target_list → • target, COMMA / SEMI / EOF]
// [8, target_list → • target_list COMMA target, COMMA / SEMI / EOF]
// [9, target_list → • target_list COMMA, COMMA / SEMI / EOF]
// [10, target → • IDENT alias, COMMA / SEMI / EOF]
// [11, target → • IDENT LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [69, import_targets_prime → • import_targets, $]

///|
fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_import_targets => Shift(yy_state_138)
    NT_target => Shift(yy_state_139)
    T_IDENT => Shift(yy_state_140)
    NT_target_list => Shift(yy_state_154)
    _ => Error
  }
}

// [69, import_targets_prime → import_targets •, $]

///|
fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [7, target_list → target •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_target_list, yy_action_13)
}

// [4, import_targets → IDENT • target_list semis EOF, $]
// [7, target_list → • target, COMMA / SEMI / EOF]
// [8, target_list → • target_list COMMA target, COMMA / SEMI / EOF]
// [9, target_list → • target_list COMMA, COMMA / SEMI / EOF]
// [10, target → • IDENT alias, COMMA / SEMI / EOF]
// [10, target → IDENT • alias, COMMA / SEMI / EOF]
// [11, target → • IDENT LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [11, target → IDENT • LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [12, alias → •, COMMA / SEMI / EOF]
// [13, alias → • AS IDENT, COMMA / SEMI / EOF]

///|
fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_target => Shift(yy_state_139)
    T_AS => Shift(yy_state_141)
    T_LBRACE => Shift(yy_state_143)
    T_IDENT => Shift(yy_state_144)
    NT_alias => Shift(yy_state_145)
    NT_target_list => Shift(yy_state_150)
    T_COMMA | T_SEMI | T_EOF => Reduce(0, NT_alias, yy_action_12)
    _ => Error
  }
}

// [13, alias → AS • IDENT, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_142)
    _ => Error
  }
}

// [13, alias → AS IDENT •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_alias, yy_action_11)
}

// [7, target_list → • target, RBRACE / COMMA]
// [8, target_list → • target_list COMMA target, RBRACE / COMMA]
// [9, target_list → • target_list COMMA, RBRACE / COMMA]
// [10, target → • IDENT alias, RBRACE / COMMA]
// [11, target → • IDENT LBRACE target_list RBRACE, RBRACE / COMMA]
// [11, target → IDENT LBRACE • target_list RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_target => Shift(yy_state_139)
    T_IDENT => Shift(yy_state_144)
    NT_target_list => Shift(yy_state_146)
    _ => Error
  }
}

// [10, target → IDENT • alias, RBRACE / COMMA / SEMI / EOF]
// [11, target → IDENT • LBRACE target_list RBRACE, RBRACE / COMMA / SEMI / EOF]
// [12, alias → •, RBRACE / COMMA / SEMI / EOF]
// [13, alias → • AS IDENT, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AS => Shift(yy_state_141)
    T_LBRACE => Shift(yy_state_143)
    NT_alias => Shift(yy_state_145)
    T_RBRACE | T_COMMA | T_SEMI | T_EOF => Reduce(0, NT_alias, yy_action_12)
    _ => Error
  }
}

// [10, target → IDENT alias •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_target, yy_action_10)
}

// [8, target_list → target_list • COMMA target, RBRACE / COMMA]
// [9, target_list → target_list • COMMA, RBRACE / COMMA]
// [11, target → IDENT LBRACE target_list • RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_147)
    T_COMMA => Shift(yy_state_148)
    _ => Error
  }
}

// [11, target → IDENT LBRACE target_list RBRACE •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_target, yy_action_9)
}

// [8, target_list → target_list COMMA • target, RBRACE / COMMA / SEMI / EOF]
// [9, target_list → target_list COMMA •, RBRACE / COMMA / SEMI / EOF]
// [10, target → • IDENT alias, RBRACE / COMMA / SEMI / EOF]
// [11, target → • IDENT LBRACE target_list RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_144)
    NT_target => Shift(yy_state_149)
    T_RBRACE | T_COMMA | T_SEMI | T_EOF =>
      Reduce(2, NT_target_list, yy_action_8)
    _ => Error
  }
}

// [8, target_list → target_list COMMA target •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_target_list, yy_action_7)
}

// [4, import_targets → IDENT target_list • semis EOF, $]
// [5, semis → •, SEMI / EOF]
// [6, semis → • semis SEMI, SEMI / EOF]
// [8, target_list → target_list • COMMA target, COMMA / SEMI / EOF]
// [9, target_list → target_list • COMMA, COMMA / SEMI / EOF]

///|
fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_148)
    NT_semis => Shift(yy_state_151)
    T_SEMI | T_EOF => Reduce(0, NT_semis, yy_action_6)
    _ => Error
  }
}

// [4, import_targets → IDENT target_list semis • EOF, $]
// [6, semis → semis • SEMI, SEMI / EOF]

///|
fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_152)
    T_EOF => Shift(yy_state_153)
    _ => Error
  }
}

// [6, semis → semis SEMI •, SEMI / EOF]

///|
fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semis, yy_action_5)
}

// [4, import_targets → IDENT target_list semis EOF •, $]

///|
fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_import_targets, yy_action_4)
}

// [3, import_targets → target_list • semis EOF, $]
// [5, semis → •, SEMI / EOF]
// [6, semis → • semis SEMI, SEMI / EOF]
// [8, target_list → target_list • COMMA target, COMMA / SEMI / EOF]
// [9, target_list → target_list • COMMA, COMMA / SEMI / EOF]

///|
fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_148)
    NT_semis => Shift(yy_state_155)
    T_SEMI | T_EOF => Reduce(0, NT_semis, yy_action_6)
    _ => Error
  }
}

// [3, import_targets → target_list semis • EOF, $]
// [6, semis → semis • SEMI, SEMI / EOF]

///|
fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_152)
    T_EOF => Shift(yy_state_156)
    _ => Error
  }
}

// [3, import_targets → target_list semis EOF •, $]

///|
fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_targets, yy_action_3)
}

// [0, raw_top_level_items → • items EOF, $]
// [1, items → •, ITEM / EOF]
// [2, items → • items ITEM, ITEM / EOF]
// [68, raw_top_level_items_prime → • raw_top_level_items, $]

///|
fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_raw_top_level_items => Shift(yy_state_158)
    NT_items => Shift(yy_state_159)
    T_ITEM | T_EOF => Reduce(0, NT_items, yy_action_2)
    _ => Error
  }
}

// [68, raw_top_level_items_prime → raw_top_level_items •, $]

///|
fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [0, raw_top_level_items → items • EOF, $]
// [2, items → items • ITEM, ITEM / EOF]

///|
fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ITEM => Shift(yy_state_160)
    T_EOF => Shift(yy_state_161)
    _ => Error
  }
}

// [2, items → items ITEM •, ITEM / EOF]

///|
fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_items, yy_action_1)
}

// [0, raw_top_level_items → items EOF •, $]

///|
fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
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
    yy_state_157,
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
    yy_state_137,
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
    yy_state_131,
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
    yy_state_125,
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
    yy_state_94,
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
    yy_state_90,
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
    yy_state_74,
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
    yy_state_58,
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
    yy_state_52,
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
    yy_state_34,
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
    yy_state_22,
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
    yy_state_17,
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
    yy_state_4,
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
    yy_state_0,
    it => {
      guard it is YYObj__ast_WgslExprRef(result)
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
