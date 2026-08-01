# SubAgentProviderPlugin

提供一组**继承主 Agent 当前选中供应商/模型**的内置通用子 Agent。

## 为什么需要这个插件

Lumi 的子 Agent 体系（`delegate_task` 工具）由各插件通过 `LumiPlugin.subAgents(kernel:)` 贡献。在此之前，只有 `LLMProviderStepFunPlugin` 贡献了子 Agent，并且：

1. 每个 StepFun 子 Agent 的 `providerID`/`modelID` 被硬编码为 `stepfun` / `step-3.7-flash`；
2. 注入受一个可用性探测门控（`StepFunSubAgentsGate`），探测不通过就一个子 Agent 都不返回。

也就是说，**StepFun 一旦不可用，主 Agent 就完全没有子 Agent 可用**。

本插件解决这个问题：它贡献一组与具体供应商解耦的通用子 Agent（探索、代码审查、修 bug、写测试），通过 `LumiSubAgentDefinition.inheritsSelectedProvider = true`，让它们在执行时使用**主 Agent 当前选中的供应商和模型**。这样只要用户选了任意支持工具调用的模型，就永远有子 Agent 可用，不依赖任何特定供应商。

## 内置子 Agent

| id | displayName | 用途 |
|---|---|---|
| `builtin-explore` | Explore | 只读探索：定位文件、阅读实现、追踪架构 |
| `builtin-code-review` | Code Review | 代码审查，找出问题/风险/回归 |
| `builtin-bugfixer` | Bug Fixer | 调试并修复 bug |
| `builtin-test-writer` | Test Writer | 编写/补充测试 |

它们经 `SubAgentRouterTool`（`delegate_task`）的关键词路由自动派发，关键词命中 `explore`/`review`/`fix`/`bug`/`test` 时会被选中。

## 工作机制

- 定义里 `providerID`/`modelID` 留空（占位），`inheritsSelectedProvider = true`。
- 运行时由 `SubAgentDelegateTool.runDelegate` 读取 `LLMProviderManaging.selectedProviderID` / `selectedModel` 现查现用，因此用户切换模型后立即生效。
- 若当前没有选中供应商/模型，或选中模型不支持工具调用，子 Agent 会返回清晰的错误提示，由主 Agent 转告用户。

## 与 StepFun 子 Agent 的关系

两者共存、互不干扰：

- routingID 是 `"\(providerID):\(id)"`。StepFun 的探索 Agent 是 `stepfun:explore`，本插件的是 `:builtin-explore`，不会撞名。
- 本插件的 id 统一加 `builtin-` 前缀，避免在 `delegate_task` 按 id 路由时与 StepFun 同名 Agent 产生歧义。
