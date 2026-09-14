// ip.mbt — IPv4/IPv6 parsing and CIDR matching for `ipMatch`.
//
// Implements the subset of Go's `net` package that Casbin's `ipMatch`
// relies on: `ParseIP` (IPv4; IPv6 with `::` compression and an
// IPv4-embedded tail) and `ParseCIDR` prefix containment. Addresses are
// kept as byte sequences (4 for IPv4, 16 for IPv6), so addresses of
// different families are simply unequal — the same outcome as Go, where
// `cidr.Contains` returns false across families.
//
// Deliberate deviations from Go: IPv4 octets with leading zeros are
// rejected (Go rejects them since 1.17), and zone identifiers such as
// `fe80::1%eth0` are not supported.

///|
/// Whether `ip1` is covered by `ip2`, where `ip2` is either a CIDR
/// (`192.168.2.0/24`) or a plain address.
///
/// Raises `MatcherEval` when either argument does not parse, mirroring the
/// errors Casbin's `ipMatch` raises.
pub fn ip_match(ip1 : String, ip2 : String) -> Bool raise CasbinError {
  let address = match parse_ip(ip1) {
    Some(address) => address
    None =>
      raise casbin_error(
        MatcherEval,
        "ipMatch: \"" + ip1 + "\" is not an IP address",
      )
  }
  match parse_cidr(ip2) {
    Some((network, prefix)) =>
      network.length() == address.length() &&
      prefix_matches(address, network, prefix)
    None =>
      match parse_ip(ip2) {
        Some(other) =>
          other.length() == address.length() &&
          prefix_matches(address, other, address.length() * 8)
        None =>
          raise casbin_error(
            MatcherEval,
            "ipMatch: \"" + ip2 + "\" is neither an IP address nor a CIDR",
          )
      }
  }
}

///|
/// Parses an IPv4 or IPv6 address into 4 or 16 bytes.
fn parse_ip(text : String) -> Array[Int]? {
  if text.contains(":") {
    parse_ipv6(text)
  } else {
    parse_ipv4(text)
  }
}

///|
fn parse_ipv4(text : String) -> Array[Int]? {
  let parts = text.split(".").collect()
  if parts.length() != 4 {
    return None
  }
  let bytes : Array[Int] = []
  for part in parts {
    match parse_octet(part) {
      Some(value) => bytes.push(value)
      None => return None
    }
  }
  Some(bytes)
}

///|
fn parse_octet(part : StringView) -> Int? {
  let chars : Array[Char] = part.iter().collect()
  if chars.length() == 0 || chars.length() > 3 {
    return None
  }
  if chars.length() > 1 && chars[0] == '0' {
    return None
  }
  let mut value = 0
  for ch in chars {
    if !ch.is_ascii_digit() {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  if value > 255 {
    return None
  }
  Some(value)
}

///|
/// Parses an IPv6 address (`::` compression and an IPv4 tail are
/// supported) into 16 bytes.
fn parse_ipv6(text : String) -> Array[Int]? {
  let parts = text.split("::").collect()
  if parts.length() > 2 {
    return None
  }
  let mut groups : Array[Int] = []
  match parse_ipv6_side(parts[0]) {
    Some(left) => groups = left
    None => return None
  }
  if parts.length() == 2 {
    let right = match parse_ipv6_side(parts[1]) {
      Some(right) => right
      None => return None
    }
    let total = groups.length() + right.length()
    // `::` must stand for at least one zero group.
    if total > 7 {
      return None
    }
    for _i in 0..<(8 - total) {
      groups.push(0)
    }
    for group in right {
      groups.push(group)
    }
  } else if groups.length() != 8 {
    return None
  }
  let bytes : Array[Int] = []
  for group in groups {
    bytes.push(group / 256)
    bytes.push(group % 256)
  }
  Some(bytes)
}

///|
/// Parses one side of an IPv6 address into 16-bit groups; an IPv4 tail
/// contributes two groups.
fn parse_ipv6_side(part : StringView) -> Array[Int]? {
  if part.is_empty() {
    return Some([])
  }
  let fields = part.split(":").collect()
  let groups : Array[Int] = []
  for i in 0..<fields.length() {
    let field = fields[i]
    if field.is_empty() {
      return None
    }
    if field.contains(".") {
      if i != fields.length() - 1 {
        return None
      }
      let tail = match parse_ipv4(field.to_owned()) {
        Some(tail) => tail
        None => return None
      }
      groups.push(tail[0] * 256 + tail[1])
      groups.push(tail[2] * 256 + tail[3])
    } else {
      match parse_hex_group(field) {
        Some(value) => groups.push(value)
        None => return None
      }
    }
  }
  Some(groups)
}

///|
fn parse_hex_group(field : StringView) -> Int? {
  let chars : Array[Char] = field.iter().collect()
  if chars.length() == 0 || chars.length() > 4 {
    return None
  }
  let mut value = 0
  for ch in chars {
    let digit = if ch.is_ascii_digit() {
      ch.to_int() - '0'.to_int()
    } else if ch >= 'a' && ch <= 'f' {
      ch.to_int() - 'a'.to_int() + 10
    } else if ch >= 'A' && ch <= 'F' {
      ch.to_int() - 'A'.to_int() + 10
    } else {
      return None
    }
    value = value * 16 + digit
  }
  Some(value)
}

///|
/// Parses `<address>/<prefix>`; the prefix must fit the address family.
fn parse_cidr(text : String) -> (Array[Int], Int)? {
  let parts = text.split("/").collect()
  if parts.length() != 2 {
    return None
  }
  let address = match parse_ip(parts[0].to_owned()) {
    Some(address) => address
    None => return None
  }
  let prefix = match parse_decimal(parts[1]) {
    Some(prefix) => prefix
    None => return None
  }
  if prefix > address.length() * 8 {
    return None
  }
  Some((address, prefix))
}

///|
fn parse_decimal(text : StringView) -> Int? {
  let chars : Array[Char] = text.iter().collect()
  if chars.length() == 0 || chars.length() > 3 {
    return None
  }
  let mut value = 0
  for ch in chars {
    if !ch.is_ascii_digit() {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
/// Whether the first `prefix` bits of two same-length addresses agree.
fn prefix_matches(
  address : Array[Int],
  network : Array[Int],
  prefix : Int,
) -> Bool {
  let full_bytes = prefix / 8
  let remaining_bits = prefix % 8
  for i in 0..<full_bytes {
    if address[i] != network[i] {
      return false
    }
  }
  if remaining_bits > 0 {
    let mask = 0xFF << (8 - remaining_bits)
    if (address[full_bytes] & mask) != (network[full_bytes] & mask) {
      return false
    }
  }
  true
}
