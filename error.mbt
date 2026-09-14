// error.mbt — Structured error model for moonbit-casbin.
//
// Loading a model, parsing a matcher expression, and enforcement fail for
// different reasons, so errors carry both a category and a position.
// Public APIs return `Result[T, CasbinError]`; internal helpers
// `raise CasbinError` and let it propagate without plumbing. Field access
// is provided by accessor methods because MoonBit suberror payloads are
// positional.
//
// `line()` is the 1-based line in a configuration text for config and
// model errors, and `offset()` is the 0-based character offset in an
// expression for matcher errors; each is `0` when not meaningful.

///|
/// The broad category of a `CasbinError`.
pub(all) enum CasbinErrorKind {
  /// The configuration text is malformed.
  ConfigSyntax
  /// The configuration is well formed but does not describe a valid model.
  ModelValidation
  /// Policy text is malformed.
  PolicySyntax
  /// A matcher expression is malformed.
  MatcherSyntax
  /// A matcher expression cannot be evaluated against the given values.
  MatcherEval
  /// An enforcement request is inconsistent with the model or the policy.
  Enforcement
} derive(Eq, Debug)

///|
/// A structured error returned by every public API and raised internally.
pub(all) suberror CasbinError {
  CasbinError(CasbinErrorKind, String, Int, Int)
}

///|
/// Constructs a `CasbinError` not tied to a position.
pub fn casbin_error(kind : CasbinErrorKind, message : String) -> CasbinError {
  CasbinError(kind, message, 0, 0)
}

///|
/// Constructs a `CasbinError` carrying the 1-based configuration line.
pub fn casbin_error_at(
  kind : CasbinErrorKind,
  line : Int,
  message : String,
) -> CasbinError {
  CasbinError(kind, message, line, 0)
}

///|
/// Constructs a `CasbinError` carrying a 0-based character offset in an
/// expression.
pub fn casbin_error_at_offset(
  kind : CasbinErrorKind,
  offset : Int,
  message : String,
) -> CasbinError {
  CasbinError(kind, message, 0, offset)
}

///|
/// The error category.
pub fn CasbinError::kind(self : CasbinError) -> CasbinErrorKind {
  let CasbinError(kind, _, _, _) = self
  kind
}

///|
/// A short, caller-visible description.
pub fn CasbinError::message(self : CasbinError) -> String {
  let CasbinError(_, message, _, _) = self
  message
}

///|
/// The 1-based configuration line, or `0` when not meaningful.
pub fn CasbinError::line(self : CasbinError) -> Int {
  let CasbinError(_, _, line, _) = self
  line
}

///|
/// The 0-based character offset in an expression, or `0` when not
/// meaningful.
pub fn CasbinError::offset(self : CasbinError) -> Int {
  let CasbinError(_, _, _, offset) = self
  offset
}
