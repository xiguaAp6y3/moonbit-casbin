// model_test.mbt — Tests for Casbin model loading.

///|
let basic_model_text =
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
  #|m = r.sub == p.sub && r.obj == p.obj && r.act == p.act

///|
let rbac_model_text =
  #|[request_definition]
  #|r = sub, obj, act
  #|
  #|[policy_definition]
  #|p = sub, obj, act
  #|
  #|[role_definition]
  #|g = _, _
  #|
  #|[policy_effect]
  #|e = some(where (p.eft == allow))
  #|
  #|[matchers]
  #|m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act

///|
test "model loads the basic model" {
  let model = Model::from_config(Config::parse(basic_model_text).unwrap()).unwrap()
  let request = model.request_definition("r").unwrap()
  assert_true(request.tokens() == ["sub", "obj", "act"])
  let policy = model.policy_definition("p").unwrap()
  assert_true(policy.tokens() == ["sub", "obj", "act"])
  let effect = model.policy_effect().unwrap()
  assert_true(effect.value() == "some(where (p.eft == allow))")
  let matcher = model.matcher("m").unwrap()
  assert_true(
    matcher.value() == "r.sub == p.sub && r.obj == p.obj && r.act == p.act",
  )
  assert_true(model.role_definition("g") == None)
}

///|
test "model loads the RBAC model with a role definition" {
  let model = Model::from_config(Config::parse(rbac_model_text).unwrap()).unwrap()
  let role = model.role_definition("g").unwrap()
  assert_true(role.tokens() == ["_", "_"])
  assert_true(model.matcher("m") != None)
}

///|
test "model requires the matchers section" {
  let text =
    #|[request_definition]
    #|r = sub, obj, act
    #|
    #|[policy_definition]
    #|p = sub, obj, act
    #|
    #|[policy_effect]
    #|e = some(where (p.eft == allow))
  match Model::from_config(Config::parse(text).unwrap()) {
    Err(error) => {
      assert_eq(error.kind(), CasbinErrorKind::ModelValidation)
      assert_true(error.message().contains("[matchers]"))
    }
    Ok(_) => fail("expected a ModelValidation error")
  }
}

///|
test "model rejects unknown sections" {
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
    #|m = true
    #|
    #|[wat]
    #|x = y
  match Model::from_config(Config::parse(text).unwrap()) {
    Err(error) => {
      assert_eq(error.kind(), CasbinErrorKind::ModelValidation)
      assert_true(error.message().contains("[wat]"))
    }
    Ok(_) => fail("expected a ModelValidation error")
  }
}

///|
test "model rejects invalid tokens" {
  let text =
    #|[request_definition]
    #|r = sub, obj, act
    #|
    #|[policy_definition]
    #|p = sub, 1act
    #|
    #|[policy_effect]
    #|e = some(where (p.eft == allow))
    #|
    #|[matchers]
    #|m = true
  match Model::from_config(Config::parse(text).unwrap()) {
    Err(error) => assert_true(error.message().contains("\"1act\""))
    Ok(_) => fail("expected a ModelValidation error")
  }
}

///|
test "model rejects mismatched definition prefixes" {
  let text =
    #|[request_definition]
    #|x = sub, obj, act
    #|
    #|[policy_definition]
    #|p = sub, obj, act
    #|
    #|[policy_effect]
    #|e = some(where (p.eft == allow))
    #|
    #|[matchers]
    #|m = true
  match Model::from_config(Config::parse(text).unwrap()) {
    Err(error) => assert_true(error.message().contains("must start with \"r\""))
    Ok(_) => fail("expected a ModelValidation error")
  }
}

///|
test "model rejects several policy effects" {
  let text =
    #|[request_definition]
    #|r = sub, obj, act
    #|
    #|[policy_definition]
    #|p = sub, obj, act
    #|
    #|[policy_effect]
    #|e = some(where (p.eft == allow))
    #|e2 = some(where (p.eft == deny))
    #|
    #|[matchers]
    #|m = true
  match Model::from_config(Config::parse(text).unwrap()) {
    Err(error) => assert_true(error.message().contains("exactly one entry"))
    Ok(_) => fail("expected a ModelValidation error")
  }
}

///|
test "model rejects an empty definition value" {
  let text =
    #|[request_definition]
    #|r =
    #|
    #|[policy_definition]
    #|p = sub, obj, act
    #|
    #|[policy_effect]
    #|e = some(where (p.eft == allow))
    #|
    #|[matchers]
    #|m = true
  match Model::from_config(Config::parse(text).unwrap()) {
    Err(error) => assert_true(error.message().contains("empty token"))
    Ok(_) => fail("expected a ModelValidation error")
  }
}
