# 架构说明

## 数据流

项目把授权判断拆成五层：配置解析、模型校验、表达式求值、策略与角色管理、判定执行。

1. `config.mbt` 将 Casbin 风格的 INI 文本解析为结构化配置。
2. `model.mbt` 校验 `request_definition`、`policy_definition`、`role_definition`、`policy_effect` 和 `matchers`。
3. `lexer.mbt`、`parser.mbt`、`eval.mbt` 将 matcher 转为 AST 并执行短路求值。
4. `policy.mbt`、`adapter_csv.mbt`、`role_manager.mbt` 和 `management_api.mbt` 管理策略、CSV 输入和角色图。
5. `enforcer.mbt` 预处理请求字段，逐条匹配策略并按 `effect.mbt` 聚合结果。

## 主要边界

核心库只接收模型、策略和请求值，不读写数据库或网络资源，因此可编译到 wasm、wasm-gc、js 和 native。调用方负责持久化策略和注册业务特有的 matcher 函数。

## 错误处理

解析、模型校验、策略、matcher 求值和 enforcement 错误使用结构化错误类型，错误中保留错误类别以及可用的行号或字符偏移，便于调用方定位输入问题。

## 安全与兼容性

项目按 Casbin 公开文档重新实现模型和判定语义，不复制 Casbin Go 源码。参考测试表和依赖许可证记录在 `THIRD_PARTY_NOTICES.md`。当前不支持数据库适配器、Watcher、`eval()` 和角色名模式匹配。
