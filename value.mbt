// value.mbt — Runtime values for matcher evaluation.
//
// The evaluator works on a small dynamic value model. Casbin binds request
// and policy parameters as strings; numbers, booleans, lists, and records
// appear in matchers such as `r_sub.Age > 18` or
// `r_obj in ('data2', 'data3')`.

///|
/// A runtime value produced or consumed by the matcher evaluator.
pub(all) enum Value {
  Null
  Bool(Bool)
  Int(Int)
  Double(Double)
  String(String)
  Array(Array[Value])
  /// A record used for field access (ABAC-style attributes). Field lookup
  /// is linear and the first match wins.
  Object(Array[(String, Value)])
} derive(Eq, Debug)

///|
/// A human-readable type name used in error messages.
pub fn Value::type_name(self : Value) -> String {
  match self {
    Null => "null"
    Bool(_) => "bool"
    Int(_) => "int"
    Double(_) => "double"
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}

///|
/// Casbin-style equality: numbers compare across int and double, values of
/// different types are never equal, arrays compare element-wise, and
/// records compare field-wise in order.
pub fn Value::equals(self : Value, other : Value) -> Bool {
  match (self, other) {
    (Null, Null) => true
    (Bool(a), Bool(b)) => a == b
    (Int(a), Int(b)) => a == b
    (Double(a), Double(b)) => a == b
    (Int(a), Double(b)) => a.to_double() == b
    (Double(a), Int(b)) => a == b.to_double()
    (String(a), String(b)) => a == b
    (Array(a), Array(b)) => {
      let mut same = a.length() == b.length()
      if same {
        for i in 0..<a.length() {
          if !a[i].equals(b[i]) {
            same = false
            break
          }
        }
      }
      same
    }
    (Object(a), Object(b)) => {
      let mut same = a.length() == b.length()
      if same {
        for i in 0..<a.length() {
          if a[i].0 != b[i].0 || !a[i].1.equals(b[i].1) {
            same = false
            break
          }
        }
      }
      same
    }
    _ => false
  }
}
