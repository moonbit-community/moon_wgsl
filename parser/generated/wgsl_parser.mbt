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
  HASH
  PREFIX
  AS
  ARROW
  LPAREN
  RPAREN
  LBRACE
  RBRACE
  COLON
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
    HASH => TK_HASH
    PREFIX => TK_PREFIX
    AS => TK_AS
    ARROW => TK_ARROW
    LPAREN => TK_LPAREN
    RPAREN => TK_RPAREN
    LBRACE => TK_LBRACE
    RBRACE => TK_RBRACE
    COLON => TK_COLON
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
  TK_HASH
  TK_PREFIX
  TK_AS
  TK_ARROW
  TK_LPAREN
  TK_RPAREN
  TK_LBRACE
  TK_RBRACE
  TK_COLON
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
      TK_HASH => "\"#\""
      TK_PREFIX => "PREFIX"
      TK_AS => "\"as\""
      TK_ARROW => "\"->\""
      TK_LPAREN => "\"(\""
      TK_RPAREN => "\")\""
      TK_LBRACE => "\"{\""
      TK_RBRACE => "\"}\""
      TK_COLON => "\":\""
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
    TK_HASH => to_repr("#")
    TK_PREFIX => to_repr("PREFIX")
    TK_AS => to_repr("as")
    TK_ARROW => to_repr("->")
    TK_LPAREN => to_repr("(")
    TK_RPAREN => to_repr(")")
    TK_LBRACE => to_repr("{")
    TK_RBRACE => to_repr("}")
    TK_COLON => to_repr(":")
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
priv suberror YYObj__String___ast_WgslTypeRef__ {
  YYObj__String___ast_WgslTypeRef__((String, @ast.WgslTypeRef?))
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
  T_HASH
  T_PREFIX
  T_AS
  T_ARROW
  T_LPAREN
  T_RPAREN
  T_LBRACE
  T_RBRACE
  T_COLON
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
// 55|    items EOF { $1 }

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
// 60|    items ITEM {
// 61|      let items = $1
// 62|      items.push($2)
// 63|      items
// 64|    }

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
// 59|    { [] }

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
// 68|    target_list semis EOF { $1 }

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
// 69|    module_path=IDENT targets=target_list semis EOF {
// 70|      let out : Array[@common.WgslImportTarget] = []
// 71|      for target in targets {
// 72|        let sep = if module_path.has_suffix("::") || target.raw_path == "" {
// 73|          ""
// 74|        } else {
// 75|          "::"
// 76|        }
// 77|        out.push(@common.WgslImportTarget::{
// 78|          raw_path: module_path + sep + target.raw_path,
// 79|          alias_name: target.alias_name,
// 80|        })
// 81|      }
// 82|      out
// 83|    }

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
// 88|    semis ";" { () }

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
// 87|    { () }

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
//  95|    target_list "," target {
//  96|      let targets = $1
//  97|      for target in $3 {
//  98|        targets.push(target)
//  99|      }
// 100|      targets
// 101|    }

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
// 102|    target_list "," {
// 103|      $1
// 104|    }

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
// 111|    module_path=IDENT "{" targets=target_list "}" {
// 112|      let out : Array[@common.WgslImportTarget] = []
// 113|      for target in targets {
// 114|        let sep = if module_path.has_suffix("::") || target.raw_path == "" {
// 115|          ""
// 116|        } else {
// 117|          "::"
// 118|        }
// 119|        out.push(@common.WgslImportTarget::{
// 120|          raw_path: module_path + sep + target.raw_path,
// 121|          alias_name: target.alias_name,
// 122|        })
// 123|      }
// 124|      out
// 125|    }

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
// 108|    path=IDENT alias_name=alias {
// 109|      [@common.WgslImportTarget::{ raw_path: path, alias_name }]
// 110|    }

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
// 130|    "as" name=IDENT { name }

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
// 129|    { "" }

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
// 92|    target {
// 93|      $1
// 94|    }

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
// 134|    "#" head=DIRECTIVE_HEAD tail=directive_tail EOF {
// 135|      let (name, text) = head
// 136|      let kind = match name {
// 137|        "ifdef" => @ast.WgslDirectiveKind::Ifdef
// 138|        "ifndef" => @ast.WgslDirectiveKind::Ifndef
// 139|        "if" => @ast.WgslDirectiveKind::If
// 140|        "else" => @ast.WgslDirectiveKind::Else
// 141|        "endif" => @ast.WgslDirectiveKind::Endif
// 142|        "define_import_path" => @ast.WgslDirectiveKind::DefineImportPath
// 143|        "define" => @ast.WgslDirectiveKind::Define
// 144|        "import" => @ast.WgslDirectiveKind::Import
// 145|        "enable" => @ast.WgslDirectiveKind::Enable
// 146|        "requires" => @ast.WgslDirectiveKind::Requires
// 147|        "diagnostic" => @ast.WgslDirectiveKind::Diagnostic
// 148|        _ => @ast.WgslDirectiveKind::Other(name)
// 149|      }
// 150|      @ast.WgslDirective::{ kind, name, tail, text }
// 151|    }

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
// 155|    "#" PREFIX tail=directive_tail EOF { tail }

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
// 160|    DIRECTIVE_TAIL { $1 }

///|
fn yy_action_16(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 159|    { "" }

///|
fn yy_action_17(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_String(
    {
      ()
      ""
    },
  )
}

// file:///./wgsl_parser.mbty
// 164|    attrs=DECL_ATTRS KW_VIRTUAL fn_kw=KW_FN EOF {
// 165|      @ast.WgslDeclHead::{
// 166|        kind: @ast.WgslDeclHeadKind::Function,
// 167|        attributes: attrs,
// 168|        keyword: Some(fn_kw),
// 169|        qualifier: "virtual",
// 170|        qualifier_start: Some($2.start),
// 171|        qualifier_end: Some($2.end),
// 172|        fn_keyword: Some(fn_kw),
// 173|        consumed: 2,
// 174|      }
// 175|    }

///|
fn yy_action_18(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 176|    attrs=DECL_ATTRS KW_OVERRIDE fn_kw=KW_FN EOF {
// 177|      @ast.WgslDeclHead::{
// 178|        kind: @ast.WgslDeclHeadKind::Function,
// 179|        attributes: attrs,
// 180|        keyword: Some(fn_kw),
// 181|        qualifier: "override",
// 182|        qualifier_start: Some($2.start),
// 183|        qualifier_end: Some($2.end),
// 184|        fn_keyword: Some(fn_kw),
// 185|        consumed: 2,
// 186|      }
// 187|    }

///|
fn yy_action_19(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 200|    attrs=DECL_ATTRS keyword=KW_OVERRIDE EOF {
// 201|      @ast.WgslDeclHead::{
// 202|        kind: @ast.WgslDeclHeadKind::Override,
// 203|        attributes: attrs,
// 204|        keyword: Some(keyword),
// 205|        qualifier: "",
// 206|        qualifier_start: None,
// 207|        qualifier_end: None,
// 208|        fn_keyword: None,
// 209|        consumed: 1,
// 210|      }
// 211|    }

///|
fn yy_action_20(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 188|    attrs=DECL_ATTRS keyword=KW_FN EOF {
// 189|      @ast.WgslDeclHead::{
// 190|        kind: @ast.WgslDeclHeadKind::Function,
// 191|        attributes: attrs,
// 192|        keyword: Some(keyword),
// 193|        qualifier: "",
// 194|        qualifier_start: None,
// 195|        qualifier_end: None,
// 196|        fn_keyword: Some(keyword),
// 197|        consumed: 1,
// 198|      }
// 199|    }

///|
fn yy_action_21(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 212|    attrs=DECL_ATTRS keyword=KW_VAR EOF {
// 213|      @ast.WgslDeclHead::{
// 214|        kind: @ast.WgslDeclHeadKind::GlobalVariable,
// 215|        attributes: attrs,
// 216|        keyword: Some(keyword),
// 217|        qualifier: "",
// 218|        qualifier_start: None,
// 219|        qualifier_end: None,
// 220|        fn_keyword: None,
// 221|        consumed: 1,
// 222|      }
// 223|    }

///|
fn yy_action_22(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 224|    attrs=DECL_ATTRS keyword=KW_STRUCT EOF {
// 225|      @ast.WgslDeclHead::{
// 226|        kind: @ast.WgslDeclHeadKind::Struct,
// 227|        attributes: attrs,
// 228|        keyword: Some(keyword),
// 229|        qualifier: "",
// 230|        qualifier_start: None,
// 231|        qualifier_end: None,
// 232|        fn_keyword: None,
// 233|        consumed: 1,
// 234|      }
// 235|    }

///|
fn yy_action_23(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 236|    attrs=DECL_ATTRS keyword=KW_CONST EOF {
// 237|      @ast.WgslDeclHead::{
// 238|        kind: @ast.WgslDeclHeadKind::Const,
// 239|        attributes: attrs,
// 240|        keyword: Some(keyword),
// 241|        qualifier: "",
// 242|        qualifier_start: None,
// 243|        qualifier_end: None,
// 244|        fn_keyword: None,
// 245|        consumed: 1,
// 246|      }
// 247|    }

///|
fn yy_action_24(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 248|    attrs=DECL_ATTRS keyword=KW_CONST_ASSERT EOF {
// 249|      @ast.WgslDeclHead::{
// 250|        kind: @ast.WgslDeclHeadKind::ConstAssert,
// 251|        attributes: attrs,
// 252|        keyword: Some(keyword),
// 253|        qualifier: "",
// 254|        qualifier_start: None,
// 255|        qualifier_end: None,
// 256|        fn_keyword: None,
// 257|        consumed: 1,
// 258|      }
// 259|    }

///|
fn yy_action_25(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 260|    attrs=DECL_ATTRS keyword=KW_ALIAS EOF {
// 261|      @ast.WgslDeclHead::{
// 262|        kind: @ast.WgslDeclHeadKind::TypeAlias,
// 263|        attributes: attrs,
// 264|        keyword: Some(keyword),
// 265|        qualifier: "",
// 266|        qualifier_start: None,
// 267|        qualifier_end: None,
// 268|        fn_keyword: None,
// 269|        consumed: 1,
// 270|      }
// 271|    }

///|
fn yy_action_26(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 272|    attrs=DECL_ATTRS keyword=KW_TYPE EOF {
// 273|      @ast.WgslDeclHead::{
// 274|        kind: @ast.WgslDeclHeadKind::TypeAlias,
// 275|        attributes: attrs,
// 276|        keyword: Some(keyword),
// 277|        qualifier: "",
// 278|        qualifier_start: None,
// 279|        qualifier_end: None,
// 280|        fn_keyword: None,
// 281|        consumed: 1,
// 282|      }
// 283|    }

///|
fn yy_action_27(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 284|    attrs=DECL_ATTRS keyword=KW_ENABLE EOF {
// 285|      @ast.WgslDeclHead::{
// 286|        kind: @ast.WgslDeclHeadKind::SourceDirective(@ast.WgslDirectiveKind::Enable),
// 287|        attributes: attrs,
// 288|        keyword: Some(keyword),
// 289|        qualifier: "",
// 290|        qualifier_start: None,
// 291|        qualifier_end: None,
// 292|        fn_keyword: None,
// 293|        consumed: 1,
// 294|      }
// 295|    }

///|
fn yy_action_28(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 296|    attrs=DECL_ATTRS keyword=KW_REQUIRES EOF {
// 297|      @ast.WgslDeclHead::{
// 298|        kind: @ast.WgslDeclHeadKind::SourceDirective(@ast.WgslDirectiveKind::Requires),
// 299|        attributes: attrs,
// 300|        keyword: Some(keyword),
// 301|        qualifier: "",
// 302|        qualifier_start: None,
// 303|        qualifier_end: None,
// 304|        fn_keyword: None,
// 305|        consumed: 1,
// 306|      }
// 307|    }

///|
fn yy_action_29(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 308|    attrs=DECL_ATTRS keyword=KW_DIAGNOSTIC EOF {
// 309|      @ast.WgslDeclHead::{
// 310|        kind: @ast.WgslDeclHeadKind::SourceDirective(@ast.WgslDirectiveKind::Diagnostic),
// 311|        attributes: attrs,
// 312|        keyword: Some(keyword),
// 313|        qualifier: "",
// 314|        qualifier_start: None,
// 315|        qualifier_end: None,
// 316|        fn_keyword: None,
// 317|        consumed: 1,
// 318|      }
// 319|    }

///|
fn yy_action_30(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 320|    attrs=DECL_ATTRS EOF {
// 321|      @ast.WgslDeclHead::raw(attrs)
// 322|    }

///|
fn yy_action_31(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  YYObj__ast_WgslDeclHead(
    {
      ()
      @ast.WgslDeclHead::raw(attrs)
    },
  )
}

// file:///./wgsl_parser.mbty
// 326|    value=type_expr EOF { value }

///|
fn yy_action_32(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj__ast_WgslTypeRef(
    {
      ()
      value
    },
  )
}

// file:///./wgsl_parser.mbty
// 412|    TYPE_LT args=template_args TYPE_GT EOF { args }

///|
fn yy_action_33(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_String_(args)
  YYObj_Array_String_(
    {
      ()
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 419|    args=template_args "," value=type_expr {
// 420|      args.push(value.text)
// 421|      args
// 422|    }

///|
fn yy_action_34(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 416|    value=type_expr {
// 417|      [value.text]
// 418|    }

///|
fn yy_action_35(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array_String_(
    {
      ()
      [value.text]
    },
  )
}

// file:///./wgsl_parser.mbty
// 429|    atom=TYPE_ATOM TYPE_LT args=type_ref_args gt=TYPE_GT {
// 430|      wgsl_type_ref_from_atom(atom, args, gt)
// 431|    }

///|
fn yy_action_36(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 438|    args=type_ref_args "," value=type_expr {
// 439|      args.push(value)
// 440|      args
// 441|    }

///|
fn yy_action_37(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 435|    value=type_expr {
// 436|      [value]
// 437|    }

///|
fn yy_action_38(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 426|    atom=TYPE_ATOM {
// 427|      wgsl_type_ref_from_atom(atom, [], atom.4)
// 428|    }

///|
fn yy_action_39(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String__String__Int__Int__Int_(atom)
  YYObj__ast_WgslTypeRef(
    {
      ()
      wgsl_type_ref_from_atom(atom, [], atom.4)
    },
  )
}

// file:///./wgsl_parser.mbty
// 330|    "(" ")" EOF { [] }

///|
fn yy_action_40(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 331|    "(" args=function_arg_list optional_comma ")" EOF { args }

///|
fn yy_action_41(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslFunctionArgument_(args)
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 386|    args=function_arg_list "," value=function_arg {
// 387|      args.push(value)
// 388|      args
// 389|    }

///|
fn yy_action_42(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 408|    "," { () }

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
// 407|    { () }

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
// 383|    value=function_arg {
// 384|      [value]
// 385|    }

///|
fn yy_action_45(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslFunctionArgument(value)
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 393|    attrs=DECL_ATTRS name=ARG_NAME ":" ty=ARG_TYPE {
// 394|      let (ty_text, ty_ref) = ty
// 395|      @ast.WgslFunctionArgument::{
// 396|        attributes: attrs,
// 397|        name: name.name,
// 398|        name_start: name.start,
// 399|        name_end: name.end,
// 400|        ty: ty_text,
// 401|        ty_ref,
// 402|      }
// 403|    }

///|
fn yy_action_46(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 335|    "->" attrs=DECL_ATTRS ty=ARG_TYPE EOF {
// 336|      let (ty_text, ty_ref) = ty
// 337|      Some(@ast.WgslFunctionResult::{ attributes: attrs, ty: ty_text, ty_ref })
// 338|    }

///|
fn yy_action_47(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 342|    "{" "}" EOF { [] }

///|
fn yy_action_48(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 343|    "{" members=struct_member_list optional_member_separator "}" EOF {
// 344|      members
// 345|    }

///|
fn yy_action_49(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslStructMember_(members)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      members
    },
  )
}

// file:///./wgsl_parser.mbty
// 352|    members=struct_member_list member_separator value=struct_member {
// 353|      members.push(value)
// 354|      members
// 355|    }

///|
fn yy_action_50(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 379|    member_separator { () }

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
// 373|    "," { () }

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
// 374|    ";" { () }

///|
fn yy_action_53(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 378|    { () }

///|
fn yy_action_54(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 349|    value=struct_member {
// 350|      [value]
// 351|    }

///|
fn yy_action_55(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslStructMember(value)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 359|    attrs=DECL_ATTRS name=MEMBER_NAME ":" ty=MEMBER_TYPE {
// 360|      let (ty_text, ty_ref) = ty
// 361|      @ast.WgslStructMember::{
// 362|        attributes: attrs,
// 363|        name: name.name,
// 364|        name_start: name.start,
// 365|        name_end: name.end,
// 366|        ty: ty_text,
// 367|        ty_ref,
// 368|      }
// 369|    }

///|
fn yy_action_56(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
    HASH => (T_HASH, YYObj_Void)
    PREFIX => (T_PREFIX, YYObj_Void)
    AS => (T_AS, YYObj_Void)
    ARROW => (T_ARROW, YYObj_Void)
    LPAREN => (T_LPAREN, YYObj_Void)
    RPAREN => (T_RPAREN, YYObj_Void)
    LBRACE => (T_LBRACE, YYObj_Void)
    RBRACE => (T_RBRACE, YYObj_Void)
    COLON => (T_COLON, YYObj_Void)
    TYPE_LT(data) => (T_TYPE_LT, YYObj_Int(data))
    TYPE_GT(data) => (T_TYPE_GT, YYObj_Int(data))
    COMMA => (T_COMMA, YYObj_Void)
    SEMI => (T_SEMI, YYObj_Void)
    EOF => (T_EOF, YYObj_Void)
  }
}

// [36, struct_members → • LBRACE RBRACE EOF, $]
// [37, struct_members → • LBRACE struct_member_list optional_member_separator RBRACE EOF, $]
// [66, struct_members_prime → • struct_members, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_1)
    T_LBRACE => Shift(yy_state_2)
    _ => Error
  }
}

// [66, struct_members_prime → struct_members •, $]

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [36, struct_members → LBRACE • RBRACE EOF, $]
// [37, struct_members → LBRACE • struct_member_list optional_member_separator RBRACE EOF, $]
// [38, struct_member_list → • struct_member, RBRACE / COMMA / SEMI]
// [39, struct_member_list → • struct_member_list member_separator struct_member, RBRACE / COMMA / SEMI]
// [40, struct_member → • DECL_ATTRS MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_3)
    NT_struct_member => Shift(yy_state_7)
    NT_struct_member_list => Shift(yy_state_8)
    T_RBRACE => Shift(yy_state_16)
    _ => Error
  }
}

// [40, struct_member → DECL_ATTRS • MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_NAME => Shift(yy_state_4)
    _ => Error
  }
}

// [40, struct_member → DECL_ATTRS MEMBER_NAME • COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_5)
    _ => Error
  }
}

// [40, struct_member → DECL_ATTRS MEMBER_NAME COLON • MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_TYPE => Shift(yy_state_6)
    _ => Error
  }
}

// [40, struct_member → DECL_ATTRS MEMBER_NAME COLON MEMBER_TYPE •, RBRACE / COMMA / SEMI]

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_struct_member, yy_action_56)
}

// [38, struct_member_list → struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member_list, yy_action_55)
}

// [37, struct_members → LBRACE struct_member_list • optional_member_separator RBRACE EOF, $]
// [39, struct_member_list → struct_member_list • member_separator struct_member, RBRACE / COMMA / SEMI]
// [41, member_separator → • COMMA, DECL_ATTRS / RBRACE]
// [42, member_separator → • SEMI, DECL_ATTRS / RBRACE]
// [43, optional_member_separator → •, RBRACE]
// [44, optional_member_separator → • member_separator, RBRACE]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_9)
    T_COMMA => Shift(yy_state_10)
    NT_member_separator => Shift(yy_state_11)
    NT_optional_member_separator => Shift(yy_state_13)
    T_RBRACE => Reduce(0, NT_optional_member_separator, yy_action_54)
    _ => Error
  }
}

// [42, member_separator → SEMI •, DECL_ATTRS / RBRACE]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_53)
}

// [41, member_separator → COMMA •, DECL_ATTRS / RBRACE]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_52)
}

// [39, struct_member_list → struct_member_list member_separator • struct_member, RBRACE / COMMA / SEMI]
// [40, struct_member → • DECL_ATTRS MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]
// [44, optional_member_separator → member_separator •, RBRACE]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_3)
    NT_struct_member => Shift(yy_state_12)
    T_RBRACE => Reduce(1, NT_optional_member_separator, yy_action_51)
    _ => Error
  }
}

// [39, struct_member_list → struct_member_list member_separator struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_member_list, yy_action_50)
}

// [37, struct_members → LBRACE struct_member_list optional_member_separator • RBRACE EOF, $]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_14)
    _ => Error
  }
}

// [37, struct_members → LBRACE struct_member_list optional_member_separator RBRACE • EOF, $]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_15)
    _ => Error
  }
}

// [37, struct_members → LBRACE struct_member_list optional_member_separator RBRACE EOF •, $]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_members, yy_action_49)
}

// [36, struct_members → LBRACE RBRACE • EOF, $]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_17)
    _ => Error
  }
}

// [36, struct_members → LBRACE RBRACE EOF •, $]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_members, yy_action_48)
}

// [35, function_result → • ARROW DECL_ATTRS ARG_TYPE EOF, $]
// [65, function_result_prime → • function_result, $]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_result => Shift(yy_state_19)
    T_ARROW => Shift(yy_state_20)
    _ => Error
  }
}

// [65, function_result_prime → function_result •, $]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [35, function_result → ARROW • DECL_ATTRS ARG_TYPE EOF, $]

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_21)
    _ => Error
  }
}

// [35, function_result → ARROW DECL_ATTRS • ARG_TYPE EOF, $]

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_TYPE => Shift(yy_state_22)
    _ => Error
  }
}

// [35, function_result → ARROW DECL_ATTRS ARG_TYPE • EOF, $]

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_23)
    _ => Error
  }
}

// [35, function_result → ARROW DECL_ATTRS ARG_TYPE EOF •, $]

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_result, yy_action_47)
}

// [33, function_args → • LPAREN RPAREN EOF, $]
// [34, function_args → • LPAREN function_arg_list optional_comma RPAREN EOF, $]
// [64, function_args_prime → • function_args, $]

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_args => Shift(yy_state_25)
    T_LPAREN => Shift(yy_state_26)
    _ => Error
  }
}

// [64, function_args_prime → function_args •, $]

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [33, function_args → LPAREN • RPAREN EOF, $]
// [34, function_args → LPAREN • function_arg_list optional_comma RPAREN EOF, $]
// [45, function_arg_list → • function_arg, RPAREN / COMMA]
// [46, function_arg_list → • function_arg_list COMMA function_arg, RPAREN / COMMA]
// [47, function_arg → • DECL_ATTRS ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_27)
    NT_function_arg => Shift(yy_state_31)
    NT_function_arg_list => Shift(yy_state_32)
    T_RPAREN => Shift(yy_state_38)
    _ => Error
  }
}

// [47, function_arg → DECL_ATTRS • ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_NAME => Shift(yy_state_28)
    _ => Error
  }
}

// [47, function_arg → DECL_ATTRS ARG_NAME • COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_29)
    _ => Error
  }
}

// [47, function_arg → DECL_ATTRS ARG_NAME COLON • ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_TYPE => Shift(yy_state_30)
    _ => Error
  }
}

// [47, function_arg → DECL_ATTRS ARG_NAME COLON ARG_TYPE •, RPAREN / COMMA]

///|
fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_arg, yy_action_46)
}

// [45, function_arg_list → function_arg •, RPAREN / COMMA]

///|
fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_arg_list, yy_action_45)
}

// [34, function_args → LPAREN function_arg_list • optional_comma RPAREN EOF, $]
// [46, function_arg_list → function_arg_list • COMMA function_arg, RPAREN / COMMA]
// [48, optional_comma → •, RPAREN]
// [49, optional_comma → • COMMA, RPAREN]

///|
fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_33)
    NT_optional_comma => Shift(yy_state_35)
    T_RPAREN => Reduce(0, NT_optional_comma, yy_action_44)
    _ => Error
  }
}

// [46, function_arg_list → function_arg_list COMMA • function_arg, RPAREN / COMMA]
// [47, function_arg → • DECL_ATTRS ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]
// [49, optional_comma → COMMA •, RPAREN]

///|
fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_ATTRS => Shift(yy_state_27)
    NT_function_arg => Shift(yy_state_34)
    T_RPAREN => Reduce(1, NT_optional_comma, yy_action_43)
    _ => Error
  }
}

// [46, function_arg_list → function_arg_list COMMA function_arg •, RPAREN / COMMA]

///|
fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_arg_list, yy_action_42)
}

// [34, function_args → LPAREN function_arg_list optional_comma • RPAREN EOF, $]

///|
fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_36)
    _ => Error
  }
}

// [34, function_args → LPAREN function_arg_list optional_comma RPAREN • EOF, $]

///|
fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_37)
    _ => Error
  }
}

// [34, function_args → LPAREN function_arg_list optional_comma RPAREN EOF •, $]

///|
fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_args, yy_action_41)
}

// [33, function_args → LPAREN RPAREN • EOF, $]

///|
fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_39)
    _ => Error
  }
}

// [33, function_args → LPAREN RPAREN EOF •, $]

///|
fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_args, yy_action_40)
}

// [50, template_list → • TYPE_LT template_args TYPE_GT EOF, $]
// [63, template_list_prime → • template_list, $]

///|
fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_template_list => Shift(yy_state_41)
    T_TYPE_LT => Shift(yy_state_42)
    _ => Error
  }
}

// [63, template_list_prime → template_list •, $]

///|
fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [50, template_list → TYPE_LT • template_args TYPE_GT EOF, $]
// [51, template_args → • type_expr, TYPE_GT / COMMA]
// [52, template_args → • template_args COMMA type_expr, TYPE_GT / COMMA]
// [53, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [54, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_43)
    NT_type_expr => Shift(yy_state_50)
    NT_template_args => Shift(yy_state_51)
    _ => Error
  }
}

// [53, type_expr → TYPE_ATOM •, TYPE_GT / COMMA / EOF]
// [54, type_expr → TYPE_ATOM • TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]

///|
fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_LT => Shift(yy_state_44)
    T_TYPE_GT | T_COMMA | T_EOF => Reduce(1, NT_type_expr, yy_action_39)
    _ => Error
  }
}

// [53, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [54, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [54, type_expr → TYPE_ATOM TYPE_LT • type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]
// [55, type_ref_args → • type_expr, TYPE_GT / COMMA]
// [56, type_ref_args → • type_ref_args COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_43)
    NT_type_expr => Shift(yy_state_45)
    NT_type_ref_args => Shift(yy_state_46)
    _ => Error
  }
}

// [55, type_ref_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_ref_args, yy_action_38)
}

// [54, type_expr → TYPE_ATOM TYPE_LT type_ref_args • TYPE_GT, TYPE_GT / COMMA / EOF]
// [56, type_ref_args → type_ref_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_47)
    T_TYPE_GT => Shift(yy_state_49)
    _ => Error
  }
}

// [53, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [54, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [56, type_ref_args → type_ref_args COMMA • type_expr, TYPE_GT / COMMA]

///|
fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_43)
    NT_type_expr => Shift(yy_state_48)
    _ => Error
  }
}

// [56, type_ref_args → type_ref_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_ref_args, yy_action_37)
}

// [54, type_expr → TYPE_ATOM TYPE_LT type_ref_args TYPE_GT •, TYPE_GT / COMMA / EOF]

///|
fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_expr, yy_action_36)
}

// [51, template_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_template_args, yy_action_35)
}

// [50, template_list → TYPE_LT template_args • TYPE_GT EOF, $]
// [52, template_args → template_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_52)
    T_TYPE_GT => Shift(yy_state_54)
    _ => Error
  }
}

// [52, template_args → template_args COMMA • type_expr, TYPE_GT / COMMA]
// [53, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [54, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_43)
    NT_type_expr => Shift(yy_state_53)
    _ => Error
  }
}

// [52, template_args → template_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_template_args, yy_action_34)
}

// [50, template_list → TYPE_LT template_args TYPE_GT • EOF, $]

///|
fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_55)
    _ => Error
  }
}

// [50, template_list → TYPE_LT template_args TYPE_GT EOF •, $]

///|
fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_template_list, yy_action_33)
}

// [32, type_ref → • type_expr EOF, $]
// [53, type_expr → • TYPE_ATOM, EOF]
// [54, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, EOF]
// [62, type_ref_prime → • type_ref, $]

///|
fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_43)
    NT_type_ref => Shift(yy_state_57)
    NT_type_expr => Shift(yy_state_58)
    _ => Error
  }
}

// [62, type_ref_prime → type_ref •, $]

///|
fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [32, type_ref → type_expr • EOF, $]

///|
fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_59)
    _ => Error
  }
}

// [32, type_ref → type_expr EOF •, $]

///|
fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_ref, yy_action_32)
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
// [61, decl_head_prime → • decl_head, $]

///|
fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_decl_head => Shift(yy_state_61)
    T_DECL_ATTRS => Shift(yy_state_62)
    _ => Error
  }
}

// [61, decl_head_prime → decl_head •, $]

///|
fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
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
fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_63)
    T_KW_DIAGNOSTIC => Shift(yy_state_64)
    T_KW_REQUIRES => Shift(yy_state_66)
    T_KW_ENABLE => Shift(yy_state_68)
    T_KW_TYPE => Shift(yy_state_70)
    T_KW_ALIAS => Shift(yy_state_72)
    T_KW_CONST_ASSERT => Shift(yy_state_74)
    T_KW_CONST => Shift(yy_state_76)
    T_KW_STRUCT => Shift(yy_state_78)
    T_KW_VAR => Shift(yy_state_80)
    T_KW_FN => Shift(yy_state_82)
    T_KW_OVERRIDE => Shift(yy_state_84)
    T_KW_VIRTUAL => Shift(yy_state_88)
    _ => Error
  }
}

// [31, decl_head → DECL_ATTRS EOF •, $]

///|
fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_decl_head, yy_action_31)
}

// [30, decl_head → DECL_ATTRS KW_DIAGNOSTIC • EOF, $]

///|
fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_65)
    _ => Error
  }
}

// [30, decl_head → DECL_ATTRS KW_DIAGNOSTIC EOF •, $]

///|
fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_30)
}

// [29, decl_head → DECL_ATTRS KW_REQUIRES • EOF, $]

///|
fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_67)
    _ => Error
  }
}

// [29, decl_head → DECL_ATTRS KW_REQUIRES EOF •, $]

///|
fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_29)
}

// [28, decl_head → DECL_ATTRS KW_ENABLE • EOF, $]

///|
fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_69)
    _ => Error
  }
}

// [28, decl_head → DECL_ATTRS KW_ENABLE EOF •, $]

///|
fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_28)
}

// [27, decl_head → DECL_ATTRS KW_TYPE • EOF, $]

///|
fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_71)
    _ => Error
  }
}

// [27, decl_head → DECL_ATTRS KW_TYPE EOF •, $]

///|
fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_27)
}

// [26, decl_head → DECL_ATTRS KW_ALIAS • EOF, $]

///|
fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_73)
    _ => Error
  }
}

// [26, decl_head → DECL_ATTRS KW_ALIAS EOF •, $]

///|
fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_26)
}

// [25, decl_head → DECL_ATTRS KW_CONST_ASSERT • EOF, $]

///|
fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_75)
    _ => Error
  }
}

// [25, decl_head → DECL_ATTRS KW_CONST_ASSERT EOF •, $]

///|
fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_25)
}

// [24, decl_head → DECL_ATTRS KW_CONST • EOF, $]

///|
fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_77)
    _ => Error
  }
}

// [24, decl_head → DECL_ATTRS KW_CONST EOF •, $]

///|
fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_24)
}

// [23, decl_head → DECL_ATTRS KW_STRUCT • EOF, $]

///|
fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_79)
    _ => Error
  }
}

// [23, decl_head → DECL_ATTRS KW_STRUCT EOF •, $]

///|
fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_23)
}

// [22, decl_head → DECL_ATTRS KW_VAR • EOF, $]

///|
fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_81)
    _ => Error
  }
}

// [22, decl_head → DECL_ATTRS KW_VAR EOF •, $]

///|
fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_22)
}

// [20, decl_head → DECL_ATTRS KW_FN • EOF, $]

///|
fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_83)
    _ => Error
  }
}

// [20, decl_head → DECL_ATTRS KW_FN EOF •, $]

///|
fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_21)
}

// [19, decl_head → DECL_ATTRS KW_OVERRIDE • KW_FN EOF, $]
// [21, decl_head → DECL_ATTRS KW_OVERRIDE • EOF, $]

///|
fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_85)
    T_KW_FN => Shift(yy_state_86)
    _ => Error
  }
}

// [21, decl_head → DECL_ATTRS KW_OVERRIDE EOF •, $]

///|
fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_20)
}

// [19, decl_head → DECL_ATTRS KW_OVERRIDE KW_FN • EOF, $]

///|
fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_87)
    _ => Error
  }
}

// [19, decl_head → DECL_ATTRS KW_OVERRIDE KW_FN EOF •, $]

///|
fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_decl_head, yy_action_19)
}

// [18, decl_head → DECL_ATTRS KW_VIRTUAL • KW_FN EOF, $]

///|
fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KW_FN => Shift(yy_state_89)
    _ => Error
  }
}

// [18, decl_head → DECL_ATTRS KW_VIRTUAL KW_FN • EOF, $]

///|
fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_90)
    _ => Error
  }
}

// [18, decl_head → DECL_ATTRS KW_VIRTUAL KW_FN EOF •, $]

///|
fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_decl_head, yy_action_18)
}

// [15, directive_prefix_tail → • HASH PREFIX directive_tail EOF, $]
// [60, directive_prefix_tail_prime → • directive_prefix_tail, $]

///|
fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_prefix_tail => Shift(yy_state_92)
    T_HASH => Shift(yy_state_93)
    _ => Error
  }
}

// [60, directive_prefix_tail_prime → directive_prefix_tail •, $]

///|
fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [15, directive_prefix_tail → HASH • PREFIX directive_tail EOF, $]

///|
fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PREFIX => Shift(yy_state_94)
    _ => Error
  }
}

// [15, directive_prefix_tail → HASH PREFIX • directive_tail EOF, $]
// [16, directive_tail → •, EOF]
// [17, directive_tail → • DIRECTIVE_TAIL, EOF]

///|
fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_95)
    NT_directive_tail => Shift(yy_state_96)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_17)
    _ => Error
  }
}

// [17, directive_tail → DIRECTIVE_TAIL •, EOF]

///|
fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_directive_tail, yy_action_16)
}

// [15, directive_prefix_tail → HASH PREFIX directive_tail • EOF, $]

///|
fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_97)
    _ => Error
  }
}

// [15, directive_prefix_tail → HASH PREFIX directive_tail EOF •, $]

///|
fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_directive_prefix_tail, yy_action_15)
}

// [14, directive_line → • HASH DIRECTIVE_HEAD directive_tail EOF, $]
// [59, directive_line_prime → • directive_line, $]

///|
fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_line => Shift(yy_state_99)
    T_HASH => Shift(yy_state_100)
    _ => Error
  }
}

// [59, directive_line_prime → directive_line •, $]

///|
fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [14, directive_line → HASH • DIRECTIVE_HEAD directive_tail EOF, $]

///|
fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_HEAD => Shift(yy_state_101)
    _ => Error
  }
}

// [14, directive_line → HASH DIRECTIVE_HEAD • directive_tail EOF, $]
// [16, directive_tail → •, EOF]
// [17, directive_tail → • DIRECTIVE_TAIL, EOF]

///|
fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_95)
    NT_directive_tail => Shift(yy_state_102)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_17)
    _ => Error
  }
}

// [14, directive_line → HASH DIRECTIVE_HEAD directive_tail • EOF, $]

///|
fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_103)
    _ => Error
  }
}

// [14, directive_line → HASH DIRECTIVE_HEAD directive_tail EOF •, $]

///|
fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_directive_line, yy_action_14)
}

// [3, import_targets → • target_list semis EOF, $]
// [4, import_targets → • IDENT target_list semis EOF, $]
// [7, target_list → • target, COMMA / SEMI / EOF]
// [8, target_list → • target_list COMMA target, COMMA / SEMI / EOF]
// [9, target_list → • target_list COMMA, COMMA / SEMI / EOF]
// [10, target → • IDENT alias, COMMA / SEMI / EOF]
// [11, target → • IDENT LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [58, import_targets_prime → • import_targets, $]

///|
fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_import_targets => Shift(yy_state_105)
    NT_target => Shift(yy_state_106)
    T_IDENT => Shift(yy_state_107)
    NT_target_list => Shift(yy_state_121)
    _ => Error
  }
}

// [58, import_targets_prime → import_targets •, $]

///|
fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [7, target_list → target •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
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
fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_target => Shift(yy_state_106)
    T_AS => Shift(yy_state_108)
    T_LBRACE => Shift(yy_state_110)
    T_IDENT => Shift(yy_state_111)
    NT_alias => Shift(yy_state_112)
    NT_target_list => Shift(yy_state_117)
    T_COMMA | T_SEMI | T_EOF => Reduce(0, NT_alias, yy_action_12)
    _ => Error
  }
}

// [13, alias → AS • IDENT, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_109)
    _ => Error
  }
}

// [13, alias → AS IDENT •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_alias, yy_action_11)
}

// [7, target_list → • target, RBRACE / COMMA]
// [8, target_list → • target_list COMMA target, RBRACE / COMMA]
// [9, target_list → • target_list COMMA, RBRACE / COMMA]
// [10, target → • IDENT alias, RBRACE / COMMA]
// [11, target → • IDENT LBRACE target_list RBRACE, RBRACE / COMMA]
// [11, target → IDENT LBRACE • target_list RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_target => Shift(yy_state_106)
    T_IDENT => Shift(yy_state_111)
    NT_target_list => Shift(yy_state_113)
    _ => Error
  }
}

// [10, target → IDENT • alias, RBRACE / COMMA / SEMI / EOF]
// [11, target → IDENT • LBRACE target_list RBRACE, RBRACE / COMMA / SEMI / EOF]
// [12, alias → •, RBRACE / COMMA / SEMI / EOF]
// [13, alias → • AS IDENT, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AS => Shift(yy_state_108)
    T_LBRACE => Shift(yy_state_110)
    NT_alias => Shift(yy_state_112)
    T_RBRACE | T_COMMA | T_SEMI | T_EOF => Reduce(0, NT_alias, yy_action_12)
    _ => Error
  }
}

// [10, target → IDENT alias •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_target, yy_action_10)
}

// [8, target_list → target_list • COMMA target, RBRACE / COMMA]
// [9, target_list → target_list • COMMA, RBRACE / COMMA]
// [11, target → IDENT LBRACE target_list • RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_114)
    T_COMMA => Shift(yy_state_115)
    _ => Error
  }
}

// [11, target → IDENT LBRACE target_list RBRACE •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_target, yy_action_9)
}

// [8, target_list → target_list COMMA • target, RBRACE / COMMA / SEMI / EOF]
// [9, target_list → target_list COMMA •, RBRACE / COMMA / SEMI / EOF]
// [10, target → • IDENT alias, RBRACE / COMMA / SEMI / EOF]
// [11, target → • IDENT LBRACE target_list RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_111)
    NT_target => Shift(yy_state_116)
    T_RBRACE | T_COMMA | T_SEMI | T_EOF =>
      Reduce(2, NT_target_list, yy_action_8)
    _ => Error
  }
}

// [8, target_list → target_list COMMA target •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_target_list, yy_action_7)
}

// [4, import_targets → IDENT target_list • semis EOF, $]
// [5, semis → •, SEMI / EOF]
// [6, semis → • semis SEMI, SEMI / EOF]
// [8, target_list → target_list • COMMA target, COMMA / SEMI / EOF]
// [9, target_list → target_list • COMMA, COMMA / SEMI / EOF]

///|
fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_115)
    NT_semis => Shift(yy_state_118)
    T_SEMI | T_EOF => Reduce(0, NT_semis, yy_action_6)
    _ => Error
  }
}

// [4, import_targets → IDENT target_list semis • EOF, $]
// [6, semis → semis • SEMI, SEMI / EOF]

///|
fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_119)
    T_EOF => Shift(yy_state_120)
    _ => Error
  }
}

// [6, semis → semis SEMI •, SEMI / EOF]

///|
fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semis, yy_action_5)
}

// [4, import_targets → IDENT target_list semis EOF •, $]

///|
fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_import_targets, yy_action_4)
}

// [3, import_targets → target_list • semis EOF, $]
// [5, semis → •, SEMI / EOF]
// [6, semis → • semis SEMI, SEMI / EOF]
// [8, target_list → target_list • COMMA target, COMMA / SEMI / EOF]
// [9, target_list → target_list • COMMA, COMMA / SEMI / EOF]

///|
fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_115)
    NT_semis => Shift(yy_state_122)
    T_SEMI | T_EOF => Reduce(0, NT_semis, yy_action_6)
    _ => Error
  }
}

// [3, import_targets → target_list semis • EOF, $]
// [6, semis → semis • SEMI, SEMI / EOF]

///|
fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_119)
    T_EOF => Shift(yy_state_123)
    _ => Error
  }
}

// [3, import_targets → target_list semis EOF •, $]

///|
fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_targets, yy_action_3)
}

// [0, raw_top_level_items → • items EOF, $]
// [1, items → •, ITEM / EOF]
// [2, items → • items ITEM, ITEM / EOF]
// [57, raw_top_level_items_prime → • raw_top_level_items, $]

///|
fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_raw_top_level_items => Shift(yy_state_125)
    NT_items => Shift(yy_state_126)
    T_ITEM | T_EOF => Reduce(0, NT_items, yy_action_2)
    _ => Error
  }
}

// [57, raw_top_level_items_prime → raw_top_level_items •, $]

///|
fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [0, raw_top_level_items → items • EOF, $]
// [2, items → items • ITEM, ITEM / EOF]

///|
fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ITEM => Shift(yy_state_127)
    T_EOF => Shift(yy_state_128)
    _ => Error
  }
}

// [2, items → items ITEM •, ITEM / EOF]

///|
fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_items, yy_action_1)
}

// [0, raw_top_level_items → items EOF •, $]

///|
fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
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
        (T_HASH, TK_HASH),
        (T_PREFIX, TK_PREFIX),
        (T_AS, TK_AS),
        (T_ARROW, TK_ARROW),
        (T_LPAREN, TK_LPAREN),
        (T_RPAREN, TK_RPAREN),
        (T_LBRACE, TK_LBRACE),
        (T_RBRACE, TK_RBRACE),
        (T_COLON, TK_COLON),
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
    yy_state_124,
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
    yy_state_104,
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
    yy_state_98,
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
    yy_state_91,
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
    yy_state_60,
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
    yy_state_56,
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
    yy_state_40,
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
    yy_state_24,
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
    yy_state_18,
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
    yy_state_0,
    it => {
      guard it is YYObj_Array__ast_WgslStructMember_(result)
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
