// parser.mbt — Pratt parser for matcher expressions.
//
// Precedence, lowest first: `||`, `&&`, `==` / `!=` / `in`, comparisons,
// `+` / `-`, `*` / `/` / `%`, unary `!` / `-`, field access, calls.
// Binary operators are left-associative. The parser rejects trailing
// input so `a b` and stray operators surface as `MatcherSyntax` errors
// pointing at the offending offset.

///|
/// Parses a matcher expression into an AST.
///
/// The text is expected to be preprocessed the way Casbin preprocesses
/// model files: `r.sub` has already become `r_sub`, so identifiers are
/// plain names.
pub fn parse_matcher(text : String) -> Result[Expr, CasbinError] {
  try {
    let tokens = tokenize(text)
    let parser = Parser::new(tokens, text.length())
    let expression = parser.parse_expression()
    parser.expect_end()
    Ok(expression)
  } catch {
    error => Err(error)
  }
}

///|
priv struct Parser {
  tokens : Array[Token]
  end_offset : Int
  mut pos : Int
}

///|
fn Parser::new(tokens : Array[Token], end_offset : Int) -> Parser {
  { tokens, end_offset, pos: 0, }
}

///|
fn Parser::peek(self : Parser) -> Token? {
  if self.pos < self.tokens.length() {
    Some(self.tokens[self.pos])
  } else {
    None
  }
}

///|
fn Parser::advance(self : Parser) -> Unit {
  self.pos += 1
}

///|
fn Parser::eat(self : Parser, kind : TokenKind) -> Bool {
  let matched = match self.peek() {
    Some(token) => token.kind == kind
    None => false
  }
  if matched {
    self.advance()
  }
  matched
}

///|
fn Parser::expect(
  self : Parser,
  kind : TokenKind,
  message : String,
) -> Unit raise CasbinError {
  if self.eat(kind) {
    return
  }
  match self.peek() {
    Some(token) =>
      raise casbin_error_at_offset(MatcherSyntax, token.offset, message)
    None =>
      raise casbin_error_at_offset(MatcherSyntax, self.end_offset, message)
  }
}

///|
fn Parser::expect_end(self : Parser) -> Unit raise CasbinError {
  match self.peek() {
    None => ()
    Some(token) =>
      raise casbin_error_at_offset(
        MatcherSyntax,
        token.offset,
        "unexpected trailing input",
      )
  }
}

///|
fn Parser::parse_expression(self : Parser) -> Expr raise CasbinError {
  self.parse_binary(1)
}

///|
fn Parser::parse_binary(
  self : Parser,
  min_precedence : Int,
) -> Expr raise CasbinError {
  let mut left = self.parse_unary()
  while true {
    let op = match self.peek() {
      Some({ kind: Or, .. }) => Some(BinaryOp::Or)
      Some({ kind: And, .. }) => Some(BinaryOp::And)
      Some({ kind: Equal, .. }) => Some(BinaryOp::Eq)
      Some({ kind: NotEqual, .. }) => Some(BinaryOp::NotEq)
      Some({ kind: In, .. }) => Some(BinaryOp::In)
      Some({ kind: Less, .. }) => Some(BinaryOp::Less)
      Some({ kind: LessEqual, .. }) => Some(BinaryOp::LessEq)
      Some({ kind: Greater, .. }) => Some(BinaryOp::Greater)
      Some({ kind: GreaterEqual, .. }) => Some(BinaryOp::GreaterEq)
      Some({ kind: Plus, .. }) => Some(BinaryOp::Add)
      Some({ kind: Minus, .. }) => Some(BinaryOp::Sub)
      Some({ kind: Star, .. }) => Some(BinaryOp::Mul)
      Some({ kind: Slash, .. }) => Some(BinaryOp::Div)
      Some({ kind: Percent, .. }) => Some(BinaryOp::Mod)
      _ => None
    }
    let op = match op {
      Some(op) => op
      None => break
    }
    let precedence = binary_precedence(op)
    if precedence < min_precedence {
      break
    }
    self.advance()
    let right = self.parse_binary(precedence + 1)
    left = Binary(op, left, right)
  }
  left
}

///|
fn binary_precedence(op : BinaryOp) -> Int {
  match op {
    Or => 1
    And => 2
    Eq | NotEq | In => 3
    Less | LessEq | Greater | GreaterEq => 4
    Add | Sub => 5
    Mul | Div | Mod => 6
  }
}

///|
fn Parser::parse_unary(self : Parser) -> Expr raise CasbinError {
  match self.peek() {
    Some({ kind: Bang, .. }) => {
      self.advance()
      Unary(Not, self.parse_unary())
    }
    Some({ kind: Minus, .. }) => {
      self.advance()
      Unary(Neg, self.parse_unary())
    }
    _ => self.parse_postfix()
  }
}

///|
fn Parser::parse_postfix(self : Parser) -> Expr raise CasbinError {
  let mut expression = self.parse_primary()
  while true {
    match self.peek() {
      Some({ kind: Dot, .. }) => {
        self.advance()
        let name = match self.peek() {
          Some({ kind: Ident(name), .. }) => {
            self.advance()
            name
          }
          Some(token) =>
            raise casbin_error_at_offset(
              MatcherSyntax,
              token.offset,
              "expected a field name after '.'",
            )
          None =>
            raise casbin_error_at_offset(
              MatcherSyntax,
              self.end_offset,
              "expected a field name after '.'",
            )
        }
        expression = Member(expression, name)
      }
      _ => break
    }
  }
  expression
}

///|
fn Parser::parse_primary(self : Parser) -> Expr raise CasbinError {
  match self.peek() {
    Some({ kind: IntValue(value), .. }) => {
      self.advance()
      Literal(Value::Int(value))
    }
    Some({ kind: DoubleValue(value), .. }) => {
      self.advance()
      Literal(Value::Double(value))
    }
    Some({ kind: Str(value), .. }) => {
      self.advance()
      Literal(Value::String(value))
    }
    Some({ kind: True, .. }) => {
      self.advance()
      Literal(Value::Bool(true))
    }
    Some({ kind: False, .. }) => {
      self.advance()
      Literal(Value::Bool(false))
    }
    Some({ kind: Ident(name), .. }) => {
      self.advance()
      match self.peek() {
        Some({ kind: LParen, .. }) => self.parse_call(name)
        _ => Ident(name)
      }
    }
    Some({ kind: LParen, .. }) => self.parse_paren()
    Some({ kind: LBracket, .. }) => self.parse_bracket_list()
    Some(token) =>
      raise casbin_error_at_offset(
        MatcherSyntax,
        token.offset,
        "unexpected token in expression",
      )
    None =>
      raise casbin_error_at_offset(
        MatcherSyntax,
        self.end_offset,
        "unexpected end of expression",
      )
  }
}

///|
fn Parser::parse_call(self : Parser, name : String) -> Expr raise CasbinError {
  self.advance()
  let arguments : Array[Expr] = []
  if self.eat(RParen) {
    return Call(name, arguments)
  }
  while true {
    arguments.push(self.parse_expression())
    if self.eat(Comma) {
      continue
    }
    if self.eat(RParen) {
      break
    }
    raise casbin_error_at_offset(
      MatcherSyntax,
      self.current_offset(),
      "expected ',' or ')' in the argument list of \"" + name + "\"",
    )
  }
  Call(name, arguments)
}

///|
fn Parser::parse_paren(self : Parser) -> Expr raise CasbinError {
  self.advance()
  if self.eat(RParen) {
    return List([])
  }
  let first = self.parse_expression()
  if self.eat(Comma) {
    let items : Array[Expr] = [first]
    while true {
      items.push(self.parse_expression())
      if self.eat(Comma) {
        continue
      }
      break
    }
    self.expect(RParen, "expected ')' after the list elements")
    return List(items)
  }
  self.expect(RParen, "expected ')'")
  first
}

///|
fn Parser::parse_bracket_list(self : Parser) -> Expr raise CasbinError {
  self.advance()
  let items : Array[Expr] = []
  if self.eat(RBracket) {
    return List(items)
  }
  while true {
    items.push(self.parse_expression())
    if self.eat(Comma) {
      continue
    }
    break
  }
  self.expect(RBracket, "expected ']'")
  List(items)
}

///|
fn Parser::current_offset(self : Parser) -> Int {
  match self.peek() {
    Some(token) => token.offset
    None => self.end_offset
  }
}
