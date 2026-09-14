// policy.mbt — In-memory policy storage.
//
// Policies are grouped by policy type (`p`, `p2`, `g`, `g2`, ...) with rows
// kept in insertion order, because both the priority effect and Casbin's
// policy ordering are order-sensitive. A hash index detects duplicates;
// unlike Casbin, rows are joined with a unit separator rather than a comma
// so values containing commas cannot collide.

///|
/// One policy type section: its rows plus a duplicate-detection index.
pub(all) struct PolicySection {
  key : String
  rows : Array[Array[String]]
  index : @hashmap.HashMap[String, Int]
}

///|
/// The policy type, for example `p`, `p2`, `g`, or `g2`.
pub fn PolicySection::key(self : PolicySection) -> String {
  self.key
}

///|
/// The rows of this section in insertion order.
pub fn PolicySection::rows(self : PolicySection) -> Array[Array[String]] {
  self.rows
}

///|
/// An in-memory policy store.
pub(all) struct PolicyStore {
  sections : Array[PolicySection]
}

///|
/// Creates an empty store.
pub fn PolicyStore::new() -> PolicyStore {
  { sections: [], }
}

///|
/// The rows of the section `key` in insertion order; empty when the
/// section does not exist.
pub fn PolicyStore::rows(
  self : PolicyStore,
  key : String,
) -> Array[Array[String]] {
  for section in self.sections {
    if section.key == key {
      return section.rows
    }
  }
  []
}

///|
/// Whether `row` is present in the section `key`.
pub fn PolicyStore::has(
  self : PolicyStore,
  key : String,
  row : Array[String],
) -> Bool {
  match self.find_section(key) {
    Some(position) => self.sections[position].index.contains(row_key(row))
    None => false
  }
}

///|
/// Adds `row` to the section `key`, creating the section when needed.
/// Returns `false` when the row is already present.
pub fn PolicyStore::add(
  self : PolicyStore,
  key : String,
  row : Array[String],
) -> Bool {
  let position = match self.find_section(key) {
    Some(position) => position
    None => {
      let position = self.sections.length()
      self.sections.push({ key, rows: [], index: @hashmap.HashMap([]), })
      position
    }
  }
  let section = self.sections[position]
  let joined = row_key(row)
  if section.index.contains(joined) {
    return false
  }
  section.index.set(joined, section.rows.length())
  section.rows.push(row)
  true
}

///|
/// Removes `row` from the section `key`, keeping the order of the
/// remaining rows. Returns `false` when the row is not present.
pub fn PolicyStore::remove(
  self : PolicyStore,
  key : String,
  row : Array[String],
) -> Bool {
  let position = match self.find_section(key) {
    Some(position) => position
    None => return false
  }
  let section = self.sections[position]
  let joined = row_key(row)
  let target = match section.index.get(joined) {
    Some(target) => target
    None => return false
  }
  section.index.remove(joined)
  let shifted = section.rows.length() - 1
  for i in target..<shifted {
    section.rows[i] = section.rows[i + 1]
    section.index.set(row_key(section.rows[i]), i)
  }
  ignore(section.rows.pop())
  true
}

///|
/// Removes every row of every section.
pub fn PolicyStore::clear(self : PolicyStore) -> Unit {
  self.sections.clear()
}

///|
fn PolicyStore::find_section(self : PolicyStore, key : String) -> Int? {
  for i in 0..<self.sections.length() {
    if self.sections[i].key == key {
      return Some(i)
    }
  }
  None
}

///|
fn row_key(row : Array[String]) -> String {
  let joined : Array[Char] = []
  for value in row {
    joined.push('\u{1f}')
    for ch in value.iter() {
      joined.push(ch)
    }
  }
  StringView::from_iter(joined.iter()).to_owned()
}
