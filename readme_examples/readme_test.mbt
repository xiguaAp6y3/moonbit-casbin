// README conformance tests: every code snippet in the README "快速开始" section
// is reproduced here (plus the error-kind/message claims), so documentation and
// implementation cannot drift apart. `moon test` runs these with the rest of the
// suite on all four targets.

///|
test "readme 快速开始: load an RBAC model" {
  let text =
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

  let model = @casbin.Model::from_config(@casbin.Config::parse(text).unwrap()).unwrap()
  let request = model.request_definition("r").unwrap()
  assert_eq(request.tokens(), ["sub", "obj", "act"])
  let role = model.role_definition("g").unwrap()
  assert_eq(role.tokens(), ["_", "_"])
}

///|
test "readme 错误处理: config syntax error carries kind, line and message" {
  match @casbin.Config::parse("r = sub, obj, act") {
    Err(error) => {
      assert_eq(error.kind(), @casbin.CasbinErrorKind::ConfigSyntax)
      assert_eq(error.line(), 1)
      assert_eq(error.message(), "entry outside of any section")
    }
    Ok(_) => assert_true(false)
  }
}

///|
test "readme 错误处理: model validation error kind" {
  let text =
    #|[request_definition]
    #|r = sub, obj, act
  match @casbin.Model::from_config(@casbin.Config::parse(text).unwrap()) {
    Err(error) =>
      assert_eq(error.kind(), @casbin.CasbinErrorKind::ModelValidation)
    Ok(_) => assert_true(false)
  }
}

///|
test "readme matcher 引擎: standalone evaluation" {
  let value = @casbin.parse_matcher("keyMatch(r_obj, p_obj) && !denied")
    .unwrap()
    .eval(
      name => {
        match name {
          "r_obj" => Some(@casbin.Value::String("/foo/bar"))
          "p_obj" => Some(@casbin.Value::String("/foo/*"))
          "denied" => Some(@casbin.Value::Bool(false))
          _ => None
        }
      },
      @casbin.builtin_functions(),
    )
    .unwrap()
  assert_true(value == @casbin.Value::Bool(true))
}

///|
test "readme 端到端判定: ACL enforce" {
  let model_text =
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

  let model = @casbin.Model::from_config(
    @casbin.Config::parse(model_text).unwrap(),
  ).unwrap()
  let enforcer = @casbin.Enforcer::new(model).unwrap()
  let policy =
    #|p, alice, data1, read
    #|p, bob, data2, write
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(enforcer.enforce(["alice", "data1", "read"]).unwrap())
  assert_true(!enforcer.enforce(["alice", "data1", "write"]).unwrap())
}

///|
test "readme RBAC: role hierarchy and management API" {
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

  let model = @casbin.Model::from_config(
    @casbin.Config::parse(rbac_model_text).unwrap(),
  ).unwrap()
  let enforcer = @casbin.Enforcer::new(model).unwrap()
  let policy =
    #|p, alice, data1, read
    #|p, data2_admin, data2, read
    #|g, alice, data2_admin
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(enforcer.enforce(["alice", "data2", "read"]).unwrap())
  assert_true(enforcer.add_role_for_user("bob", "data2_admin").unwrap())
  assert_true(enforcer.get_implicit_roles_for_user("bob") == ["data2_admin"])
  assert_true(enforcer.enforce(["bob", "data2", "read"]).unwrap())
  assert_true(enforcer.delete_role_for_user("bob", "data2_admin").unwrap())
  assert_true(!enforcer.enforce(["bob", "data2", "read"]).unwrap())
}
