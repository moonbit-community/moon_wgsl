#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: privatize_moonyacc_output.sh <generated-parser.mbt>" >&2
  exit 2
fi

output="$1"

perl -0777pi -e '
  s/pub[(]all[)] enum Token/priv enum Token/g;
  s/pub[(]all[)] enum TokenKind/priv enum TokenKind/g;
  s/pub suberror ParseError/priv suberror ParseError/g;
  s/pub impl Debug for TokenKind/impl Debug for TokenKind/g;
  s/pub fn (raw_top_level_items|import_targets|directive_line|decl_head|type_ref|template_list|function_args|function_result|struct_members|typed_initializer_tail|type_alias_tail|source_directive|const_assert_expr|block)[(]/fn $1(/g;
' "$output"

perl -0777pi -e '
  s{///\|\n(?:pub )?fn Token::kind.*?\n\n///\|\npriv enum TokenKind}{///|\npriv enum TokenKind}s;
  s{///\|\n(?:pub )?impl Show for TokenKind.*?\n\n///\|\nimpl Debug for TokenKind}{///|\nimpl Debug for TokenKind}s;
' "$output"

moonfmt -w "$output"
moonfmt -w "$output"
