# SubAgentProviderPlugin

提供一组**继承主 Agent 当前选中供应商/模型**的内置通用子 Agent。

## 为什么需要这个插件

本插件暂时保留通用子 Agent 定义，后续将改造为通过 AgentTool 调用 Kernel 的 `AgentTurnManaging.createTurn`。旧的 `delegate_task` 路由执行机制已经移除。

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

这些定义暂时只作为后续 AgentTool 改造的输入，不会被当前 Kernel 自动注册或执行。

## 工作机制

- 定义里 `providerID`/`modelID` 留空（占位），`inheritsSelectedProvider = true`。
- 后续 AgentTool 将在创建 Turn 时决定 provider/model 继承策略。
- 若当前没有选中供应商/模型，或选中模型不支持工具调用，子 Agent 会返回清晰的错误提示，由主 Agent 转告用户。

## 与 StepFun 子 Agent 的关系

两者共存、互不干扰：

- routingID 是 `"\(providerID):\(id)"`。StepFun 的探索 Agent 是 `stepfun:explore`，本插件的是 `:builtin-explore`，不会撞名。
- 本插件的 id 统一加 `builtin-` 前缀，供后续 AgentTool 路由和展示使用。
