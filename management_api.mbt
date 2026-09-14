// management_api.mbt — Policy and role management APIs.
//
// Mirrors the subset of Casbin's management and RBAC APIs that operate on
// the in-memory store:
//
// - policy rows (`p`): add / remove / has / get / filtered queries;
// - grouping rows (`g`): the same operations, each rebuilding role links
//   when automatic rebuilding is enabled;
// - RBAC: roles for a user, users for a role, implicit roles and users,
//   permissions for a user, implicit permissions, and the cascading deletes
//   (`delete_roles_for_user`, `delete_user`, `delete_role`).
//
// Filtered queries and removals use Casbin's convention: an empty string in
// `values` matches any field. Unlike Casbin, row sizes are validated when a
// row is added, so mistakes surface at the call site instead of at
// enforcement time. `domain` arguments are optional and only meaningful for
// role definitions with three tokens (`g = _, _, _`).

///|
/// Adds a policy row to the `p` section. Returns `false` when the row
/// already exists.
pub fn Enforcer::add_policy(
  self : Enforcer,
  values : Array[String],
) -> Result[Bool, CasbinError] {
  self.add_named_policy("p", values)
}

///|
/// Adds a policy row to the section `key`.
pub fn Enforcer::add_named_policy(
  self : Enforcer,
  key : String,
  values : Array[String],
) -> Result[Bool, CasbinError] {
  Ok(enforcer_add_named_policy_raise(self, key, values)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_add_named_policy_raise(
  enforcer : Enforcer,
  key : String,
  values : Array[String],
) -> Bool raise CasbinError {
  let assertion = match enforcer.model.policy_definition(key) {
    Some(assertion) => assertion
    None =>
      raise casbin_error(
        ModelValidation,
        "policy type \"" + key + "\" is not defined in the model",
      )
  }
  if values.length() != assertion.tokens().length() {
    raise casbin_error(
      Enforcement,
      "invalid policy rule size for \"" +
      key +
      "\": expected " +
      assertion.tokens().length().to_string() +
      ", got " +
      values.length().to_string(),
    )
  }
  enforcer.store.add(key, values)
}

///|
/// Removes a policy row from the `p` section.
pub fn Enforcer::remove_policy(
  self : Enforcer,
  values : Array[String],
) -> Result[Bool, CasbinError] {
  self.remove_named_policy("p", values)
}

///|
/// Removes a policy row from the section `key`.
pub fn Enforcer::remove_named_policy(
  self : Enforcer,
  key : String,
  values : Array[String],
) -> Result[Bool, CasbinError] {
  Ok(self.store.remove(key, values))
}

///|
/// Whether the `p` section contains the row.
pub fn Enforcer::has_policy(
  self : Enforcer,
  values : Array[String],
) -> Result[Bool, CasbinError] {
  Ok(self.store.has("p", values))
}

///|
/// The rows of the `p` section, in insertion order.
pub fn Enforcer::get_policy(self : Enforcer) -> Array[Array[String]] {
  self.store.rows("p")
}

///|
/// The `p` rows whose fields from `field_index` on match `values`; an
/// empty string in `values` matches any field.
pub fn Enforcer::get_filtered_policy(
  self : Enforcer,
  field_index : Int,
  values : Array[String],
) -> Array[Array[String]] {
  self.filtered_rows(self.policy_type, field_index, values)
}

///|
/// Removes every `p` row matched by `values`. Returns whether any row was
/// removed.
pub fn Enforcer::remove_filtered_policy(
  self : Enforcer,
  field_index : Int,
  values : Array[String],
) -> Result[Bool, CasbinError] {
  Ok(self.remove_filtered_rows(self.policy_type, field_index, values))
}

///|
/// Adds a grouping row to the `g` section. Returns `false` when the row
/// already exists.
pub fn Enforcer::add_grouping_policy(
  self : Enforcer,
  values : Array[String],
) -> Result[Bool, CasbinError] {
  Ok(enforcer_add_grouping_policy_raise(self, values)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_add_grouping_policy_raise(
  enforcer : Enforcer,
  values : Array[String],
) -> Bool raise CasbinError {
  let assertion = match enforcer.model.role_definition("g") {
    Some(assertion) => assertion
    None =>
      raise casbin_error(
        ModelValidation,
        "role type \"g\" is not defined in the model",
      )
  }
  if values.length() < assertion.tokens().length() {
    raise casbin_error(
      Enforcement,
      "grouping policy elements do not meet role definition \"g\"",
    )
  }
  let added = enforcer.store.add("g", values)
  if added && enforcer.auto_build_role_links {
    enforcer_build_role_links_raise(enforcer)
  }
  added
}

///|
/// Removes a grouping row from the `g` section.
pub fn Enforcer::remove_grouping_policy(
  self : Enforcer,
  values : Array[String],
) -> Result[Bool, CasbinError] {
  Ok(enforcer_remove_grouping_policy_raise(self, values)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_remove_grouping_policy_raise(
  enforcer : Enforcer,
  values : Array[String],
) -> Bool raise CasbinError {
  let removed = enforcer.store.remove("g", values)
  if removed && enforcer.auto_build_role_links {
    enforcer_build_role_links_raise(enforcer)
  }
  removed
}

///|
/// Whether the `g` section contains the row.
pub fn Enforcer::has_grouping_policy(
  self : Enforcer,
  values : Array[String],
) -> Result[Bool, CasbinError] {
  Ok(self.store.has("g", values))
}

///|
/// The rows of the `g` section, in insertion order.
pub fn Enforcer::get_grouping_policy(self : Enforcer) -> Array[Array[String]] {
  self.store.rows("g")
}

///|
/// The `g` rows matched by `values` (empty string matches any field).
pub fn Enforcer::get_filtered_grouping_policy(
  self : Enforcer,
  field_index : Int,
  values : Array[String],
) -> Array[Array[String]] {
  self.filtered_rows("g", field_index, values)
}

///|
/// Removes every `g` row matched by `values`. Returns whether any row was
/// removed.
pub fn Enforcer::remove_filtered_grouping_policy(
  self : Enforcer,
  field_index : Int,
  values : Array[String],
) -> Result[Bool, CasbinError] {
  Ok(enforcer_remove_filtered_grouping_rows_raise(self, field_index, values)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_remove_filtered_grouping_rows_raise(
  enforcer : Enforcer,
  field_index : Int,
  values : Array[String],
) -> Bool raise CasbinError {
  let removed = enforcer.remove_filtered_rows("g", field_index, values)
  if removed && enforcer.auto_build_role_links {
    enforcer_build_role_links_raise(enforcer)
  }
  removed
}

///|
/// The roles `user` has, directly.
pub fn Enforcer::get_roles_for_user(
  self : Enforcer,
  user : String,
  domain? : String,
) -> Result[Array[String], CasbinError] {
  Ok(enforcer_get_roles_for_user_raise(self, user, domain)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_get_roles_for_user_raise(
  enforcer : Enforcer,
  user : String,
  domain : String?,
) -> Array[String] raise CasbinError {
  let manager = match enforcer.manager_for("g") {
    Some(manager) => manager
    None =>
      raise casbin_error(
        ModelValidation,
        "role manager \"g\" is not initialized",
      )
  }
  manager.get_roles(user, domain=enforcer.manager_domain("g", domain))
}

///|
/// The users of `role`, directly.
pub fn Enforcer::get_users_for_role(
  self : Enforcer,
  role : String,
  domain? : String,
) -> Result[Array[String], CasbinError] {
  Ok(enforcer_get_users_for_role_raise(self, role, domain)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_get_users_for_role_raise(
  enforcer : Enforcer,
  role : String,
  domain : String?,
) -> Array[String] raise CasbinError {
  let manager = match enforcer.manager_for("g") {
    Some(manager) => manager
    None =>
      raise casbin_error(
        ModelValidation,
        "role manager \"g\" is not initialized",
      )
  }
  manager.get_users(role, domain=enforcer.manager_domain("g", domain))
}

///|
/// Whether `user` has the role `role`, directly.
pub fn Enforcer::has_role_for_user(
  self : Enforcer,
  user : String,
  role : String,
  domain? : String,
) -> Result[Bool, CasbinError] {
  Ok(enforcer_has_role_for_user_raise(self, user, role, domain)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_has_role_for_user_raise(
  enforcer : Enforcer,
  user : String,
  role : String,
  domain : String?,
) -> Bool raise CasbinError {
  let roles = enforcer_get_roles_for_user_raise(enforcer, user, domain)
  contains_name(roles, role)
}

///|
/// Adds `role` to `user`, optionally within `domain`.
pub fn Enforcer::add_role_for_user(
  self : Enforcer,
  user : String,
  role : String,
  domain? : String,
) -> Result[Bool, CasbinError] {
  let values = match domain {
    None => [user, role]
    Some(value) => [user, role, value]
  }
  self.add_grouping_policy(values)
}

///|
/// Removes `role` from `user`.
pub fn Enforcer::delete_role_for_user(
  self : Enforcer,
  user : String,
  role : String,
  domain? : String,
) -> Result[Bool, CasbinError] {
  let values = match domain {
    None => [user, role]
    Some(value) => [user, role, value]
  }
  self.remove_grouping_policy(values)
}

///|
/// Removes all roles of `user`, optionally within `domain`.
pub fn Enforcer::delete_roles_for_user(
  self : Enforcer,
  user : String,
  domain? : String,
) -> Result[Bool, CasbinError] {
  Ok(enforcer_delete_roles_for_user_raise(self, user, domain)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_delete_roles_for_user_raise(
  enforcer : Enforcer,
  user : String,
  domain : String?,
) -> Bool raise CasbinError {
  let values = match domain {
    None => [user]
    Some(value) => [user, "", value]
  }
  enforcer_remove_filtered_grouping_rows_raise(enforcer, 0, values)
}

///|
/// Removes the user: every grouping row with the user as first field and
/// every policy row with the user as subject.
pub fn Enforcer::delete_user(
  self : Enforcer,
  user : String,
) -> Result[Bool, CasbinError] {
  Ok(enforcer_delete_user_raise(self, user)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_delete_user_raise(
  enforcer : Enforcer,
  user : String,
) -> Bool raise CasbinError {
  let grouping_removed = enforcer_remove_filtered_grouping_rows_raise(
    enforcer,
    0,
    [user],
  )
  let subject_index = match enforcer.field_index("sub") {
    Some(index) => index
    None => 0
  }
  let policy_removed = enforcer.remove_filtered_rows(
    enforcer.policy_type,
    subject_index,
    [user],
  )
  grouping_removed || policy_removed
}

///|
/// Removes the role: grouping rows that reference it in either position and
/// policy rows that use it as subject.
pub fn Enforcer::delete_role(
  self : Enforcer,
  role : String,
) -> Result[Bool, CasbinError] {
  Ok(enforcer_delete_role_raise(self, role)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_delete_role_raise(
  enforcer : Enforcer,
  role : String,
) -> Bool raise CasbinError {
  let as_user = enforcer_remove_filtered_grouping_rows_raise(enforcer, 0, [role])
  let as_role = enforcer_remove_filtered_grouping_rows_raise(enforcer, 1, [role])
  let subject_index = match enforcer.field_index("sub") {
    Some(index) => index
    None => 0
  }
  let policy_removed = enforcer.remove_filtered_rows(
    enforcer.policy_type,
    subject_index,
    [role],
  )
  as_user || as_role || policy_removed
}

///|
/// Every role `user` has, direct and indirect, across all role managers.
pub fn Enforcer::get_implicit_roles_for_user(
  self : Enforcer,
  user : String,
  domain? : String,
) -> Array[String] {
  enforcer_implicit_roles_for_user(self, user, domain)
}

///|
fn enforcer_implicit_roles_for_user(
  enforcer : Enforcer,
  user : String,
  domain : String?,
) -> Array[String] {
  let result : Array[String] = []
  for entry in enforcer.role_managers {
    let manager = entry.1
    let manager_domain = enforcer.manager_domain(entry.0, domain)
    for role in manager.get_implicit_roles(user, domain=manager_domain) {
      if !contains_name(result, role) {
        result.push(role)
      }
    }
  }
  result
}

///|
/// Every user of `role`, direct and indirect, across all role managers.
pub fn Enforcer::get_implicit_users_for_role(
  self : Enforcer,
  role : String,
  domain? : String,
) -> Array[String] {
  let result : Array[String] = []
  for entry in self.role_managers {
    let manager = entry.1
    let manager_domain = self.manager_domain(entry.0, domain)
    for user in manager.get_implicit_users(role, domain=manager_domain) {
      if !contains_name(result, user) {
        result.push(user)
      }
    }
  }
  result
}

///|
/// The policy rows whose subject is `user` (and whose domain field is
/// `domain`, when given).
pub fn Enforcer::get_permissions_for_user(
  self : Enforcer,
  user : String,
  domain? : String,
) -> Result[Array[Array[String]], CasbinError] {
  Ok(enforcer_get_permissions_for_user_raise(self, user, domain)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_get_permissions_for_user_raise(
  enforcer : Enforcer,
  user : String,
  domain : String?,
) -> Array[Array[String]] raise CasbinError {
  let arguments : Array[String] = []
  for _i in 0..<enforcer.policy_tokens.length() {
    arguments.push("")
  }
  let subject_index = match enforcer.field_index("sub") {
    Some(index) => index
    None => 0
  }
  arguments[subject_index] = user
  match domain {
    Some(value) =>
      match enforcer.field_index("dom") {
        Some(index) => arguments[index] = value
        None =>
          raise casbin_error(
            ModelValidation,
            "the policy definition has no domain field",
          )
      }
    None => ()
  }
  enforcer.filtered_rows(enforcer.policy_type, 0, arguments)
}

///|
/// The policy rows whose subject is `user` or one of the user's implicit
/// roles. With a domain, only rows for that domain are returned.
pub fn Enforcer::get_implicit_permissions_for_user(
  self : Enforcer,
  user : String,
  domain? : String,
) -> Result[Array[Array[String]], CasbinError] {
  Ok(enforcer_get_implicit_permissions_for_user_raise(self, user, domain)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_get_implicit_permissions_for_user_raise(
  enforcer : Enforcer,
  user : String,
  domain : String?,
) -> Array[Array[String]] raise CasbinError {
  let allowed : Array[String] = [user]
  for role in enforcer_implicit_roles_for_user(enforcer, user, domain) {
    allowed.push(role)
  }
  let subject_index = match enforcer.field_index("sub") {
    Some(index) => index
    None => 0
  }
  let result : Array[Array[String]] = []
  for row in enforcer.store.rows(enforcer.policy_type) {
    if subject_index >= row.length() ||
      !contains_name(allowed, row[subject_index]) {
      continue
    }
    match domain {
      None => result.push(row)
      Some(value) =>
        match enforcer.field_index("dom") {
          Some(domain_index) =>
            if domain_index < row.length() && row[domain_index] == value {
              result.push(row)
            }
          None =>
            raise casbin_error(
              ModelValidation,
              "the policy definition has no domain field",
            )
        }
    }
  }
  result
}

///|
/// Removes every policy row whose subject is `user`.
pub fn Enforcer::delete_permissions_for_user(
  self : Enforcer,
  user : String,
) -> Result[Bool, CasbinError] {
  let subject_index = match self.field_index("sub") {
    Some(index) => index
    None => 0
  }
  self.remove_filtered_policy(subject_index, [user])
}

///|
fn Enforcer::manager_for(self : Enforcer, key : String) -> RoleManager? {
  for entry in self.role_managers {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
/// The domain to use for a manager: definitions with three tokens are
/// domain-aware, everything else lives in the default domain.
fn Enforcer::manager_domain(
  self : Enforcer,
  key : String,
  domain : String?,
) -> String {
  let token_count = match self.model.role_definition(key) {
    Some(assertion) => assertion.tokens().length()
    None => 2
  }
  if token_count >= 3 {
    match domain {
      Some(value) => value
      None => ""
    }
  } else {
    ""
  }
}

///|
/// The index of the policy token `p_<field>`, if the policy definition has
/// it (mirrors Casbin's `GetFieldIndex` fallback).
fn Enforcer::field_index(self : Enforcer, field : String) -> Int? {
  find_token(self.policy_tokens, self.policy_type + "_" + field)
}

///|
/// The rows of `key` whose fields from `field_index` on match `values`; an
/// empty string in `values` matches any field.
fn Enforcer::filtered_rows(
  self : Enforcer,
  key : String,
  field_index : Int,
  values : Array[String],
) -> Array[Array[String]] {
  let result : Array[Array[String]] = []
  for row in self.store.rows(key) {
    let mut matched = true
    for i in 0..<values.length() {
      if values[i] != "" {
        if field_index + i >= row.length() || row[field_index + i] != values[i] {
          matched = false
          break
        }
      }
    }
    if matched {
      result.push(row)
    }
  }
  result
}

///|
/// Removes the rows of `key` matched by `values`. Returns whether any row
/// was removed.
fn Enforcer::remove_filtered_rows(
  self : Enforcer,
  key : String,
  field_index : Int,
  values : Array[String],
) -> Bool {
  let rows = self.filtered_rows(key, field_index, values)
  let mut removed = false
  for row in rows {
    if self.store.remove(key, row) {
      removed = true
    }
  }
  removed
}
