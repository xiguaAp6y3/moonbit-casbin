# 复现指南

## 环境

- MoonBit 工具链 0.10.20 或更高（2026-11-05 起）；已验证版本：
  `moon 0.1.20261104` / `moonc v0.10.20+65efd5b93` / `moonrun 0.1.20261104`；
- 可用的 `wasm`、`wasm-gc`、`js` 和 `native` 目标；
- 旧版工具链（只认 JSON 清单 `moon.mod.json` 的版本）无法构建本项目，
  `moonbitlang/regexp` 需为 `0.3.7` 或更高的 TOML 清单版本。

安装与更新方式见 <https://www.moonbitlang.com/download/>。安装完成后先确认版本：

```sh
moon version --all
```

Windows 手动安装时，除工具链归档外还需把 `core-<version>.tar.gz` 解压到
`~/.moon/lib` 并在 `~/.moon/lib/core` 下执行
`moon bundle --warn-list -a --all`，否则构建会报
`Cannot inject the standard library moonbitlang/core`。

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

四个目标各 103/103 通过（97 个库测试 + 6 个 README 代码片段测试），0 errors、0 warnings。

## 运行示例

```sh
moon run examples/quickstart
moon run examples/matchers
```

示例分别覆盖 ACL/RBAC 管理 API，以及 `keyMatch2`、`regexMatch`、`ipMatch` 和 `globMatch`。

GitHub Actions 在每次 push 和 pull request 中运行相同的严格检查，并执行两个示例；
流水线固定已验证的工具链版本，另有一条每周定时任务用最新发布版运行同样的检查，
用于提前发现上游兼容性变化。
