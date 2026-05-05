///|
priv enum Token {
  ITEM(WgslRawTopLevelItem)
  STMT(@ast.WgslStatement)
  IDENT(String)
  TYPE_ATOM((String, String, Int, Int, Int))
  ARG_NAME(@ast.WgslIdent)
  ARG_TYPE((String, @ast.WgslTypeRef?, Int, Int))
  MEMBER_NAME(@ast.WgslIdent)
  MEMBER_TYPE((String, @ast.WgslTypeRef?, Int, Int))
  DECL_TYPE((String, @ast.WgslTypeRef?, Int, Int))
  INIT_EXPR((String, @ast.WgslExprRef?))
  EXPR_REF(@ast.WgslExprRef)
  AT(Int)
  ATTR_NAME(@ast.WgslIdent)
  ATTR_ARGS((String, @ast.WgslExprRef?, Int))
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
  DIRECTIVE_HEAD((String, String, Int, Int, Int, Int))
  DIRECTIVE_TAIL((String, Int, Int))
  SOURCE_TEXT(String)
  HASH
  AS
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
  TK_IDENT
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
  TK_DIRECTIVE_HEAD
  TK_DIRECTIVE_TAIL
  TK_SOURCE_TEXT
  TK_HASH
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
impl Debug for TokenKind with to_repr(self) {
  match self {
    TK_ITEM => to_repr("ITEM")
    TK_STMT => to_repr("STMT")
    TK_IDENT => to_repr("IDENT")
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
    TK_DIRECTIVE_HEAD => to_repr("DIRECTIVE_HEAD")
    TK_DIRECTIVE_TAIL => to_repr("DIRECTIVE_TAIL")
    TK_SOURCE_TEXT => to_repr("SOURCE_TEXT")
    TK_HASH => to_repr("#")
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
priv suberror YYObj_Array_String_ {
  YYObj_Array_String_(Array[String])
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
priv suberror YYObj_Array__common_WgslImportTarget_ {
  YYObj_Array__common_WgslImportTarget_(Array[@common.WgslImportTarget])
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
priv suberror YYObj__ast_WgslFunctionResult_ {
  YYObj__ast_WgslFunctionResult_(@ast.WgslFunctionResult?)
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
priv suberror YYObj__String__Int__Int_ {
  YYObj__String__Int__Int_((String, Int, Int))
}

///|
priv suberror YYObj__String___ast_WgslExprRef___Int_ {
  YYObj__String___ast_WgslExprRef___Int_((String, @ast.WgslExprRef?, Int))
}

///|
priv suberror YYObj__String___ast_WgslExprRef___Int__ {
  YYObj__String___ast_WgslExprRef___Int__((String, @ast.WgslExprRef?, Int?))
}

///|
priv suberror YYObj__String___ast_WgslTypeRef___Int__Int_ {
  YYObj__String___ast_WgslTypeRef___Int__Int_(
    (String, @ast.WgslTypeRef?, Int, Int)
  )
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
priv suberror YYObj__String__String__Int__Int__Int__Int_ {
  YYObj__String__String__Int__Int__Int__Int_(
    (String, String, Int, Int, Int, Int)
  )
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
  T_DIRECTIVE_HEAD
  T_DIRECTIVE_TAIL
  T_SOURCE_TEXT
  T_HASH
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
// 66|    items EOF { $1 }

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
// 120|    items ITEM {
// 121|      let items = $1
// 122|      items.push($2)
// 123|      items
// 124|    }

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
// 119|    { [] }

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
// 128|    target_list semis EOF { $1 }

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
// 129|    module_path=IDENT targets=target_list semis EOF {
// 130|      let out : Array[@common.WgslImportTarget] = []
// 131|      for target in targets {
// 132|        out.push(@common.WgslImportTarget::{
// 133|          raw_path: module_path + "::" + target.raw_path,
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
        out.push(@common.WgslImportTarget::{
          raw_path: module_path + "::" + target.raw_path,
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
// 190|      let (name, _, start, end, name_start, name_end) = head
// 191|      let (tail, raw_tail_start, raw_tail_end) = tail
// 192|      let tail_start = if tail == "" { name_end } else { raw_tail_start }
// 193|      let tail_end = if tail == "" { name_end } else { raw_tail_end }
// 194|      let kind = match name {
// 195|        "ifdef" => @ast.WgslDirectiveKind::Ifdef
// 196|        "ifndef" => @ast.WgslDirectiveKind::Ifndef
// 197|        "if" => @ast.WgslDirectiveKind::If
// 198|        "else" => @ast.WgslDirectiveKind::Else
// 199|        "endif" => @ast.WgslDirectiveKind::Endif
// 200|        "define_import_path" => @ast.WgslDirectiveKind::DefineImportPath
// 201|        "define" => @ast.WgslDirectiveKind::Define
// 202|        "import" => @ast.WgslDirectiveKind::Import
// 203|        "enable" => @ast.WgslDirectiveKind::Enable
// 204|        "requires" => @ast.WgslDirectiveKind::Requires
// 205|        "diagnostic" => @ast.WgslDirectiveKind::Diagnostic
// 206|        _ => @ast.WgslDirectiveKind::Other(name)
// 207|      }
// 208|      @ast.WgslDirective::new(
// 209|        kind,
// 210|        name,
// 211|        tail,
// 212|        start,
// 213|        end,
// 214|        name_start,
// 215|        name_end,
// 216|        tail_start,
// 217|        tail_end,
// 218|      )
// 219|    }

///|
fn yy_action_14(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__String__String__Int__Int__Int__Int_(head)
  guard _args[2].0 is YYObj__String__Int__Int_(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      let (name, _, start, end, name_start, name_end) = head
      let (tail, raw_tail_start, raw_tail_end) = tail
      let tail_start = if tail == "" { name_end } else { raw_tail_start }
      let tail_end = if tail == "" { name_end } else { raw_tail_end }
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
      @ast.WgslDirective::new(
        kind, name, tail, start, end, name_start, name_end, tail_start, tail_end,
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 228|    attrs=attributes KW_VIRTUAL fn_kw=KW_FN EOF {
// 229|      WgslDeclHead::{
// 230|        kind: WgslDeclHeadKind::Function,
// 231|        attributes: attrs,
// 232|        keyword: Some(fn_kw),
// 233|        qualifier: "virtual",
// 234|        qualifier_start: Some($2.start),
// 235|        qualifier_end: Some($2.end),
// 236|        fn_keyword: Some(fn_kw),
// 237|        consumed: 2,
// 238|      }
// 239|    }

///|
fn yy_action_15(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 240|    attrs=attributes KW_OVERRIDE fn_kw=KW_FN EOF {
// 241|      WgslDeclHead::{
// 242|        kind: WgslDeclHeadKind::Function,
// 243|        attributes: attrs,
// 244|        keyword: Some(fn_kw),
// 245|        qualifier: "override",
// 246|        qualifier_start: Some($2.start),
// 247|        qualifier_end: Some($2.end),
// 248|        fn_keyword: Some(fn_kw),
// 249|        consumed: 2,
// 250|      }
// 251|    }

///|
fn yy_action_16(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 264|    attrs=attributes keyword=KW_OVERRIDE EOF {
// 265|      WgslDeclHead::{
// 266|        kind: WgslDeclHeadKind::Override,
// 267|        attributes: attrs,
// 268|        keyword: Some(keyword),
// 269|        qualifier: "",
// 270|        qualifier_start: None,
// 271|        qualifier_end: None,
// 272|        fn_keyword: None,
// 273|        consumed: 1,
// 274|      }
// 275|    }

///|
fn yy_action_17(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::Override,
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
// 252|    attrs=attributes keyword=KW_FN EOF {
// 253|      WgslDeclHead::{
// 254|        kind: WgslDeclHeadKind::Function,
// 255|        attributes: attrs,
// 256|        keyword: Some(keyword),
// 257|        qualifier: "",
// 258|        qualifier_start: None,
// 259|        qualifier_end: None,
// 260|        fn_keyword: Some(keyword),
// 261|        consumed: 1,
// 262|      }
// 263|    }

///|
fn yy_action_18(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::Function,
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
// 276|    attrs=attributes keyword=KW_VAR EOF {
// 277|      WgslDeclHead::{
// 278|        kind: WgslDeclHeadKind::GlobalVariable,
// 279|        attributes: attrs,
// 280|        keyword: Some(keyword),
// 281|        qualifier: "",
// 282|        qualifier_start: None,
// 283|        qualifier_end: None,
// 284|        fn_keyword: None,
// 285|        consumed: 1,
// 286|      }
// 287|    }

///|
fn yy_action_19(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::GlobalVariable,
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
// 288|    attrs=attributes keyword=KW_STRUCT EOF {
// 289|      WgslDeclHead::{
// 290|        kind: WgslDeclHeadKind::Struct,
// 291|        attributes: attrs,
// 292|        keyword: Some(keyword),
// 293|        qualifier: "",
// 294|        qualifier_start: None,
// 295|        qualifier_end: None,
// 296|        fn_keyword: None,
// 297|        consumed: 1,
// 298|      }
// 299|    }

///|
fn yy_action_20(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::Struct,
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
// 300|    attrs=attributes keyword=KW_CONST EOF {
// 301|      WgslDeclHead::{
// 302|        kind: WgslDeclHeadKind::Const,
// 303|        attributes: attrs,
// 304|        keyword: Some(keyword),
// 305|        qualifier: "",
// 306|        qualifier_start: None,
// 307|        qualifier_end: None,
// 308|        fn_keyword: None,
// 309|        consumed: 1,
// 310|      }
// 311|    }

///|
fn yy_action_21(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::Const,
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
// 312|    attrs=attributes keyword=KW_CONST_ASSERT EOF {
// 313|      WgslDeclHead::{
// 314|        kind: WgslDeclHeadKind::ConstAssert,
// 315|        attributes: attrs,
// 316|        keyword: Some(keyword),
// 317|        qualifier: "",
// 318|        qualifier_start: None,
// 319|        qualifier_end: None,
// 320|        fn_keyword: None,
// 321|        consumed: 1,
// 322|      }
// 323|    }

///|
fn yy_action_22(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::ConstAssert,
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
// 324|    attrs=attributes keyword=KW_ALIAS EOF {
// 325|      WgslDeclHead::{
// 326|        kind: WgslDeclHeadKind::TypeAlias,
// 327|        attributes: attrs,
// 328|        keyword: Some(keyword),
// 329|        qualifier: "",
// 330|        qualifier_start: None,
// 331|        qualifier_end: None,
// 332|        fn_keyword: None,
// 333|        consumed: 1,
// 334|      }
// 335|    }

///|
fn yy_action_23(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::TypeAlias,
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
// 336|    attrs=attributes keyword=KW_TYPE EOF {
// 337|      WgslDeclHead::{
// 338|        kind: WgslDeclHeadKind::TypeAlias,
// 339|        attributes: attrs,
// 340|        keyword: Some(keyword),
// 341|        qualifier: "",
// 342|        qualifier_start: None,
// 343|        qualifier_end: None,
// 344|        fn_keyword: None,
// 345|        consumed: 1,
// 346|      }
// 347|    }

///|
fn yy_action_24(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::TypeAlias,
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
// 348|    attrs=attributes keyword=KW_ENABLE EOF {
// 349|      WgslDeclHead::{
// 350|        kind: WgslDeclHeadKind::SourceDirective,
// 351|        attributes: attrs,
// 352|        keyword: Some(keyword),
// 353|        qualifier: "",
// 354|        qualifier_start: None,
// 355|        qualifier_end: None,
// 356|        fn_keyword: None,
// 357|        consumed: 1,
// 358|      }
// 359|    }

///|
fn yy_action_25(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::SourceDirective,
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
// 360|    attrs=attributes keyword=KW_REQUIRES EOF {
// 361|      WgslDeclHead::{
// 362|        kind: WgslDeclHeadKind::SourceDirective,
// 363|        attributes: attrs,
// 364|        keyword: Some(keyword),
// 365|        qualifier: "",
// 366|        qualifier_start: None,
// 367|        qualifier_end: None,
// 368|        fn_keyword: None,
// 369|        consumed: 1,
// 370|      }
// 371|    }

///|
fn yy_action_26(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::SourceDirective,
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
// 372|    attrs=attributes keyword=KW_DIAGNOSTIC EOF {
// 373|      WgslDeclHead::{
// 374|        kind: WgslDeclHeadKind::SourceDirective,
// 375|        attributes: attrs,
// 376|        keyword: Some(keyword),
// 377|        qualifier: "",
// 378|        qualifier_start: None,
// 379|        qualifier_end: None,
// 380|        fn_keyword: None,
// 381|        consumed: 1,
// 382|      }
// 383|    }

///|
fn yy_action_27(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::{
        kind: WgslDeclHeadKind::SourceDirective,
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
// 384|    attrs=attributes EOF {
// 385|      WgslDeclHead::raw(attrs)
// 386|    }

///|
fn yy_action_28(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  YYObj_WgslDeclHead(
    {
      ()
      WgslDeclHead::raw(attrs)
    },
  )
}

// file:///./wgsl_parser.mbty
// 390|    value=type_expr EOF { value }

///|
fn yy_action_29(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj__ast_WgslTypeRef(
    {
      ()
      value
    },
  )
}

// file:///./wgsl_parser.mbty
// 568|    TYPE_LT args=template_args TYPE_GT EOF { args }

///|
fn yy_action_30(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_String_(args)
  YYObj_Array_String_(
    {
      ()
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 575|    args=template_args "," value=type_expr {
// 576|      args.push(value.canonical_text())
// 577|      args
// 578|    }

///|
fn yy_action_31(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_String_(args)
  guard _args[2].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array_String_(
    {
      ()
      args.push(value.canonical_text())
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 572|    value=type_expr {
// 573|      [value.canonical_text()]
// 574|    }

///|
fn yy_action_32(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array_String_(
    {
      ()
      [value.canonical_text()]
    },
  )
}

// file:///./wgsl_parser.mbty
// 585|    atom=TYPE_ATOM TYPE_LT args=type_ref_args gt=TYPE_GT {
// 586|      wgsl_type_ref_from_atom(atom, args, gt)
// 587|    }

///|
fn yy_action_33(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 594|    args=type_ref_args "," value=type_expr {
// 595|      args.push(value)
// 596|      args
// 597|    }

///|
fn yy_action_34(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 591|    value=type_expr {
// 592|      [value]
// 593|    }

///|
fn yy_action_35(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslTypeRef(value)
  YYObj_Array__ast_WgslTypeRef_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 582|    atom=TYPE_ATOM {
// 583|      wgsl_type_ref_from_atom(atom, [], atom.4)
// 584|    }

///|
fn yy_action_36(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String__String__Int__Int__Int_(atom)
  YYObj__ast_WgslTypeRef(
    {
      ()
      wgsl_type_ref_from_atom(atom, [], atom.4)
    },
  )
}

// file:///./wgsl_parser.mbty
// 394|    "(" ")" EOF { [] }

///|
fn yy_action_37(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 395|    "(" args=function_arg_list optional_comma ")" EOF { args }

///|
fn yy_action_38(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslFunctionArgument_(args)
  YYObj_Array__ast_WgslFunctionArgument_(
    {
      ()
      args
    },
  )
}

// file:///./wgsl_parser.mbty
// 547|    attrs=attributes name=ARG_NAME ":" ty=ARG_TYPE {
// 548|      let (_, ty_ref, _, ty_end) = ty
// 549|      let start = if attrs.length() > 0 { attrs[0].start() } else { name.start }
// 550|      @ast.WgslFunctionArgument::new(
// 551|        attrs,
// 552|        name.name,
// 553|        start,
// 554|        ty_end,
// 555|        name.start,
// 556|        name.end,
// 557|        ty_ref,
// 558|      )
// 559|    }

///|
fn yy_action_39(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(name)
  guard _args[3].0 is YYObj__String___ast_WgslTypeRef___Int__Int_(ty)
  YYObj__ast_WgslFunctionArgument(
    {
      ()
      let (_, ty_ref, _, ty_end) = ty
      let start = if attrs.length() > 0 { attrs[0].start() } else { name.start }
      @ast.WgslFunctionArgument::new(
        attrs,
        name.name,
        start,
        ty_end,
        name.start,
        name.end,
        ty_ref,
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 540|    args=function_arg_list "," value=function_arg {
// 541|      args.push(value)
// 542|      args
// 543|    }

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
// 564|    "," { () }

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
// 563|    { () }

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
// 537|    value=function_arg {
// 538|      [value]
// 539|    }

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
// 399|    arrow=ARROW attrs=attributes ty=ARG_TYPE EOF {
// 400|      let (ty_text, ty_ref, _, ty_end) = ty
// 401|      Some(@ast.WgslFunctionResult::new(attrs, arrow, ty_end, ty_text, ty_ref))
// 402|    }

///|
fn yy_action_44(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(arrow)
  guard _args[1].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[2].0 is YYObj__String___ast_WgslTypeRef___Int__Int_(ty)
  YYObj__ast_WgslFunctionResult_(
    {
      ()
      let (ty_text, ty_ref, _, ty_end) = ty
      Some(@ast.WgslFunctionResult::new(attrs, arrow, ty_end, ty_text, ty_ref))
    },
  )
}

// file:///./wgsl_parser.mbty
// 406|    "{" "}" EOF { [] }

///|
fn yy_action_45(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 407|    "{" members=struct_member_list optional_member_separator "}" EOF {
// 408|      members
// 409|    }

///|
fn yy_action_46(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_WgslStructMember_(members)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      members
    },
  )
}

// file:///./wgsl_parser.mbty
// 86|    attributes attribute {
// 87|      let attributes = $1
// 88|      attributes.push($2)
// 89|      attributes
// 90|    }

///|
fn yy_action_47(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
//  94|    at=AT name=ATTR_NAME args=attribute_args {
//  95|      let (arguments, arguments_ref, args_end) = args
//  96|      let end = match args_end {
//  97|        Some(value) => value
//  98|        None => name.end
//  99|      }
// 100|      @ast.WgslAttribute::new(
// 101|        name.name,
// 102|        at,
// 103|        end,
// 104|        arguments,
// 105|        arguments_ref,
// 106|      )
// 107|    }

///|
fn yy_action_48(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(at)
  guard _args[1].0 is YYObj__ast_WgslIdent(name)
  guard _args[2].0 is YYObj__String___ast_WgslExprRef___Int__(args)
  YYObj__ast_WgslAttribute(
    {
      ()
      let (arguments, arguments_ref, args_end) = args
      let end = match args_end {
        Some(value) => value
        None => name.end
      }
      @ast.WgslAttribute::new(name.name, at, end, arguments, arguments_ref)
    },
  )
}

// file:///./wgsl_parser.mbty
// 112|    ATTR_ARGS {
// 113|      let (arguments, arguments_ref, end) = $1
// 114|      (arguments, arguments_ref, Some(end))
// 115|    }

///|
fn yy_action_49(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String___ast_WgslExprRef___Int_(_dollar1)
  YYObj__String___ast_WgslExprRef___Int__(
    {
      ()
      let (arguments, arguments_ref, end) = _dollar1
      (arguments, arguments_ref, Some(end))
    },
  )
}

// file:///./wgsl_parser.mbty
// 111|    { ("", None, None) }

///|
fn yy_action_50(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__String___ast_WgslExprRef___Int__(
    {
      ()
      ("", None, None)
    },
  )
}

// file:///./wgsl_parser.mbty
// 423|    attrs=attributes name=MEMBER_NAME ":" ty=MEMBER_TYPE {
// 424|      let (ty_text, ty_ref, _, ty_end) = ty
// 425|      let start = if attrs.length() > 0 { attrs[0].start() } else { name.start }
// 426|      @ast.WgslStructMember::new(
// 427|        attrs,
// 428|        name.name,
// 429|        start,
// 430|        ty_end,
// 431|        name.start,
// 432|        name.end,
// 433|        ty_text,
// 434|        ty_ref,
// 435|      )
// 436|    }

///|
fn yy_action_51(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__ast_WgslAttribute_(attrs)
  guard _args[1].0 is YYObj__ast_WgslIdent(name)
  guard _args[3].0 is YYObj__String___ast_WgslTypeRef___Int__Int_(ty)
  YYObj__ast_WgslStructMember(
    {
      ()
      let (ty_text, ty_ref, _, ty_end) = ty
      let start = if attrs.length() > 0 { attrs[0].start() } else { name.start }
      @ast.WgslStructMember::new(
        attrs,
        name.name,
        start,
        ty_end,
        name.start,
        name.end,
        ty_text,
        ty_ref,
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 416|    members=struct_member_list member_separator value=struct_member {
// 417|      members.push(value)
// 418|      members
// 419|    }

///|
fn yy_action_52(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 533|    member_separator { () }

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
// 527|    "," { () }

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
// 528|    ";" { () }

///|
fn yy_action_55(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 532|    { () }

///|
fn yy_action_56(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Unit(
    {
      ()
      ()
    },
  )
}

// file:///./wgsl_parser.mbty
// 413|    value=struct_member {
// 414|      [value]
// 415|    }

///|
fn yy_action_57(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslStructMember(value)
  YYObj_Array__ast_WgslStructMember_(
    {
      ()
      [value]
    },
  )
}

// file:///./wgsl_parser.mbty
// 85|    { [] }

///|
fn yy_action_58(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj_Array__ast_WgslAttribute_(
    {
      ()
      []
    },
  )
}

// file:///./wgsl_parser.mbty
// 440|    EOF { (None, None, None, None) }

///|
fn yy_action_59(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__String____ast_WgslTypeRef___String____ast_WgslExprRef__(
    {
      ()
      (None, None, None, None)
    },
  )
}

// file:///./wgsl_parser.mbty
// 441|    ":" ty=DECL_TYPE init=initializer_opt EOF {
// 442|      let (ty_text, ty_ref, _, _) = ty
// 443|      let (init_text, init_ref) = init
// 444|      (Some(ty_text), ty_ref, init_text, init_ref)
// 445|    }

///|
fn yy_action_60(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__String___ast_WgslTypeRef___Int__Int_(ty)
  guard _args[2].0 is YYObj__String____ast_WgslExprRef__(init)
  YYObj__String____ast_WgslTypeRef___String____ast_WgslExprRef__(
    {
      ()
      let (ty_text, ty_ref, _, _) = ty
      let (init_text, init_ref) = init
      (Some(ty_text), ty_ref, init_text, init_ref)
    },
  )
}

// file:///./wgsl_parser.mbty
// 516|    initializer { $1 }

///|
fn yy_action_61(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String____ast_WgslExprRef__(_dollar1)
  YYObj__String____ast_WgslExprRef__(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 515|    { (None, None) }

///|
fn yy_action_62(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__String____ast_WgslExprRef__(
    {
      ()
      (None, None)
    },
  )
}

// file:///./wgsl_parser.mbty
// 446|    init=initializer EOF {
// 447|      let (init_text, init_ref) = init
// 448|      (None, None, init_text, init_ref)
// 449|    }

///|
fn yy_action_63(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 520|    "=" expr=INIT_EXPR {
// 521|      let (text, expr_ref) = expr
// 522|      (Some(text), expr_ref)
// 523|    }

///|
fn yy_action_64(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 453|    "=" ty=DECL_TYPE EOF {
// 454|      let (ty_text, ty_ref, _, _) = ty
// 455|      (ty_text, ty_ref)
// 456|    }

///|
fn yy_action_65(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[1].0 is YYObj__String___ast_WgslTypeRef___Int__Int_(ty)
  YYObj__String___ast_WgslTypeRef__(
    {
      ()
      let (ty_text, ty_ref, _, _) = ty
      (ty_text, ty_ref)
    },
  )
}

// file:///./wgsl_parser.mbty
// 460|    text=SOURCE_TEXT keyword=KW_ENABLE tail=directive_tail EOF {
// 461|      let (tail, raw_tail_start, raw_tail_end) = tail
// 462|      let tail_start = if tail == "" { keyword.end } else { raw_tail_start }
// 463|      let tail_end = if tail == "" { keyword.end } else { raw_tail_end }
// 464|      @ast.WgslDirective::new(
// 465|        @ast.WgslDirectiveKind::Enable,
// 466|        keyword.name,
// 467|        tail,
// 468|        0,
// 469|        text.length(),
// 470|        keyword.start,
// 471|        keyword.end,
// 472|        tail_start,
// 473|        tail_end,
// 474|      )
// 475|    }

///|
fn yy_action_66(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(text)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  guard _args[2].0 is YYObj__String__Int__Int_(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      let (tail, raw_tail_start, raw_tail_end) = tail
      let tail_start = if tail == "" { keyword.end } else { raw_tail_start }
      let tail_end = if tail == "" { keyword.end } else { raw_tail_end }
      @ast.WgslDirective::new(
        @ast.WgslDirectiveKind::Enable,
        keyword.name,
        tail,
        0,
        text.length(),
        keyword.start,
        keyword.end,
        tail_start,
        tail_end,
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 476|    text=SOURCE_TEXT keyword=KW_REQUIRES tail=directive_tail EOF {
// 477|      let (tail, raw_tail_start, raw_tail_end) = tail
// 478|      let tail_start = if tail == "" { keyword.end } else { raw_tail_start }
// 479|      let tail_end = if tail == "" { keyword.end } else { raw_tail_end }
// 480|      @ast.WgslDirective::new(
// 481|        @ast.WgslDirectiveKind::Requires,
// 482|        keyword.name,
// 483|        tail,
// 484|        0,
// 485|        text.length(),
// 486|        keyword.start,
// 487|        keyword.end,
// 488|        tail_start,
// 489|        tail_end,
// 490|      )
// 491|    }

///|
fn yy_action_67(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(text)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  guard _args[2].0 is YYObj__String__Int__Int_(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      let (tail, raw_tail_start, raw_tail_end) = tail
      let tail_start = if tail == "" { keyword.end } else { raw_tail_start }
      let tail_end = if tail == "" { keyword.end } else { raw_tail_end }
      @ast.WgslDirective::new(
        @ast.WgslDirectiveKind::Requires,
        keyword.name,
        tail,
        0,
        text.length(),
        keyword.start,
        keyword.end,
        tail_start,
        tail_end,
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 224|    DIRECTIVE_TAIL { $1 }

///|
fn yy_action_68(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__String__Int__Int_(_dollar1)
  YYObj__String__Int__Int_(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 492|    text=SOURCE_TEXT keyword=KW_DIAGNOSTIC tail=directive_tail EOF {
// 493|      let (tail, raw_tail_start, raw_tail_end) = tail
// 494|      let tail_start = if tail == "" { keyword.end } else { raw_tail_start }
// 495|      let tail_end = if tail == "" { keyword.end } else { raw_tail_end }
// 496|      @ast.WgslDirective::new(
// 497|        @ast.WgslDirectiveKind::Diagnostic,
// 498|        keyword.name,
// 499|        tail,
// 500|        0,
// 501|        text.length(),
// 502|        keyword.start,
// 503|        keyword.end,
// 504|        tail_start,
// 505|        tail_end,
// 506|      )
// 507|    }

///|
fn yy_action_69(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj_String(text)
  guard _args[1].0 is YYObj__ast_WgslIdent(keyword)
  guard _args[2].0 is YYObj__String__Int__Int_(tail)
  YYObj__ast_WgslDirective(
    {
      ()
      let (tail, raw_tail_start, raw_tail_end) = tail
      let tail_start = if tail == "" { keyword.end } else { raw_tail_start }
      let tail_end = if tail == "" { keyword.end } else { raw_tail_end }
      @ast.WgslDirective::new(
        @ast.WgslDirectiveKind::Diagnostic,
        keyword.name,
        tail,
        0,
        text.length(),
        keyword.start,
        keyword.end,
        tail_start,
        tail_end,
      )
    },
  )
}

// file:///./wgsl_parser.mbty
// 223|    { ("", 0, 0) }

///|
fn yy_action_70(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  YYObj__String__Int__Int_(
    {
      ()
      ("", 0, 0)
    },
  )
}

// file:///./wgsl_parser.mbty
// 511|    EXPR_REF EOF { $1 }

///|
fn yy_action_71(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_WgslExprRef(_dollar1)
  YYObj__ast_WgslExprRef(
    {
      ()
      _dollar1
    },
  )
}

// file:///./wgsl_parser.mbty
// 70|    open=LBRACE statements close=RBRACE EOF {
// 71|      @ast.WgslBlock::new(open, close + 1, $2)
// 72|    }

///|
fn yy_action_72(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 77|    statements STMT {
// 78|      let statements = $1
// 79|      statements.push($2)
// 80|      statements
// 81|    }

///|
fn yy_action_73(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
// 76|    { [] }

///|
fn yy_action_74(_last_pos : Int, _args : ArrayView[(YYObj, Int, Int)]) -> YYObj {
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
    IDENT(data) => (T_IDENT, YYObj_String(data))
    TYPE_ATOM(data) =>
      (T_TYPE_ATOM, YYObj__String__String__Int__Int__Int_(data))
    ARG_NAME(data) => (T_ARG_NAME, YYObj__ast_WgslIdent(data))
    ARG_TYPE(data) =>
      (T_ARG_TYPE, YYObj__String___ast_WgslTypeRef___Int__Int_(data))
    MEMBER_NAME(data) => (T_MEMBER_NAME, YYObj__ast_WgslIdent(data))
    MEMBER_TYPE(data) =>
      (T_MEMBER_TYPE, YYObj__String___ast_WgslTypeRef___Int__Int_(data))
    DECL_TYPE(data) =>
      (T_DECL_TYPE, YYObj__String___ast_WgslTypeRef___Int__Int_(data))
    INIT_EXPR(data) => (T_INIT_EXPR, YYObj__String___ast_WgslExprRef__(data))
    EXPR_REF(data) => (T_EXPR_REF, YYObj__ast_WgslExprRef(data))
    AT(data) => (T_AT, YYObj_Int(data))
    ATTR_NAME(data) => (T_ATTR_NAME, YYObj__ast_WgslIdent(data))
    ATTR_ARGS(data) =>
      (T_ATTR_ARGS, YYObj__String___ast_WgslExprRef___Int_(data))
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
    DIRECTIVE_HEAD(data) =>
      (T_DIRECTIVE_HEAD, YYObj__String__String__Int__Int__Int__Int_(data))
    DIRECTIVE_TAIL(data) => (T_DIRECTIVE_TAIL, YYObj__String__Int__Int_(data))
    SOURCE_TEXT(data) => (T_SOURCE_TEXT, YYObj_String(data))
    HASH => (T_HASH, YYObj_Void)
    AS => (T_AS, YYObj_Void)
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
// [88, block_prime → • block, $]

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_block => Shift(yy_state_1)
    T_LBRACE => Shift(yy_state_2)
    _ => Error
  }
}

// [88, block_prime → block •, $]

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
    T_STMT | T_RBRACE => Reduce(0, NT_statements, yy_action_74)
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
  ReduceNoLookahead(2, NT_statements, yy_action_73)
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
  ReduceNoLookahead(4, NT_block, yy_action_72)
}

// [55, const_assert_expr → • EXPR_REF EOF, $]
// [87, const_assert_expr_prime → • const_assert_expr, $]

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_const_assert_expr => Shift(yy_state_8)
    T_EXPR_REF => Shift(yy_state_9)
    _ => Error
  }
}

// [87, const_assert_expr_prime → const_assert_expr •, $]

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [55, const_assert_expr → EXPR_REF • EOF, $]

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_10)
    _ => Error
  }
}

// [55, const_assert_expr → EXPR_REF EOF •, $]

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_const_assert_expr, yy_action_71)
}

// [52, source_directive → • SOURCE_TEXT KW_ENABLE directive_tail EOF, $]
// [53, source_directive → • SOURCE_TEXT KW_REQUIRES directive_tail EOF, $]
// [54, source_directive → • SOURCE_TEXT KW_DIAGNOSTIC directive_tail EOF, $]
// [86, source_directive_prime → • source_directive, $]

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_source_directive => Shift(yy_state_12)
    T_SOURCE_TEXT => Shift(yy_state_13)
    _ => Error
  }
}

// [86, source_directive_prime → source_directive •, $]

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [52, source_directive → SOURCE_TEXT • KW_ENABLE directive_tail EOF, $]
// [53, source_directive → SOURCE_TEXT • KW_REQUIRES directive_tail EOF, $]
// [54, source_directive → SOURCE_TEXT • KW_DIAGNOSTIC directive_tail EOF, $]

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KW_DIAGNOSTIC => Shift(yy_state_14)
    T_KW_REQUIRES => Shift(yy_state_18)
    T_KW_ENABLE => Shift(yy_state_21)
    _ => Error
  }
}

// [23, directive_tail → •, EOF]
// [24, directive_tail → • DIRECTIVE_TAIL, EOF]
// [54, source_directive → SOURCE_TEXT KW_DIAGNOSTIC • directive_tail EOF, $]

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_tail => Shift(yy_state_15)
    T_DIRECTIVE_TAIL => Shift(yy_state_17)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_70)
    _ => Error
  }
}

// [54, source_directive → SOURCE_TEXT KW_DIAGNOSTIC directive_tail • EOF, $]

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_16)
    _ => Error
  }
}

// [54, source_directive → SOURCE_TEXT KW_DIAGNOSTIC directive_tail EOF •, $]

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_69)
}

// [24, directive_tail → DIRECTIVE_TAIL •, EOF]

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_directive_tail, yy_action_68)
}

// [23, directive_tail → •, EOF]
// [24, directive_tail → • DIRECTIVE_TAIL, EOF]
// [53, source_directive → SOURCE_TEXT KW_REQUIRES • directive_tail EOF, $]

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_17)
    NT_directive_tail => Shift(yy_state_19)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_70)
    _ => Error
  }
}

// [53, source_directive → SOURCE_TEXT KW_REQUIRES directive_tail • EOF, $]

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_20)
    _ => Error
  }
}

// [53, source_directive → SOURCE_TEXT KW_REQUIRES directive_tail EOF •, $]

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_67)
}

// [23, directive_tail → •, EOF]
// [24, directive_tail → • DIRECTIVE_TAIL, EOF]
// [52, source_directive → SOURCE_TEXT KW_ENABLE • directive_tail EOF, $]

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_17)
    NT_directive_tail => Shift(yy_state_22)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_70)
    _ => Error
  }
}

// [52, source_directive → SOURCE_TEXT KW_ENABLE directive_tail • EOF, $]

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_23)
    _ => Error
  }
}

// [52, source_directive → SOURCE_TEXT KW_ENABLE directive_tail EOF •, $]

///|
fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_source_directive, yy_action_66)
}

// [51, type_alias_tail → • EQUAL DECL_TYPE EOF, $]
// [85, type_alias_tail_prime → • type_alias_tail, $]

///|
fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_alias_tail => Shift(yy_state_25)
    T_EQUAL => Shift(yy_state_26)
    _ => Error
  }
}

// [85, type_alias_tail_prime → type_alias_tail •, $]

///|
fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [51, type_alias_tail → EQUAL • DECL_TYPE EOF, $]

///|
fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_TYPE => Shift(yy_state_27)
    _ => Error
  }
}

// [51, type_alias_tail → EQUAL DECL_TYPE • EOF, $]

///|
fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_28)
    _ => Error
  }
}

// [51, type_alias_tail → EQUAL DECL_TYPE EOF •, $]

///|
fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_alias_tail, yy_action_65)
}

// [48, typed_initializer_tail → • EOF, $]
// [49, typed_initializer_tail → • COLON DECL_TYPE initializer_opt EOF, $]
// [50, typed_initializer_tail → • initializer EOF, $]
// [58, initializer → • EQUAL INIT_EXPR, EOF]
// [84, typed_initializer_tail_prime → • typed_initializer_tail, $]

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

// [84, typed_initializer_tail_prime → typed_initializer_tail •, $]

///|
fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [58, initializer → EQUAL • INIT_EXPR, EOF]

///|
fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INIT_EXPR => Shift(yy_state_32)
    _ => Error
  }
}

// [58, initializer → EQUAL INIT_EXPR •, EOF]

///|
fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_initializer, yy_action_64)
}

// [50, typed_initializer_tail → initializer • EOF, $]

///|
fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_34)
    _ => Error
  }
}

// [50, typed_initializer_tail → initializer EOF •, $]

///|
fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_typed_initializer_tail, yy_action_63)
}

// [49, typed_initializer_tail → COLON • DECL_TYPE initializer_opt EOF, $]

///|
fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DECL_TYPE => Shift(yy_state_36)
    _ => Error
  }
}

// [49, typed_initializer_tail → COLON DECL_TYPE • initializer_opt EOF, $]
// [56, initializer_opt → •, EOF]
// [57, initializer_opt → • initializer, EOF]
// [58, initializer → • EQUAL INIT_EXPR, EOF]

///|
fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_31)
    NT_initializer => Shift(yy_state_37)
    NT_initializer_opt => Shift(yy_state_38)
    T_EOF => Reduce(0, NT_initializer_opt, yy_action_62)
    _ => Error
  }
}

// [57, initializer_opt → initializer •, EOF]

///|
fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_initializer_opt, yy_action_61)
}

// [49, typed_initializer_tail → COLON DECL_TYPE initializer_opt • EOF, $]

///|
fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_39)
    _ => Error
  }
}

// [49, typed_initializer_tail → COLON DECL_TYPE initializer_opt EOF •, $]

///|
fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_typed_initializer_tail, yy_action_60)
}

// [48, typed_initializer_tail → EOF •, $]

///|
fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_typed_initializer_tail, yy_action_59)
}

// [43, struct_members → • LBRACE RBRACE EOF, $]
// [44, struct_members → • LBRACE struct_member_list optional_member_separator RBRACE EOF, $]
// [83, struct_members_prime → • struct_members, $]

///|
fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_members => Shift(yy_state_42)
    T_LBRACE => Shift(yy_state_43)
    _ => Error
  }
}

// [83, struct_members_prime → struct_members •, $]

///|
fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [4, attributes → •, MEMBER_NAME / AT]
// [5, attributes → • attributes attribute, MEMBER_NAME / AT]
// [43, struct_members → LBRACE • RBRACE EOF, $]
// [44, struct_members → LBRACE • struct_member_list optional_member_separator RBRACE EOF, $]
// [45, struct_member_list → • struct_member, RBRACE / COMMA / SEMI]
// [46, struct_member_list → • struct_member_list member_separator struct_member, RBRACE / COMMA / SEMI]
// [47, struct_member → • attributes MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_member => Shift(yy_state_44)
    NT_struct_member_list => Shift(yy_state_45)
    NT_attributes => Shift(yy_state_50)
    T_RBRACE => Shift(yy_state_62)
    T_MEMBER_NAME | T_AT => Reduce(0, NT_attributes, yy_action_58)
    _ => Error
  }
}

// [45, struct_member_list → struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_struct_member_list, yy_action_57)
}

// [44, struct_members → LBRACE struct_member_list • optional_member_separator RBRACE EOF, $]
// [46, struct_member_list → struct_member_list • member_separator struct_member, RBRACE / COMMA / SEMI]
// [59, member_separator → • COMMA, MEMBER_NAME / AT / RBRACE]
// [60, member_separator → • SEMI, MEMBER_NAME / AT / RBRACE]
// [61, optional_member_separator → •, RBRACE]
// [62, optional_member_separator → • member_separator, RBRACE]

///|
fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_46)
    T_COMMA => Shift(yy_state_47)
    NT_member_separator => Shift(yy_state_48)
    NT_optional_member_separator => Shift(yy_state_59)
    T_RBRACE => Reduce(0, NT_optional_member_separator, yy_action_56)
    _ => Error
  }
}

// [60, member_separator → SEMI •, MEMBER_NAME / AT / RBRACE]

///|
fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_55)
}

// [59, member_separator → COMMA •, MEMBER_NAME / AT / RBRACE]

///|
fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_member_separator, yy_action_54)
}

// [4, attributes → •, MEMBER_NAME / AT]
// [5, attributes → • attributes attribute, MEMBER_NAME / AT]
// [46, struct_member_list → struct_member_list member_separator • struct_member, RBRACE / COMMA / SEMI]
// [47, struct_member → • attributes MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]
// [62, optional_member_separator → member_separator •, RBRACE]

///|
fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_struct_member => Shift(yy_state_49)
    NT_attributes => Shift(yy_state_50)
    T_MEMBER_NAME | T_AT => Reduce(0, NT_attributes, yy_action_58)
    T_RBRACE => Reduce(1, NT_optional_member_separator, yy_action_53)
    _ => Error
  }
}

// [46, struct_member_list → struct_member_list member_separator struct_member •, RBRACE / COMMA / SEMI]

///|
fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_member_list, yy_action_52)
}

// [5, attributes → attributes • attribute, MEMBER_NAME / AT]
// [6, attribute → • AT ATTR_NAME attribute_args, MEMBER_NAME / AT]
// [47, struct_member → attributes • MEMBER_NAME COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_NAME => Shift(yy_state_51)
    T_AT => Shift(yy_state_54)
    NT_attribute => Shift(yy_state_58)
    _ => Error
  }
}

// [47, struct_member → attributes MEMBER_NAME • COLON MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_52)
    _ => Error
  }
}

// [47, struct_member → attributes MEMBER_NAME COLON • MEMBER_TYPE, RBRACE / COMMA / SEMI]

///|
fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MEMBER_TYPE => Shift(yy_state_53)
    _ => Error
  }
}

// [47, struct_member → attributes MEMBER_NAME COLON MEMBER_TYPE •, RBRACE / COMMA / SEMI]

///|
fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_struct_member, yy_action_51)
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
    | T_EOF => Reduce(0, NT_attribute_args, yy_action_50)
    _ => Error
  }
}

// [8, attribute_args → ATTR_ARGS •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]

///|
fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_attribute_args, yy_action_49)
}

// [6, attribute → AT ATTR_NAME attribute_args •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]

///|
fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_attribute, yy_action_48)
}

// [5, attributes → attributes attribute •, ARG_NAME / ARG_TYPE / MEMBER_NAME / AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]

///|
fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_attributes, yy_action_47)
}

// [44, struct_members → LBRACE struct_member_list optional_member_separator • RBRACE EOF, $]

///|
fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_60)
    _ => Error
  }
}

// [44, struct_members → LBRACE struct_member_list optional_member_separator RBRACE • EOF, $]

///|
fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_61)
    _ => Error
  }
}

// [44, struct_members → LBRACE struct_member_list optional_member_separator RBRACE EOF •, $]

///|
fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_struct_members, yy_action_46)
}

// [43, struct_members → LBRACE RBRACE • EOF, $]

///|
fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_63)
    _ => Error
  }
}

// [43, struct_members → LBRACE RBRACE EOF •, $]

///|
fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_struct_members, yy_action_45)
}

// [42, function_result → • ARROW attributes ARG_TYPE EOF, $]
// [82, function_result_prime → • function_result, $]

///|
fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_result => Shift(yy_state_65)
    T_ARROW => Shift(yy_state_66)
    _ => Error
  }
}

// [82, function_result_prime → function_result •, $]

///|
fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [4, attributes → •, ARG_TYPE / AT]
// [5, attributes → • attributes attribute, ARG_TYPE / AT]
// [42, function_result → ARROW • attributes ARG_TYPE EOF, $]

///|
fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attributes => Shift(yy_state_67)
    T_ARG_TYPE | T_AT => Reduce(0, NT_attributes, yy_action_58)
    _ => Error
  }
}

// [5, attributes → attributes • attribute, ARG_TYPE / AT]
// [6, attribute → • AT ATTR_NAME attribute_args, ARG_TYPE / AT]
// [42, function_result → ARROW attributes • ARG_TYPE EOF, $]

///|
fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_54)
    NT_attribute => Shift(yy_state_58)
    T_ARG_TYPE => Shift(yy_state_68)
    _ => Error
  }
}

// [42, function_result → ARROW attributes ARG_TYPE • EOF, $]

///|
fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_69)
    _ => Error
  }
}

// [42, function_result → ARROW attributes ARG_TYPE EOF •, $]

///|
fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_result, yy_action_44)
}

// [40, function_args → • LPAREN RPAREN EOF, $]
// [41, function_args → • LPAREN function_arg_list optional_comma RPAREN EOF, $]
// [81, function_args_prime → • function_args, $]

///|
fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_args => Shift(yy_state_71)
    T_LPAREN => Shift(yy_state_72)
    _ => Error
  }
}

// [81, function_args_prime → function_args •, $]

///|
fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [4, attributes → •, ARG_NAME / AT]
// [5, attributes → • attributes attribute, ARG_NAME / AT]
// [40, function_args → LPAREN • RPAREN EOF, $]
// [41, function_args → LPAREN • function_arg_list optional_comma RPAREN EOF, $]
// [63, function_arg_list → • function_arg, RPAREN / COMMA]
// [64, function_arg_list → • function_arg_list COMMA function_arg, RPAREN / COMMA]
// [65, function_arg → • attributes ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_arg => Shift(yy_state_73)
    NT_function_arg_list => Shift(yy_state_74)
    NT_attributes => Shift(yy_state_77)
    T_RPAREN => Shift(yy_state_84)
    T_ARG_NAME | T_AT => Reduce(0, NT_attributes, yy_action_58)
    _ => Error
  }
}

// [63, function_arg_list → function_arg •, RPAREN / COMMA]

///|
fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_arg_list, yy_action_43)
}

// [41, function_args → LPAREN function_arg_list • optional_comma RPAREN EOF, $]
// [64, function_arg_list → function_arg_list • COMMA function_arg, RPAREN / COMMA]
// [66, optional_comma → •, RPAREN]
// [67, optional_comma → • COMMA, RPAREN]

///|
fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_75)
    NT_optional_comma => Shift(yy_state_81)
    T_RPAREN => Reduce(0, NT_optional_comma, yy_action_42)
    _ => Error
  }
}

// [4, attributes → •, ARG_NAME / AT]
// [5, attributes → • attributes attribute, ARG_NAME / AT]
// [64, function_arg_list → function_arg_list COMMA • function_arg, RPAREN / COMMA]
// [65, function_arg → • attributes ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]
// [67, optional_comma → COMMA •, RPAREN]

///|
fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_arg => Shift(yy_state_76)
    NT_attributes => Shift(yy_state_77)
    T_ARG_NAME | T_AT => Reduce(0, NT_attributes, yy_action_58)
    T_RPAREN => Reduce(1, NT_optional_comma, yy_action_41)
    _ => Error
  }
}

// [64, function_arg_list → function_arg_list COMMA function_arg •, RPAREN / COMMA]

///|
fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_arg_list, yy_action_40)
}

// [5, attributes → attributes • attribute, ARG_NAME / AT]
// [6, attribute → • AT ATTR_NAME attribute_args, ARG_NAME / AT]
// [65, function_arg → attributes • ARG_NAME COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_54)
    NT_attribute => Shift(yy_state_58)
    T_ARG_NAME => Shift(yy_state_78)
    _ => Error
  }
}

// [65, function_arg → attributes ARG_NAME • COLON ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_79)
    _ => Error
  }
}

// [65, function_arg → attributes ARG_NAME COLON • ARG_TYPE, RPAREN / COMMA]

///|
fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARG_TYPE => Shift(yy_state_80)
    _ => Error
  }
}

// [65, function_arg → attributes ARG_NAME COLON ARG_TYPE •, RPAREN / COMMA]

///|
fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_arg, yy_action_39)
}

// [41, function_args → LPAREN function_arg_list optional_comma • RPAREN EOF, $]

///|
fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_82)
    _ => Error
  }
}

// [41, function_args → LPAREN function_arg_list optional_comma RPAREN • EOF, $]

///|
fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_83)
    _ => Error
  }
}

// [41, function_args → LPAREN function_arg_list optional_comma RPAREN EOF •, $]

///|
fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_function_args, yy_action_38)
}

// [40, function_args → LPAREN RPAREN • EOF, $]

///|
fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_85)
    _ => Error
  }
}

// [40, function_args → LPAREN RPAREN EOF •, $]

///|
fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_args, yy_action_37)
}

// [68, template_list → • TYPE_LT template_args TYPE_GT EOF, $]
// [80, template_list_prime → • template_list, $]

///|
fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_template_list => Shift(yy_state_87)
    T_TYPE_LT => Shift(yy_state_88)
    _ => Error
  }
}

// [80, template_list_prime → template_list •, $]

///|
fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [68, template_list → TYPE_LT • template_args TYPE_GT EOF, $]
// [69, template_args → • type_expr, TYPE_GT / COMMA]
// [70, template_args → • template_args COMMA type_expr, TYPE_GT / COMMA]
// [71, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [72, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_96)
    NT_template_args => Shift(yy_state_97)
    _ => Error
  }
}

// [71, type_expr → TYPE_ATOM •, TYPE_GT / COMMA / EOF]
// [72, type_expr → TYPE_ATOM • TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]

///|
fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_LT => Shift(yy_state_90)
    T_TYPE_GT | T_COMMA | T_EOF => Reduce(1, NT_type_expr, yy_action_36)
    _ => Error
  }
}

// [71, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [72, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [72, type_expr → TYPE_ATOM TYPE_LT • type_ref_args TYPE_GT, TYPE_GT / COMMA / EOF]
// [73, type_ref_args → • type_expr, TYPE_GT / COMMA]
// [74, type_ref_args → • type_ref_args COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_91)
    NT_type_ref_args => Shift(yy_state_92)
    _ => Error
  }
}

// [73, type_ref_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_ref_args, yy_action_35)
}

// [72, type_expr → TYPE_ATOM TYPE_LT type_ref_args • TYPE_GT, TYPE_GT / COMMA / EOF]
// [74, type_ref_args → type_ref_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_93)
    T_TYPE_GT => Shift(yy_state_95)
    _ => Error
  }
}

// [71, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [72, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]
// [74, type_ref_args → type_ref_args COMMA • type_expr, TYPE_GT / COMMA]

///|
fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_94)
    _ => Error
  }
}

// [74, type_ref_args → type_ref_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_type_ref_args, yy_action_34)
}

// [72, type_expr → TYPE_ATOM TYPE_LT type_ref_args TYPE_GT •, TYPE_GT / COMMA / EOF]

///|
fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_type_expr, yy_action_33)
}

// [69, template_args → type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_template_args, yy_action_32)
}

// [68, template_list → TYPE_LT template_args • TYPE_GT EOF, $]
// [70, template_args → template_args • COMMA type_expr, TYPE_GT / COMMA]

///|
fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_98)
    T_TYPE_GT => Shift(yy_state_100)
    _ => Error
  }
}

// [70, template_args → template_args COMMA • type_expr, TYPE_GT / COMMA]
// [71, type_expr → • TYPE_ATOM, TYPE_GT / COMMA]
// [72, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, TYPE_GT / COMMA]

///|
fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_expr => Shift(yy_state_99)
    _ => Error
  }
}

// [70, template_args → template_args COMMA type_expr •, TYPE_GT / COMMA]

///|
fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_template_args, yy_action_31)
}

// [68, template_list → TYPE_LT template_args TYPE_GT • EOF, $]

///|
fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_101)
    _ => Error
  }
}

// [68, template_list → TYPE_LT template_args TYPE_GT EOF •, $]

///|
fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_template_list, yy_action_30)
}

// [39, type_ref → • type_expr EOF, $]
// [71, type_expr → • TYPE_ATOM, EOF]
// [72, type_expr → • TYPE_ATOM TYPE_LT type_ref_args TYPE_GT, EOF]
// [79, type_ref_prime → • type_ref, $]

///|
fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TYPE_ATOM => Shift(yy_state_89)
    NT_type_ref => Shift(yy_state_103)
    NT_type_expr => Shift(yy_state_104)
    _ => Error
  }
}

// [79, type_ref_prime → type_ref •, $]

///|
fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [39, type_ref → type_expr • EOF, $]

///|
fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_105)
    _ => Error
  }
}

// [39, type_ref → type_expr EOF •, $]

///|
fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_ref, yy_action_29)
}

// [4, attributes → •, AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]
// [5, attributes → • attributes attribute, AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]
// [25, decl_head → • attributes KW_VIRTUAL KW_FN EOF, $]
// [26, decl_head → • attributes KW_OVERRIDE KW_FN EOF, $]
// [27, decl_head → • attributes KW_FN EOF, $]
// [28, decl_head → • attributes KW_OVERRIDE EOF, $]
// [29, decl_head → • attributes KW_VAR EOF, $]
// [30, decl_head → • attributes KW_STRUCT EOF, $]
// [31, decl_head → • attributes KW_CONST EOF, $]
// [32, decl_head → • attributes KW_CONST_ASSERT EOF, $]
// [33, decl_head → • attributes KW_ALIAS EOF, $]
// [34, decl_head → • attributes KW_TYPE EOF, $]
// [35, decl_head → • attributes KW_ENABLE EOF, $]
// [36, decl_head → • attributes KW_REQUIRES EOF, $]
// [37, decl_head → • attributes KW_DIAGNOSTIC EOF, $]
// [38, decl_head → • attributes EOF, $]
// [78, decl_head_prime → • decl_head, $]

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
    | T_EOF => Reduce(0, NT_attributes, yy_action_58)
    _ => Error
  }
}

// [78, decl_head_prime → decl_head •, $]

///|
fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [5, attributes → attributes • attribute, AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]
// [6, attribute → • AT ATTR_NAME attribute_args, AT / KW_VIRTUAL / KW_OVERRIDE / KW_FN / KW_VAR / KW_STRUCT / KW_CONST / KW_CONST_ASSERT / KW_ALIAS / KW_TYPE / KW_ENABLE / KW_REQUIRES / KW_DIAGNOSTIC / EOF]
// [25, decl_head → attributes • KW_VIRTUAL KW_FN EOF, $]
// [26, decl_head → attributes • KW_OVERRIDE KW_FN EOF, $]
// [27, decl_head → attributes • KW_FN EOF, $]
// [28, decl_head → attributes • KW_OVERRIDE EOF, $]
// [29, decl_head → attributes • KW_VAR EOF, $]
// [30, decl_head → attributes • KW_STRUCT EOF, $]
// [31, decl_head → attributes • KW_CONST EOF, $]
// [32, decl_head → attributes • KW_CONST_ASSERT EOF, $]
// [33, decl_head → attributes • KW_ALIAS EOF, $]
// [34, decl_head → attributes • KW_TYPE EOF, $]
// [35, decl_head → attributes • KW_ENABLE EOF, $]
// [36, decl_head → attributes • KW_REQUIRES EOF, $]
// [37, decl_head → attributes • KW_DIAGNOSTIC EOF, $]
// [38, decl_head → attributes • EOF, $]

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

// [38, decl_head → attributes EOF •, $]

///|
fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_decl_head, yy_action_28)
}

// [37, decl_head → attributes KW_DIAGNOSTIC • EOF, $]

///|
fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_111)
    _ => Error
  }
}

// [37, decl_head → attributes KW_DIAGNOSTIC EOF •, $]

///|
fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_27)
}

// [36, decl_head → attributes KW_REQUIRES • EOF, $]

///|
fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_113)
    _ => Error
  }
}

// [36, decl_head → attributes KW_REQUIRES EOF •, $]

///|
fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_26)
}

// [35, decl_head → attributes KW_ENABLE • EOF, $]

///|
fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_115)
    _ => Error
  }
}

// [35, decl_head → attributes KW_ENABLE EOF •, $]

///|
fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_25)
}

// [34, decl_head → attributes KW_TYPE • EOF, $]

///|
fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_117)
    _ => Error
  }
}

// [34, decl_head → attributes KW_TYPE EOF •, $]

///|
fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_24)
}

// [33, decl_head → attributes KW_ALIAS • EOF, $]

///|
fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_119)
    _ => Error
  }
}

// [33, decl_head → attributes KW_ALIAS EOF •, $]

///|
fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_23)
}

// [32, decl_head → attributes KW_CONST_ASSERT • EOF, $]

///|
fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_121)
    _ => Error
  }
}

// [32, decl_head → attributes KW_CONST_ASSERT EOF •, $]

///|
fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_22)
}

// [31, decl_head → attributes KW_CONST • EOF, $]

///|
fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_123)
    _ => Error
  }
}

// [31, decl_head → attributes KW_CONST EOF •, $]

///|
fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_21)
}

// [30, decl_head → attributes KW_STRUCT • EOF, $]

///|
fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_125)
    _ => Error
  }
}

// [30, decl_head → attributes KW_STRUCT EOF •, $]

///|
fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_20)
}

// [29, decl_head → attributes KW_VAR • EOF, $]

///|
fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_127)
    _ => Error
  }
}

// [29, decl_head → attributes KW_VAR EOF •, $]

///|
fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_19)
}

// [27, decl_head → attributes KW_FN • EOF, $]

///|
fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_129)
    _ => Error
  }
}

// [27, decl_head → attributes KW_FN EOF •, $]

///|
fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_18)
}

// [26, decl_head → attributes KW_OVERRIDE • KW_FN EOF, $]
// [28, decl_head → attributes KW_OVERRIDE • EOF, $]

///|
fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_131)
    T_KW_FN => Shift(yy_state_132)
    _ => Error
  }
}

// [28, decl_head → attributes KW_OVERRIDE EOF •, $]

///|
fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_decl_head, yy_action_17)
}

// [26, decl_head → attributes KW_OVERRIDE KW_FN • EOF, $]

///|
fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_133)
    _ => Error
  }
}

// [26, decl_head → attributes KW_OVERRIDE KW_FN EOF •, $]

///|
fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_decl_head, yy_action_16)
}

// [25, decl_head → attributes KW_VIRTUAL • KW_FN EOF, $]

///|
fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_KW_FN => Shift(yy_state_135)
    _ => Error
  }
}

// [25, decl_head → attributes KW_VIRTUAL KW_FN • EOF, $]

///|
fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_136)
    _ => Error
  }
}

// [25, decl_head → attributes KW_VIRTUAL KW_FN EOF •, $]

///|
fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_decl_head, yy_action_15)
}

// [22, directive_line → • HASH DIRECTIVE_HEAD directive_tail EOF, $]
// [77, directive_line_prime → • directive_line, $]

///|
fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_directive_line => Shift(yy_state_138)
    T_HASH => Shift(yy_state_139)
    _ => Error
  }
}

// [77, directive_line_prime → directive_line •, $]

///|
fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [22, directive_line → HASH • DIRECTIVE_HEAD directive_tail EOF, $]

///|
fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_HEAD => Shift(yy_state_140)
    _ => Error
  }
}

// [22, directive_line → HASH DIRECTIVE_HEAD • directive_tail EOF, $]
// [23, directive_tail → •, EOF]
// [24, directive_tail → • DIRECTIVE_TAIL, EOF]

///|
fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DIRECTIVE_TAIL => Shift(yy_state_17)
    NT_directive_tail => Shift(yy_state_141)
    T_EOF => Reduce(0, NT_directive_tail, yy_action_70)
    _ => Error
  }
}

// [22, directive_line → HASH DIRECTIVE_HEAD directive_tail • EOF, $]

///|
fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_142)
    _ => Error
  }
}

// [22, directive_line → HASH DIRECTIVE_HEAD directive_tail EOF •, $]

///|
fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_directive_line, yy_action_14)
}

// [11, import_targets → • target_list semis EOF, $]
// [12, import_targets → • IDENT target_list semis EOF, $]
// [15, target_list → • target, COMMA / SEMI / EOF]
// [16, target_list → • target_list COMMA target, COMMA / SEMI / EOF]
// [17, target_list → • target_list COMMA, COMMA / SEMI / EOF]
// [18, target → • IDENT alias, COMMA / SEMI / EOF]
// [19, target → • IDENT LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [76, import_targets_prime → • import_targets, $]

///|
fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_import_targets => Shift(yy_state_144)
    NT_target => Shift(yy_state_145)
    T_IDENT => Shift(yy_state_146)
    NT_target_list => Shift(yy_state_160)
    _ => Error
  }
}

// [76, import_targets_prime → import_targets •, $]

///|
fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [15, target_list → target •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_target_list, yy_action_13)
}

// [12, import_targets → IDENT • target_list semis EOF, $]
// [15, target_list → • target, COMMA / SEMI / EOF]
// [16, target_list → • target_list COMMA target, COMMA / SEMI / EOF]
// [17, target_list → • target_list COMMA, COMMA / SEMI / EOF]
// [18, target → • IDENT alias, COMMA / SEMI / EOF]
// [18, target → IDENT • alias, COMMA / SEMI / EOF]
// [19, target → • IDENT LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [19, target → IDENT • LBRACE target_list RBRACE, COMMA / SEMI / EOF]
// [20, alias → •, COMMA / SEMI / EOF]
// [21, alias → • AS IDENT, COMMA / SEMI / EOF]

///|
fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_target => Shift(yy_state_145)
    T_AS => Shift(yy_state_147)
    T_LBRACE => Shift(yy_state_149)
    T_IDENT => Shift(yy_state_150)
    NT_alias => Shift(yy_state_151)
    NT_target_list => Shift(yy_state_156)
    T_COMMA | T_SEMI | T_EOF => Reduce(0, NT_alias, yy_action_12)
    _ => Error
  }
}

// [21, alias → AS • IDENT, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_148)
    _ => Error
  }
}

// [21, alias → AS IDENT •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_alias, yy_action_11)
}

// [15, target_list → • target, RBRACE / COMMA]
// [16, target_list → • target_list COMMA target, RBRACE / COMMA]
// [17, target_list → • target_list COMMA, RBRACE / COMMA]
// [18, target → • IDENT alias, RBRACE / COMMA]
// [19, target → • IDENT LBRACE target_list RBRACE, RBRACE / COMMA]
// [19, target → IDENT LBRACE • target_list RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_target => Shift(yy_state_145)
    T_IDENT => Shift(yy_state_150)
    NT_target_list => Shift(yy_state_152)
    _ => Error
  }
}

// [18, target → IDENT • alias, RBRACE / COMMA / SEMI / EOF]
// [19, target → IDENT • LBRACE target_list RBRACE, RBRACE / COMMA / SEMI / EOF]
// [20, alias → •, RBRACE / COMMA / SEMI / EOF]
// [21, alias → • AS IDENT, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AS => Shift(yy_state_147)
    T_LBRACE => Shift(yy_state_149)
    NT_alias => Shift(yy_state_151)
    T_RBRACE | T_COMMA | T_SEMI | T_EOF => Reduce(0, NT_alias, yy_action_12)
    _ => Error
  }
}

// [18, target → IDENT alias •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_target, yy_action_10)
}

// [16, target_list → target_list • COMMA target, RBRACE / COMMA]
// [17, target_list → target_list • COMMA, RBRACE / COMMA]
// [19, target → IDENT LBRACE target_list • RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_153)
    T_COMMA => Shift(yy_state_154)
    _ => Error
  }
}

// [19, target → IDENT LBRACE target_list RBRACE •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_target, yy_action_9)
}

// [16, target_list → target_list COMMA • target, RBRACE / COMMA / SEMI / EOF]
// [17, target_list → target_list COMMA •, RBRACE / COMMA / SEMI / EOF]
// [18, target → • IDENT alias, RBRACE / COMMA / SEMI / EOF]
// [19, target → • IDENT LBRACE target_list RBRACE, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_150)
    NT_target => Shift(yy_state_155)
    T_RBRACE | T_COMMA | T_SEMI | T_EOF =>
      Reduce(2, NT_target_list, yy_action_8)
    _ => Error
  }
}

// [16, target_list → target_list COMMA target •, RBRACE / COMMA / SEMI / EOF]

///|
fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_target_list, yy_action_7)
}

// [12, import_targets → IDENT target_list • semis EOF, $]
// [13, semis → •, SEMI / EOF]
// [14, semis → • semis SEMI, SEMI / EOF]
// [16, target_list → target_list • COMMA target, COMMA / SEMI / EOF]
// [17, target_list → target_list • COMMA, COMMA / SEMI / EOF]

///|
fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_154)
    NT_semis => Shift(yy_state_157)
    T_SEMI | T_EOF => Reduce(0, NT_semis, yy_action_6)
    _ => Error
  }
}

// [12, import_targets → IDENT target_list semis • EOF, $]
// [14, semis → semis • SEMI, SEMI / EOF]

///|
fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_158)
    T_EOF => Shift(yy_state_159)
    _ => Error
  }
}

// [14, semis → semis SEMI •, SEMI / EOF]

///|
fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semis, yy_action_5)
}

// [12, import_targets → IDENT target_list semis EOF •, $]

///|
fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_import_targets, yy_action_4)
}

// [11, import_targets → target_list • semis EOF, $]
// [13, semis → •, SEMI / EOF]
// [14, semis → • semis SEMI, SEMI / EOF]
// [16, target_list → target_list • COMMA target, COMMA / SEMI / EOF]
// [17, target_list → target_list • COMMA, COMMA / SEMI / EOF]

///|
fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_154)
    NT_semis => Shift(yy_state_161)
    T_SEMI | T_EOF => Reduce(0, NT_semis, yy_action_6)
    _ => Error
  }
}

// [11, import_targets → target_list semis • EOF, $]
// [14, semis → semis • SEMI, SEMI / EOF]

///|
fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_158)
    T_EOF => Shift(yy_state_162)
    _ => Error
  }
}

// [11, import_targets → target_list semis EOF •, $]

///|
fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_targets, yy_action_3)
}

// [0, raw_top_level_items → • items EOF, $]
// [9, items → •, ITEM / EOF]
// [10, items → • items ITEM, ITEM / EOF]
// [75, raw_top_level_items_prime → • raw_top_level_items, $]

///|
fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_raw_top_level_items => Shift(yy_state_164)
    NT_items => Shift(yy_state_165)
    T_ITEM | T_EOF => Reduce(0, NT_items, yy_action_2)
    _ => Error
  }
}

// [75, raw_top_level_items_prime → raw_top_level_items •, $]

///|
fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

// [0, raw_top_level_items → items • EOF, $]
// [10, items → items • ITEM, ITEM / EOF]

///|
fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ITEM => Shift(yy_state_166)
    T_EOF => Shift(yy_state_167)
    _ => Error
  }
}

// [10, items → items ITEM •, ITEM / EOF]

///|
fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_items, yy_action_1)
}

// [0, raw_top_level_items → items EOF •, $]

///|
fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
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
        (T_DIRECTIVE_HEAD, TK_DIRECTIVE_HEAD),
        (T_DIRECTIVE_TAIL, TK_DIRECTIVE_TAIL),
        (T_SOURCE_TEXT, TK_SOURCE_TEXT),
        (T_HASH, TK_HASH),
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
fn raw_top_level_items(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[WgslRawTopLevelItem] raise ParseError {
  yy_parse(
    tokens,
    yy_state_163,
    it => {
      guard it is YYObj_Array_WgslRawTopLevelItem_(result)
      result
    },
    initial_pos?,
  )
}

///|
fn import_targets(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> Array[@common.WgslImportTarget] raise ParseError {
  yy_parse(
    tokens,
    yy_state_143,
    it => {
      guard it is YYObj_Array__common_WgslImportTarget_(result)
      result
    },
    initial_pos?,
  )
}

///|
fn directive_line(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> @ast.WgslDirective raise ParseError {
  yy_parse(
    tokens,
    yy_state_137,
    it => {
      guard it is YYObj__ast_WgslDirective(result)
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
) -> Array[String] raise ParseError {
  yy_parse(
    tokens,
    yy_state_86,
    it => {
      guard it is YYObj_Array_String_(result)
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
) -> (String?, @ast.WgslTypeRef?, String?, @ast.WgslExprRef?) raise ParseError {
  yy_parse(
    tokens,
    yy_state_29,
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
fn type_alias_tail(
  tokens : Array[(Token, Int, Int)],
  initial_pos? : Int,
) -> (String, @ast.WgslTypeRef?) raise ParseError {
  yy_parse(
    tokens,
    yy_state_24,
    it => {
      guard it is YYObj__String___ast_WgslTypeRef__(result)
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
  atom : (String, String, Int, Int, Int),
  arguments : Array[@ast.WgslTypeRef],
  _end : Int,
) -> @ast.WgslTypeRef {
  let (name, _, _, start, _) = atom
  @ast.WgslTypeRef::new(name, arguments, start)
}
