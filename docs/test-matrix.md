# 测试矩阵

本项目当前有 97 个具名测试，覆盖核心授权路径和 Casbin 参考行为表；另有
`readme_examples/` 下 6 个 README 代码片段一致性测试，`moon test` 合计 103 个。

| 领域 | 覆盖内容 |
| --- | --- |
| 配置与模型 | INI 节、注释、重复项、token 校验、模型必需节和错误位置 |
| Matcher | 词法、Pratt 解析、比较、算术、字符串、`in`、字段访问和短路 |
| 策略与判定 | CSV 引号、策略去重、5 种 effect、逐行匹配和提前终止 |
| RBAC | 角色层级、域隔离、`g`/`g2` 注入、角色变更和级联删除 |
| 管理 API | 策略与角色增删查、隐式角色、隐式权限和过滤查询 |
| 内置函数 | `keyMatch`、`keyGet`、`regexMatch`、`globMatch`、IPv4/IPv6/CIDR `ipMatch` |
| 错误处理 | 配置、模型、策略、matcher 和 enforcement 错误分类及定位信息 |
| 文档一致性 | `readme_examples/` 重跑 README 五段示例并断言文档声明的 `tokens()`、错误类别/行号/消息与判定结果 |

## 目标矩阵

验证工具链：`moon 0.1.20261104` / `moonc v0.10.20+65efd5b93`（2026-11-05）。

| 目标 | check | build | test |
| --- | --- | --- | --- |
| wasm | 通过 | 通过 | 103/103 |
| wasm-gc | 通过 | 通过 | 103/103 |
| js | 通过 | 通过 | 103/103 |
| native | 通过 | 通过 | 103/103 |

四目标均为 0 errors、0 warnings（`--deny-warn`）。

## 来源与复现

扩展 matcher、预处理、RBAC 和角色 API 的参考测试来源见 `THIRD_PARTY_NOTICES.md`。本地执行 `moon test --target all --deny-warn` 可重现目标矩阵；CI 还会执行两个可运行示例。
