// preprocess_test.mbt — Tests for matcher/effect text preprocessing.
//
// The `escape_assertion` and `remove_comments` tables are ported from
// Casbin's `util/util_test.go` (see THIRD_PARTY_NOTICES.md).

///|
test "escape_assertion follows Casbin" {
  let cases : Array[(String, String)] = [
    ("r_sub == r_obj.value", "r_sub == r_obj.value"),
    ("p_sub == r_sub.value", "p_sub == r_sub.value"),
    ("r.attr.value == p.attr", "r_attr.value == p_attr"),
    ("r.attp.value || p.attr", "r_attp.value || p_attr"),
    ("r2.attr.value == p2.attr", "r2_attr.value == p2_attr"),
    ("r2.attp.value || p2.attr", "r2_attp.value || p2_attr"),
    ("r.attp.value &&p.attr", "r_attp.value &&p_attr"),
    ("r.attp.value >p.attr", "r_attp.value >p_attr"),
    ("r.attp.value <p.attr", "r_attp.value <p_attr"),
    ("r.attp.value +p.attr", "r_attp.value +p_attr"),
    ("r.attp.value -p.attr", "r_attp.value -p_attr"),
    ("r.attp.value *p.attr", "r_attp.value *p_attr"),
    ("r.attp.value /p.attr", "r_attp.value /p_attr"),
    ("!r.attp.value /p.attr", "!r_attp.value /p_attr"),
    ("g(r.sub, p.sub) == p.attr", "g(r_sub, p_sub) == p_attr"),
    ("g(r.sub,p.sub) == p.attr", "g(r_sub,p_sub) == p_attr"),
    ("(r.attp.value || p.attr)p.u", "(r_attp.value || p_attr)p_u"),
    ("r.sub == \"a.p.p.l.e\"", "r_sub == \"a.p.p.l.e\""),
    ("r.sub == \"test.p.value\"", "r_sub == \"test.p.value\""),
  ]
  for case in cases {
    assert_true(escape_assertion(case.0) == case.1)
  }
}

///|
test "remove_comments follows Casbin" {
  let cases : Array[(String, String)] = [
    ("r.act == p.act # comments", "r.act == p.act"),
    ("r.act == p.act#comments", "r.act == p.act"),
    ("r.act == p.act###", "r.act == p.act"),
    ("### comments", ""),
    ("r.act == p.act", "r.act == p.act"),
  ]
  for case in cases {
    assert_true(remove_comments(case.0) == case.1)
  }
}

///|
test "preprocess_expression escapes accessors and strips comments" {
  assert_true(
    preprocess_expression("r.sub == p.sub # note") == "r_sub == p_sub",
  )
  assert_true(
    preprocess_expression("g(r.sub, p.sub) && r.obj == p.obj") ==
    "g(r_sub, p_sub) && r_obj == p_obj",
  )
}

///|
test "escape_assertion leaves identifiers and strings alone" {
  assert_true(escape_assertion("role.sub") == "role.sub")
  assert_true(escape_assertion("'p.x' == r.sub") == "'p.x' == r_sub")
}
