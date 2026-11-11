// expr.mbt — Abstract syntax tree for matcher expressions.
//
// The grammar follows the subset of govaluate that Casbin models actually
// use: literals, identifiers (the preprocessed `r_sub` / `p_obj` names),
// function calls, `in` with parenthesized or bracketed lists, field
// access, unary `!` and `-`, and binary operators with short-circuit
// logical evaluation. Ternary, bitwise, regex-match, and null-coalescing
// operators are intentionally not supported; see the README.

///|
/// A matcher expression node.
#derive(Eq, Debug)
pub(all) enum Expr {
  Literal(Value)
  Ident(String)
  /// A parenthesized list `('a', 'b')` or a bracketed list `['a', 'b']`.
  List(Array[Expr])
  /// Field access `target.field`.
  Member(Expr, String)
  Unary(UnaryOp, Expr)
  Binary(BinaryOp, Expr, Expr)
  Call(String, Array[Expr])
}

// E0079: derived trait methods stay reachable with dot syntax.

///|
pub extend Expr with Eq::{not_equal, equal}

///|
pub extend Expr with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Unary operators.
#derive(Eq, Debug)
pub(all) enum UnaryOp {
  /// Logical negation `!`.
  Not
  /// Arithmetic negation `-`.
  Neg
}

// E0079: derived trait methods stay reachable with dot syntax.

///|
pub extend UnaryOp with Eq::{not_equal, equal}

///|
pub extend UnaryOp with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Binary operators, lowest precedence first.
#derive(Eq, Debug)
pub(all) enum BinaryOp {
  /// `||`
  Or
  /// `&&`
  And
  /// `==`
  Eq
  /// `!=`
  NotEq
  /// `in`
  In
  /// `<`
  Less
  /// `<=`
  LessEq
  /// `>`
  Greater
  /// `>=`
  GreaterEq
  /// `+`
  Add
  /// `-`
  Sub
  /// `*`
  Mul
  /// `/`
  Div
  /// `%`
  Mod
}

// E0079: derived trait methods stay reachable with dot syntax.

///|
pub extend BinaryOp with Eq::{not_equal, equal}

///|
pub extend BinaryOp with @moonbitlang/core/debug.Debug::{to_repr}
