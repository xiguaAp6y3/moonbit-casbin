# 测试矩阵

本项目当前有 97 个具名测试，覆盖核心授权路径和 Casbin 参考行为表。

| 领域 | 覆盖内容 |
| --- | --- |
| 配置与模型 | INI 节、注释、重复项、token 校验、模型必需节和错误位置 |
| Matcher | 词法、Pratt 解析、比较、算术、字符串、`in`、字段访问和短路 |
| 策略与判定 | CSV 引号、策略去重、5 种 effect、逐行匹配和提前终止 |
| RBAC | 角色层级、域隔离、`g`/`g2` 注入、角色变更和级联删除 |
| 管理 API | 策略与角色增删查、隐式角色、隐式权限和过滤查询 |
| 内置函数 | `keyMatch`、`keyGet`、`regexMatch`、`globMatch`、IPv4/IPv6/CIDR `ipMatch` |
| 错误处理 | 配置、模型、策略、matcher 和 enforcement 错误分类及定位信息 |

## 目标矩阵

| 目标 | check | build | test |
| --- | --- | --- | --- |
| wasm | 通过 | 通过 | 97/97 |
| wasm-gc | 通过 | 通过 | 97/97 |
| js | 通过 | 通过 | 97/97 |
| native | 通过 | 通过 | 97/97 |

## 来源与复现

扩展 matcher、预处理、RBAC 和角色 API 的参考测试来源见 `THIRD_PARTY_NOTICES.md`。本地执行 `moon test --target all --deny-warn` 可重现目标矩阵；CI 还会执行两个可运行示例。
