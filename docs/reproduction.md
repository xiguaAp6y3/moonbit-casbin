# 复现指南

## 环境

- MoonBit 0.10.7 或更高版本；
- 可用的 `wasm`、`wasm-gc`、`js` 和 `native` 目标。

## 获取与依赖

```sh
git clone https://github.com/xiguaAp6y3/moonbit-casbin.git
cd moonbit-casbin
moon update
```

## 严格验证

```sh
moon fmt --check
moon check --target all --deny-warn
moon build --target all
moon test --target all --deny-warn
moon package --list
```

## 运行示例

```sh
moon run examples/quickstart
moon run examples/matchers
```

示例分别覆盖 ACL/RBAC 管理 API，以及 `keyMatch2`、`regexMatch`、`ipMatch` 和 `globMatch`。

GitHub Actions 在每次 push 和 pull request 中运行相同的严格检查，并执行两个示例。
