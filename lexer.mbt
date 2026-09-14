// lexer.mbt — Tokenizer for matcher expressions.
//
// The tokenizer scans the text as an array of characters, so offsets are
// character offsets. Identifiers are `[A-Za-z_][A-Za-z0-9_]*`, numbers
// are integers or doubles, strings use single or double quotes with
// backslash escapes (`\\` and the quote character), and the operator set
// is the one in expr.mbt. Every token records the offset of its first
// character so syntax errors can point at the offending position.

///|
priv enum TokenKind {
  Ident(String)
  IntValue(Int)
  DoubleValue(Double)
  Str(String)
  True
  False
  In
  Or
  And
  Equal
  NotEqual
  Less
  LessEqual
  Greater
  GreaterEqual
  Plus
  Minus
  Star
  Slash
  Percent
  Bang
  LParen
  RParen
  LBracket
  RBracket
  Comma
  Dot
} derive(Eq)

///|
priv struct Token {
  kind : TokenKind
  offset : Int
}

///|
/// Splits `text` into tokens, raising `MatcherSyntax` on the first
/// character or literal the grammar cannot tokenize.
fn tokenize(text : String) -> Array[Token] raise CasbinError {
  let chars : Array[Char] = text.iter().collect()
  let length = chars.length()
  let tokens : Array[Token] = []
  let mut index = 0
  while index < length {
    let ch = chars[index]
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      index += 1
      continue
    }
    if is_identifier_start(ch) {
      let start = index
      while index < length && is_identifier_char(chars[index]) {
        index += 1
      }
      let word = slice_to_string(chars, start, index)
      let kind = match word {
        "true" => TokenKind::True
        "false" => TokenKind::False
        "in" => TokenKind::In
        _ => TokenKind::Ident(word)
      }
      tokens.push({ kind, offset: start, })
      continue
    }
    if ch.is_ascii_digit() {
      let start = index
      let mut mantissa = 0
      let mut fraction_digits = 0
      let mut is_double = false
      while index < length && chars[index].is_ascii_digit() {
        mantissa = mantissa * 10 + (chars[index].to_int() - '0'.to_int())
        index += 1
      }
      if index < length &&
        chars[index] == '.' &&
        index + 1 < length &&
        chars[index + 1].is_ascii_digit() {
        is_double = true
        index += 1
        while index < length && chars[index].is_ascii_digit() {
          mantissa = mantissa * 10 + (chars[index].to_int() - '0'.to_int())
          fraction_digits += 1
          index += 1
        }
      }
      if is_double {
        let value = mantissa.to_double() / power_of_ten(fraction_digits)
        tokens.push({ kind: DoubleValue(value), offset: start, })
      } else {
        tokens.push({ kind: IntValue(mantissa), offset: start, })
      }
      continue
    }
    if ch == '\'' || ch == '"' {
      let start = index
      let (value, next) = read_string(chars, start)
      tokens.push({ kind: Str(value), offset: start, })
      index = next
      continue
    }
    if index + 1 < length {
      let two_character = match (ch, chars[index + 1]) {
        ('|', '|') => Some(TokenKind::Or)
        ('&', '&') => Some(TokenKind::And)
        ('=', '=') => Some(TokenKind::Equal)
        ('!', '=') => Some(TokenKind::NotEqual)
        ('<', '=') => Some(TokenKind::LessEqual)
        ('>', '=') => Some(TokenKind::GreaterEqual)
        _ => None
      }
      match two_character {
        Some(kind) => {
          tokens.push({ kind, offset: index, })
          index += 2
          continue
        }
        None => ()
      }
    }
    match ch {
      '(' => {
        tokens.push({ kind: LParen, offset: index, })
        index += 1
      }
      ')' => {
        tokens.push({ kind: RParen, offset: index, })
        index += 1
      }
      '[' => {
        tokens.push({ kind: LBracket, offset: index, })
        index += 1
      }
      ']' => {
        tokens.push({ kind: RBracket, offset: index, })
        index += 1
      }
      ',' => {
        tokens.push({ kind: Comma, offset: index, })
        index += 1
      }
      '.' => {
        tokens.push({ kind: Dot, offset: index, })
        index += 1
      }
      '<' => {
        tokens.push({ kind: Less, offset: index, })
        index += 1
      }
      '>' => {
        tokens.push({ kind: Greater, offset: index, })
        index += 1
      }
      '+' => {
        tokens.push({ kind: Plus, offset: index, })
        index += 1
      }
      '-' => {
        tokens.push({ kind: Minus, offset: index, })
        index += 1
      }
      '*' => {
        tokens.push({ kind: Star, offset: index, })
        index += 1
      }
      '/' => {
        tokens.push({ kind: Slash, offset: index, })
        index += 1
      }
      '%' => {
        tokens.push({ kind: Percent, offset: index, })
        index += 1
      }
      '!' => {
        tokens.push({ kind: Bang, offset: index, })
        index += 1
      }
      '=' =>
        raise casbin_error_at_offset(
          MatcherSyntax,
          index,
          "unsupported operator '='; use '==' for equality",
        )
      '&' =>
        raise casbin_error_at_offset(
          MatcherSyntax,
          index,
          "unsupported operator '&'; use '&&'",
        )
      '|' =>
        raise casbin_error_at_offset(
          MatcherSyntax,
          index,
          "unsupported operator '|'; use '||'",
        )
      '?' =>
        raise casbin_error_at_offset(
          MatcherSyntax,
          index,
          "unsupported operator '?'; ternary expressions are not supported",
        )
      ':' =>
        raise casbin_error_at_offset(
          MatcherSyntax,
          index,
          "unsupported operator ':'; ternary expressions are not supported",
        )
      _ =>
        raise casbin_error_at_offset(
          MatcherSyntax,
          index,
          "unexpected character '" + ch.to_string() + "'",
        )
    }
  }
  tokens
}

///|
/// Reads a quoted string starting at `start` and returns the decoded
/// value plus the index just past the closing quote. Inside the literal,
/// `\` escapes the next character; an unterminated literal raises.
fn read_string(
  chars : Array[Char],
  start : Int,
) -> (String, Int) raise CasbinError {
  let quote = chars[start]
  let length = chars.length()
  let value : Array[Char] = []
  let mut index = start + 1
  while index < length {
    let ch = chars[index]
    if ch == '\\' {
      if index + 1 >= length {
        raise casbin_error_at_offset(
          MatcherSyntax,
          start,
          "unterminated string literal",
        )
      }
      value.push(chars[index + 1])
      index += 2
      continue
    }
    if ch == quote {
      return (StringView::from_iter(value.iter()).to_owned(), index + 1)
    }
    value.push(ch)
    index += 1
  }
  raise casbin_error_at_offset(
    MatcherSyntax,
    start,
    "unterminated string literal",
  )
}

///|
fn slice_to_string(chars : Array[Char], start : Int, end : Int) -> String {
  let slice : Array[Char] = []
  for i in start..<end {
    slice.push(chars[i])
  }
  StringView::from_iter(slice.iter()).to_owned()
}

///|
fn is_identifier_start(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch == '_'
}

///|
fn is_identifier_char(ch : Char) -> Bool {
  is_identifier_start(ch) || ch.is_ascii_digit()
}

///|
fn power_of_ten(exponent : Int) -> Double {
  let mut result = 1.0
  for _i in 0..<exponent {
    result = result * 10.0
  }
  result
}
