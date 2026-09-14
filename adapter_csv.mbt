// adapter_csv.mbt — Policy text parsing (Casbin's CSV policy format).
//
// Each non-empty, non-comment line is one policy rule:
//
//     p, alice, data1, read
//     g, alice, admin
//
// The first field is the policy type (`p`, `p2`, `g`, `g2`, ...) and the
// remaining fields are the rule values. Fields follow RFC 4180 quoting: a
// field starting with `"` ends at the matching quote, and `""` is a
// literal quote. Lines starting with `#` are comments.
//
// Casbin parses lines with Go's `encoding/csv` and `TrimLeadingSpace`; this
// implementation trims both ends of unquoted fields, a deliberate
// simplification (trailing spaces in policy values are almost always
// accidental). Quoted field contents are preserved exactly.

///|
/// One parsed policy line: the policy type plus the rule values.
pub(all) struct PolicyLine {
  key : String
  values : Array[String]
} derive(Eq, Debug)

///|
/// The policy type, for example `p` or `g`.
pub fn PolicyLine::key(self : PolicyLine) -> String {
  self.key
}

///|
/// The rule values, without the policy type.
pub fn PolicyLine::values(self : PolicyLine) -> Array[String] {
  self.values
}

///|
/// Parses policy text into lines. Empty lines and `#` comments are
/// skipped; a line whose first field is empty raises `PolicySyntax`.
pub fn parse_policy_text(
  text : String,
) -> Result[Array[PolicyLine], CasbinError] {
  Ok(parse_policy_text_raise(text)) catch {
    error => Err(error)
  }
}

///|
fn parse_policy_text_raise(
  text : String,
) -> Array[PolicyLine] raise CasbinError {
  let lines : Array[PolicyLine] = []
  for raw_line in text.split("\n") {
    let line = raw_line.trim().to_owned()
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let fields = parse_csv_line(line)
    if fields.is_empty() || fields[0].is_empty() {
      raise casbin_error(
        PolicySyntax,
        "invalid policy rule: missing policy type",
      )
    }
    let values : Array[String] = []
    for i in 1..<fields.length() {
      values.push(fields[i])
    }
    lines.push({ key: fields[0], values, })
  }
  lines
}

///|
/// Splits one line into CSV fields. Empty fields are preserved, so
/// `p, a, , b` yields four fields.
fn parse_csv_line(line : String) -> Array[String] raise CasbinError {
  let chars : Array[Char] = line.iter().collect()
  let length = chars.length()
  let fields : Array[String] = []
  let mut index = 0
  while true {
    while index < length && (chars[index] == ' ' || chars[index] == '\t') {
      index += 1
    }
    if index < length && chars[index] == '"' {
      let value : Array[Char] = []
      let mut closed = false
      index += 1
      while index < length {
        let ch = chars[index]
        if ch == '"' {
          if index + 1 < length && chars[index + 1] == '"' {
            value.push('"')
            index += 2
            continue
          }
          index += 1
          closed = true
          break
        }
        value.push(ch)
        index += 1
      }
      if !closed {
        raise casbin_error(PolicySyntax, "unterminated quoted field")
      }
      while index < length && (chars[index] == ' ' || chars[index] == '\t') {
        index += 1
      }
      if index < length && chars[index] != ',' {
        raise casbin_error(
          PolicySyntax,
          "unexpected character after a quoted field",
        )
      }
      fields.push(StringView::from_iter(value.iter()).to_owned())
    } else {
      let value : Array[Char] = []
      while index < length && chars[index] != ',' {
        value.push(chars[index])
        index += 1
      }
      fields.push(
        StringView::from_iter(value.iter()).to_owned().trim().to_owned(),
      )
    }
    if index < length {
      index += 1
      continue
    }
    break
  }
  fields
}
