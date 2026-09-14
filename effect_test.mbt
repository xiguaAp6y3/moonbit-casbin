// effect_test.mbt — Tests for effect expressions and effect merging.

///|
test "effect expressions parse canonically" {
  assert_true(
    EffectExpression::parse("some(where (p_eft == allow))") ==
    Some(AllowOverride),
  )
  assert_true(
    EffectExpression::parse("!some(where (p_eft == deny))") ==
    Some(DenyOverride),
  )
  assert_true(
    EffectExpression::parse(
      "some(where (p_eft == allow)) && !some(where (p_eft == deny))",
    ) ==
    Some(AllowAndDeny),
  )
  assert_true(
    EffectExpression::parse("priority(p_eft) || deny") == Some(Priority),
  )
  assert_true(
    EffectExpression::parse("subjectPriority(p_eft) || deny") ==
    Some(SubjectPriority),
  )
  assert_true(EffectExpression::parse("some(where (p.eft == allow))") == None)
  assert_true(EffectExpression::parse("nonsense") == None)
}

///|
test "allow override decides on the current row only" {
  let effects : Array[Effect] = [Allow, Indeterminate]
  let matches : Array[Bool] = [true, false]
  assert_true(
    merge_effects(AllowOverride, effects, matches, 0, 2) == (Allow, 0),
  )
  assert_true(
    merge_effects(AllowOverride, effects, matches, 1, 2) == (Indeterminate, -1),
  )
  let undecided : Array[Effect] = [Indeterminate]
  let undecided_matches : Array[Bool] = [true]
  assert_true(
    merge_effects(AllowOverride, undecided, undecided_matches, 0, 1) ==
    (Indeterminate, -1),
  )
}

///|
test "deny override allows when the last row has no deny" {
  let effects : Array[Effect] = [Allow, Allow]
  let matches : Array[Bool] = [true, false]
  assert_true(
    merge_effects(DenyOverride, effects, matches, 0, 2) == (Indeterminate, -1),
  )
  assert_true(
    merge_effects(DenyOverride, effects, matches, 1, 2) == (Allow, -1),
  )
  let denied : Array[Effect] = [Indeterminate, Deny]
  let denied_matches : Array[Bool] = [false, true]
  assert_true(
    merge_effects(DenyOverride, denied, denied_matches, 1, 2) == (Deny, 1),
  )
}

///|
test "allow and deny waits for the last row" {
  let effects : Array[Effect] = [Allow, Indeterminate]
  let matches : Array[Bool] = [true, false]
  assert_true(
    merge_effects(AllowAndDeny, effects, matches, 0, 2) == (Indeterminate, -1),
  )
  assert_true(merge_effects(AllowAndDeny, effects, matches, 1, 2) == (Allow, 0))
  let deny_late : Array[Effect] = [Allow, Deny]
  let deny_matches : Array[Bool] = [true, true]
  assert_true(
    merge_effects(AllowAndDeny, deny_late, deny_matches, 1, 2) == (Deny, 1),
  )
}

///|
test "priority scans rows in reverse" {
  // Mirrors the incremental call pattern: rows beyond the current index
  // have not been evaluated yet.
  let effects : Array[Effect] = [Allow, Indeterminate, Indeterminate]
  let matches : Array[Bool] = [true, false, false]
  assert_true(merge_effects(Priority, effects, matches, 0, 3) == (Allow, 0))
  effects[1] = Deny
  matches[1] = true
  assert_true(merge_effects(Priority, effects, matches, 1, 3) == (Deny, 1))
  matches[2] = true
  assert_true(merge_effects(Priority, effects, matches, 2, 3) == (Deny, 1))
  assert_true(
    merge_effects(SubjectPriority, effects, matches, 1, 3) == (Deny, 1),
  )
}
