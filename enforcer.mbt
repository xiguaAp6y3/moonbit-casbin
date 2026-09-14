// enforcer.mbt — The enforcement core: model + policy + request -> decision.
//
// `Enforcer::new` preprocesses the matcher and effect expressions, parses
// the matcher once, and resolves the token names (`r_sub`, `p_obj`, ...).
// `load_policy_from_text` validates policy lines against the model and adds
// them to the in-memory store. `enforce` follows Casbin's algorithm:
//
// 1. The request must match the request definition token count.
// 2. When the policy has rows and the matcher references the policy (`p_`),
//    the matcher is evaluated once per row; each row's `eft` column maps to
//    allow / deny / indeterminate, and `merge_effects` decides whether to
//    stop early. A row without an `eft` column counts as allow.
// 3. Otherwise the matcher is evaluated once with no policy values; a truthy
//    result contributes an allow effect, and the effect expression merges
//    that single result.
//
// The final decision is `effect == Allow`. Role definitions (`g`, `g2`) get
// one role manager each; the manager is injected into the function registry
// under the definition key, and role links are rebuilt from the grouping
// policy after every load or grouping-policy change (see `build_role_links`
// and `enable_auto_build_role_links`).

///|
/// An enforcer bound to one model and one in-memory policy store.
pub(all) struct Enforcer {
  model : Model
  store : PolicyStore
  effect : EffectExpression
  functions : FunctionRegistry
  matcher : Expr
  uses_policy : Bool
  request_tokens : Array[String]
  policy_type : String
  policy_tokens : Array[String]
  eft_index : Int?
  role_managers : Array[(String, RoleManager)]
  mut auto_build_role_links : Bool
}

///|
/// Builds an enforcer from a loaded model.
///
/// Returns `Err(ModelValidation)` for an unsupported policy effect or a
/// missing matcher, and `Err(MatcherSyntax)` when the matcher does not
/// parse.
pub fn Enforcer::new(model : Model) -> Result[Enforcer, CasbinError] {
  Ok(enforcer_new_raise(model)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_new_raise(model : Model) -> Enforcer raise CasbinError {
  let matcher_assertion = match model.matcher("m") {
    Some(assertion) => assertion
    None => raise casbin_error(ModelValidation, "missing matcher \"m\"")
  }
  let matcher_source = preprocess_expression(matcher_assertion.value())
  let matcher = match parse_matcher(matcher_source) {
    Ok(expression) => expression
    Err(error) => raise error
  }
  let effect_assertion = match model.policy_effect() {
    Some(assertion) => assertion
    None => raise casbin_error(ModelValidation, "missing policy effect")
  }
  let effect_text = preprocess_expression(effect_assertion.value())
  let effect = match EffectExpression::parse(effect_text) {
    Some(effect) => effect
    None =>
      raise casbin_error(
        ModelValidation,
        "unsupported policy effect \"" + effect_text + "\"",
      )
  }
  let request_assertion = match model.request_definition("r") {
    Some(assertion) => assertion
    None =>
      raise casbin_error(ModelValidation, "missing request definition \"r\"")
  }
  let policy_assertion = match model.policy_definition("p") {
    Some(assertion) => assertion
    None =>
      raise casbin_error(ModelValidation, "missing policy definition \"p\"")
  }
  let request_tokens = qualified_tokens(request_assertion)
  let policy_tokens = qualified_tokens(policy_assertion)
  let eft_index = find_token(policy_tokens, "p_eft")
  let functions = builtin_functions()
  let role_managers : Array[(String, RoleManager)] = []
  for assertion in model.role {
    let manager = RoleManager::new()
    functions.add(assertion.key(), make_g_function(manager))
    role_managers.push((assertion.key(), manager))
  }
  {
    model,
    store: PolicyStore::new(),
    effect,
    functions,
    matcher,
    uses_policy: matcher_source.contains("p_"),
    request_tokens,
    policy_type: "p",
    policy_tokens,
    eft_index,
    role_managers,
    auto_build_role_links: true,
  }
}

///|
/// The model this enforcer was built from.
pub fn Enforcer::model(self : Enforcer) -> Model {
  self.model
}

///|
/// The in-memory policy store.
pub fn Enforcer::policy(self : Enforcer) -> PolicyStore {
  self.store
}

///|
/// Registers a custom matcher function, replacing an existing one.
pub fn Enforcer::add_function(
  self : Enforcer,
  name : String,
  function : (Array[Value]) -> Value raise CasbinError,
) -> Unit {
  self.functions.add(name, function)
}

///|
/// Rebuilds every role graph from the grouping policy, mirroring Casbin's
/// `BuildRoleLinks`. Called automatically after policy loads and grouping
/// policy changes unless automatic rebuilding is disabled.
pub fn Enforcer::build_role_links(self : Enforcer) -> Result[Unit, CasbinError] {
  Ok(enforcer_build_role_links_raise(self)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_build_role_links_raise(
  enforcer : Enforcer,
) -> Unit raise CasbinError {
  for entry in enforcer.role_managers {
    let key = entry.0
    let manager = entry.1
    manager.clear()
    let token_count = match enforcer.model.role_definition(key) {
      Some(assertion) => assertion.tokens().length()
      None => 0
    }
    if token_count < 2 {
      raise casbin_error(
        ModelValidation,
        "role definition \"" + key + "\" must have at least 2 tokens",
      )
    }
    for row in enforcer.store.rows(key) {
      if row.length() < token_count {
        raise casbin_error(
          Enforcement,
          "grouping policy elements do not meet role definition \"" + key + "\"",
        )
      }
      if token_count >= 3 {
        manager.add_link(row[0], row[1], domain=row[2])
      } else {
        manager.add_link(row[0], row[1])
      }
    }
  }
}

///|
/// Enables or disables automatic role-link rebuilding. Enabled by default,
/// like Casbin.
pub fn Enforcer::enable_auto_build_role_links(
  self : Enforcer,
  enabled : Bool,
) -> Unit {
  self.auto_build_role_links = enabled
}

///|
/// Whether automatic role-link rebuilding is enabled.
pub fn Enforcer::is_auto_build_role_links(self : Enforcer) -> Bool {
  self.auto_build_role_links
}

///|
/// Builds the `g`-style matcher function for one role manager: two
/// arguments test `has_link`, three arguments additionally pass the domain.
/// Like Casbin, a failed lookup is `false`; a wrong argument count or a
/// non-string argument raises `MatcherEval`.
fn make_g_function(
  manager : RoleManager,
) -> (Array[Value]) -> Value raise CasbinError {
  arguments => {
    let count = arguments.length()
    if count != 2 && count != 3 {
      raise casbin_error(
        MatcherEval,
        "g: expected 2 or 3 arguments, but got " + count.to_string(),
      )
    }
    let name1 = match arguments[0] {
      Value::String(name) => name
      other =>
        raise casbin_error(
          MatcherEval,
          "g: argument must be a string, got " + other.type_name(),
        )
    }
    let name2 = match arguments[1] {
      Value::String(name) => name
      other =>
        raise casbin_error(
          MatcherEval,
          "g: argument must be a string, got " + other.type_name(),
        )
    }
    let linked = if count == 2 {
      manager.has_link(name1, name2)
    } else {
      let domain = match arguments[2] {
        Value::String(name) => name
        other =>
          raise casbin_error(
            MatcherEval,
            "g: argument must be a string, got " + other.type_name(),
          )
      }
      manager.has_link(name1, name2, domain~)
    }
    Value::Bool(linked)
  }
}

///|
/// Loads policy lines from text, validating each against the model.
///
/// `p` sections require every row to have exactly the token count of the
/// policy definition; `g` sections require at least the token count.
/// Duplicate rows are skipped. Returns `Err(ModelValidation)` for a policy
/// type the model does not define, and `Err(Enforcement)` for a row of the
/// wrong size.
pub fn Enforcer::load_policy_from_text(
  self : Enforcer,
  text : String,
) -> Result[Unit, CasbinError] {
  Ok(enforcer_load_policy_raise(self, text)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_load_policy_raise(
  enforcer : Enforcer,
  text : String,
) -> Unit raise CasbinError {
  let lines = match parse_policy_text(text) {
    Ok(lines) => lines
    Err(error) => raise error
  }
  for line in lines {
    let key = line.key()
    let row = line.values()
    if key.has_prefix("p") {
      let assertion = match enforcer.model.policy_definition(key) {
        Some(assertion) => assertion
        None =>
          raise casbin_error(
            ModelValidation,
            "policy type \"" + key + "\" is not defined in the model",
          )
      }
      if row.length() != assertion.tokens().length() {
        raise casbin_error(
          Enforcement,
          "invalid policy rule size for \"" +
          key +
          "\": expected " +
          assertion.tokens().length().to_string() +
          ", got " +
          row.length().to_string(),
        )
      }
    } else if key.has_prefix("g") {
      let assertion = match enforcer.model.role_definition(key) {
        Some(assertion) => assertion
        None =>
          raise casbin_error(
            ModelValidation,
            "policy type \"" + key + "\" is not defined in the model",
          )
      }
      if row.length() < assertion.tokens().length() {
        raise casbin_error(
          Enforcement,
          "invalid policy rule size for \"" +
          key +
          "\": expected at least " +
          assertion.tokens().length().to_string() +
          ", got " +
          row.length().to_string(),
        )
      }
    } else {
      raise casbin_error(PolicySyntax, "invalid policy type \"" + key + "\"")
    }
    ignore(enforcer.store.add(key, row))
  }
  if enforcer.auto_build_role_links {
    enforcer_build_role_links_raise(enforcer)
  }
}

///|
/// Decides whether `request` is allowed.
///
/// The request must provide one value per request definition token.
pub fn Enforcer::enforce(
  self : Enforcer,
  request : Array[String],
) -> Result[Bool, CasbinError] {
  Ok(enforcer_enforce_raise(self, request)) catch {
    error => Err(error)
  }
}

///|
fn enforcer_enforce_raise(
  enforcer : Enforcer,
  request : Array[String],
) -> Bool raise CasbinError {
  if request.length() != enforcer.request_tokens.length() {
    raise casbin_error(
      Enforcement,
      "invalid request size: expected " +
      enforcer.request_tokens.length().to_string() +
      ", got " +
      request.length().to_string(),
    )
  }
  let rows = enforcer.store.rows(enforcer.policy_type)
  let mut effect = Indeterminate
  if rows.length() != 0 && enforcer.uses_policy {
    let effects : Array[Effect] = []
    let matches : Array[Bool] = []
    for _i in 0..<rows.length() {
      effects.push(Indeterminate)
      matches.push(false)
    }
    let mut index = 0
    while index < rows.length() {
      let row = rows[index]
      if row.length() != enforcer.policy_tokens.length() {
        raise casbin_error(
          Enforcement,
          "invalid policy size: expected " +
          enforcer.policy_tokens.length().to_string() +
          ", got " +
          row.length().to_string(),
        )
      }
      matches[index] = enforcer.row_matches(request, row)
      effects[index] = enforcer.row_effect(row)
      let (merged, _explain_index) = merge_effects(
        enforcer.effect,
        effects,
        matches,
        index,
        rows.length(),
      )
      effect = merged
      if effect != Indeterminate {
        break
      }
      index += 1
    }
  } else {
    let value = enforcer.eval_matcher(request, [])
    let matched = match value {
      Bool(flag) => flag
      other =>
        raise casbin_error(
          Enforcement,
          "matcher result should be bool, got " + other.type_name(),
        )
    }
    let effects : Array[Effect] = [if matched { Allow } else { Indeterminate }]
    let matches : Array[Bool] = [true]
    let (merged, _explain_index) = merge_effects(
      enforcer.effect,
      effects,
      matches,
      0,
      1,
    )
    effect = merged
  }
  effect == Allow
}

///|
/// Evaluates the matcher for one policy row; a numeric result counts as
/// matched when non-zero, like Casbin.
fn Enforcer::row_matches(
  self : Enforcer,
  request : Array[String],
  row : Array[String],
) -> Bool raise CasbinError {
  let value = self.eval_matcher(request, row)
  match value {
    Bool(flag) => flag
    Int(number) => number != 0
    Double(number) => number != 0.0
    other =>
      raise casbin_error(
        Enforcement,
        "matcher result should be bool, int or float, got " + other.type_name(),
      )
  }
}

///|
/// The effect contributed by one policy row: its `eft` value when the
/// policy definition has an `eft` token, otherwise allow.
fn Enforcer::row_effect(self : Enforcer, row : Array[String]) -> Effect {
  match self.eft_index {
    None => Allow
    Some(index) =>
      if index >= row.length() {
        Indeterminate
      } else {
        match row[index] {
          "allow" => Allow
          "deny" => Deny
          _ => Indeterminate
        }
      }
  }
}

///|
/// Evaluates the matcher with the request and one policy row bound to the
/// `r_` / `p_` tokens.
fn Enforcer::eval_matcher(
  self : Enforcer,
  request : Array[String],
  row : Array[String],
) -> Value raise CasbinError {
  let lookup = (name : String) => {
    if name.has_prefix("r_") {
      match find_token(self.request_tokens, name) {
        Some(index) => Some(Value::String(request[index]))
        None => None
      }
    } else if name.has_prefix("p_") {
      match find_token(self.policy_tokens, name) {
        Some(index) =>
          if index < row.length() {
            Some(Value::String(row[index]))
          } else {
            Some(Value::String(""))
          }
        None => None
      }
    } else {
      None
    }
  }
  match self.matcher.eval(lookup, self.functions) {
    Ok(value) => value
    Err(error) => raise error
  }
}

///|
/// The full token names of a definition assertion, for example
/// `["r_sub", "r_obj", "r_act"]`, matching Casbin's `AddDef`.
fn qualified_tokens(assertion : Assertion) -> Array[String] {
  let tokens : Array[String] = []
  for token in assertion.tokens() {
    tokens.push(assertion.key() + "_" + token)
  }
  tokens
}

///|
fn find_token(tokens : Array[String], name : String) -> Int? {
  for i in 0..<tokens.length() {
    if tokens[i] == name {
      return Some(i)
    }
  }
  None
}
