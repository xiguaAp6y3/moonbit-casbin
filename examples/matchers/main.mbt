// matchers — path, regex, glob, and IP operators in matchers.

///|
fn main {
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
    #|m = r.sub == p.sub && keyMatch2(r.obj, p.obj) && regexMatch(r.act, p.act)

  let enforcer = @casbin.Enforcer::new(
    @casbin.Model::from_config(@casbin.Config::parse(model_text).unwrap()).unwrap(),
  ).unwrap()
  let policy =
    #|p, alice, /alice_data/:resource, GET
    #|p, alice, /alice_data2/:id/using/:resId, GET|POST
  enforcer.load_policy_from_text(policy).unwrap()
  println("== keyMatch2 + regexMatch ==")
  println(
    "alice GET /alice_data/hello -> " +
    enforcer.enforce(["alice", "/alice_data/hello", "GET"]).unwrap().to_string(),
  )
  println(
    "alice GET /alice_data2/1/using/2 -> " +
    enforcer
    .enforce(["alice", "/alice_data2/1/using/2", "GET"])
    .unwrap()
    .to_string(),
  )
  println(
    "alice PUT /alice_data/hello -> " +
    enforcer.enforce(["alice", "/alice_data/hello", "PUT"]).unwrap().to_string(),
  )

  let ip_model =
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
    #|m = r.sub == p.sub && ipMatch(r.obj, p.obj) && globMatch(r.act, p.act)

  let enforcer = @casbin.Enforcer::new(
    @casbin.Model::from_config(@casbin.Config::parse(ip_model).unwrap()).unwrap(),
  ).unwrap()
  let policy =
    #|p, alice, 192.168.2.0/24, /data/**
  enforcer.load_policy_from_text(policy).unwrap()
  println("== ipMatch + globMatch ==")
  println(
    "alice 192.168.2.123 /data/report.txt -> " +
    enforcer
    .enforce(["alice", "192.168.2.123", "/data/report.txt"])
    .unwrap()
    .to_string(),
  )
  println(
    "alice 192.168.3.1 /data/report.txt -> " +
    enforcer
    .enforce(["alice", "192.168.3.1", "/data/report.txt"])
    .unwrap()
    .to_string(),
  )
  println(
    "alice 192.168.2.123 /other/file.txt -> " +
    enforcer
    .enforce(["alice", "192.168.2.123", "/other/file.txt"])
    .unwrap()
    .to_string(),
  )
}
