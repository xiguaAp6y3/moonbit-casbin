// eval_test.mbt — Black-box tests for the matcher evaluator.

///|
/// Builds an identifier lookup from name/value pairs.
fn scope(pairs : Array[(String, Value)]) -> (String) -> Value? {
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
fn eval_text(text : String, pairs : Array[(String, Value)]) -> Value {
  parse_matcher(text).unwrap().eval(scope(pairs), builtin_functions()).unwrap()
}

///|
test "evaluates comparisons and cross-type numeric equality" {
  assert_true(eval_text("18 > 17", []) == Value::Bool(true))
  assert_true(eval_text("'a' == 'a'", []) == Value::Bool(true))
  assert_true(eval_text("18 == 18.0", []) == Value::Bool(true))
  assert_true(eval_text("'a' != 'b'", []) == Value::Bool(true))
  assert_true(eval_text("'a' < 'b'", []) == Value::Bool(true))
}

///|
test "short-circuits logical operators" {
  assert_true(eval_text("false && missing", []) == Value::Bool(false))
  assert_true(eval_text("true || missing", []) == Value::Bool(true))
  assert_true(
    eval_text("flag && count >= 2", [
      ("flag", Value::Bool(true)),
      ("count", Value::Int(3)),
    ]) ==
    Value::Bool(true),
  )
}

///|
test "tests membership with in" {
  assert_true(
    eval_text("r_obj in ('data2', 'data3')", [("r_obj", Value::String("data2"))]) ==
    Value::Bool(true),
  )
  assert_true(
    eval_text("r_obj in ('data2', 'data3')", [("r_obj", Value::String("data1"))]) ==
    Value::Bool(false),
  )
  match
    parse_matcher("r_obj in r_obj")
    .unwrap()
    .eval(scope([("r_obj", Value::String("data1"))]), builtin_functions()) {
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
      ("r_obj", Value::String("/foo/bar")),
      ("p_obj", Value::String("/foo/*")),
    ]) ==
    Value::Bool(true),
  )
  assert_true(
    eval_text("keyMatch(r_obj, p_obj)", [
      ("r_obj", Value::String("/foobar")),
      ("p_obj", Value::String("/foo/*")),
    ]) ==
    Value::Bool(false),
  )
}

///|
test "reads fields from records" {
  let subject = Value::Object([("Age", Value::Int(20))])
  assert_true(
    eval_text("r_sub.Age >= 18", [("r_sub", subject)]) == Value::Bool(true),
  )
  match
    parse_matcher("r_sub.Age")
    .unwrap()
    .eval(scope([("r_sub", Value::String("alice"))]), builtin_functions()) {
    Err(error) => {
      assert_true(error.message().contains("cannot read field"))
      assert_true(error.message().contains("string"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
}

///|
test "evaluates arithmetic and string concatenation" {
  assert_true(eval_text("1 + 2 * 3", []) == Value::Int(7))
  assert_true(eval_text("7 / 2", []) == Value::Double(3.5))
  assert_true(eval_text("7 % 4", []) == Value::Int(3))
  assert_true(eval_text("'a' + 'b'", []) == Value::String("ab"))
  assert_true(eval_text("-1 + 2", []) == Value::Int(1))
}

///|
test "rejects unknown identifiers and functions" {
  match parse_matcher("mystery").unwrap().eval(scope([]), builtin_functions()) {
    Err(error) => {
      assert_true(error.kind() == MatcherEval)
      assert_true(error.message().contains("mystery"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
  match
    parse_matcher("mystery(1)").unwrap().eval(scope([]), builtin_functions()) {
    Err(error) => assert_true(error.message().contains("is not defined"))
    Ok(_) => fail("expected a MatcherEval error")
  }
}

///|
test "rejects type mismatches and division by zero" {
  match parse_matcher("1 + 'a'").unwrap().eval(scope([]), builtin_functions()) {
    Err(error) => assert_true(error.message().contains("cannot add"))
    Ok(_) => fail("expected a MatcherEval error")
  }
  match parse_matcher("1 % 0").unwrap().eval(scope([]), builtin_functions()) {
    Err(error) => assert_true(error.message().contains("modulo by zero"))
    Ok(_) => fail("expected a MatcherEval error")
  }
  match
    parse_matcher("flag && 1")
    .unwrap()
    .eval(scope([("flag", Value::Bool(true))]), builtin_functions()) {
    Err(error) => assert_true(error.message().contains("requires bool"))
    Ok(_) => fail("expected a MatcherEval error")
  }
}
