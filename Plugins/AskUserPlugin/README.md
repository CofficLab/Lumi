# AskUserPlugin

提供 `ask_user` 工具，让 LLM 可以向用户提问并等待回答。

- **是/否选择**：`question` + 默认 options `["是", "否"]`
- **多选项选择**：`question` + `options`
- **自由输入**：`allow_free_input: true`，允许用户输入任意文本

## 工作流程

1. LLM 调用 `ask_user` 工具
2. 工具立即返回 `__ASK_USER_PENDING__` 前缀 + JSON payload
3. `ToolCallExecutor` 识别前缀，设置 `awaitingUserResponse = true`
4. `AgentTurnService` 检测到暂停循环
5. 渲染器（`AskUserRowRenderer`）根据 `verbosity` 路由到 `Brief` / `Standard` / `Detailed` view
6. 用户点击选项，调用 `AskUserBridge.shared.resume(...)` 写回结果并恢复 Agent 循环
7. LLM 收到用户回答作为 tool result，继续处理

## 核心组件

| 组件 | 职责 |
|---|---|
| `AskUserTool` | 工具实现，生成 pending JSON payload |
| `AskUserRowRenderer` | ToolCall 行级渲染器，按 verbosity 分发视图 |
| `AskUserBriefView` / `StandardView` / `DetailedView` | 三种 verbosity 的 SwiftUI 视图 |
| `AskUserBridge` | 恢复回调桥接，渲染器 → ChatService |
| `AskUserPlugin` | 插件入口，注册工具 + 渲染器 |

## 测试

测试位于 `Tests/`，使用 Swift Testing 框架。运行：

```bash
swift test --package-path Plugins/AskUserPlugin
```

**当前状态：117 个测试，32 个 suite，全部通过。**

### 覆盖矩阵

| 文件 | Suite | 测试数 | 覆盖范围 |
|---|---|---:|---|
| `AskUserToolTests.swift` | `AskUserToolInputSchemaTests` | 6 | schema 类型 / 必需字段 |
| | `AskUserToolDisplayDescriptionTests` | 3 | displayDescription 截断 / fallback |
| | `AskUserToolRiskLevelTests` | 1 | 风险等级 |
| | `AskUserToolDescriptionTests` | 2 | 中英文 description |
| | `AskUserToolNameTests` | 2 | 工具名 / pending 前缀契约 |
| | `AskUserToolExecuteTests` | 9 | execute 正常路径 + error path |
| | `AskUserToolErrorResultTests` | 2 | errorResult 前缀 / 内容 |
| | `AskUserResponseModelTests` | 2 | Codable 双向 |
| | `AskUserToolResolvedOptionsTests` | 7 | options 归一化（空 / 缺失 / 非 [String] / 顺序 / 重复） |
| | `AskUserToolResolvedAllowFreeInputTests` | 5 | allowFreeInput 归一化（默认 false / 非 Bool 回退） |
| | `AskUserToolDefaultOptionsTests` | 2 | defaultOptions 不变量 |
| | `AskUserToolBuildPendingResponseTests` | 4 | verbosity 六档透传 / nil fallback / 空 options |
| | `AskUserToolEncodePayloadTests` | 3 | pretty JSON / round-trip / error payload |
| | `AskUserToolErrorResultPayloadTests` | 2 | error JSON 解析 / 幂等性 |
| `AskUserBridgeTests.swift` | `AskUserBridgeResumeTests` | 5 | resume handler 设置 / 替换 / 清除 / 调用 / nil 安全 |
| | `AskUserBridgeSharedInstanceTests` | 2 | 单例恒等 |
| `AskUserPluginTests.swift` | `AskUserPluginInfoTests` | 4 | info 字段 |
| | `AskUserPluginPropertiesTests` | 3 | policy / category / icon |
| | `AskUserPluginAgentToolsTests` | 2 | agentTools 返回 AskUserTool |
| | `AskUserPluginConfigureResumeTests` | 3 | configureAskUserResume 注入 / 错误 UUID 忽略 |
| `AskUserRowRendererTests.swift` | `AskUserRowRendererParsePendingResponseTests` | 7 | 解析边界（prefix / 空 / 损坏 JSON / 缺字段 / 合法） |
| | `AskUserRowRendererCanRenderTests` | 4 | canRender 双条件（name + awaiting） |
| | `AskUserRowRendererIdentityTests` | 2 | id / priority 不变量 |
| | `AskUserRowRendererRenderRouteTests` | 6 | verbosity 路由 / 占位 fallback |
| | `AskUserPluginOneShotRegistrationTests` | 2 | 一次性注册 / messageRenderers 返回空 |
| | `AskUserRowRendererRoundTripTests` | 2 | execute → render 端到端 / isPendingResponse helper |
| `AskUserToolBridgeTests.swift` | `AskUserToolBridgeIdentityTests` | 3 | bridge.name / description / inputSchema |
| | `AskUserToolBridgeExecuteTests` | 7 | 参数透传（options / allowFreeInput / toolCallId / verbosity） |
| | `AskUserToolBridgeErrorPathTests` | 4 | error prefix / 缺失 / 空 / 非 String / JSON 解析 |
| | `AskUserToolBridgeRiskLevelTests` | 3 | 风险等级透传 |
| | `AskUserToolBridgeDisplayDescriptionTests` | 4 | displayDescription 透传 + 截断 + fallback |
| | `AskUserToolBridgeContextConversionTests` | 3 | context 字段透传（id / verbosity 六档） |

### 未覆盖范围

- **SwiftUI 视图交互**（Task 7 跳过）：`AskUserBriefView` / `StandardView` / `DetailedView` 的按钮点击
  触发 `AskUserBridge.resume` 的端到端交互。`AskUserBridge` 本身有完整测试覆盖；
  视图层依赖 SwiftUI 反射框架（如 ViewInspector），仓库目前未引入。
- **PluginService 集成**：插件注册到主 app 的路径（`PluginService.messageRenderers` 链
  `AskUserPlugin.messageRenderers` → `ToolCallRowRendererRegistry`）已在
  `AskUserPluginOneShotRegistrationTests` 中覆盖其注册副作用。

## 关键设计

### 渲染器 verbosity 路由

`AskUserRowRenderer.render(toolCall:message:)` 根据 `response.verbosity`（来自
`ToolExecutionContext.verbosity`）路由：

| verbosity | view |
|---|---|
| `v1` / `brief` | `AskUserBriefView` |
| `v2` / `standard`（默认） | `AskUserStandardView` |
| `v3` / `detailed` | `AskUserDetailedView` |
| 其他 / 未知 | `AskUserStandardView`（fallback） |

`context.verbosity == nil` 时，`AskUserTool.buildPendingResponse` 默认填充 `"standard"`。

### 一次性渲染器注册

`AskUserPlugin.messageRenderers(context:)` 用 `didConfigureRenderer` 静态标志位
确保 `ToolCallRowRendererRegistry.shared.register(AskUserRowRenderer())` 只调用一次。
`ToolCallRowRendererRegistry` 本身也按 `id` 去重（重复 register 会替换而非 append），
两道防线保证渲染器只占一个槽位。
