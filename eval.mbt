// eval.mbt — Tree-walking evaluator for matcher expressions.
//
// Evaluation is deterministic and side-effect free. `&&` and `||`
// short-circuit, so `false && unknown` does not raise. `in` tests list
// membership. Field access reads fields from records. Arithmetic is
// intentionally small: `+`, `-`, and `*` keep integers when both
// operands are integers, `/` always produces a double, and `%` works on
// integers only. Unknown identifiers and function names, wrong argument
// counts, and type mismatches raise `MatcherEval` errors.

///|
/// Evaluates a matcher expression.
///
/// `lookup` resolves identifiers such as `r_sub` or `p_obj` and returns
/// `None` for unknown names; `functions` resolves calls.
pub fn Expr::eval(
  self : Expr,
  lookup : (String) -> Value?,
  functions : FunctionRegistry,
) -> Result[Value, CasbinError] {
  Ok(eval_raise(self, lookup, functions)) catch {
    error => Err(error)
  }
}

///|
fn eval_raise(
  expression : Expr,
  lookup : (String) -> Value?,
  functions : FunctionRegistry,
) -> Value raise CasbinError {
  match expression {
    Literal(value) => value
    Ident(name) =>
      match lookup(name) {
        Some(value) => value
        None =>
          raise casbin_error(MatcherEval, "no parameter \"" + name + "\" found")
      }
    List(items) => {
      let values : Array[Value] = []
      for item in items {
        values.push(eval_raise(item, lookup, functions))
      }
      Value::Array(values)
    }
    Member(target, field) =>
      match eval_raise(target, lookup, functions) {
        Value::Object(fields) =>
          match find_field(fields, field) {
            Some(value) => value
            None =>
              raise casbin_error(
                MatcherEval,
                "record has no field \"" + field + "\"",
              )
          }
        other =>
          raise casbin_error(
            MatcherEval,
            "cannot read field \"" + field + "\" of " + other.type_name(),
          )
      }
    Unary(op, operand) => eval_unary(op, operand, lookup, functions)
    Binary(op, left, right) => eval_binary(op, left, right, lookup, functions)
    Call(name, arguments) => {
      let values : Array[Value] = []
      for argument in arguments {
        values.push(eval_raise(argument, lookup, functions))
      }
      match functions.get(name) {
        Some(function) => function(values)
        None =>
          raise casbin_error(
            MatcherEval,
            "function \"" + name + "\" is not defined",
          )
      }
    }
  }
}

///|
fn eval_unary(
  op : UnaryOp,
  operand : Expr,
  lookup : (String) -> Value?,
  functions : FunctionRegistry,
) -> Value raise CasbinError {
  let value = eval_raise(operand, lookup, functions)
  match op {
    Not => Value::Bool(!require_bool(value, "!"))
    Neg =>
      match value {
        Value::Int(i) => Value::Int(-i)
        Value::Double(d) => Value::Double(-d)
        other =>
          raise casbin_error(MatcherEval, "cannot negate " + other.type_name())
      }
  }
}

///|
fn eval_binary(
  op : BinaryOp,
  left : Expr,
  right : Expr,
  lookup : (String) -> Value?,
  functions : FunctionRegistry,
) -> Value raise CasbinError {
  match op {
    Or => {
      let left_value = eval_raise(left, lookup, functions)
      if require_bool(left_value, "||") {
        Value::Bool(true)
      } else {
        Value::Bool(require_bool(eval_raise(right, lookup, functions), "||"))
      }
    }
    And => {
      let left_value = eval_raise(left, lookup, functions)
      if require_bool(left_value, "&&") {
        Value::Bool(require_bool(eval_raise(right, lookup, functions), "&&"))
      } else {
        Value::Bool(false)
      }
    }
    Eq =>
      Value::Bool(
        eval_raise(left, lookup, functions).equals(
          eval_raise(right, lookup, functions),
        ),
      )
    NotEq =>
      Value::Bool(
        !eval_raise(left, lookup, functions).equals(
          eval_raise(right, lookup, functions),
        ),
      )
    In => {
      let needle = eval_raise(left, lookup, functions)
      let haystack = eval_raise(right, lookup, functions)
      match haystack {
        Value::Array(items) => {
          let mut found = false
          for item in items {
            if needle.equals(item) {
              found = true
              break
            }
          }
          Value::Bool(found)
        }
        other =>
          raise casbin_error(
            MatcherEval,
            "right operand of \"in\" must be a list, got " + other.type_name(),
          )
      }
    }
    Less | LessEq | Greater | GreaterEq => {
      let a = eval_raise(left, lookup, functions)
      let b = eval_raise(right, lookup, functions)
      let order = compare_values(a, b)
      Value::Bool(
        match op {
          Less => order < 0
          LessEq => order <= 0
          Greater => order > 0
          _ => order >= 0
        },
      )
    }
    Add | Sub | Mul | Div | Mod => {
      let a = eval_raise(left, lookup, functions)
      let b = eval_raise(right, lookup, functions)
      eval_arithmetic(op, a, b)
    }
  }
}

///|
fn eval_arithmetic(
  op : BinaryOp,
  a : Value,
  b : Value,
) -> Value raise CasbinError {
  match op {
    Add =>
      match (a, b) {
        (Value::String(x), Value::String(y)) => Value::String(x + y)
        _ => numeric_binary(a, b, add_int, add_double, "add")
      }
    Sub => numeric_binary(a, b, sub_int, sub_double, "subtract")
    Mul => numeric_binary(a, b, mul_int, mul_double, "multiply")
    Div =>
      match (as_double(a), as_double(b)) {
        (Some(x), Some(y)) =>
          if y == 0.0 {
            raise casbin_error(MatcherEval, "division by zero")
          } else {
            Value::Double(x / y)
          }
        _ =>
          raise casbin_error(
            MatcherEval,
            "cannot divide " + a.type_name() + " by " + b.type_name(),
          )
      }
    Mod =>
      match (a, b) {
        (Value::Int(x), Value::Int(y)) =>
          if y == 0 {
            raise casbin_error(MatcherEval, "modulo by zero")
          } else {
            Value::Int(x % y)
          }
        _ =>
          raise casbin_error(
            MatcherEval,
            "cannot take the modulo of " +
            a.type_name() +
            " and " +
            b.type_name(),
          )
      }
    _ => raise casbin_error(MatcherEval, "unsupported arithmetic operator")
  }
}

///|
fn numeric_binary(
  a : Value,
  b : Value,
  int_op : (Int, Int) -> Int,
  double_op : (Double, Double) -> Double,
  name : String,
) -> Value raise CasbinError {
  match (a, b) {
    (Value::Int(x), Value::Int(y)) => Value::Int(int_op(x, y))
    (Value::Double(x), Value::Double(y)) => Value::Double(double_op(x, y))
    (Value::Int(x), Value::Double(y)) =>
      Value::Double(double_op(x.to_double(), y))
    (Value::Double(x), Value::Int(y)) =>
      Value::Double(double_op(x, y.to_double()))
    _ =>
      raise casbin_error(
        MatcherEval,
        "cannot " + name + " " + a.type_name() + " and " + b.type_name(),
      )
  }
}

///|
fn compare_values(a : Value, b : Value) -> Int raise CasbinError {
  match (a, b) {
    (Value::Int(x), Value::Int(y)) => compare_int(x, y)
    (Value::Double(x), Value::Double(y)) => compare_double(x, y)
    (Value::Int(x), Value::Double(y)) => compare_double(x.to_double(), y)
    (Value::Double(x), Value::Int(y)) => compare_double(x, y.to_double())
    (Value::String(x), Value::String(y)) => compare_string(x, y)
    _ =>
      raise casbin_error(
        MatcherEval,
        "cannot compare " + a.type_name() + " with " + b.type_name(),
      )
  }
}

///|
fn require_bool(value : Value, operator : String) -> Bool raise CasbinError {
  match value {
    Value::Bool(flag) => flag
    other =>
      raise casbin_error(
        MatcherEval,
        "operator \"" + operator + "\" requires bool, got " + other.type_name(),
      )
  }
}

///|
fn as_double(value : Value) -> Double? {
  match value {
    Value::Int(i) => Some(i.to_double())
    Value::Double(d) => Some(d)
    _ => None
  }
}

///|
fn find_field(fields : Array[(String, Value)], name : String) -> Value? {
  for field in fields {
    if field.0 == name {
      return Some(field.1)
    }
  }
  None
}

///|
fn add_int(x : Int, y : Int) -> Int {
  x + y
}

///|
fn add_double(x : Double, y : Double) -> Double {
  x + y
}

///|
fn sub_int(x : Int, y : Int) -> Int {
  x - y
}

///|
fn sub_double(x : Double, y : Double) -> Double {
  x - y
}

///|
fn mul_int(x : Int, y : Int) -> Int {
  x * y
}

///|
fn mul_double(x : Double, y : Double) -> Double {
  x * y
}

///|
fn compare_int(x : Int, y : Int) -> Int {
  if x < y {
    -1
  } else if x == y {
    0
  } else {
    1
  }
}

///|
fn compare_double(x : Double, y : Double) -> Int {
  if x < y {
    -1
  } else if x == y {
    0
  } else {
    1
  }
}

///|
fn compare_string(x : String, y : String) -> Int {
  if x < y {
    -1
  } else if x == y {
    0
  } else {
    1
  }
}
