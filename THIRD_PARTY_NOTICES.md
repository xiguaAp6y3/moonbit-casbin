# Third-Party Notices

## Reference project

- **casbin/casbin** — https://github.com/casbin/casbin — Apache-2.0.

  moonbit-casbin follows the Casbin model configuration format
  (`[request_definition]`, `[policy_definition]`, `[role_definition]`,
  `[policy_effect]`, `[matchers]`) and its authorization semantics as
  documented by the Casbin project. The implementation is written from
  scratch in MoonBit; no Go source code is copied or translated.

## Ported test data

- **`keyMatch` / `keyGet` case tables** — ported from Casbin's
  `util/builtin_operators_test.go` (Apache-2.0). The input/expected-value
  pairs are reproduced in `functions_test.mbt` to verify behavioral
  parity. Only the test tables are reproduced; no implementation code is
  copied.
- **`EscapeAssertion` / `RemoveComments` case tables** — ported from
  Casbin's `util/util_test.go` (Apache-2.0) into `preprocess_test.mbt`.
  Again only the input/expected-value tables are reproduced.
- **RBAC model and policy examples, role API chain** — Casbin's
  `examples/rbac_model.conf`, `examples/rbac_policy.csv`,
  `examples/rbac_with_domains_model.conf` and the `TestRoleAPI` /
  `TestImplicitPermissionAPI` sequences from `rbac_api_test.go`
  (Apache-2.0) are reproduced as fixtures and expectations in
  `rbac_api_test.mbt`.
- **Extended operator case tables** — the `TestKeyMatch2`, `TestKeyMatch3`,
  `TestKeyMatch4`, `TestKeyMatch5`, `TestKeyGet2`, `TestKeyGet3`,
  `TestRegexMatch`, `TestGlobMatch`, and `TestIPMatch` tables from Casbin's
  `util/builtin_operators_test.go` (Apache-2.0) are reproduced in
  `builtin_operators_test.mbt` and `ip_test.mbt`. Only the test tables are
  reproduced; the operators are implemented from the documented rewrite
  rules, not translated from the Go source.
- Further Casbin test cases will be listed here as they are ported.

## Runtime dependencies

- **moonbitlang/core** — Apache-2.0, the MoonBit standard library.
- **moonbitlang/regexp@0.3.5** — Apache-2.0,
  https://github.com/moonbitlang/regexp.mbt. The official MoonBit regular
  expression engine, used by the `regexMatch`, `keyMatch2`..`keyMatch5`,
  `keyGet2` / `keyGet3`, and `globMatch` operators. Consumed as a
  dependency; no code is copied from it.

## Scope of this notice

This project does not copy, translate, or rewrite any third-party
authorization engine implementation in another language. Model-format
compatibility and semantic parity are implemented against the public
documentation of the reference project named above.
