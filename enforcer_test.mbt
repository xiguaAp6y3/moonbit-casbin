// enforcer_test.mbt — End-to-end enforcement tests.
//
// Model and policy examples follow Casbin's `examples/` directory; the
// decision expectations follow Casbin's `enforcer_test.go`.

///|
let deny_override_model_text =
  #|[request_definition]
  #|r = sub, obj, act
  #|
  #|[policy_definition]
  #|p = sub, obj, act, eft
  #|
  #|[policy_effect]
  #|e = !some(where (p.eft == deny))
  #|
  #|[matchers]
  #|m = r.sub == p.sub && r.obj == p.obj && r.act == p.act

///|
let allow_and_deny_model_text =
  #|[request_definition]
  #|r = sub, obj, act
  #|
  #|[policy_definition]
  #|p = sub, obj, act, eft
  #|
  #|[policy_effect]
  #|e = some(where (p.eft == allow)) && !some(where (p.eft == deny))
  #|
  #|[matchers]
  #|m = r.sub == p.sub && r.obj == p.obj && r.act == p.act

///|
let priority_model_text =
  #|[request_definition]
  #|r = sub, obj, act
  #|
  #|[policy_definition]
  #|p = sub, obj, act, eft
  #|
  #|[policy_effect]
  #|e = priority(p.eft) || deny
  #|
  #|[matchers]
  #|m = r.sub == p.sub && r.obj == p.obj && r.act == p.act

///|
let boolean_matcher_model_text =
  #|[request_definition]
  #|r = sub
  #|
  #|[policy_definition]
  #|p = sub
  #|
  #|[policy_effect]
  #|e = some(where (p.eft == allow))
  #|
  #|[matchers]
  #|m = is_admin(r.sub)

///|
fn build_enforcer(model_text : String) -> Enforcer {
  let model = Model::from_config(Config::parse(model_text).unwrap()).unwrap()
  Enforcer::new(model).unwrap()
}

///|
fn is_admin_function(arguments : Array[Value]) -> Value raise CasbinError {
  if arguments.length() != 1 {
    raise casbin_error(MatcherEval, "is_admin: expected 1 argument")
  }
  match arguments[0] {
    Value::String(name) => Value::Bool(name == "root")
    other =>
      raise casbin_error(
        MatcherEval,
        "is_admin: expected a string, got " + other.type_name(),
      )
  }
}

///|
test "basic model decisions follow the policy" {
  let enforcer = build_enforcer(basic_model_text)
  let policy =
    #|p, alice, data1, read
    #|p, bob, data2, write
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(enforcer.enforce(["alice", "data1", "read"]).unwrap())
  assert_true(enforcer.enforce(["bob", "data2", "write"]).unwrap())
  assert_true(!enforcer.enforce(["alice", "data2", "read"]).unwrap())
  assert_true(!enforcer.enforce(["alice", "data1", "write"]).unwrap())
  assert_true(!enforcer.enforce(["bob", "data1", "read"]).unwrap())
}

///|
test "duplicate policy rows are skipped" {
  let enforcer = build_enforcer(basic_model_text)
  let policy =
    #|p, alice, data1, read
    #|p, alice, data1, read
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(enforcer.policy().rows("p").length() == 1)
}

///|
test "unsupported policy effects are rejected at construction" {
  let text =
    #|[request_definition]
    #|r = sub, obj, act
    #|
    #|[policy_definition]
    #|p = sub, obj, act
    #|
    #|[policy_effect]
    #|e = something(else)
    #|
    #|[matchers]
    #|m = r.sub == p.sub
  match
    Enforcer::new(Model::from_config(Config::parse(text).unwrap()).unwrap()) {
    Err(error) => {
      assert_true(error.kind() == ModelValidation)
      assert_true(error.message().contains("unsupported policy effect"))
    }
    Ok(_) => fail("expected a ModelValidation error")
  }
}

///|
test "policy types must exist in the model" {
  let enforcer = build_enforcer(basic_model_text)
  match enforcer.load_policy_from_text("p2, alice, data1, read") {
    Err(error) => {
      assert_true(error.kind() == ModelValidation)
      assert_true(error.message().contains("p2"))
    }
    Ok(_) => fail("expected a ModelValidation error")
  }
  match enforcer.load_policy_from_text("x, alice, data1, read") {
    Err(error) => assert_true(error.kind() == PolicySyntax)
    Ok(_) => fail("expected a PolicySyntax error")
  }
}

///|
test "policy row size is validated at load time" {
  let enforcer = build_enforcer(basic_model_text)
  match enforcer.load_policy_from_text("p, alice, data1") {
    Err(error) => {
      assert_true(error.kind() == Enforcement)
      assert_true(error.message().contains("invalid policy rule size"))
    }
    Ok(_) => fail("expected an Enforcement error")
  }
}

///|
test "request size is validated" {
  let enforcer = build_enforcer(basic_model_text)
  match enforcer.enforce(["alice", "data1"]) {
    Err(error) => {
      assert_true(error.kind() == Enforcement)
      assert_true(error.message().contains("invalid request size"))
    }
    Ok(_) => fail("expected an Enforcement error")
  }
}

///|
test "deny override allows when no deny rule matches" {
  let enforcer = build_enforcer(deny_override_model_text)
  let policy =
    #|p, alice, data1, read, allow
    #|p, alice, data1, write, deny
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(enforcer.enforce(["alice", "data1", "read"]).unwrap())
  assert_true(!enforcer.enforce(["alice", "data1", "write"]).unwrap())
  assert_true(enforcer.enforce(["bob", "data9", "read"]).unwrap())
}

///|
test "allow and deny requires an allow and no deny" {
  let enforcer = build_enforcer(allow_and_deny_model_text)
  let policy =
    #|p, alice, data1, read, allow
    #|p, alice, data1, write, deny
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(enforcer.enforce(["alice", "data1", "read"]).unwrap())
  assert_true(!enforcer.enforce(["alice", "data1", "write"]).unwrap())
  assert_true(!enforcer.enforce(["bob", "data9", "read"]).unwrap())
}

///|
test "priority takes the first matching row" {
  let enforcer = build_enforcer(priority_model_text)
  let policy =
    #|p, alice, data1, read, deny
    #|p, alice, data1, read, allow
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(!enforcer.enforce(["alice", "data1", "read"]).unwrap())
  let enforcer = build_enforcer(priority_model_text)
  let policy =
    #|p, alice, data1, read, allow
    #|p, alice, data1, read, deny
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(enforcer.enforce(["alice", "data1", "read"]).unwrap())
  assert_true(!enforcer.enforce(["bob", "data9", "read"]).unwrap())
}

///|
test "unknown effect values leave a row indeterminate" {
  let enforcer = build_enforcer(allow_and_deny_model_text)
  let policy =
    #|p, alice, data1, read, maybe
    #|p, alice, data1, read, allow
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(enforcer.enforce(["alice", "data1", "read"]).unwrap())
  let enforcer = build_enforcer(allow_and_deny_model_text)
  enforcer.load_policy_from_text("p, alice, data1, read, maybe").unwrap()
  assert_true(!enforcer.enforce(["alice", "data1", "read"]).unwrap())
}

///|
test "a matcher without policy references is evaluated once" {
  let enforcer = build_enforcer(boolean_matcher_model_text)
  enforcer.load_policy_from_text("p, root").unwrap()
  enforcer.add_function("is_admin", is_admin_function)
  assert_true(enforcer.enforce(["root"]).unwrap())
  assert_true(!enforcer.enforce(["alice"]).unwrap())
}

///|
test "matcher errors are reported with the matcher error kind" {
  let enforcer = build_enforcer(basic_model_text)
  enforcer.load_policy_from_text("p, alice, data1, read").unwrap()
  // Drop the request field by asking for an unknown identifier through a
  // custom model instead: reuse enforce size validation covered above, and
  // check that a matcher referencing an undefined policy token fails.
  let text =
    #|[request_definition]
    #|r = sub, obj, act
    #|
    #|[policy_definition]
    #|p = sub, obj, act
    #|
    #|[policy_effect]
    #|e = some(where (p.eft == allow))
    #|
    #|[matchers]
    #|m = p_missing == r.sub
  let enforcer = build_enforcer(text)
  enforcer.load_policy_from_text("p, alice, data1, read").unwrap()
  match enforcer.enforce(["alice", "data1", "read"]) {
    Err(error) => {
      assert_true(error.kind() == MatcherEval)
      assert_true(error.message().contains("p_missing"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
}
