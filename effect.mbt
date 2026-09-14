// effect.mbt — Policy effect expressions and effect merging.
//
// Casbin resolves a request to a decision by evaluating the matcher once
// per policy row and merging the per-row effects through the expression in
// `[policy_effect]`. The five canonical expressions and the merge rules of
// `DefaultEffector.MergeEffects` are reproduced here; the strings match
// Casbin's constants after `p.eft` has been escaped to `p_eft`.
//
// `merge_effects` is called after each row with the current row index and
// the total row count. `Indeterminate` means "no decision yet, keep
// scanning"; the enforcer stops at the first decisive result. The returned
// index explains which row produced the decision, or `-1`.

///|
/// The decision contributed by one policy row, or by the single-evaluation
/// branch when the matcher does not reference the policy.
pub(all) enum Effect {
  Allow
  /// No decision yet.
  Indeterminate
  Deny
} derive(Eq, Debug)

///|
/// The five policy effect expressions Casbin supports.
pub(all) enum EffectExpression {
  AllowOverride
  DenyOverride
  AllowAndDeny
  Priority
  SubjectPriority
} derive(Eq, Debug)

///|
/// Parses the canonical effect strings; the text must already be
/// preprocessed (`p.eft` escaped to `p_eft`).
pub fn EffectExpression::parse(text : String) -> EffectExpression? {
  match text {
    "some(where (p_eft == allow))" => Some(AllowOverride)
    "!some(where (p_eft == deny))" => Some(DenyOverride)
    "some(where (p_eft == allow)) && !some(where (p_eft == deny))" =>
      Some(AllowAndDeny)
    "priority(p_eft) || deny" => Some(Priority)
    "subjectPriority(p_eft) || deny" => Some(SubjectPriority)
    _ => None
  }
}

///|
/// Merges the effects collected so far for the row at `policy_index`,
/// mirroring `DefaultEffector.MergeEffects`.
///
/// `matches[i]` records whether row `i` satisfied the matcher; `effects[i]`
/// is that row's effect. Both arrays have one entry per policy row.
pub fn merge_effects(
  expression : EffectExpression,
  effects : Array[Effect],
  matches : Array[Bool],
  policy_index : Int,
  policy_length : Int,
) -> (Effect, Int) {
  let mut result = Indeterminate
  let mut explain_index = -1
  match expression {
    AllowOverride =>
      // Only the current row matters.
      if matches[policy_index] && effects[policy_index] == Allow {
        result = Allow
        explain_index = policy_index
      }
    DenyOverride =>
      // A matched deny decides immediately; when the last row produces no
      // deny, everything is allowed.
      if matches[policy_index] && effects[policy_index] == Deny {
        result = Deny
        explain_index = policy_index
      } else if policy_index == policy_length - 1 {
        result = Allow
      }
    AllowAndDeny =>
      if matches[policy_index] && effects[policy_index] == Deny {
        result = Deny
        explain_index = policy_index
      } else if policy_index == policy_length - 1 {
        // Scan everything once at the end and take the first matched allow.
        let mut i = 0
        while i < effects.length() {
          if matches[i] && effects[i] == Allow {
            result = Allow
            explain_index = i
            break
          }
          i += 1
        }
      }
    Priority | SubjectPriority => {
      // Reverse scan of the rows seen so far: the most recent matched row
      // with a definite effect wins, which makes policy order the priority
      // order.
      let mut i = effects.length() - 1
      while i >= 0 {
        if matches[i] && effects[i] != Indeterminate {
          result = if effects[i] == Allow { Allow } else { Deny }
          explain_index = i
          break
        }
        i -= 1
      }
    }
  }
  (result, explain_index)
}
