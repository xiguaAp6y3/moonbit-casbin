# moonbit-casbin

Casbin-style authorization engine in MoonBit: model-driven policy
configuration, matcher and effect evaluation, RBAC role hierarchy, and an
in-memory policy store.

> **Project/module**: `xiguaAp6y3/moonbit-casbin`
> **Repository**: https://github.com/xiguaAp6y3/moonbit-casbin
> **Version**: 0.1.0
> **License**: Apache-2.0

## 中文项目介绍

`moonbit-casbin` 是使用 MoonBit 实现的 [Casbin] 风格授权引擎。它按照与
Casbin 相同的模型配置格式（`[request_definition]`、`[policy_definition]`、
`[role_definition]`、`[policy_effect]`、`[matchers]`）加载授权模型，并自带
matcher 表达式求值引擎；后续将提供访问决策 API（`enforce`）、策略存储与
管理接口。

当前已实现：

- **配置解析**：完整解析 Casbin 模型文件的小型 INI 方言，支持 `#` / `;`
  注释、空行、重复节合并、重复键按声明顺序保留、CRLF 换行；
- **模型加载**：把配置装载为请求定义、策略定义、角色定义、策略 effect 与
  matcher 断言，校验必需的节和取值（定义键前缀、token 标识符、effect 唯一性）；
- **Matcher 表达式引擎**：自研词法器、Pratt 解析器与树遍历求值器，支持
  比较、`&&` / `||`（短路）、`in` 列表、字段访问、算术与字符串拼接；
  函数注册表可通过 `FunctionRegistry::add` 扩展；语法错误携带字符偏移；
- **判定链路**：`r.sub` → `r_sub` 等预处理、内存策略存储（保序 + 去重）、
  CSV 策略解析（RFC 4180 引号子集）、5 种 effect 聚合
  （allow-override / deny-override / allow-and-deny / priority /
  subjectPriority）、`Enforcer::enforce` 逐行匹配与提前终止；
- **内置函数**：`keyMatch`、`keyGet`，用例表对齐 Casbin 官方测试；
- **结构化错误**：配置/模型/策略/匹配表达式/判定六类错误分类
  （`ConfigSyntax`、`ModelValidation`、`PolicySyntax`、`MatcherSyntax`、
  `MatcherEval`、`Enforcement`），语法错误携带行号或字符偏移；
- **零依赖**：仅依赖 MoonBit 标准库，`wasm` / `wasm-gc` / `js` / `native`
  四目标通过检查、构建与测试；
- **持续集成**：GitHub Actions 严格流水线（格式检查、`--deny-warn` 检查、
  四目标构建与测试、打包清单）。

## English Summary

`moonbit-casbin` is a Casbin-style authorization engine implemented in
MoonBit. It loads the Casbin model configuration format (request, policy,
and role definitions, policy effect, matchers), ships its own matcher
expression engine (lexer, Pratt parser, tree-walking evaluator with
short-circuit logic, `in` lists, field access, and an extensible function
registry), and enforces requests end to end: accessor preprocessing,
an in-memory policy store, a CSV policy adapter, the five Casbin policy
effects, and `Enforcer::enforce` with per-row matching and early
termination. It will grow into a full library with RBAC role hierarchy,
management APIs, and the regex/glob/IP built-ins. It is **not** a port of
the Casbin Go source code; the model format and semantics are
reimplemented from the public documentation. The library depends only on
the MoonBit standard library and passes check, build, and test on `wasm`,
`wasm-gc`, `js`, and `native`.

## Casbin 简介

Casbin 是一个广泛使用的授权库，把访问控制策略从业务代码中抽离为模型
（model）与策略（policy）两部分：

- **模型**描述"如何判断"：请求参数（`r = sub, obj, act`）、策略参数
  （`p = sub, obj, act`）、角色定义（`g = _, _`）、匹配表达式
  （`m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act`）以及
  聚合方式（`e = some(where (p.eft == allow))`）；
- **策略**描述"判断什么"：一行行具体规则，例如
  `p, alice, data1, read`、`g, alice, admin`。

同一个模型可以支撑 ACL、RBAC、ABAC 等不同授权风格，切换风格通常只需换
模型文件，不改业务代码。参考实现见 [casbin/casbin]。

## 项目价值

- 为 MoonBit 补齐模型驱动的授权基础件：Web 框架、服务框架与工具类项目
  可以复用同一套模型与策略语义，避免各自造轮子；
- 与 Casbin 生态格式兼容：现有模型文件和策略文件的组织方式可以直接沿用，
  迁移成本低；
- 结构化错误与显式校验：配置错误在加载期暴露，并给出可定位的行号；
- 多后端可用：核心库不依赖宿主能力，可编译到 `wasm` / `wasm-gc` / `js` /
  `native`，适合服务端与边缘场景。

## 功能支持矩阵

| 功能 | 状态 |
| --- | --- |
| 模型配置解析（INI 方言、注释、重复节、CRLF） | 已实现并测试 |
| 模型加载与校验（`r` / `p` / `g` / `e` / `m`） | 已实现并测试 |
| Matcher 表达式求值（词法 / Pratt 语法 / 短路求值 / 函数注册表） | 已实现并测试 |
| 判定链路（预处理 / 策略校验 / 逐行匹配 / 提前终止） | 已实现并测试 |
| 策略 effect（allow-override / deny-override / allow-and-deny / priority / subjectPriority） | 已实现并测试 |
| 内存策略存储（保序、去重）与 CSV 策略解析 | 已实现并测试 |
| 内置函数 `keyMatch`、`keyGet` | 已实现并测试 |
| 结构化错误（六类错误 + 行号或偏移） | 已实现并测试 |
| RBAC 角色层级与角色域（`g` / `g2`、domain） | 计划中 |
| 策略与角色管理 API（`add_policy`、`add_role_for_user` 等） | 计划中 |
| 内置函数 `keyMatch2`..`keyMatch5`、`regexMatch`、`globMatch`、`ipMatch` | 计划中 |
| CLI 工具 | 计划中 |

## 不支持内容

当前代码（v0.2 开发中）**不包含**：

- RBAC 角色管理（`g` 函数注入、角色层级与角色域）；
- 策略与角色的增删管理 API（判定链路本身已可用，但策略只能整体加载）；
- 正则 / glob / IP 类内置匹配函数（`regexMatch`、`keyMatch2`..`keyMatch5`、
  `globMatch`、`ipMatch`）；
- `eval()` 内置函数、条件角色（temporal roles）与 `EnforceContext`；
- 持久化适配器（数据库、Redis 等）与 Watcher；
- 分布式部署、过滤器策略加载与自适应策略；
- 策略管理 HTTP 接口或 Dashboard。

上表"计划中"的能力按 `Roadmap` 逐步实现；在实现之前，README 与发布说明
不会声称支持。

## 本地使用方式

环境要求：MoonBit 工具链（含 `wasm` / `wasm-gc` / `js` / `native` 目标）。

```sh
git clone https://github.com/xiguaAp6y3/moonbit-casbin.git
cd moonbit-casbin
moon test
```

四目标严格验证（与 CI 相同）：

```sh
moon fmt --check
moon check --target all --deny-warn
moon build --target all
moon test --target all --deny-warn
```

## 快速开始

加载一个 RBAC 模型（`rbac_model.conf` 的内容与 Casbin 官方示例一致）：

```moonbit
let text =
  #|[request_definition]
  #|r = sub, obj, act
  #|
  #|[policy_definition]
  #|p = sub, obj, act
  #|
  #|[role_definition]
  #|g = _, _
  #|
  #|[policy_effect]
  #|e = some(where (p.eft == allow))
  #|
  #|[matchers]
  #|m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act

let model = Model::from_config(Config::parse(text).unwrap()).unwrap()
let request = model.request_definition("r").unwrap()
// request.tokens() == ["sub", "obj", "act"]
let role = model.role_definition("g").unwrap()
// role.tokens() == ["_", "_"]
```

错误处理：`Config::parse` 只返回 `ConfigSyntax`，`Model::from_config` 只返回
`ModelValidation`，错误携带可读描述与行号（如适用）。

```moonbit
match Config::parse("r = sub, obj, act") {
  Err(error) => {
    // error.kind() == ConfigSyntax
    // error.line() == 1
    // error.message() == "entry outside of any section"
  }
  Ok(_) => ()
}
```

Matcher 表达式引擎可以独立使用。标识符是 Casbin 预处理后的名字
（`r.sub` 写作 `r_sub`），求值时的取值方式由调用方提供：

```moonbit
let value = parse_matcher("keyMatch(r_obj, p_obj) && !denied")
  .unwrap()
  .eval(
    (name) =>
      match name {
        "r_obj" => Some(Value::String("/foo/bar"))
        "p_obj" => Some(Value::String("/foo/*"))
        "denied" => Some(Value::Bool(false))
        _ => None
      },
    builtin_functions(),
  )
  .unwrap()
// value == Value::Bool(true)
```

端到端判定：模型 + 策略文本 → `enforce`。

```moonbit
let model_text =
  #|[request_definition]
  #|r = sub, obj, act
  #|
  #|[policy_definition]
  #|p = sub, obj, act
  #|
  #|[policy_effect]
  #|e = some(where (p.eft == allow))
  #|
  #|[matchers]
  #|m = r.sub == p.sub && r.obj == p.obj && r.act == p.act

let model = Model::from_config(Config::parse(model_text).unwrap()).unwrap()
let enforcer = Enforcer::new(model).unwrap()
let policy =
  #|p, alice, data1, read
  #|p, bob, data2, write
enforcer.load_policy_from_text(policy).unwrap()
assert_true(enforcer.enforce(["alice", "data1", "read"]).unwrap())
assert_true(!enforcer.enforce(["alice", "data1", "write"]).unwrap())
```

## 开发与验证

```sh
moon check --target all --deny-warn   # 清零警告的严格检查
moon fmt                              # 格式化
moon test --target all --deny-warn    # 四目标测试
moon package --list                   # 打包清单
```

## 测试结果

- 具名测试：71 个（配置解析 10、模型加载 8、词法 5、语法 6、求值 8、
  内置函数 5、预处理 4、effect 5、策略存储 4、CSV 适配器 4、判定 12）；
- `keyMatch` / `keyGet` 用例表与 `EscapeAssertion` / `RemoveComments`
  用例表移植自 Casbin 官方测试，逐项来源见 `THIRD_PARTY_NOTICES.md`；
- `wasm` / `wasm-gc` / `js` / `native` 四目标：`check` / `build` / `test`
  均通过，0 errors，0 warnings。

## 目录结构

```
├── .github/workflows/       CI 与发布流水线
├── error.mbt                结构化错误类型
├── config.mbt               模型配置解析
├── model.mbt                模型加载与校验
├── preprocess.mbt           matcher/effect 文本预处理
├── value.mbt                求值器的运行时值模型
├── expr.mbt                 matcher 表达式 AST
├── lexer.mbt                matcher 词法器
├── parser.mbt               matcher Pratt 解析器
├── eval.mbt                 matcher 求值器
├── functions.mbt            函数注册表与内置函数
├── effect.mbt               policy effect 与效果聚合
├── policy.mbt               内存策略存储
├── adapter_csv.mbt          CSV 策略解析
├── enforcer.mbt             判定核心
├── *_test.mbt               黑盒测试（含 lexer_wbtest.mbt 白盒测试）
├── moon.mod / moon.pkg      模块清单
└── LICENSE / README.md
```

## Roadmap

- v0.1：配置解析、模型加载、结构化错误、CI。
- v0.2（开发中）：matcher 表达式引擎、判定链路（预处理、策略存储、CSV
  适配器、effect 聚合、`enforce`）已完成；RBAC 角色管理与策略管理 API
  进行中。
- v0.3：RBAC 角色层级与角色域、策略与角色管理 API。
- v0.4：内置匹配函数补齐（`keyMatch2`..`keyMatch5`、`regexMatch`、
  `globMatch`、`ipMatch`）、CLI 工具、示例工程。

这些是未来计划，尚未完成。

## 移植说明

- 参考项目名称：Casbin（`casbin/casbin`）；
- 原项目链接：https://github.com/casbin/casbin ；
- 原项目许可证：Apache-2.0；
- 本项目许可证：Apache-2.0；
- 参考范围：模型配置格式与判定语义按 Casbin 公开文档重新实现，不复制
  Go 源码；`keyMatch` / `keyGet` 的用例表已移植自 Casbin 官方测试
  （`util/builtin_operators_test.go`），逐项来源与范围见
  `THIRD_PARTY_NOTICES.md`。

## 发布状态

截至项目立项时对 MoonBit 生态的公开检索（GitHub `language:moonbit` 仓库与
mooncakes.io 注册表），未发现 Casbin 风格授权引擎的完整实现。**这不是绝对
保证**，仅代表立项时检索到的公开信息。

## License

Apache-2.0，见 [LICENSE](LICENSE)。

[Casbin]: https://casbin.org/
[casbin/casbin]: https://github.com/casbin/casbin
