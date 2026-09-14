// functions.mbt — Matcher function registry and built-in functions.
//
// Casbin resolves function calls in matchers through a per-enforcer
// function map. This module provides the registry plus the built-ins that
// need no external dependency: `keyMatch` and `keyGet`. The regex-,
// glob-, and IP-based built-ins (`regexMatch`, `keyMatch2`..`keyMatch5`,
// `globMatch`, `ipMatch`) arrive with their own modules.
//
// Arguments are validated strictly: a wrong argument count or a
// non-string argument raises `MatcherEval`, matching the behavior of
// Casbin's built-in operator wrappers.

///|
/// A registry of matcher functions keyed by name.
pub(all) struct FunctionRegistry {
  entries : Array[(String, (Array[Value]) -> Value raise CasbinError)]
}

///|
/// Creates an empty registry.
pub fn FunctionRegistry::new() -> FunctionRegistry {
  { entries: [], }
}

///|
/// Registers `function` under `name`, replacing an existing entry.
pub fn FunctionRegistry::add(
  self : FunctionRegistry,
  name : String,
  function : (Array[Value]) -> Value raise CasbinError,
) -> Unit {
  for i in 0..<self.entries.length() {
    if self.entries[i].0 == name {
      self.entries[i] = (name, function)
      return
    }
  }
  self.entries.push((name, function))
}

///|
/// The function registered under `name`, if any.
pub fn FunctionRegistry::get(
  self : FunctionRegistry,
  name : String,
) -> ((Array[Value]) -> Value raise CasbinError)? {
  for entry in self.entries {
    if entry.0 == name {
      return Some(entry.1)
    }
  }
  None
}

///|
/// A registry containing the dependency-free built-in functions.
pub fn builtin_functions() -> FunctionRegistry {
  let registry = FunctionRegistry::new()
  registry.add("keyMatch", key_match_function)
  registry.add("keyGet", key_get_function)
  registry
}

///|
fn key_match_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2) = two_string_arguments("keyMatch", arguments)
  Value::Bool(key_match(key1, key2))
}

///|
fn key_get_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2) = two_string_arguments("keyGet", arguments)
  Value::String(key_get(key1, key2))
}

///|
/// Casbin's `keyMatch`: `/foo/bar` matches `/foo/*`; a pattern without
/// `*` must equal the key.
fn key_match(key1 : String, key2 : String) -> Bool {
  match key2.find("*") {
    None => key1 == key2
    Some(index) =>
      if key1.length() > index {
        key1[:index] == key2[:index]
      } else {
        key1[:] == key2[:index]
      }
  }
}

///|
/// Casbin's `keyGet`: the part of `key1` after the prefix of `key2` that
/// precedes its first `*`, or the empty string when there is no `*` or
/// the prefix does not match.
fn key_get(key1 : String, key2 : String) -> String {
  match key2.find("*") {
    None => ""
    Some(index) =>
      if key1.length() > index && key1[:index] == key2[:index] {
        key1[index:].to_owned()
      } else {
        ""
      }
  }
}

///|
fn two_string_arguments(
  name : String,
  arguments : Array[Value],
) -> (String, String) raise CasbinError {
  if arguments.length() != 2 {
    raise casbin_error(
      MatcherEval,
      name + ": expected 2 arguments, but got " + arguments.length().to_string(),
    )
  }
  let first = match arguments[0] {
    Value::String(value) => value
    other =>
      raise casbin_error(
        MatcherEval,
        name + ": argument must be a string, got " + other.type_name(),
      )
  }
  let second = match arguments[1] {
    Value::String(value) => value
    other =>
      raise casbin_error(
        MatcherEval,
        name + ": argument must be a string, got " + other.type_name(),
      )
  }
  (first, second)
}
