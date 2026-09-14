// role_manager.mbt — Role graphs and role managers (RBAC).
//
// Mirrors Casbin's default role manager semantics:
//
// - `add_link(user, role, domain?)` records that `user` inherits `role`.
// - `has_link(name1, name2, domain?)` is true when both names are equal or
//   when `name2` is reachable from `name1` through at most
//   `max_hierarchy_level` links.
// - `get_roles` / `get_users` return direct relations in insertion order.
// - `get_implicit_roles` / `get_implicit_users` walk the graph
//   breadth-first with a visited set, up to `max_hierarchy_level` levels,
//   excluding the start name, and deduplicated.
//
// Links are grouped by domain; the empty string is the default domain, so a
// two-token role definition (`g = _, _`) is simply a manager whose links all
// live in the default domain. Role-name pattern matching (Casbin's
// `AddMatchingFunc`) is not supported: names compare exactly.
//
// ponytail: node lookup is a linear scan; add a hash index if role graphs
// grow beyond a few thousand nodes.

///|
/// One node of a role graph: direct parents (roles inherited) and direct
/// users (nodes that inherit this one).
pub(all) struct RoleNode {
  name : String
  parents : Array[String]
  users : Array[String]
}

///|
/// The role graph of one domain.
pub(all) struct RoleGraph {
  nodes : Array[RoleNode]
}

///|
/// A role manager holding one graph per domain.
pub(all) struct RoleManager {
  graphs : Array[(String, RoleGraph)]
  max_hierarchy_level : Int
}

///|
/// The maximum hierarchy level used by Casbin's default role managers.
pub let default_max_hierarchy_level : Int = 10

///|
/// Creates an empty role manager.
pub fn RoleManager::new(
  max_hierarchy_level? : Int = default_max_hierarchy_level,
) -> RoleManager {
  { graphs: [], max_hierarchy_level, }
}

///|
/// The configured maximum hierarchy level.
pub fn RoleManager::max_hierarchy_level(self : RoleManager) -> Int {
  self.max_hierarchy_level
}

///|
/// Records that `user` inherits `role` in `domain` (the default domain when
/// omitted).
pub fn RoleManager::add_link(
  self : RoleManager,
  user : String,
  role : String,
  domain? : String = "",
) -> Unit {
  let graph = self.ensure_graph(domain)
  let user_node = graph.nodes[graph.ensure_node(user)]
  if !contains_name(user_node.parents, role) {
    user_node.parents.push(role)
  }
  let role_node = graph.nodes[graph.ensure_node(role)]
  if !contains_name(role_node.users, user) {
    role_node.users.push(user)
  }
}

///|
/// Removes the link `user` -> `role`. Returns `false` when the link does
/// not exist.
pub fn RoleManager::delete_link(
  self : RoleManager,
  user : String,
  role : String,
  domain? : String = "",
) -> Bool {
  let graph = match self.graph(domain) {
    Some(graph) => graph
    None => return false
  }
  let user_index = match graph.find(user) {
    Some(index) => index
    None => return false
  }
  let role_index = match graph.find(role) {
    Some(index) => index
    None => return false
  }
  let user_node = graph.nodes[user_index]
  let had_link = contains_name(user_node.parents, role)
  remove_name(user_node.parents, role)
  remove_name(graph.nodes[role_index].users, user)
  had_link
}

///|
/// Whether `name1` inherits `name2`, directly or transitively.
pub fn RoleManager::has_link(
  self : RoleManager,
  name1 : String,
  name2 : String,
  domain? : String = "",
) -> Bool {
  if name1 == name2 {
    return true
  }
  let graph = match self.graph(domain) {
    Some(graph) => graph
    None => return false
  }
  let mut current : Array[String] = [name1]
  let mut level = self.max_hierarchy_level
  while level >= 0 && current.length() != 0 {
    let next : Array[String] = []
    for node_name in current {
      if node_name == name2 {
        return true
      }
      match graph.find(node_name) {
        Some(index) =>
          for parent in graph.nodes[index].parents {
            if !contains_name(next, parent) {
              next.push(parent)
            }
          }
        None => ()
      }
    }
    current = next
    level -= 1
  }
  false
}

///|
/// The roles `name` directly inherits, in insertion order.
pub fn RoleManager::get_roles(
  self : RoleManager,
  name : String,
  domain? : String = "",
) -> Array[String] {
  match self.graph(domain) {
    Some(graph) =>
      match graph.find(name) {
        Some(index) => copy_names(graph.nodes[index].parents)
        None => []
      }
    None => []
  }
}

///|
/// The nodes directly inheriting `name`, in insertion order.
pub fn RoleManager::get_users(
  self : RoleManager,
  name : String,
  domain? : String = "",
) -> Array[String] {
  match self.graph(domain) {
    Some(graph) =>
      match graph.find(name) {
        Some(index) => copy_names(graph.nodes[index].users)
        None => []
      }
    None => []
  }
}

///|
/// Every role `name` inherits, direct and indirect, deduplicated and in
/// breadth-first order; `name` itself is never included.
pub fn RoleManager::get_implicit_roles(
  self : RoleManager,
  name : String,
  domain? : String = "",
) -> Array[String] {
  self.collect_implicit(name, domain, true)
}

///|
/// Every node that inherits `name`, direct and indirect, deduplicated and
/// in breadth-first order; `name` itself is never included.
pub fn RoleManager::get_implicit_users(
  self : RoleManager,
  name : String,
  domain? : String = "",
) -> Array[String] {
  self.collect_implicit(name, domain, false)
}

///|
/// Removes every link of every domain.
pub fn RoleManager::clear(self : RoleManager) -> Unit {
  self.graphs.clear()
}

///|
fn RoleManager::collect_implicit(
  self : RoleManager,
  name : String,
  domain : String,
  upwards : Bool,
) -> Array[String] {
  let graph = match self.graph(domain) {
    Some(graph) => graph
    None => return []
  }
  let result : Array[String] = []
  let visited : Array[String] = [name]
  let mut current : Array[String] = [name]
  let mut level = 0
  while level < self.max_hierarchy_level && current.length() != 0 {
    let next : Array[String] = []
    for node_name in current {
      let neighbours = match graph.find(node_name) {
        Some(index) =>
          if upwards {
            graph.nodes[index].parents
          } else {
            graph.nodes[index].users
          }
        None => []
      }
      for neighbour in neighbours {
        if !contains_name(visited, neighbour) {
          visited.push(neighbour)
          result.push(neighbour)
          next.push(neighbour)
        }
      }
    }
    current = next
    level += 1
  }
  result
}

///|
fn RoleManager::graph(self : RoleManager, domain : String) -> RoleGraph? {
  for entry in self.graphs {
    if entry.0 == domain {
      return Some(entry.1)
    }
  }
  None
}

///|
fn RoleManager::ensure_graph(self : RoleManager, domain : String) -> RoleGraph {
  for entry in self.graphs {
    if entry.0 == domain {
      return entry.1
    }
  }
  let graph : RoleGraph = { nodes: [], }
  self.graphs.push((domain, graph))
  graph
}

///|
fn RoleGraph::find(self : RoleGraph, name : String) -> Int? {
  for i in 0..<self.nodes.length() {
    if self.nodes[i].name == name {
      return Some(i)
    }
  }
  None
}

///|
fn RoleGraph::ensure_node(self : RoleGraph, name : String) -> Int {
  match self.find(name) {
    Some(index) => index
    None => {
      self.nodes.push({ name, parents: [], users: [], })
      self.nodes.length() - 1
    }
  }
}

///|
fn contains_name(names : Array[String], name : String) -> Bool {
  for existing in names {
    if existing == name {
      return true
    }
  }
  false
}

///|
fn copy_names(names : Array[String]) -> Array[String] {
  let copy : Array[String] = []
  for name in names {
    copy.push(name)
  }
  copy
}

///|
fn remove_name(names : Array[String], name : String) -> Unit {
  let mut index = 0
  while index < names.length() {
    if names[index] == name {
      for i in index..<(names.length() - 1) {
        names[i] = names[i + 1]
      }
      ignore(names.pop())
      return
    }
    index += 1
  }
}
