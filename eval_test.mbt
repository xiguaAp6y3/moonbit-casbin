// eval_test.mbt — Black-box tests for the matcher evaluator.

///|
/// Builds an identifier lookup from name/value pairs.
fn scope(
  pairs : Array[(String, @moonbit-casbin.Value)],
) -> (String) -> @moonbit-casbin.Value? {
  name => {
    for pair in pairs {
      if pair.0 == name {
        return Some(pair.1)
      }
    }
    None
  }
}

///|
/// Parses and evaluates `text`, unwrapping both steps.
fn eval_text(
  text : String,
  pairs : Array[(String, @moonbit-casbin.Value)],
) -> @moonbit-casbin.Value {
  @moonbit-casbin.parse_matcher(text)
  .unwrap()
  .eval(scope(pairs), @moonbit-casbin.builtin_functions())
  .unwrap()
}

///|
test "evaluates comparisons and cross-type numeric equality" {
  assert_true(eval_text("18 > 17", []) == @moonbit-casbin.Value::Bool(true))
  assert_true(eval_text("'a' == 'a'", []) == @moonbit-casbin.Value::Bool(true))
  assert_true(eval_text("18 == 18.0", []) == @moonbit-casbin.Value::Bool(true))
  assert_true(eval_text("'a' != 'b'", []) == @moonbit-casbin.Value::Bool(true))
  assert_true(eval_text("'a' < 'b'", []) == @moonbit-casbin.Value::Bool(true))
}

///|
test "short-circuits logical operators" {
  assert_true(
    eval_text("false && missing", []) == @moonbit-casbin.Value::Bool(false),
  )
  assert_true(
    eval_text("true || missing", []) == @moonbit-casbin.Value::Bool(true),
  )
  assert_true(
    eval_text("flag && count >= 2", [
      ("flag", @moonbit-casbin.Value::Bool(true)),
      ("count", @moonbit-casbin.Value::Int(3)),
    ]) ==
    @moonbit-casbin.Value::Bool(true),
  )
}

///|
test "tests membership with in" {
  assert_true(
    eval_text("r_obj in ('data2', 'data3')", [
      ("r_obj", @moonbit-casbin.Value::String("data2")),
    ]) ==
    @moonbit-casbin.Value::Bool(true),
  )
  assert_true(
    eval_text("r_obj in ('data2', 'data3')", [
      ("r_obj", @moonbit-casbin.Value::String("data1")),
    ]) ==
    @moonbit-casbin.Value::Bool(false),
  )
  match
    @moonbit-casbin.parse_matcher("r_obj in r_obj")
    .unwrap()
    .eval(
      scope([("r_obj", @moonbit-casbin.Value::String("data1"))]),
      @moonbit-casbin.builtin_functions(),
    ) {
    Err(error) => {
      assert_true(error.kind() == MatcherEval)
      assert_true(error.message().contains("must be a list"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
}

///|
test "calls built-in functions" {
  assert_true(
    eval_text("keyMatch(r_obj, p_obj)", [
      ("r_obj", @moonbit-casbin.Value::String("/foo/bar")),
      ("p_obj", @moonbit-casbin.Value::String("/foo/*")),
    ]) ==
    @moonbit-casbin.Value::Bool(true),
  )
  assert_true(
    eval_text("keyMatch(r_obj, p_obj)", [
      ("r_obj", @moonbit-casbin.Value::String("/foobar")),
      ("p_obj", @moonbit-casbin.Value::String("/foo/*")),
    ]) ==
    @moonbit-casbin.Value::Bool(false),
  )
}

///|
test "reads fields from records" {
  let subject = @moonbit-casbin.Value::Object([
    ("Age", @moonbit-casbin.Value::Int(20)),
  ])
  assert_true(
    eval_text("r_sub.Age >= 18", [("r_sub", subject)]) ==
    @moonbit-casbin.Value::Bool(true),
  )
  match
    @moonbit-casbin.parse_matcher("r_sub.Age")
    .unwrap()
    .eval(
      scope([("r_sub", @moonbit-casbin.Value::String("alice"))]),
      @moonbit-casbin.builtin_functions(),
    ) {
    Err(error) => {
      assert_true(error.message().contains("cannot read field"))
      assert_true(error.message().contains("string"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
}

///|
test "evaluates arithmetic and string concatenation" {
  assert_true(eval_text("1 + 2 * 3", []) == @moonbit-casbin.Value::Int(7))
  assert_true(eval_text("7 / 2", []) == @moonbit-casbin.Value::Double(3.5))
  assert_true(eval_text("7 % 4", []) == @moonbit-casbin.Value::Int(3))
  assert_true(eval_text("'a' + 'b'", []) == @moonbit-casbin.Value::String("ab"))
  assert_true(eval_text("-1 + 2", []) == @moonbit-casbin.Value::Int(1))
}

///|
test "rejects unknown identifiers and functions" {
  match
    @moonbit-casbin.parse_matcher("mystery")
    .unwrap()
    .eval(scope([]), @moonbit-casbin.builtin_functions()) {
    Err(error) => {
      assert_true(error.kind() == MatcherEval)
      assert_true(error.message().contains("mystery"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
  match
    @moonbit-casbin.parse_matcher("mystery(1)")
    .unwrap()
    .eval(scope([]), @moonbit-casbin.builtin_functions()) {
    Err(error) => assert_true(error.message().contains("is not defined"))
    Ok(_) => fail("expected a MatcherEval error")
  }
}

///|
test "rejects type mismatches and division by zero" {
  match
    @moonbit-casbin.parse_matcher("1 + 'a'")
    .unwrap()
    .eval(scope([]), @moonbit-casbin.builtin_functions()) {
    Err(error) => assert_true(error.message().contains("cannot add"))
    Ok(_) => fail("expected a MatcherEval error")
  }
  match
    @moonbit-casbin.parse_matcher("1 % 0")
    .unwrap()
    .eval(scope([]), @moonbit-casbin.builtin_functions()) {
    Err(error) => assert_true(error.message().contains("modulo by zero"))
    Ok(_) => fail("expected a MatcherEval error")
  }
  match
    @moonbit-casbin.parse_matcher("flag && 1")
    .unwrap()
    .eval(
      scope([("flag", @moonbit-casbin.Value::Bool(true))]),
      @moonbit-casbin.builtin_functions(),
    ) {
    Err(error) => assert_true(error.message().contains("requires bool"))
    Ok(_) => fail("expected a MatcherEval error")
  }
}
