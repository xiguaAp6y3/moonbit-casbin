// ip_test.mbt — Tests for IP matching.
//
// The IPv4/CIDR cases follow Casbin's `TestIPMatch`; IPv6 cases follow Go's
// `net.ParseIP` / `ParseCIDR` behavior that Casbin relies on.

///|
test "ipMatch follows Casbin" {
  let cases : Array[(String, String, Bool)] = [
    ("192.168.2.123", "192.168.2.0/24", true),
    ("192.168.2.123", "192.168.3.0/24", false),
    ("192.168.2.123", "192.168.2.0/16", true),
    ("192.168.2.123", "192.168.2.123", true),
    ("192.168.2.123", "192.168.2.123/32", true),
    ("10.0.0.11", "10.0.0.0/8", true),
    ("11.0.0.123", "10.0.0.0/8", false),
  ]
  for case in cases {
    assert_true(ip_match(case.0, case.1) == case.2)
  }
}

///|
test "ipMatch handles IPv6 addresses and CIDRs" {
  let cases : Array[(String, String, Bool)] = [
    ("2001:db8::1", "2001:db8::/32", true),
    ("2001:db9::1", "2001:db8::/32", false),
    ("::1", "::1", true),
    ("::1", "::1/128", true),
    ("::1", "::/0", true),
    ("2001:db8:0:0:0:0:0:1", "2001:db8::1", true),
    ("::ffff:192.168.2.123", "::ffff:192.168.2.0/120", true),
    ("2001:db8::1", "192.168.2.0/24", false),
    ("192.168.2.123", "2001:db8::/32", false),
  ]
  for case in cases {
    assert_true(ip_match(case.0, case.1) == case.2)
  }
}

///|
test "ipMatch rejects invalid arguments" {
  match try_ip_match("not-an-ip", "192.168.2.0/24") {
    Err(error) => {
      assert_true(error.kind() == MatcherEval)
      assert_true(error.message().contains("is not an IP address"))
    }
    Ok(_) => fail("expected a MatcherEval error")
  }
  match try_ip_match("192.168.2.123", "192.168.2.0/33") {
    Err(error) =>
      assert_true(error.message().contains("neither an IP address nor a CIDR"))
    Ok(_) => fail("expected a MatcherEval error")
  }
  match try_ip_match("192.168.2.123", "192.168.2.256") {
    Err(error) =>
      assert_true(error.message().contains("neither an IP address nor a CIDR"))
    Ok(_) => fail("expected a MatcherEval error")
  }
  match try_ip_match("010.1.1.1", "10.0.0.0/8") {
    Err(_) => ()
    Ok(_) => fail("expected leading zeros to be rejected")
  }
}

///|
fn try_ip_match(ip1 : String, ip2 : String) -> Result[Bool, CasbinError] {
  Ok(ip_match(ip1, ip2)) catch {
    error => Err(error)
  }
}
