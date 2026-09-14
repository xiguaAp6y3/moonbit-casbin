// builtin_operators.mbt — Regex-based and IP-based matcher operators.
//
// KeyMatch2..5, KeyGet2/3, RegexMatch, GlobMatch, and IPMatch mirror
// Casbin's `util/builtin_operators.go`. The rewrite-and-match operators
// follow Casbin exactly: the pattern is rewritten textually and then
// matched as an anchored regular expression through the official
// `moonbitlang/regexp` engine, which reproduces Casbin's behavior —
// including how stray regex metacharacters in a pattern are interpreted.
// Casbin's `keyMatchShortcut` optimization is reproduced as well: patterns
// without regex metacharacters skip the engine, which also means plain
// patterns are never regex-interpreted.
//
// GlobMatch approximates `doublestar.Match` by translating the pattern to a
// regular expression: `**` crosses path separators, `*` and `?` do not,
// `[...]` classes are supported (`!` or `^` negates), and `{a,b}` provides
// alternation without nesting. Invalid patterns raise `MatcherEval`.
//
// Casbin raises (and recovers into errors) for invalid regex, invalid glob,
// and invalid IP arguments; here the same situations raise `MatcherEval`.

///|
fn key_match2_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2) = two_string_arguments("keyMatch2", arguments)
  Value::Bool(key_match2(key1, key2))
}

///|
fn key_match3_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2) = two_string_arguments("keyMatch3", arguments)
  Value::Bool(key_match3(key1, key2))
}

///|
fn key_match4_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2) = two_string_arguments("keyMatch4", arguments)
  Value::Bool(key_match4(key1, key2))
}

///|
fn key_match5_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2) = two_string_arguments("keyMatch5", arguments)
  Value::Bool(key_match5(key1, key2))
}

///|
fn key_get2_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2, path_var) = three_string_arguments("keyGet2", arguments)
  Value::String(key_get2(key1, key2, path_var))
}

///|
fn key_get3_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2, path_var) = three_string_arguments("keyGet3", arguments)
  Value::String(key_get3(key1, key2, path_var))
}

///|
fn regex_match_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2) = two_string_arguments("regexMatch", arguments)
  Value::Bool(regex_match(key1, key2))
}

///|
fn glob_match_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2) = two_string_arguments("globMatch", arguments)
  Value::Bool(glob_match(key1, key2))
}

///|
fn ip_match_function(arguments : Array[Value]) -> Value raise CasbinError {
  let (key1, key2) = two_string_arguments("ipMatch", arguments)
  Value::Bool(ip_match(key1, key2))
}

///|
/// Casbin's `keyMatch2`: `:param` matches one non-empty path segment and
/// `/*` matches the rest of the path.
fn key_match2(key1 : String, key2 : String) -> Bool raise CasbinError {
  match key_match_shortcut(key1, key2, ":") {
    Some(matched) => matched
    None => {
      let (pattern, _tokens) = rewrite_colon_params(
        strip_slash_star(key2),
        "[^/]+",
      )
      regex_match_anchored(pattern, key1)
    }
  }
}

///|
/// Casbin's `keyMatch3`: like keyMatch2 but with `{param}` placeholders.
fn key_match3(key1 : String, key2 : String) -> Bool raise CasbinError {
  match key_match_shortcut(key1, key2, "") {
    Some(matched) => matched
    None => {
      let (pattern, _tokens) = rewrite_braces(
        strip_slash_star(key2),
        "[^/]+",
        true,
      )
      regex_match_anchored(pattern, key1)
    }
  }
}

///|
/// Casbin's `keyMatch4`: `{param}` placeholders; repeated placeholders must
/// capture equal values.
fn key_match4(key1 : String, key2 : String) -> Bool raise CasbinError {
  match key_match_shortcut(key1, key2, "") {
    Some(matched) => matched
    None => {
      let (pattern, tokens) = rewrite_braces(
        strip_slash_star(key2),
        "([^/]+)",
        true,
      )
      let compiled = compile_pattern("^" + pattern + "$")
      let result = compiled.execute(key1)
      if !result.matched() {
        return false
      }
      let captures = result.results()
      if captures.length() != tokens.length() + 1 {
        raise casbin_error(
          MatcherEval,
          "keyMatch4: number of tokens is not equal to number of values",
        )
      }
      let seen : Array[(String, String)] = []
      for i in 0..<tokens.length() {
        let value = match captures[i + 1] {
          Some(capture) => capture.to_owned()
          None => ""
        }
        match find_pair_value(seen, tokens[i]) {
          Some(existing) => if existing != value { return false }
          None => seen.push((tokens[i], value))
        }
      }
      true
    }
  }
}

///|
/// Casbin's `keyMatch5`: `{param}` placeholders, and the query string of
/// `key1` is ignored.
fn key_match5(key1 : String, key2 : String) -> Bool raise CasbinError {
  let key1 = match key1.find("?") {
    Some(index) => key1[:index].to_owned()
    None => key1
  }
  match key_match_shortcut(key1, key2, "") {
    Some(matched) => matched
    None => {
      let (pattern, _tokens) = rewrite_braces(
        strip_slash_star(key2),
        "[^/]+",
        true,
      )
      regex_match_anchored(pattern, key1)
    }
  }
}

///|
/// Casbin's `keyGet2`: the value captured for `path_var` by a `:param`
/// pattern, or the empty string.
fn key_get2(
  key1 : String,
  key2 : String,
  path_var : String,
) -> String raise CasbinError {
  let (pattern, tokens) = rewrite_colon_params(
    strip_slash_star(key2),
    "([^/]+)",
  )
  let compiled = compile_pattern("^" + pattern + "$")
  let result = compiled.execute(key1)
  if !result.matched() {
    return ""
  }
  let captures = result.results()
  for i in 0..<tokens.length() {
    if tokens[i] == path_var {
      return match captures[i + 1] {
        Some(capture) => capture.to_owned()
        None => ""
      }
    }
  }
  ""
}

///|
/// Casbin's `keyGet3`: the value captured for `path_var` by a `{param}`
/// pattern, or the empty string.
fn key_get3(
  key1 : String,
  key2 : String,
  path_var : String,
) -> String raise CasbinError {
  let (pattern, tokens) = rewrite_braces(
    strip_slash_star(key2),
    "([^/]+?)",
    false,
  )
  let compiled = compile_pattern("^" + pattern + "$")
  let result = compiled.execute(key1)
  if !result.matched() {
    return ""
  }
  let captures = result.results()
  for i in 0..<tokens.length() {
    if tokens[i] == path_var {
      return match captures[i + 1] {
        Some(capture) => capture.to_owned()
        None => ""
      }
    }
  }
  ""
}

///|
/// Casbin's `regexMatch`: an unanchored regular expression search.
fn regex_match(key1 : String, key2 : String) -> Bool raise CasbinError {
  let compiled = compile_pattern(key2)
  match compiled.match_(key1) {
    Some(_) => true
    None => false
  }
}

///|
/// Casbin's `globMatch` (`doublestar.Match(key2, key1)`).
fn glob_match(key1 : String, key2 : String) -> Bool raise CasbinError {
  let pattern = glob_to_regex(key2)
  regex_match_anchored(pattern, key1)
}

///|
/// Casbin's `keyMatchShortcut`: `*` matches everything, and patterns
/// without regex metacharacters are plain equality comparisons.
fn key_match_shortcut(
  key1 : String,
  key2 : String,
  extra_chars : String,
) -> Bool? {
  if key2 == "*" {
    return Some(true)
  }
  if !key2.contains_any(chars="\\.+*?()|[]{}^$") &&
    !key2.contains_any(chars=extra_chars) {
    return Some(key1 == key2)
  }
  None
}

///|
fn strip_slash_star(pattern : String) -> String {
  pattern.replace_all(old="/*", new="/.*")
}

///|
/// Rewrites `:name` placeholders into `replacement`, recording the names in
/// order of appearance.
fn rewrite_colon_params(
  pattern : String,
  replacement : String,
) -> (String, Array[String]) {
  let chars : Array[Char] = pattern.iter().collect()
  let output : Array[Char] = []
  let tokens : Array[String] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] == ':' {
      let mut end = index + 1
      while end < chars.length() && chars[end] != '/' {
        end += 1
      }
      if end > index + 1 {
        tokens.push(slice_to_string(chars, index + 1, end))
        push_text(output, replacement)
        index = end
        continue
      }
    }
    output.push(chars[index])
    index += 1
  }
  (StringView::from_iter(output.iter()).to_owned(), tokens)
}

///|
/// Rewrites `{name}` placeholders into `replacement`, recording the names in
/// order of appearance. `greedy` selects Casbin's greedy `\{[^/]+\}` for
/// keyMatch3/5; non-greedy selects `\{[^/]+?\}` for keyGet3.
fn rewrite_braces(
  pattern : String,
  replacement : String,
  greedy : Bool,
) -> (String, Array[String]) {
  let chars : Array[Char] = pattern.iter().collect()
  let output : Array[Char] = []
  let tokens : Array[String] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '{' {
      // The match may not cross a path separator.
      let mut limit = index + 1
      while limit < chars.length() && chars[limit] != '/' {
        limit += 1
      }
      let closing = if greedy {
        last_brace_before(chars, index + 1, limit)
      } else {
        first_brace_before(chars, index + 1, limit)
      }
      match closing {
        Some(end) =>
          if end > index + 1 {
            tokens.push(slice_to_string(chars, index + 1, end))
            push_text(output, replacement)
            index = end + 1
            continue
          }
        None => ()
      }
    }
    output.push(chars[index])
    index += 1
  }
  // Escape the braces that survived the rewrite: they cannot be placeholders
  // any more, Go's regexp treats a stray `{` as a literal, and this engine
  // raises `MissingRepeatArgument` for it.
  let escaped : Array[Char] = []
  for ch in output.iter() {
    if ch == '{' || ch == '}' {
      escaped.push('\\')
    }
    escaped.push(ch)
  }
  (StringView::from_iter(escaped.iter()).to_owned(), tokens)
}

///|
fn first_brace_before(chars : Array[Char], start : Int, limit : Int) -> Int? {
  for i in start..<limit {
    if chars[i] == '}' {
      return Some(i)
    }
  }
  None
}

///|
fn last_brace_before(chars : Array[Char], start : Int, limit : Int) -> Int? {
  let mut found : Int? = None
  for i in start..<limit {
    if chars[i] == '}' {
      found = Some(i)
    }
  }
  found
}

///|
/// Translates a glob pattern to an anchored regular expression.
fn glob_to_regex(pattern : String) -> String raise CasbinError {
  let chars : Array[Char] = pattern.iter().collect()
  let output : Array[Char] = []
  let mut index = 0
  while index < chars.length() {
    let ch = chars[index]
    match ch {
      '*' => {
        let start = index
        let mut end = index
        while end < chars.length() && chars[end] == '*' {
          end += 1
        }
        let run = end - start
        let at_segment_start = start == 0 || chars[start - 1] == '/'
        let at_segment_end = end == chars.length() || chars[end] == '/'
        if run >= 2 && at_segment_start && at_segment_end {
          if start == 0 && end == chars.length() {
            // A bare `**` matches everything.
            push_text(output, ".*")
            index = end
          } else if end == chars.length() {
            // A trailing `/**` also matches the directory itself, so the
            // separator before it becomes optional.
            ignore(output.pop())
            push_text(output, "(/.*)?")
            index = end
          } else {
            // `**/` matches zero or more leading segments; the separator is
            // part of the group, so consume it here.
            push_text(output, "(.*/)?")
            index = end + 1
          }
        } else {
          // A single star, or a doublestar glued to a name, does not cross
          // path separators.
          push_text(output, "[^/]*")
          index = end
        }
        continue
      }
      '?' => push_text(output, "[^/]")
      '[' => {
        let mut end = index + 1
        if end < chars.length() && (chars[end] == '!' || chars[end] == '^') {
          end += 1
        }
        while end < chars.length() && chars[end] != ']' {
          end += 1
        }
        if end >= chars.length() {
          raise casbin_error(
            MatcherEval,
            "globMatch: unterminated character class in \"" + pattern + "\"",
          )
        }
        output.push('[')
        let mut inner = index + 1
        if inner < end && chars[inner] == '!' {
          output.push('^')
          inner += 1
        }
        while inner <= end {
          output.push(chars[inner])
          inner += 1
        }
        index = end + 1
        continue
      }
      '{' => {
        let mut end = index + 1
        while end < chars.length() && chars[end] != '}' {
          end += 1
        }
        if end >= chars.length() {
          raise casbin_error(
            MatcherEval,
            "globMatch: unterminated alternation in \"" + pattern + "\"",
          )
        }
        let body = slice_to_string(chars, index + 1, end)
        output.push('(')
        for option in body.split(",") {
          // Translate each alternative as a glob so `*` and `?` keep their
          // glob meaning inside `{...}`.
          push_text(output, glob_to_regex(option.to_owned()))
          output.push('|')
        }
        // Replace the trailing '|' with the closing parenthesis.
        ignore(output.pop())
        output.push(')')
        index = end + 1
        continue
      }
      '.' | '+' | '(' | ')' | '|' | '^' | '$' | '\\' => {
        output.push('\\')
        output.push(ch)
      }
      _ => output.push(ch)
    }
    index += 1
  }
  StringView::from_iter(output.iter()).to_owned()
}

///|
fn regex_match_anchored(
  pattern : String,
  text : String,
) -> Bool raise CasbinError {
  let compiled = compile_pattern("^" + pattern + "$")
  match compiled.match_(text) {
    Some(_) => true
    None => false
  }
}

///|
fn compile_pattern(pattern : String) -> @regexp.Regexp raise CasbinError {
  @regexp.compile(pattern) catch {
    error =>
      raise casbin_error(
        MatcherEval,
        "invalid regular expression \"" + pattern + "\": " + error.to_string(),
      )
  }
}

///|
fn three_string_arguments(
  name : String,
  arguments : Array[Value],
) -> (String, String, String) raise CasbinError {
  if arguments.length() != 3 {
    raise casbin_error(
      MatcherEval,
      name + ": expected 3 arguments, but got " + arguments.length().to_string(),
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
  let third = match arguments[2] {
    Value::String(value) => value
    other =>
      raise casbin_error(
        MatcherEval,
        name + ": argument must be a string, got " + other.type_name(),
      )
  }
  (first, second, third)
}

///|
fn find_pair_value(pairs : Array[(String, String)], key : String) -> String? {
  for pair in pairs {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
fn push_text(output : Array[Char], text : String) -> Unit {
  for ch in text.iter() {
    output.push(ch)
  }
}
