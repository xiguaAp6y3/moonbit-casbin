// model.mbt — Casbin model loading.
//
// A model file declares up to five sections: request_definition,
// policy_definition, role_definition (optional), policy_effect, and
// matchers. Definition entries carry comma-separated tokens naming the
// positional arguments of a request or policy; expression entries keep
// their raw text for evaluation.
//
// Request, policy, effect, and matcher sections are required;
// role_definition is optional. Unknown sections and invalid tokens are
// rejected so that typos surface at load time rather than at
// enforcement time.

///|
/// One assertion in the model: a definition (`r`, `p`, `g`) or an
/// expression (`e`, `m`).
pub(all) struct Assertion {
  key : String
  value : String
  tokens : Array[String]
} derive(Eq, Debug)

///|
/// The assertion key, for example `r`, `p`, `g`, `e`, or `m`.
pub fn Assertion::key(self : Assertion) -> String {
  self.key
}

///|
/// The raw value as written in the configuration.
pub fn Assertion::value(self : Assertion) -> String {
  self.value
}

///|
/// The comma-separated tokens of a definition assertion, trimmed and in
/// declaration order; empty for expression assertions.
pub fn Assertion::tokens(self : Assertion) -> Array[String] {
  self.tokens
}

///|
/// Loaded Casbin model: request, policy, and role definitions, the
/// policy effect, and matcher expressions.
pub(all) struct Model {
  request : Array[Assertion]
  policy : Array[Assertion]
  role : Array[Assertion]
  effect : Assertion?
  matcher : Array[Assertion]
} derive(Debug)

///|
/// Builds a model from parsed configuration.
///
/// Returns `Err(CasbinErrorKind::ModelValidation)` for a semantically
/// invalid model.
pub fn Model::from_config(config : Config) -> Result[Model, CasbinError] {
  Ok(model_from_config_raise(config)) catch {
    error => Err(error)
  }
}

///|
/// Internal: builds a model, raising on the first violation.
fn model_from_config_raise(config : Config) -> Model raise CasbinError {
  for name in config.section_names() {
    if !is_known_section(name) {
      raise casbin_error(ModelValidation, "unknown section [" + name + "]")
    }
  }
  let request = load_definition(config, "request_definition", "r")
  let policy = load_definition(config, "policy_definition", "p")
  let role = load_definition(config, "role_definition", "g")
  let effect = load_effect(config)
  let matcher = load_matcher(config)
  if request.is_empty() {
    raise casbin_error(
      ModelValidation,
      "missing or empty [request_definition] section",
    )
  }
  if policy.is_empty() {
    raise casbin_error(
      ModelValidation,
      "missing or empty [policy_definition] section",
    )
  }
  if matcher.is_empty() {
    raise casbin_error(ModelValidation, "missing or empty [matchers] section")
  }
  { request, policy, role, effect, matcher, }
}

///|
/// The request definition with the given key, for example `r`.
pub fn Model::request_definition(self : Model, key : String) -> Assertion? {
  find_assertion(self.request, key)
}

///|
/// The policy definition with the given key, for example `p` or `p2`.
pub fn Model::policy_definition(self : Model, key : String) -> Assertion? {
  find_assertion(self.policy, key)
}

///|
/// The role definition with the given key, for example `g` or `g2`.
pub fn Model::role_definition(self : Model, key : String) -> Assertion? {
  find_assertion(self.role, key)
}

///|
/// The policy effect assertion.
pub fn Model::policy_effect(self : Model) -> Assertion? {
  self.effect
}

///|
/// The matcher with the given key, for example `m` or `m2`.
pub fn Model::matcher(self : Model, key : String) -> Assertion? {
  find_assertion(self.matcher, key)
}

///|
fn find_assertion(assertions : Array[Assertion], key : String) -> Assertion? {
  for assertion in assertions {
    if assertion.key == key {
      return Some(assertion)
    }
  }
  None
}

///|
fn is_known_section(name : String) -> Bool {
  match name {
    "request_definition"
    | "policy_definition"
    | "role_definition"
    | "policy_effect"
    | "matchers" => true
    _ => false
  }
}

///|
fn load_definition(
  config : Config,
  section : String,
  prefix : String,
) -> Array[Assertion] raise CasbinError {
  let assertions : Array[Assertion] = []
  for entry in config.entries(section) {
    if !entry.key.has_prefix(prefix) {
      raise casbin_error(
        ModelValidation,
        "[" +
        section +
        "] key \"" +
        entry.key +
        "\" must start with \"" +
        prefix +
        "\"",
      )
    }
    let tokens = split_tokens(entry.value)
    assertions.push({ key: entry.key, value: entry.value, tokens, })
  }
  assertions
}

///|
fn load_effect(config : Config) -> Assertion? raise CasbinError {
  let entries = config.entries("policy_effect")
  if entries.is_empty() {
    raise casbin_error(
      ModelValidation,
      "missing or empty [policy_effect] section",
    )
  }
  if entries.length() > 1 {
    raise casbin_error(
      ModelValidation,
      "[policy_effect] must contain exactly one entry",
    )
  }
  let entry = entries[0]
  if entry.value.is_empty() {
    raise casbin_error(
      ModelValidation,
      "[policy_effect] entry \"" + entry.key + "\" is empty",
    )
  }
  Some({ key: entry.key, value: entry.value, tokens: [], })
}

///|
fn load_matcher(config : Config) -> Array[Assertion] raise CasbinError {
  let assertions : Array[Assertion] = []
  for entry in config.entries("matchers") {
    if !is_identifier(entry.key) {
      raise casbin_error(
        ModelValidation,
        "[matchers] invalid key \"" + entry.key + "\"",
      )
    }
    if entry.value.is_empty() {
      raise casbin_error(
        ModelValidation,
        "[matchers] entry \"" + entry.key + "\" is empty",
      )
    }
    assertions.push({ key: entry.key, value: entry.value, tokens: [], })
  }
  assertions
}

///|
fn split_tokens(value : String) -> Array[String] raise CasbinError {
  let tokens : Array[String] = []
  for raw in value.split(",") {
    let token = raw.trim()
    if token.is_empty() {
      raise casbin_error(ModelValidation, "empty token in \"" + value + "\"")
    }
    if !is_identifier(token) {
      raise casbin_error(
        ModelValidation,
        "invalid token \"" + token.to_owned() + "\"",
      )
    }
    tokens.push(token.to_owned())
  }
  if tokens.is_empty() {
    raise casbin_error(ModelValidation, "empty definition value")
  }
  tokens
}

///|
fn is_identifier(text : StringView) -> Bool {
  if text.is_empty() {
    return false
  }
  let mut index = 0
  for ch in text.iter() {
    let valid = if index == 0 {
      ch.is_ascii_alphabetic() || ch == '_'
    } else {
      ch.is_ascii_digit() || ch.is_ascii_alphabetic() || ch == '_'
    }
    if !valid {
      return false
    }
    index += 1
  }
  true
}
