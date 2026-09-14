// error.mbt — Structured error model for moonbit-casbin.
//
// Model loading can fail for two distinct reasons: the configuration text
// is malformed, or the configuration is syntactically valid but does not
// describe a usable model. Public APIs return `Result[T, CasbinError]`;
// internal helpers `raise CasbinError` and let it propagate without
// plumbing.
//
// `line()` is the 1-based line in the configuration text for syntax
// errors, and 0 when no line is meaningful. Field access is provided by
// accessor methods because MoonBit suberror payloads are positional.

///|
/// The broad category of a `CasbinError`.
pub(all) enum CasbinErrorKind {
  /// The configuration text is malformed.
  ConfigSyntax
  /// The configuration is well formed but does not describe a valid model.
  ModelValidation
} derive(Eq, Debug)

///|
/// A structured error returned by every public API and raised internally.
pub(all) suberror CasbinError {
  CasbinError(CasbinErrorKind, String, Int)
}

///|
/// Constructs a `CasbinError` not tied to a specific line.
pub fn casbin_error(kind : CasbinErrorKind, message : String) -> CasbinError {
  CasbinError(kind, message, 0)
}

///|
/// Constructs a `CasbinError` carrying the 1-based configuration line.
pub fn casbin_error_at(
  kind : CasbinErrorKind,
  line : Int,
  message : String,
) -> CasbinError {
  CasbinError(kind, message, line)
}

///|
/// The error category.
pub fn CasbinError::kind(self : CasbinError) -> CasbinErrorKind {
  let CasbinError(kind, _, _) = self
  kind
}

///|
/// A short, caller-visible description.
pub fn CasbinError::message(self : CasbinError) -> String {
  let CasbinError(_, message, _) = self
  message
}

///|
/// The 1-based configuration line, or `0` when not meaningful.
pub fn CasbinError::line(self : CasbinError) -> Int {
  let CasbinError(_, _, line) = self
  line
}
