// parser_test.mbt — Black-box tests for the matcher parser.

///|
test "parses the ACL matcher with left associativity" {
  let expression = parse_matcher(
    "r_sub == p_sub && r_obj == p_obj && r_act == p_act",
  ).unwrap()
  match expression {
    Binary(And, Binary(And, first, second), third) => {
      assert_true(first == Binary(Eq, Ident("r_sub"), Ident("p_sub")))
      assert_true(second == Binary(Eq, Ident("r_obj"), Ident("p_obj")))
      assert_true(third == Binary(Eq, Ident("r_act"), Ident("p_act")))
    }
    _ => fail("unexpected expression shape")
  }
}

///|
test "parses calls and && binds tighter than ||" {
  let expression = parse_matcher("g(r_sub, p_sub) && r_obj == p_act || flag").unwrap()
  match expression {
    Binary(Or, left, right) => {
      assert_true(right == Ident("flag"))
      match left {
        Binary(And, call, comparison) => {
          assert_true(call == Call("g", [Ident("r_sub"), Ident("p_sub")]))
          assert_true(comparison == Binary(Eq, Ident("r_obj"), Ident("p_act")))
        }
        _ => fail("expected && on the left of ||")
      }
    }
    _ => fail("expected || at the top")
  }
}

///|
test "parses in with parenthesized and bracketed lists" {
  let expression = parse_matcher("r_obj in ('data2', 'data3')").unwrap()
  match expression {
    Binary(In, Ident("r_obj"), List(items)) => {
      assert_true(items.length() == 2)
      assert_true(items[0] == Literal(Value::String("data2")))
      assert_true(items[1] == Literal(Value::String("data3")))
    }
    _ => fail("unexpected expression shape")
  }
  let bracketed = parse_matcher("r_obj in ['data2']").unwrap()
  match bracketed {
    Binary(In, _, List(items)) => assert_true(items.length() == 1)
    _ => fail("unexpected bracketed list shape")
  }
}

///|
test "parses field access, unary minus, and nested parentheses" {
  let expression = parse_matcher("r_sub.Age > 18").unwrap()
  match expression {
    Binary(Greater, Member(Ident("r_sub"), "Age"), Literal(Value::Int(18))) =>
      ()
    _ => fail("unexpected field access shape")
  }
  let negative = parse_matcher("-1 < n").unwrap()
  match negative {
    Binary(Less, Unary(Neg, Literal(Value::Int(1))), Ident("n")) => ()
    _ => fail("unexpected unary shape")
  }
  let grouped = parse_matcher("(a || b) && c").unwrap()
  match grouped {
    Binary(And, Binary(Or, _, _), Ident("c")) => ()
    _ => fail("expected grouping to override precedence")
  }
}

///|
test "rejects unsupported operators with an offset" {
  let error = parse_matcher("a = b").unwrap_err()
  assert_true(error.kind() == MatcherSyntax)
  assert_true(error.offset() == 2)
  assert_true(error.message().contains("'=='"))
  let ternary = parse_matcher("a ? b : c").unwrap_err()
  assert_true(ternary.message().contains("ternary"))
}

///|
test "rejects trailing input and incomplete expressions" {
  let trailing = parse_matcher("a b").unwrap_err()
  assert_true(trailing.offset() == 2)
  let incomplete = parse_matcher("a ==").unwrap_err()
  assert_true(incomplete.offset() == 4)
  let unbalanced = parse_matcher("(a && b").unwrap_err()
  assert_true(unbalanced.message().contains("expected ')'"))
}
