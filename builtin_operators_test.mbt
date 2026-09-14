// builtin_operators_test.mbt — Tests for the regex/glob/IP built-in operators.
//
// The KeyMatch2..5, KeyGet2/3, RegexMatch, and IPMatch tables are ported
// from Casbin's `util/builtin_operators_test.go` (see
// THIRD_PARTY_NOTICES.md). GlobMatch cases are ported from `TestGlobMatch`
// in the same file.

///|
fn check_operator(
  name : String,
  key1 : String,
  key2 : String,
  expected : Bool,
) -> Unit raise {
  match try_call(name, [Value::String(key1), Value::String(key2)]) {
    Ok(value) =>
      if value != Value::Bool(expected) {
        fail(
          name +
          "(\"" +
          key1 +
          "\", \"" +
          key2 +
          "\") returned an unexpected result",
        )
      }
    Err(error) =>
      fail(
        name + "(\"" + key1 + "\", \"" + key2 + "\") raised: " + error.message(),
      )
  }
}

///|
fn check_get_operator(
  name : String,
  key1 : String,
  key2 : String,
  path_var : String,
  expected : String,
) -> Unit raise {
  match
    try_call(name, [
      Value::String(key1),
      Value::String(key2),
      Value::String(path_var),
    ]) {
    Ok(value) =>
      if value != Value::String(expected) {
        fail(
          name +
          "(\"" +
          key1 +
          "\", \"" +
          key2 +
          "\", \"" +
          path_var +
          "\") returned an unexpected value",
        )
      }
    Err(error) => fail(name + " raised: " + error.message())
  }
}

///|
test "keyMatch2 follows Casbin" {
  let cases : Array[(String, String, Bool)] = [
    ("/foo", "/foo", true),
    ("/foo", "/foo*", true),
    ("/foo", "/foo/*", false),
    ("/foo/bar", "/foo", false),
    ("/foo/bar", "/foo*", false),
    ("/foo/bar", "/foo/*", true),
    ("/foobar", "/foo", false),
    ("/foobar", "/foo*", false),
    ("/foobar", "/foo/*", false),
    ("/", "/:resource", false),
    ("/resource1", "/:resource", true),
    ("/myid", "/:id/using/:resId", false),
    ("/myid/using/myresid", "/:id/using/:resId", true),
    ("/proxy/myid", "/proxy/:id/*", false),
    ("/proxy/myid/", "/proxy/:id/*", true),
    ("/proxy/myid/res", "/proxy/:id/*", true),
    ("/proxy/myid/res/res2", "/proxy/:id/*", true),
    ("/proxy/myid/res/res2/res3", "/proxy/:id/*", true),
    ("/proxy/", "/proxy/:id/*", false),
    ("/alice", "/:id", true),
    ("/alice/all", "/:id/all", true),
    ("/alice", "/:id/all", false),
    ("/alice/all", "/:id", false),
    ("/alice/all", "/:/all", false),
  ]
  for case in cases {
    check_operator("keyMatch2", case.0, case.1, case.2)
  }
}

///|
test "keyMatch3 follows Casbin" {
  let cases : Array[(String, String, Bool)] = [
    ("/foo", "/foo", true),
    ("/foo", "/foo*", true),
    ("/foo", "/foo/*", false),
    ("/foo/bar", "/foo", false),
    ("/foo/bar", "/foo*", false),
    ("/foo/bar", "/foo/*", true),
    ("/foobar", "/foo", false),
    ("/foobar", "/foo*", false),
    ("/foobar", "/foo/*", false),
    ("/", "/{resource}", false),
    ("/resource1", "/{resource}", true),
    ("/myid", "/{id}/using/{resId}", false),
    ("/myid/using/myresid", "/{id}/using/{resId}", true),
    ("/proxy/myid", "/proxy/{id}/*", false),
    ("/proxy/myid/", "/proxy/{id}/*", true),
    ("/proxy/myid/res", "/proxy/{id}/*", true),
    ("/proxy/myid/res/res2", "/proxy/{id}/*", true),
    ("/proxy/myid/res/res2/res3", "/proxy/{id}/*", true),
    ("/proxy/", "/proxy/{id}/*", false),
    ("/myid/using/myresid", "/{id/using/{resId}", false),
  ]
  for case in cases {
    check_operator("keyMatch3", case.0, case.1, case.2)
  }
}

///|
test "keyMatch4 follows Casbin" {
  let cases : Array[(String, String, Bool)] = [
    ("/parent/123/child/123", "/parent/{id}/child/{id}", true),
    ("/parent/123/child/456", "/parent/{id}/child/{id}", false),
    ("/parent/123/child/123", "/parent/{id}/child/{another_id}", true),
    ("/parent/123/child/456", "/parent/{id}/child/{another_id}", true),
    (
      "/parent/123/child/123/book/123", "/parent/{id}/child/{id}/book/{id}", true,
    ),
    (
      "/parent/123/child/123/book/456", "/parent/{id}/child/{id}/book/{id}", false,
    ),
    (
      "/parent/123/child/456/book/123", "/parent/{id}/child/{id}/book/{id}", false,
    ),
    ("/parent/123/child/456/book/", "/parent/{id}/child/{id}/book/{id}", false),
    ("/parent/123/child/456", "/parent/{id}/child/{id}/book/{id}", false),
    ("/parent/123/child/123", "/parent/{i/d}/child/{i/d}", false),
  ]
  for case in cases {
    check_operator("keyMatch4", case.0, case.1, case.2)
  }
}

///|
test "keyMatch5 follows Casbin" {
  let cases : Array[(String, String, Bool)] = [
    ("/parent/child?status=1&type=2", "/parent/child", true),
    ("/parent?status=1&type=2", "/parent/child", false),
    ("/parent/child/?status=1&type=2", "/parent/child/", true),
    ("/parent/child/?status=1&type=2", "/parent/child", false),
    ("/parent/child?status=1&type=2", "/parent/child/", false),
    ("/foo", "/foo", true),
    ("/foo", "/foo*", true),
    ("/foo", "/foo/*", false),
    ("/foo/bar", "/foo", false),
    ("/foo/bar", "/foo*", false),
    ("/foo/bar", "/foo/*", true),
    ("/foobar", "/foo", false),
    ("/foobar", "/foo*", false),
    ("/foobar", "/foo/*", false),
  ]
  for case in cases {
    check_operator("keyMatch5", case.0, case.1, case.2)
  }
}

///|
test "keyGet2 follows Casbin" {
  let cases : Array[(String, String, String, String)] = [
    ("/foo", "/foo", "id", ""),
    ("/foo", "/foo*", "id", ""),
    ("/foo", "/foo/*", "id", ""),
    ("/foo/bar", "/foo", "id", ""),
    ("/foo/bar", "/foo*", "id", ""),
    ("/foo/bar", "/foo/*", "id", ""),
    ("/foobar", "/foo", "id", ""),
    ("/foobar", "/foo*", "id", ""),
    ("/foobar", "/foo/*", "id", ""),
    ("/", "/:resource", "resource", ""),
    ("/resource1", "/:resource", "resource", "resource1"),
    ("/myid", "/:id/using/:resId", "id", ""),
    ("/myid/using/myresid", "/:id/using/:resId", "id", "myid"),
    ("/myid/using/myresid", "/:id/using/:resId", "resId", "myresid"),
    ("/proxy/myid", "/proxy/:id/*", "id", ""),
    ("/proxy/myid/", "/proxy/:id/*", "id", "myid"),
    ("/proxy/myid/res", "/proxy/:id/*", "id", "myid"),
    ("/proxy/myid/res/res2", "/proxy/:id/*", "id", "myid"),
    ("/proxy/myid/res/res2/res3", "/proxy/:id/*", "id", "myid"),
    ("/proxy/myid/res/res2/res3", "/proxy/:id/res/*", "id", "myid"),
    ("/proxy/", "/proxy/:id/*", "id", ""),
    ("/alice", "/:id", "id", "alice"),
    ("/alice/all", "/:id/all", "id", "alice"),
    ("/alice", "/:id/all", "id", ""),
    ("/alice/all", "/:id", "id", ""),
    ("/alice/all", "/:/all", "", ""),
  ]
  for case in cases {
    check_get_operator("keyGet2", case.0, case.1, case.2, case.3)
  }
}

///|
test "keyGet3 follows Casbin" {
  let cases : Array[(String, String, String, String)] = [
    ("/foo", "/foo", "id", ""),
    ("/foo", "/foo*", "id", ""),
    ("/foo", "/foo/*", "id", ""),
    ("/foo/bar", "/foo", "id", ""),
    ("/foo/bar", "/foo*", "id", ""),
    ("/foo/bar", "/foo/*", "id", ""),
    ("/foobar", "/foo", "id", ""),
    ("/foobar", "/foo*", "id", ""),
    ("/foobar", "/foo/*", "id", ""),
    ("/", "/{resource}", "resource", ""),
    ("/resource1", "/{resource}", "resource", "resource1"),
    ("/myid", "/{id}/using/{resId}", "id", ""),
    ("/myid/using/myresid", "/{id}/using/{resId}", "id", "myid"),
    ("/myid/using/myresid", "/{id}/using/{resId}", "resId", "myresid"),
    ("/proxy/myid", "/proxy/{id}/*", "id", ""),
    ("/proxy/myid/", "/proxy/{id}/*", "id", "myid"),
    ("/proxy/myid/res", "/proxy/{id}/*", "id", "myid"),
    ("/proxy/myid/res/res2", "/proxy/{id}/*", "id", "myid"),
    ("/proxy/myid/res/res2/res3", "/proxy/{id}/*", "id", "myid"),
    ("/proxy/", "/proxy/{id}/*", "id", ""),
    (
      "/api/group1_group_name/project1_admin/info", "/api/{proj}_admin/info", "proj",
      "",
    ),
    ("/{id/using/myresid", "/{id/using/{resId}", "resId", "myresid"),
    (
      "/{id/using/myresid/status}", "/{id/using/{resId}/status}", "resId", "myresid",
    ),
    ("/proxy/myid/res/res2/res3", "/proxy/{id}/*/{res}", "res", "res3"),
    ("/api/project1_admin/info", "/api/{proj}_admin/info", "proj", "project1"),
    (
      "/api/group1_group_name/project1_admin/info", "/api/{g}_{gn}/{proj}_admin/info",
      "g", "group1",
    ),
    (
      "/api/group1_group_name/project1_admin/info", "/api/{g}_{gn}/{proj}_admin/info",
      "gn", "group_name",
    ),
    (
      "/api/group1_group_name/project1_admin/info", "/api/{g}_{gn}/{proj}_admin/info",
      "proj", "project1",
    ),
  ]
  for case in cases {
    check_get_operator("keyGet3", case.0, case.1, case.2, case.3)
  }
}

///|
test "regexMatch follows Casbin" {
  let cases : Array[(String, String, Bool)] = [
    ("/topic/create", "/topic/create", true),
    ("/topic/create/123", "/topic/create", true),
    ("/topic/delete", "/topic/create", false),
    ("/topic/edit", "/topic/edit/[0-9]+", false),
    ("/topic/edit/123", "/topic/edit/[0-9]+", true),
    ("/topic/edit/abc", "/topic/edit/[0-9]+", false),
    ("/foo/delete/123", "/topic/delete/[0-9]+", false),
    ("/topic/delete/0", "/topic/delete/[0-9]+", true),
    ("/topic/edit/123s", "/topic/delete/[0-9]+", false),
  ]
  for case in cases {
    check_operator("regexMatch", case.0, case.1, case.2)
  }
}

///|
test "globMatch follows Casbin" {
  let cases : Array[(String, String, Bool)] = [
    ("/foo", "/foo", true),
    ("/foo", "/foo*", true),
    ("/foo", "/foo/*", false),
    ("/foo/bar", "/foo", false),
    ("/foo/bar", "/foo*", false),
    ("/foo/bar", "/foo/*", true),
    ("/foobar", "/foo", false),
    ("/foobar", "/foo*", true),
    ("/foobar", "/foo/*", false),
    ("/foo", "*/foo", true),
    ("/foo", "*/foo*", true),
    ("/foo", "*/foo/*", false),
    ("/foo/bar", "*/foo", false),
    ("/foo/bar", "*/foo/*", true),
    ("/prefix/foo", "*/foo", false),
    ("/prefix/foo", "**/foo", true),
    ("/prefix/foo", "**/foo*", true),
    ("/prefix/foo", "*/foo/**", false),
    ("/prefix/foo/bar", "**/foo/*", true),
    ("/prefix/subprefix/foo/bar", "**/foo/*", true),
    ("/prefix/subprefix/foobar", "**/foo*", true),
    ("/foo", "**/foo/**", true),
    ("/foo/bar", "**/foo/**", true),
    ("/foobar", "**/foo/**", false),
    ("/foo", "*/foo/**", true),
    ("/foo/bar", "**/foo", false),
    ("/foobar", "**/foo**", true),
    ("/foo/bar", "**/foo**", false),
    ("/foobar", "*/foo**", true),
    ("/foo/bar", "*/foo**", false),
  ]
  for case in cases {
    check_operator("globMatch", case.0, case.1, case.2)
  }
}

///|
test "globMatch supports classes and alternation" {
  let cases : Array[(String, String, Bool)] = [
    ("/data1", "/data[0-9]", true),
    ("/datax", "/data[0-9]", false),
    ("/datax", "/data[!0-9]", true),
    ("/data1", "/data[!0-9]", false),
    ("/read.txt", "/*.{txt,md}", true),
    ("/read.md", "/*.{txt,md}", true),
    ("/read.pdf", "/*.{txt,md}", false),
    ("/a/b/c", "/a/*/c", true),
    ("/a/b/c", "/a/*", false),
    ("/a/b/c", "/a/**", true),
  ]
  for case in cases {
    check_operator("globMatch", case.0, case.1, case.2)
  }
}

///|
test "regex operators reject invalid patterns" {
  match
    try_call("regexMatch", [Value::String("/foo"), Value::String("[unclosed")]) {
    Err(error) => {
      assert_true(error.kind() == MatcherEval)
      assert_true(error.message().contains("invalid regular expression"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
  match try_call("globMatch", [Value::String("/foo"), Value::String("/foo[")]) {
    Err(error) => assert_true(error.message().contains("unterminated"))
    Ok(_) => fail("expected a MatcherEval error")
  }
}

///|
test "extended operators validate their arguments" {
  match try_call("keyMatch2", [Value::String("/foo")]) {
    Err(error) => assert_true(error.message().contains("expected 2 arguments"))
    Ok(_) => fail("expected a MatcherEval error")
  }
  match try_call("keyGet2", [Value::String("/foo"), Value::String("/:id")]) {
    Err(error) => assert_true(error.message().contains("expected 3 arguments"))
    Ok(_) => fail("expected a MatcherEval error")
  }
}
