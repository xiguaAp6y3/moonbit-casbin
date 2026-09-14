# Third-Party Notices

## Reference project

- **casbin/casbin** — https://github.com/casbin/casbin — Apache-2.0.

  moonbit-casbin follows the Casbin model configuration format
  (`[request_definition]`, `[policy_definition]`, `[role_definition]`,
  `[policy_effect]`, `[matchers]`) and its authorization semantics as
  documented by the Casbin project. The implementation is written from
  scratch in MoonBit; no Go source code is copied or translated. When
  behavior is verified against Casbin's public test cases, the ported test
  data will be listed here with its origin and scope.

## Runtime dependencies

None beyond the MoonBit standard library (`moonbitlang/core`), which is
distributed under the Apache-2.0 license by MoonBit.

## Scope of this notice

This project does not copy, translate, or rewrite any third-party
authorization engine implementation in another language. Model-format
compatibility and semantic parity are implemented against the public
documentation of the reference project named above.
