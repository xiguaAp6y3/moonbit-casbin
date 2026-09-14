// rbac_api_test.mbt — End-to-end RBAC tests.
//
// Models, policies, and the role API sequence follow Casbin's
// `examples/rbac_model.conf` / `rbac_policy.csv` and the `TestRoleAPI`
// chain in `rbac_api_test.go`. The `rbac_model_text` fixture is shared
// with `model_test.mbt`.

///|
let rbac_policy_text =
  #|p, alice, data1, read
  #|p, bob, data2, write
  #|p, data2_admin, data2, read
  #|p, data2_admin, data2, write
  #|g, alice, data2_admin

///|
let domain_rbac_model_text =
  #|[request_definition]
  #|r = sub, dom, obj, act
  #|
  #|[policy_definition]
  #|p = sub, dom, obj, act
  #|
  #|[role_definition]
  #|g = _, _, _
  #|
  #|[policy_effect]
  #|e = some(where (p.eft == allow))
  #|
  #|[matchers]
  #|m = g(r.sub, p.sub, r.dom) && r.dom == p.dom && r.obj == p.obj && r.act == p.act

///|
fn build_rbac_enforcer() -> Enforcer {
  let enforcer = build_enforcer(rbac_model_text)
  enforcer.load_policy_from_text(rbac_policy_text).unwrap()
  enforcer
}

///|
test "RBAC decisions resolve roles" {
  let enforcer = build_rbac_enforcer()
  assert_true(enforcer.enforce(["alice", "data1", "read"]).unwrap())
  assert_true(!enforcer.enforce(["alice", "data1", "write"]).unwrap())
  assert_true(enforcer.enforce(["alice", "data2", "read"]).unwrap())
  assert_true(enforcer.enforce(["alice", "data2", "write"]).unwrap())
  assert_true(!enforcer.enforce(["bob", "data1", "read"]).unwrap())
  assert_true(!enforcer.enforce(["bob", "data2", "read"]).unwrap())
  assert_true(enforcer.enforce(["bob", "data2", "write"]).unwrap())
}

///|
test "role API chain mirrors Casbin" {
  let enforcer = build_rbac_enforcer()
  assert_true(enforcer.get_roles_for_user("alice").unwrap() == ["data2_admin"])
  assert_true(enforcer.has_role_for_user("alice", "data2_admin").unwrap())
  assert_true(!enforcer.has_role_for_user("alice", "admin").unwrap())
  assert_true(enforcer.get_users_for_role("data2_admin").unwrap() == ["alice"])
  assert_true(enforcer.delete_role_for_user("alice", "data2_admin").unwrap())
  assert_true(enforcer.get_roles_for_user("alice").unwrap() == [])
  assert_true(!enforcer.enforce(["alice", "data2", "read"]).unwrap())
  assert_true(enforcer.enforce(["alice", "data1", "read"]).unwrap())
  assert_true(enforcer.add_role_for_user("bob", "data2_admin").unwrap())
  assert_true(!enforcer.add_role_for_user("bob", "data2_admin").unwrap())
  assert_true(enforcer.enforce(["bob", "data2", "read"]).unwrap())
  assert_true(enforcer.delete_roles_for_user("bob").unwrap())
  assert_true(!enforcer.enforce(["bob", "data2", "read"]).unwrap())
  assert_true(enforcer.delete_user("alice").unwrap())
  assert_true(!enforcer.enforce(["alice", "data1", "read"]).unwrap())
  assert_true(enforcer.delete_role("data2_admin").unwrap())
  // The role's policy rows are gone, but bob's direct row survives.
  assert_true(!enforcer.enforce(["alice", "data2", "read"]).unwrap())
  assert_true(enforcer.enforce(["bob", "data2", "write"]).unwrap())
}

///|
test "RBAC with domains isolates roles per domain" {
  let enforcer = build_enforcer(domain_rbac_model_text)
  let policy =
    #|p, admin, domain1, data1, read
    #|p, admin, domain1, data1, write
    #|p, admin, domain2, data2, read
    #|p, admin, domain2, data2, write
    #|g, alice, admin, domain1
    #|g, bob, admin, domain2
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(enforcer.enforce(["alice", "domain1", "data1", "read"]).unwrap())
  assert_true(!enforcer.enforce(["alice", "domain2", "data2", "read"]).unwrap())
  assert_true(enforcer.enforce(["bob", "domain2", "data2", "read"]).unwrap())
  assert_true(!enforcer.enforce(["bob", "domain1", "data1", "read"]).unwrap())
  assert_true(
    enforcer.get_roles_for_user("alice", domain="domain1").unwrap() == ["admin"],
  )
  assert_true(
    enforcer.get_roles_for_user("alice", domain="domain2").unwrap() == [],
  )
  assert_true(enforcer.get_roles_for_user("alice").unwrap() == [])
  assert_true(
    enforcer.add_role_for_user("carol", "admin", domain="domain2").unwrap(),
  )
  assert_true(enforcer.enforce(["carol", "domain2", "data2", "write"]).unwrap())
  assert_true(
    enforcer.delete_role_for_user("carol", "admin", domain="domain2").unwrap(),
  )
  assert_true(
    !enforcer.enforce(["carol", "domain2", "data2", "write"]).unwrap(),
  )
}

///|
test "role hierarchy resolves through several levels" {
  let enforcer = build_enforcer(rbac_model_text)
  let policy =
    #|p, data1_admin, data1, read
    #|g, alice, admin
    #|g, admin, data1_admin
  enforcer.load_policy_from_text(policy).unwrap()
  assert_true(enforcer.enforce(["alice", "data1", "read"]).unwrap())
  assert_true(
    enforcer.get_implicit_roles_for_user("alice") == ["admin", "data1_admin"],
  )
  assert_true(
    enforcer.get_implicit_users_for_role("data1_admin") == ["admin", "alice"],
  )
}

///|
test "permissions and implicit permissions" {
  let enforcer = build_rbac_enforcer()
  assert_true(
    enforcer.get_permissions_for_user("alice").unwrap() ==
    [["alice", "data1", "read"]],
  )
  assert_true(
    enforcer.get_permissions_for_user("data2_admin").unwrap().length() == 2,
  )
  let implicit = enforcer.get_implicit_permissions_for_user("alice").unwrap()
  assert_true(implicit.length() == 3)
  assert_true(implicit[0] == ["alice", "data1", "read"])
  assert_true(implicit[1] == ["data2_admin", "data2", "read"])
  assert_true(implicit[2] == ["data2_admin", "data2", "write"])
  assert_true(enforcer.delete_permissions_for_user("data2_admin").unwrap())
  assert_true(!enforcer.enforce(["alice", "data2", "read"]).unwrap())
}

///|
test "policy APIs validate rows and support filtering" {
  let enforcer = build_enforcer(basic_model_text)
  assert_true(enforcer.add_policy(["alice", "data1", "read"]).unwrap())
  assert_true(!enforcer.add_policy(["alice", "data1", "read"]).unwrap())
  assert_true(enforcer.has_policy(["alice", "data1", "read"]).unwrap())
  assert_true(enforcer.add_policy(["bob", "data1", "write"]).unwrap())
  assert_true(enforcer.get_policy().length() == 2)
  assert_true(enforcer.get_filtered_policy(0, ["alice"]).length() == 1)
  assert_true(enforcer.get_filtered_policy(1, ["data1"]).length() == 2)
  match enforcer.add_policy(["alice", "data1"]) {
    Err(error) => {
      assert_true(error.kind() == Enforcement)
      assert_true(error.message().contains("invalid policy rule size"))
    }
    Ok(_) => fail("expected an Enforcement error")
  }
  match enforcer.add_named_policy("p2", ["alice", "data1", "read"]) {
    Err(error) => assert_true(error.kind() == ModelValidation)
    Ok(_) => fail("expected a ModelValidation error")
  }
  assert_true(enforcer.remove_filtered_policy(1, ["data1"]).unwrap())
  assert_true(enforcer.get_policy().length() == 0)
  assert_true(!enforcer.enforce(["alice", "data1", "read"]).unwrap())
}

///|
test "a matcher calling g without a role definition fails clearly" {
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
    #|m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
  let enforcer = build_enforcer(text)
  enforcer.load_policy_from_text("p, alice, data1, read").unwrap()
  match enforcer.enforce(["alice", "data1", "read"]) {
    Err(error) => {
      assert_true(error.kind() == MatcherEval)
      assert_true(error.message().contains("g"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
}
