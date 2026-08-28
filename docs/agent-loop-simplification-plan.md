# AgentLoop 精简重构方案

## 1. 背景

当前 `AgentLoopProviding` 承载了过多职责（约 780 行），既是 LLM 对话调度器，又包含了工具授权判断、工具执行编排、挂起/恢复等逻辑。目标是将其精简为纯粹的 **LLM 对话调度器**，将工具相关逻辑下沉到 `ToolManagerProviding`。

### 当前调用链

```
MessageSendingProviding
  └─ agentLoop.runTurn()
       └─ AgentLoopProviding（780 行）
            ├─ 构造 LLM 请求
            ├─ 流式调用 LLM
            ├─ assistant 消息落库
            ├─ 检测 toolCalls
            ├─ 授权判断（automationLevel: chat/autonomous/build）
            ├─ 逐个调用 toolManager.execute()
            ├─ 工具结果落库
            ├─ 挂起/恢复（工具审批、ask_user）
            └─ 循环直到无工具调用
```

### 目标调用链

```
MessageSendingProviding
  └─ agentLoop.runTurn()
       └─ AgentLoopProviding（~300 行）
            ├─ 构造 LLM 请求
            ├─ 流式调用 LLM
            ├─ assistant 消息落库
            ├─ 检测 toolCalls
            ├─ 若无工具调用 → 完成
            └─ 若有工具调用 → 发布 AgentLoopEvent.toolCallsReceived
                 └─ PluginToolManager
                      ├─ 监听工具调用事件并选择执行策略
                      ├─ 授权判断
                      ├─ 执行工具
                      ├─ 发布 ToolManagerEvent.batchCompleted
                      └─ 授权点停止，等待 Renderer 恢复 AgentLoop
```

## 2. 核心原则

**控制权移交，不改变语义。** AgentLoop 发现工具调用后暂停，将整批工具调用交给 ToolManager 全权处理；ToolManager 完成所有工具（含授权审批）后，将结果一次性返回给 AgentLoop，AgentLoop 带着结果继续下一轮 LLM 调用。

## 3. 职责重新划分

### 3.1 AgentLoopProviding（精简后）

保留的职责：
| 职责 | 说明 |
|------|------|
| LLM 请求构造 | 消息历史 → LLMMessage 转换、工具 schema 注入 |
| 流式 LLM 调用 | 流式/非流式调用、增量渲染到 MessageStreamingProviding |
| assistant 消息落库 | LLM 响应写入数据库 |
| 循环控制 | 发布工具调用事件 → 等待 ToolManager 结果 → 继续循环 |
| 状态机 | idle / running / completed / failed / cancelled |
| 取消 | cancelTurn 中断当前 Task |
| 生命周期钩子 | willSendToLLM / didReceiveLLMResponse 等 |

**移除的职责：**
| 职责 | 去向 |
|------|------|
| 授权判断（automationLevel 分支） | → ToolManager |
| 工具执行编排（逐个 execute） | → ToolManager |
| 挂起/恢复（工具审批、ask_user 挂起点构造） | → ToolManager |
| 工具结果消息落库 | → ToolManager |
| 未完成工具批次续跑逻辑 | → ToolManager |

### 3.2 ToolManagerProviding（增强后）

在插件装配层由 `PluginToolManager` 订阅 `AgentLoopEvent.toolCallsReceived`。
AgentLoop 不直接调用 ToolManager，也不计算 `automationLevel` 对应的执行策略。
ToolManager 完成批次后发布 `ToolManagerEvent.batchCompleted`，由 AgentLoop 消费。

新增的批量执行入口：

```swift
/// 批量执行一批工具调用，内部处理授权、挂起、结果落库。
///
/// - 按顺序逐个执行，遇到需要用户审批的高风险工具时挂起并返回中间结果。
/// - 调用方（AgentLoop）根据返回的 outcome 决定是继续循环还是等待用户输入。
func executeBatch(
    _ toolCalls: [MessageToolCall],
    conversationID: UUID,
    turnID: UUID?
) async -> ToolBatchOutcome

/// 恢复被挂起的工具批次（用户已批准/拒绝）。
func resumeBatch(
    conversationID: UUID,
    request: AgentTurnResumeRequest
) async -> ToolBatchOutcome
```

新增的结果类型：

```swift
/// 工具批次的执行结果。
public enum ToolBatchOutcome {
    /// 所有工具执行完毕，结果已落库。
    case completed([MessageToolResult])
    /// 某个工具需要用户输入，已挂起。
    case suspended(suspension: AgentLoopSuspension)
}
```

新增的授权相关方法（从 AgentLoop 移入）：

```swift
/// 评估工具调用是否可以直接执行，还是需要用户审批。
/// 内部读取会话的 automationLevel 做判断。
func shouldAutoExecute(
    _ toolCall: ToolCall,
    conversationID: UUID
) -> AutoExecuteDecision

public enum AutoExecuteDecision {
    case execute           // autonomous 模式或低风险
    case block(reason: String) // chat 模式，拒绝执行
    case requireApproval(riskLevel: CommandRiskLevel) // build 模式高风险
}
```

### 3.3 MessageSendingProviding

**不变。** 接口和实现保持现状，只是底层 AgentLoop 变简单了。

### 4.1 事件驱动契约

`AgentLoopEvent.toolCallsReceived` 携带 `conversationID`、`turnID`、
`assistantMessageID` 和工具调用列表。它表示一次 LLM step 结束，不表示整个
Agent turn 完成。AgentLoop 进入 `executingTools` 后释放当前 step task，但
`runTurn()` 继续等待终态结果。

ToolManager 在授权点停止当前批次，并通过 `batchCompleted` 返回已完成结果与
`needsUserResponse`。用户操作仍由消息渲染器提交给 `AgentLoop.resumeTurn()`；
AgentLoop 只回写当前结果并重新发布剩余工具调用，继续由 ToolManager 执行。

## 4. 挂起/恢复的迁移

当前挂起逻辑在 AgentLoop 中，涉及两种场景：

| 场景 | 当前实现 | 迁移后 |
|------|----------|--------|
| 工具审批 | AgentLoop 构造 `AgentLoopSuspension(kind: "toolApproval")` | ToolManager 构造 |
| ask_user 工具 | AgentLoop 检测 `awaitingUserResponse` 并构造挂起点 | ToolManager 构造 |

迁移后，AgentLoop 中的 `suspensions`、`pendingSuspensions` 字典移到 ToolManager 中管理。

**AgentLoop 协议变更：**

```swift
// 移除（不再直接管理挂起）
// func suspension(for conversationID: UUID) -> AgentLoopSuspension?

// 改为委托查询
func suspension(for conversationID: UUID) -> AgentLoopSuspension?
// 内部实现：return toolManager.activeSuspension(for: conversationID)
```

这样对外接口不变，下游消费者（ConversationList、MessageList 等）无需改动。

## 5. 数据流对比

### 当前（AgentLoop 管工具）

```
AgentLoop.executeTurnLoop():
  while !cancelled {
    response = callLLM()                    // AgentLoop
    saveAssistantMessage(response)           // AgentLoop
    if response.toolCalls.isEmpty { return } // AgentLoop
    for toolCall in response.toolCalls {     // AgentLoop 逐个处理
      result = executeToolCall(toolCall)     // AgentLoop 授权 + 调用
      saveToolResultMessage(result)          // AgentLoop 落库
      if result.awaitingResponse { suspend } // AgentLoop 挂起
    }
  }
```

### 重构后（ToolManager 管工具）

```
AgentLoop.executeTurnLoop():
  while !cancelled {
    response = callLLM()                          // AgentLoop
    saveAssistantMessage(response)                 // AgentLoop
    if response.toolCalls.isEmpty { return }       // AgentLoop
    notify(.toolCallsReceived(                      // 交给 ToolManager 插件
      response.toolCalls, assistantMessageID, conversationID, turnID
    ))
    return await nextToolManagerEvent()             // 保持逻辑 Turn 未完成
  }
```

## 6. 下游影响

| 消费者 | 当前依赖 | 影响 |
|--------|----------|------|
| `MessageSenderPlugin` | `agentLoop.runTurn()` | **无影响** |
| `ConversationStats` | `agentLoop.isRunning(for:)` | **无影响** |
| `ConversationManager` | `agentLoop.state(for:)` | **无影响** |
| `ConversationList` | `agentLoop.isRunning(for:)` | **无影响** |
| `MessageList` | `agentLoop.state(for:)` | **无影响** |
| `AskUserPlugin` | `agentLoop.resumeTurn()` | **无影响**（接口不变） |

**结论：对外协议不变，所有下游消费者零改动。**

## 7. 内部实现变更

| 文件 | 变更内容 |
|------|----------|
| `DefaultAgentLoopProvider.swift` | 删除 `executeToolCall`、`executePendingToolCalls`、`makeToolApprovalResult`、`isToolApprovalGranted` 等方法；`executeTurnLoop` 中工具处理段替换为 `toolManager.executeBatch()` 调用 |
| `DefaultToolManagerProviding.swift` | 新增 `executeBatch`、`resumeBatch`、`shouldAutoExecute`；迁入挂起状态管理（`suspensions` 字典）；迁入授权判断逻辑 |
| `AgentLoopProviding.swift` | 协议不变 |
| `ToolManagerProviding.swift` | 新增 `executeBatch`、`resumeBatch` 方法签名 |
| `AgentLoopObservation.swift` | 增加带 assistantMessageID 的工具调用事件 |
| `PluginToolManager.swift` | 订阅 AgentLoop 工具调用事件并选择执行策略 |
| `AgentLoopProvider.swift`（PluginAgentLoop） | 只消费 ToolManager 结果，不再转发工具调用 |

## 8. 风险与注意事项

### 8.1 依赖方向

ToolManager 当前依赖 `KitAgentTool`（工具接口定义）。新增授权逻辑需要读取会话的 `automationLevel`，因此需要依赖 `ProviderConversation`。

```
当前：  AgentLoop → ToolManager, Conversation
重构后：ToolManager → Conversation（新增），KitAgentTool
        AgentLoop → ToolManager
```

这不会引入循环依赖，因为 Conversation 不依赖 ToolManager。

### 8.2 `ToolCallResult` vs `MessageToolResult` 的转换

当前 `convertResult` 方法在 AgentLoop 中将 `ToolCallResult` 转为 `MessageToolResult`。迁移后此转换应发生在 ToolManager 内部，AgentLoop 只接收最终的 `MessageToolResult`。

### 8.3 流式状态消息

当前 AgentLoop 在工具执行前插入 "正在执行xxx…" 的 status 消息。迁移后由 ToolManager 负责，但 ToolManager 需要访问 `MessageManaging` 来插入 status 消息。需确认 ToolManager 是否已持有 `MessageManaging` 引用，若无则需注入。

### 8.4 分步实施

建议分三步：

1. **Phase 1** — 固化 `toolCallsReceived` 与 `batchCompleted` 事件契约，AgentLoop 在工具调用后释放当前 step task，但保持逻辑 Turn 等待。
2. **Phase 2** — 由 `PluginToolManager.onReady` 订阅 AgentLoop 事件，执行策略和工具执行从 AgentLoop 移出。
3. **Phase 3** — 授权点立即停止批次；用户恢复后 AgentLoop 只重新发布剩余调用，最后再进入下一轮 LLM。
4. **Phase 4** — 清理 AgentLoop 中不再使用的工具批次编排代码，并补齐批次/恢复测试。

每个 Phase 独立提交、独立测试。

## 9. 预期收益

| 指标 | 重构前 | 重构后 |
|------|--------|--------|
| `DefaultAgentLoopProvider` 行数 | ~780 行 | ~300 行 |
| AgentLoop 职责数 | 8 个 | 4 个 |
| ToolManager 职责数 | 3 个 | 6 个 |
| 对外协议变更 | — | 无 |
| 下游消费者改动 | — | 无 |
