// role_manager_test.mbt — Tests for the role graph and role manager.

///|
test "role manager links and queries direct relations" {
  let manager = RoleManager::new()
  manager.add_link("alice", "admin")
  manager.add_link("alice", "editor")
  manager.add_link("bob", "admin")
  assert_true(manager.get_roles("alice") == ["admin", "editor"])
  assert_true(manager.get_users("admin") == ["alice", "bob"])
  assert_true(manager.get_roles("carol") == [])
  assert_true(manager.get_users("nobody") == [])
}

///|
test "role manager resolves transitive links with a level limit" {
  let manager = RoleManager::new()
  manager.add_link("a", "b")
  manager.add_link("b", "c")
  manager.add_link("c", "d")
  assert_true(manager.has_link("a", "d"))
  assert_true(manager.has_link("a", "a"))
  assert_true(!manager.has_link("d", "a"))
  assert_true(!manager.has_link("a", "missing"))
  let shallow = RoleManager::new(max_hierarchy_level=2)
  shallow.add_link("a", "b")
  shallow.add_link("b", "c")
  shallow.add_link("c", "d")
  assert_true(shallow.has_link("a", "c"))
  assert_true(!shallow.has_link("a", "d"))
}

///|
test "role manager implicit roles and users are transitive and deduplicated" {
  let manager = RoleManager::new()
  manager.add_link("alice", "admin")
  manager.add_link("admin", "data1_admin")
  manager.add_link("dave", "admin")
  assert_true(manager.get_implicit_roles("alice") == ["admin", "data1_admin"])
  assert_true(
    manager.get_implicit_users("data1_admin") == ["admin", "alice", "dave"],
  )
}

///|
test "role manager domains are isolated" {
  let manager = RoleManager::new()
  manager.add_link("alice", "admin", domain="domain1")
  manager.add_link("bob", "admin", domain="domain2")
  assert_true(manager.has_link("alice", "admin", domain="domain1"))
  assert_true(!manager.has_link("alice", "admin", domain="domain2"))
  assert_true(!manager.has_link("alice", "admin"))
  assert_true(manager.get_roles("alice", domain="domain1") == ["admin"])
  assert_true(manager.get_roles("alice", domain="domain2") == [])
}

///|
test "role manager deletes links and clears" {
  let manager = RoleManager::new()
  manager.add_link("alice", "admin")
  assert_true(manager.delete_link("alice", "admin"))
  assert_true(!manager.delete_link("alice", "admin"))
  assert_true(!manager.has_link("alice", "admin"))
  manager.add_link("a", "b")
  manager.clear()
  assert_true(!manager.has_link("a", "b"))
}
