// adapter_csv_test.mbt — Tests for the CSV policy text adapter.

///|
test "policy text parses quoting, comments, and blank lines" {
  let text =
    #|# comment
    #|p, alice, data1, read
    #|
    #|p, "bob", "data,2", "say ""hi"""
    #|g, alice, admin
  let lines = parse_policy_text(text).unwrap()
  assert_true(lines.length() == 3)
  assert_true(lines[0].key() == "p")
  assert_true(lines[0].values() == ["alice", "data1", "read"])
  assert_true(lines[1].values() == ["bob", "data,2", "say \"hi\""])
  assert_true(lines[2].key() == "g")
  assert_true(lines[2].values() == ["alice", "admin"])
}

///|
test "policy text preserves empty fields and trims unquoted ones" {
  let lines = parse_policy_text("p, a, ,  b  ").unwrap()
  assert_true(lines[0].values() == ["a", "", "b"])
}

///|
test "policy text rejects an unterminated quote" {
  match parse_policy_text("p, \"alice, data1") {
    Err(error) => {
      assert_true(error.kind() == PolicySyntax)
      assert_true(error.message().contains("unterminated"))
    }
    Ok(_) => fail("expected a PolicySyntax error")
  }
}

///|
test "policy text rejects a missing policy type" {
  match parse_policy_text(", alice") {
    Err(error) => {
      assert_true(error.kind() == PolicySyntax)
      assert_true(error.message().contains("missing policy type"))
    }
    Ok(_) => fail("expected a PolicySyntax error")
  }
}
