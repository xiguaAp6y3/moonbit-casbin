// preprocess.mbt — Matcher and effect text preprocessing.
//
// Casbin preprocesses `[policy_effect]` and `[matchers]` values when a
// model is loaded: comments are stripped, `r.sub` / `p.obj` style
// accessors become the flat tokens `r_sub` / `p_obj`, and — for matchers
// only — string literals are escaped for govaluate and `[` / `]` become
// `(` / `)` when the expression mentions `in`.
//
// This module implements the two steps our lexer needs:
//
// - `remove_comments` mirrors Casbin: the first `#` starts a comment and
//   everything from it on is dropped (the kept prefix is trimmed).
// - `escape_assertion` mirrors Casbin's `EscapeAssertion`: the dot right
//   after `r`, `p`, `r<digits>`, or `p<digits>` becomes `_` when the token
//   starts the text or is preceded by one of `( ) whitespace | & , = ! > <
//   + - * /`. Field access after that first dot is preserved, so
//   `r.sub.Age` becomes `r_sub.Age`.
//
// Two Casbin steps are intentionally not replicated: `EscapeStringLiterals`
// is unnecessary because this lexer handles single- and double-quoted
// strings natively, and the `in` bracket rewrite is unnecessary because the
// parser accepts both `('a', 'b')` and `['a', 'b']` lists.

///|
/// Strips a `#` comment; the kept prefix is trimmed. Mirrors Casbin's
/// `RemoveComments` (including returning the text unchanged when there is
/// no `#`).
pub fn remove_comments(text : String) -> String {
  match text.find("#") {
    None => text
    Some(index) => text[:index].trim().to_owned()
  }
}

///|
/// Rewrites the first dot of `r.attr` style accessors to `_`, mirroring
/// Casbin's `EscapeAssertion`.
pub fn escape_assertion(text : String) -> String {
  let chars : Array[Char] = text.iter().collect()
  let length = chars.length()
  let result : Array[Char] = []
  let mut index = 0
  while index < length {
    let ch = chars[index]
    if (ch == 'r' || ch == 'p') &&
      (index == 0 || is_escape_prefix(chars[index - 1])) {
      let mut digits_end = index + 1
      while digits_end < length && chars[digits_end].is_ascii_digit() {
        digits_end += 1
      }
      if digits_end < length && chars[digits_end] == '.' {
        for i in index..<digits_end {
          result.push(chars[i])
        }
        result.push('_')
        index = digits_end + 1
        continue
      }
    }
    result.push(ch)
    index += 1
  }
  StringView::from_iter(result.iter()).to_owned()
}

///|
/// The full Casbin preprocessing for expression values: escape accessors,
/// then strip comments.
pub fn preprocess_expression(text : String) -> String {
  remove_comments(escape_assertion(text))
}

///|
/// Characters that may precede an `r.` / `p.` accessor: Casbin's regex
/// uses `[()\s|&,=!><+\-*/]` or the start of the text.
fn is_escape_prefix(ch : Char) -> Bool {
  ch == '(' ||
  ch == ')' ||
  ch.is_whitespace() ||
  ch == '|' ||
  ch == '&' ||
  ch == ',' ||
  ch == '=' ||
  ch == '!' ||
  ch == '>' ||
  ch == '<' ||
  ch == '+' ||
  ch == '-' ||
  ch == '*' ||
  ch == '/'
}
