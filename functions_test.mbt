// functions_test.mbt — Black-box tests for built-in matcher functions.
//
// The `keyMatch` and `keyGet` tables are ported from Casbin's
// `util/builtin_operators_test.go` so the MoonBit implementation is
// verified against the reference behavior (see THIRD_PARTY_NOTICES.md).

///|
/// Calls a built-in function, converting a raised error into `Err`.
fn try_call(
  name : String,
  arguments : Array[@moonbit-casbin.Value],
) -> Result[@moonbit-casbin.Value, @moonbit-casbin.CasbinError] {
  let function = @moonbit-casbin.builtin_functions().get(name).unwrap()
  Ok(function(arguments)) catch {
    error => Err(error)
  }
}

///|
fn double_function(
  arguments : Array[@moonbit-casbin.Value],
) -> @moonbit-casbin.Value raise @moonbit-casbin.CasbinError {
  if arguments.length() != 1 {
    raise @moonbit-casbin.casbin_error(
      MatcherEval,
      "double: expected 1 argument",
    )
  }
  match arguments[0] {
    @moonbit-casbin.Value::Int(value) => @moonbit-casbin.Value::Int(value * 2)
    other =>
      raise @moonbit-casbin.casbin_error(
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
    match
      try_call("keyMatch", [
        @moonbit-casbin.Value::String(case.0),
        @moonbit-casbin.Value::String(case.1),
      ]) {
      Ok(value) => assert_true(value == @moonbit-casbin.Value::Bool(case.2))
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
    match
      try_call("keyGet", [
        @moonbit-casbin.Value::String(case.0),
        @moonbit-casbin.Value::String(case.1),
      ]) {
      Ok(value) => assert_true(value == @moonbit-casbin.Value::String(case.2))
      Err(error) => fail("keyGet raised: " + error.message())
    }
  }
}

///|
test "built-ins validate their arguments" {
  match try_call("keyMatch", [@moonbit-casbin.Value::String("/foo")]) {
    Err(error) => {
      assert_true(error.kind() == MatcherEval)
      assert_true(error.message().contains("expected 2 arguments"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
  match
    try_call("keyMatch", [
      @moonbit-casbin.Value::String("/foo"),
      @moonbit-casbin.Value::Int(1),
    ]) {
    Err(error) => assert_true(error.message().contains("must be a string"))
    Ok(_) => fail("expected a MatcherEval error")
  }
}

///|
test "custom functions can be registered and used in matchers" {
  let registry = @moonbit-casbin.builtin_functions()
  registry.add("double", double_function)
  assert_true(
    registry.get("double").unwrap()([@moonbit-casbin.Value::Int(21)]) ==
    @moonbit-casbin.Value::Int(42),
  )
  let value = @moonbit-casbin.parse_matcher("double(n) == 42")
    .unwrap()
    .eval(scope([("n", @moonbit-casbin.Value::Int(21))]), registry)
    .unwrap()
  assert_true(value == @moonbit-casbin.Value::Bool(true))
}

///|
test "registering a function twice replaces it" {
  let registry = @moonbit-casbin.FunctionRegistry::new()
  registry.add("value", _arguments => @moonbit-casbin.Value::Int(1))
  registry.add("value", _arguments => @moonbit-casbin.Value::Int(2))
  assert_true(
    registry.get("value").unwrap()([]) == @moonbit-casbin.Value::Int(2),
  )
}
