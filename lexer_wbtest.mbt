// lexer_wbtest.mbt — White-box tests for the matcher tokenizer.

///|
test "tokenizer splits identifiers, operators, and parentheses" {
  let kinds : Array[TokenKind] = []
  for token in tokenize("r_sub == p_sub && !flag") {
    kinds.push(token.kind)
  }
  assert_true(
    kinds ==
    [
      TokenKind::Ident("r_sub"),
      TokenKind::Equal,
      TokenKind::Ident("p_sub"),
      TokenKind::And,
      TokenKind::Bang,
      TokenKind::Ident("flag"),
    ],
  )
}

///|
test "tokenizer recognises numbers, strings, and keywords" {
  let kinds : Array[TokenKind] = []
  for token in tokenize("18 1.5 'a\\'b' \"a.p.p.l.e\" true in x") {
    kinds.push(token.kind)
  }
  assert_true(
    kinds ==
    [
      TokenKind::IntValue(18),
      TokenKind::DoubleValue(1.5),
      TokenKind::Str("a'b"),
      TokenKind::Str("a.p.p.l.e"),
      TokenKind::True,
      TokenKind::In,
      TokenKind::Ident("x"),
    ],
  )
}

///|
test "tokenizer records character offsets" {
  let tokens = tokenize("  alpha + 1")
  assert_true(tokens.length() == 3)
  assert_true(tokens[0].offset == 2)
  assert_true(tokens[1].offset == 8)
  assert_true(tokens[2].offset == 10)
}

///|
test "tokenizer rejects a single ampersand with an offset" {
  let result = Ok(tokenize("a & b")) catch { error => Err(error) }
  match result {
    Err(error) => {
      assert_true(error.kind() == MatcherSyntax)
      assert_true(error.offset() == 2)
    }
    Ok(_) => fail("expected a MatcherSyntax error")
  }
}

///|
test "tokenizer rejects an unterminated string" {
  let result = Ok(tokenize("'abc")) catch { error => Err(error) }
  match result {
    Err(error) => {
      assert_true(error.kind() == MatcherSyntax)
      assert_true(error.offset() == 0)
      assert_true(error.message().contains("unterminated"))
    }
    Ok(_) => fail("expected a MatcherSyntax error")
  }
}
