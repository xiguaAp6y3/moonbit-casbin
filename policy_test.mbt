// policy_test.mbt — Tests for the in-memory policy store.

///|
test "policy store adds rows and skips duplicates" {
  let store = PolicyStore::new()
  assert_true(store.add("p", ["alice", "data1", "read"]))
  assert_true(!store.add("p", ["alice", "data1", "read"]))
  assert_true(store.add("p", ["bob", "data2", "write"]))
  assert_true(store.rows("p").length() == 2)
  assert_true(store.has("p", ["alice", "data1", "read"]))
  assert_true(!store.has("p", ["alice", "data1"]))
  assert_true(store.rows("g").length() == 0)
  assert_true(!store.has("g", ["alice", "admin"]))
}

///|
test "policy store distinguishes rows with commas" {
  let store = PolicyStore::new()
  assert_true(store.add("p", ["a,b", "c"]))
  assert_true(store.add("p", ["a", "b,c"]))
  assert_true(store.rows("p").length() == 2)
}

///|
test "policy store keeps order after removal" {
  let store = PolicyStore::new()
  ignore(store.add("p", ["a"]))
  ignore(store.add("p", ["b"]))
  ignore(store.add("p", ["c"]))
  assert_true(store.remove("p", ["b"]))
  assert_true(!store.remove("p", ["b"]))
  assert_true(store.rows("p") == [["a"], ["c"]])
  assert_true(store.has("p", ["c"]))
  assert_true(!store.has("p", ["b"]))
}

///|
test "policy store clears every section" {
  let store = PolicyStore::new()
  ignore(store.add("p", ["a"]))
  ignore(store.add("g", ["alice", "admin"]))
  store.clear()
  assert_true(store.rows("p").length() == 0)
  assert_true(store.rows("g").length() == 0)
}
