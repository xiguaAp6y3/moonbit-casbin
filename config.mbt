// config.mbt — Config parser for Casbin model files.
//
// The format is a small INI dialect: `[section]` headers and `key = value`
// entries, with `#` and `;` comment lines and blank lines ignored. Values
// keep everything after the first `=`, so matcher expressions containing
// `==` are preserved verbatim. A repeated section header extends the
// existing section, and duplicate keys are kept in declaration order;
// `get` returns the first occurrence.

///|
/// One `key = value` entry inside a configuration section.
pub(all) struct ConfigEntry {
  key : String
  value : String
} derive(Debug)

///|
/// The entry key.
pub fn ConfigEntry::key(self : ConfigEntry) -> String {
  self.key
}

///|
/// The entry value with surrounding whitespace removed.
pub fn ConfigEntry::value(self : ConfigEntry) -> String {
  self.value
}

///|
/// A named configuration section with its entries in declaration order.
pub(all) struct ConfigSection {
  name : String
  entries : Array[ConfigEntry]
} derive(Debug)

///|
/// Parsed Casbin configuration (INI-style model file).
pub(all) struct Config {
  sections : Array[ConfigSection]
} derive(Debug)

///|
/// Parses Casbin model configuration text.
///
/// Returns `Err(CasbinErrorKind::ConfigSyntax)` for malformed text; the
/// error carries the 1-based line number.
pub fn Config::parse(text : String) -> Result[Config, CasbinError] {
  Ok(parse_config_raise(text)) catch {
    error => Err(error)
  }
}

///|
/// Internal: parses configuration text, raising on the first violation.
fn parse_config_raise(text : String) -> Config raise CasbinError {
  let sections : Array[ConfigSection] = []
  let mut current : Int = -1
  let mut line_number : Int = 0
  for raw_line in text.split("\n") {
    line_number += 1
    let line = raw_line.trim()
    if line.is_empty() || line.has_prefix("#") || line.has_prefix(";") {
      continue
    }
    if line.has_prefix("[") {
      if !line.has_suffix("]") {
        raise casbin_error_at(
          ConfigSyntax,
          line_number,
          "section header is missing ']'",
        )
      }
      let name = line.sub(start=1, end=line.length() - 1).trim()
      if name.is_empty() {
        raise casbin_error_at(ConfigSyntax, line_number, "empty section name")
      }
      if name.contains("[") || name.contains("]") {
        raise casbin_error_at(
          ConfigSyntax,
          line_number,
          "invalid section name \"" + name.to_owned() + "\"",
        )
      }
      let name = name.to_owned()
      current = find_section(sections, name)
      if current < 0 {
        sections.push({ name, entries: [], })
        current = sections.length() - 1
      }
      continue
    }
    if current < 0 {
      raise casbin_error_at(
        ConfigSyntax,
        line_number,
        "entry outside of any section",
      )
    }
    let (key, value) = match line.split_once("=") {
      Some(pair) => pair
      None =>
        raise casbin_error_at(
          ConfigSyntax,
          line_number,
          "expected \"key = value\"",
        )
    }
    let key = key.trim()
    if key.is_empty() {
      raise casbin_error_at(ConfigSyntax, line_number, "empty key")
    }
    sections[current].entries.push({
      key: key.to_owned(),
      value: value.trim().to_owned(),
    })
  }
  { sections, }
}

///|
/// The value of `key` in `section`, or `None` when either is absent.
/// When a key appears several times the first occurrence wins.
pub fn Config::get(self : Config, section : String, key : String) -> String? {
  for s in self.sections {
    if s.name == section {
      for entry in s.entries {
        if entry.key == key {
          return Some(entry.value)
        }
      }
      return None
    }
  }
  None
}

///|
/// The entries of `section` in declaration order; empty when the section
/// is absent.
pub fn Config::entries(self : Config, section : String) -> Array[ConfigEntry] {
  for s in self.sections {
    if s.name == section {
      return s.entries
    }
  }
  []
}

///|
/// The names of all declared sections in declaration order.
pub fn Config::section_names(self : Config) -> Array[String] {
  let names : Array[String] = []
  for s in self.sections {
    names.push(s.name)
  }
  names
}

///|
fn find_section(sections : Array[ConfigSection], name : String) -> Int {
  for i in 0..<sections.length() {
    if sections[i].name == name {
      return i
    }
  }
  -1
}
