// quickstart — ACL and RBAC decisions plus the management APIs.

///|
fn load_enforcer(model_text : String) -> @casbin.Enforcer {
  @casbin.Enforcer::new(
    @casbin.Model::from_config(@casbin.Config::parse(model_text).unwrap()).unwrap(),
  ).unwrap()
}

///|
fn join(names : Array[String]) -> String {
  let mut text = "["
  for name in names {
    text = text + name + " "
  }
  text + "]"
}

///|
fn main {
  let acl_model =
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

  let enforcer = load_enforcer(acl_model)
  let acl_policy =
    #|p, alice, data1, read
    #|p, bob, data2, write
  enforcer.load_policy_from_text(acl_policy).unwrap()
  println("== ACL ==")
  println(
    "alice reads data1  -> " +
    enforcer.enforce(["alice", "data1", "read"]).unwrap().to_string(),
  )
  println(
    "alice writes data1 -> " +
    enforcer.enforce(["alice", "data1", "write"]).unwrap().to_string(),
  )

  let rbac_model =
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

  let enforcer = load_enforcer(rbac_model)
  let rbac_policy =
    #|p, data2_admin, data2, read
    #|g, alice, data2_admin
  enforcer.load_policy_from_text(rbac_policy).unwrap()
  println("== RBAC ==")
  println(
    "alice reads data2 (via role) -> " +
    enforcer.enforce(["alice", "data2", "read"]).unwrap().to_string(),
  )
  ignore(enforcer.add_role_for_user("bob", "data2_admin").unwrap())
  println(
    "bob reads data2 after add_role_for_user -> " +
    enforcer.enforce(["bob", "data2", "read"]).unwrap().to_string(),
  )
  println(
    "bob implicit roles -> " + join(enforcer.get_implicit_roles_for_user("bob")),
  )
  ignore(enforcer.delete_role_for_user("bob", "data2_admin").unwrap())
  println(
    "bob reads data2 after delete_role_for_user -> " +
    enforcer.enforce(["bob", "data2", "read"]).unwrap().to_string(),
  )
}
