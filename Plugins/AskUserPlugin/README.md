# AskUserPlugin

提供 `ask_user` 工具，让 LLM 可以向用户提问并等待回答。

- **是/否选择**：`question` + 默认 options `["是", "否"]`
- **多选项选择**：`question` + `options`
- **自由输入**：`allow_free_input: true`，允许用户输入任意文本

## 工作流程

1. LLM 调用 `ask_user` 工具
2. 工具立即返回 `__ASK_USER_PENDING__` 前缀 + JSON payload
3. `AgentTurnRunner` 执行工具后检测到该前缀（`LumiAskUserMarkers.isPendingResponse`），
   把该 turn 标记为 `.awaitingUserResponse` 并暂停循环
4. `AskUserPlugin` 通过 `onTurnFinished` 钩子感知到暂停（内核在 turn 结束时分发该钩子）
5. 渲染器（`AskUserRowRenderer`，由 `onReady` 注册到 `ToolCallRowRendererRegistry`）
   根据 `verbosity` 路由到 `Brief` / `Standard` / `Detailed` view
6. 用户点击选项，调用 `AskUserBridge.shared.resume(...)` 发送 `.lumiAskUserDidAnswer` 通知
7. `AskUserAnswerObserver` 监听通知，把 pending 的 tool result 回写成真实答案，
   然后再次调用 `AgentTurnRunner.runTurn` 恢复 Agent 循环
8. LLM 收到用户回答作为 tool result，继续处理

## 核心组件

| 组件 | 职责 |
|---|---|
| `AskUserTool` | 工具实现（原生 `LumiAgentTool`），生成 pending JSON payload |
| `AskUserRowRenderer` | ToolCall 行级渲染器，按 verbosity 分发视图 |
| `AskUserBriefView` / `StandardView` / `DetailedView` | 三种 verbosity 的 SwiftUI 视图 |
| `AskUserBridge` | 恢复回调桥接，渲染器点击 → 发 `.lumiAskUserDidAnswer` 通知 |
| `AskUserAnswerObserver` | 监听用户回答，回写 tool result 并恢复 turn |
| `AskUserPlugin` | 插件入口（`policy = .alwaysOn`），`onBoot` 注册工具 + observer，`onReady` 注册渲染器 |

## 测试

测试位于 `Tests/`，使用 Swift Testing 框架。运行：

```bash
swift test --package-path Plugins/AskUserPlugin
```

**当前状态：79 个测试，22 个 suite，全部通过。**

### 覆盖矩阵

| 文件 | Suite | 测试数 | 覆盖范围 |
|---|---|---:|---|
| `AskUserToolTests.swift` | `AskUserToolInputSchemaTests` | 7 | schema 类型 / 必需字段 |
| | `AskUserToolDisplayDescriptionTests` | 3 | displayDescription 截断 / fallback |
| | `AskUserToolRiskLevelTests` | 1 | 风险等级 |
| | `AskUserToolInfoTests` | 3 | info / description / pending 前缀契约 |
| | `AskUserToolExecuteTests` | 9 | execute 正常路径 + error path |
| | `AskUserToolErrorResultTests` | 2 | errorResult 前缀 / 内容 |
| | `AskUserResponseModelTests` | 2 | Codable 双向 |
| | `AskUserToolResolvedOptionsTests` | 7 | options 归一化（空 / 缺失 / 非 [String] / 顺序 / 重复） |
| | `AskUserToolResolvedAllowFreeInputTests` | 5 | allowFreeInput 归一化（默认 false / 宽松 bool 解析） |
| | `AskUserToolDefaultOptionsTests` | 2 | defaultOptions 不变量 |
| | `AskUserToolBuildPendingResponseTests` | 4 | verbosity 六档透传 / nil fallback / 空 options |
| | `AskUserToolEncodePayloadTests` | 3 | pretty JSON / round-trip / error payload |
| | `AskUserToolErrorResultPayloadTests` | 2 | error JSON 解析 / 幂等性 |
| `AskUserBridgeTests.swift` | `AskUserBridgeResumeTests` | 5 | resume handler 设置 / 替换 / 清除 / 调用 / nil 安全 |
| | `AskUserBridgeSharedInstanceTests` | 2 | 单例恒等 |
| `AskUserPluginTests.swift` | `AskUserPluginInfoTests` | 3 | id / name / order |
| | `AskUserPluginPropertiesTests` | 1 | policy == .alwaysOn |
| `AskUserRowRendererTests.swift` | `AskUserRowRendererParsePendingResponseTests` | 7 | 解析边界（prefix / 空 / 损坏 JSON / 缺字段 / 合法） |
| | `AskUserRowRendererCanRenderTests` | 4 | canRender 双条件（name + awaiting） |
| | `AskUserRowRendererIdentityTests` | 2 | id / priority 不变量 |
| | `AskUserRowRendererRenderRouteTests` | 6 | verbosity 路由 / 占位 fallback |
| | `AskUserRowRendererRoundTripTests` | 2 | execute → render 端到端 / isPendingResponse helper |

### 未覆盖范围

- **SwiftUI 视图交互**：`AskUserBriefView` / `StandardView` / `DetailedView` 的按钮点击
  触发 `AskUserBridge.resume` 的端到端交互。`AskUserBridge` 本身有完整测试覆盖；
  视图层依赖 SwiftUI 反射框架（如 ViewInspector），仓库目前未引入。
- **内核闭环集成**：`AgentTurnRunner` 的 pending 暂停、`onTurnFinished` 分发、
  `AskUserAnswerObserver` 回写 + 恢复 turn 属于跨插件/内核行为，需在 app 级集成测试中验证。

## 关键设计

### 渲染器 verbosity 路由

`AskUserRowRenderer.render(toolCall:message:)` 根据 `response.verbosity`（来自
`LumiToolExecutionContext.verbosity`）路由：

| verbosity | view |
|---|---|
| `v1` / `brief` | `AskUserBriefView` |
| `v2` / `standard`（默认） | `AskUserStandardView` |
| `v3` / `detailed` | `AskUserDetailedView` |
| 其他 / 未知 | `AskUserStandardView`（fallback） |

`context.verbosity == nil` 时，`AskUserTool.buildPendingResponse` 默认填充
`LumiResponseVerbosity.defaultVerbosity.rawValue`（当前为 `"v2"` / standard）。

### 渲染器注册

`AskUserPlugin.onReady(kernel:)` 调用
`ToolCallRowRendererRegistry.shared.register(AskUserRowRenderer())` 完成注册。
`ToolCallRowRendererRegistry` 按 `id` 去重（重复 register 会替换而非 append），
`MessageRendererPlugin` 在渲染每个 toolCall 时通过 `findRenderer` 查询。
