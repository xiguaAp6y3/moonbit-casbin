// functions_test.mbt — Black-box tests for built-in matcher functions.
//
// The `keyMatch` and `keyGet` tables are ported from Casbin's
// `util/builtin_operators_test.go` so the MoonBit implementation is
// verified against the reference behavior (see THIRD_PARTY_NOTICES.md).

///|
/// Calls a built-in function, converting a raised error into `Err`.
fn try_call(
  name : String,
  arguments : Array[Value],
) -> Result[Value, CasbinError] {
  let function = builtin_functions().get(name).unwrap()
  Ok(function(arguments)) catch {
    error => Err(error)
  }
}

///|
fn double_function(arguments : Array[Value]) -> Value raise CasbinError {
  if arguments.length() != 1 {
    raise casbin_error(MatcherEval, "double: expected 1 argument")
  }
  match arguments[0] {
    Value::Int(value) => Value::Int(value * 2)
    other =>
      raise casbin_error(
        MatcherEval,
        "double: expected an int, got " + other.type_name(),
      )
  }
}

///|
test "keyMatch follows Casbin semantics" {
  let cases : Array[(String, String, Bool)] = [
    ("/foo", "/foo", true),
    ("/foo", "/foo*", true),
    ("/foo", "/foo/*", false),
    ("/foo/bar", "/foo", false),
    ("/foo/bar", "/foo*", true),
    ("/foo/bar", "/foo/*", true),
    ("/foobar", "/foo", false),
    ("/foobar", "/foo*", true),
    ("/foobar", "/foo/*", false),
  ]
  for case in cases {
    match try_call("keyMatch", [Value::String(case.0), Value::String(case.1)]) {
      Ok(value) => assert_true(value == Value::Bool(case.2))
      Err(error) => fail("keyMatch raised: " + error.message())
    }
  }
}

///|
test "keyGet follows Casbin semantics" {
  let cases : Array[(String, String, String)] = [
    ("/foo/bar", "/foo", ""),
    ("/foo/bar", "/foo*", "/bar"),
    ("/foo/bar", "/foo/*", "bar"),
    ("/foobar", "/foo", ""),
    ("/foobar", "/foo*", "bar"),
    ("/foobar", "/foo/*", ""),
  ]
  for case in cases {
    match try_call("keyGet", [Value::String(case.0), Value::String(case.1)]) {
      Ok(value) => assert_true(value == Value::String(case.2))
      Err(error) => fail("keyGet raised: " + error.message())
    }
  }
}

///|
test "built-ins validate their arguments" {
  match try_call("keyMatch", [Value::String("/foo")]) {
    Err(error) => {
      assert_true(error.kind() == MatcherEval)
      assert_true(error.message().contains("expected 2 arguments"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
  match try_call("keyMatch", [Value::String("/foo"), Value::Int(1)]) {
    Err(error) => assert_true(error.message().contains("must be a string"))
    Ok(_) => fail("expected a MatcherEval error")
  }
}

///|
test "custom functions can be registered and used in matchers" {
  let registry = builtin_functions()
  registry.add("double", double_function)
  assert_true(
    registry.get("double").unwrap()([Value::Int(21)]) == Value::Int(42),
  )
  let value = parse_matcher("double(n) == 42")
    .unwrap()
    .eval(scope([("n", Value::Int(21))]), registry)
    .unwrap()
  assert_true(value == Value::Bool(true))
}

///|
test "registering a function twice replaces it" {
  let registry = FunctionRegistry::new()
  registry.add("value", _arguments => Value::Int(1))
  registry.add("value", _arguments => Value::Int(2))
  assert_true(registry.get("value").unwrap()([]) == Value::Int(2))
}
