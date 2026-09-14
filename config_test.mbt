// config_test.mbt — Tests for the Casbin model config parser.

///|
test "config parses sections and entries" {
  let text =
    #|[request_definition]
    #|r = sub, obj, act
    #|
    #|[policy_definition]
    #|p = sub, obj, act
  let config = Config::parse(text).unwrap()
  assert_true(config.get("request_definition", "r") == Some("sub, obj, act"))
  assert_true(config.get("policy_definition", "p") == Some("sub, obj, act"))
  assert_true(config.get("matchers", "m") == None)
}

///|
test "config skips comments and blank lines" {
  let text =
    #|# leading comment
    #|; another comment
    #|
    #|[request_definition]
    #|r = sub, obj, act
  let config = Config::parse(text).unwrap()
  assert_true(config.get("request_definition", "r") == Some("sub, obj, act"))
}

///|
test "config keeps text after the first equals sign" {
  let text =
    #|[matchers]
    #|m = r.sub == p.sub && r.obj == p.obj
  let config = Config::parse(text).unwrap()
  assert_true(
    config.get("matchers", "m") == Some("r.sub == p.sub && r.obj == p.obj"),
  )
}

///|
test "config merges repeated section headers" {
  let text =
    #|[role_definition]
    #|g = _, _
    #|
    #|[role_definition]
    #|g2 = _, _, _
  let config = Config::parse(text).unwrap()
  assert_true(config.section_names().length() == 1)
  assert_true(config.entries("role_definition").length() == 2)
  assert_true(config.get("role_definition", "g2") == Some("_, _, _"))
}

///|
test "config get returns the first duplicate key" {
  let text =
    #|[matchers]
    #|m = first
    #|m = second
  let config = Config::parse(text).unwrap()
  assert_true(config.get("matchers", "m") == Some("first"))
}

///|
test "config handles CRLF line endings" {
  let text = "[request_definition]\r\nr = sub, obj, act\r\n"
  let config = Config::parse(text).unwrap()
  assert_true(config.get("request_definition", "r") == Some("sub, obj, act"))
}

///|
test "config rejects an entry outside any section" {
  let text = "r = sub, obj, act"
  match Config::parse(text) {
    Err(error) => {
      assert_eq(error.kind(), CasbinErrorKind::ConfigSyntax)
      assert_eq(error.line(), 1)
      assert_true(error.message().contains("outside of any section"))
    }
    Ok(_) => fail("expected a ConfigSyntax error")
  }
}

///|
test "config rejects a line without an equals sign" {
  let text =
    #|[request_definition]
    #|r sub, obj, act
  match Config::parse(text) {
    Err(error) => {
      assert_eq(error.kind(), CasbinErrorKind::ConfigSyntax)
      assert_eq(error.line(), 2)
    }
    Ok(_) => fail("expected a ConfigSyntax error")
  }
}

///|
test "config rejects an unterminated section header" {
  let text = "[request_definition\nr = sub"
  match Config::parse(text) {
    Err(error) => {
      assert_eq(error.line(), 1)
      assert_true(error.message().contains("missing ']'"))
    }
    Ok(_) => fail("expected a ConfigSyntax error")
  }
}

///|
test "config rejects an empty key" {
  let text =
    #|[matchers]
    #|= something
  match Config::parse(text) {
    Err(error) => {
      assert_eq(error.line(), 2)
      assert_true(error.message().contains("empty key"))
    }
    Ok(_) => fail("expected a ConfigSyntax error")
  }
}
