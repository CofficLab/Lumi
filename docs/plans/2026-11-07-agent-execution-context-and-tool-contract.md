# Agent Execution Context and Tool Contract Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Turn、LLM attempt、ToolJob 与 MCP 调用建立显式 Trace/Deadline 上下文，并让两条工具执行路径共享结果预算、Artifact、超时与取消语义。

**Architecture:** 在 `KitAgentTool` 扩展最小契约，在 `ProviderToolManager` 建共享执行管线，`PluginToolManager` 的独立 Job 路径与 `DefaultToolManagerProviding` 的直接路径都调用它。保留现有 ToolJob 调度、授权、只读并发、副作用屏障与 Shell 进程管理；Artifact 只替换大结果的承载方式，不新建第二套工具协议。

**Tech Stack:** Swift 6、Swift Concurrency、Swift Testing、CryptoKit、KitAgentTool、KitLLM、ProviderToolManager、PluginToolManager、KitMCP、PluginMCP。

---

## 1. 当前事实与设计约束

- `Packages/KitAgentTool/Sources/SuperAgentTool.swift` 已有 input schema、风险、显式授权、执行能力、带 Context 的 `executeResult`。
- `Packages/KitAgentTool/Sources/ToolExecutionContext.swift` 已有 job/conversation/turn、取消闭包、输出/进度回调和会话项目路径。
- `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionManager.swift` 已有 ToolJob 持久化、幂等提交、授权、并发屏障与取消，不替换。
- `Packages/ProviderToolManager/Sources/ProviderToolManager/DefaultToolManagerProviding.swift` 是第二条直接执行路径，必须共享相同 deadline/finalizer/error mapping。
- `Packages/KitShell/Sources/KitShell/ShellExecutor.swift` 已有自己的超时、输出限制与进程树终止，不重复实现 Shell executor。
- `Packages/KitMCP/Sources/KitMCP/MCPServerSession.swift` 与 `Packages/PluginMCP/Sources/PluginMCP/Models/MCPToolAdapter.swift` 需要显式 Context、deadline 和协作取消。
- `KitLLM` 已依赖 `KitAgentTool`，所以 `AgentExecutionContext` 可放 KitAgentTool；禁止让 KitAgentTool 反向依赖 KitLLM。

### 非目标

- 不新增平行 `AgentToolV2`、第二 ToolManager、第二调度器或第二套权限模型。
- 不自动重放超时、取消或结果未知的副作用工具。
- 不实现完整 JSON Schema 验证器；首版 output schema 只做声明与 JSON object 可编码性检查。
- 不把 trace ID 自动写入第三方 HTTP header 或 MCP `_meta`。
- 不用 `TaskLocal` 代替参数传播。
- 不让非协作工具的 timeout 返回被解释为远程写、子进程或服务器操作已停止。

## 2. 公共类型与状态语义

### 2.1 执行上下文

新建 `Packages/KitAgentTool/Sources/AgentExecutionContext.swift`：

```swift
public struct AgentExecutionContext: Sendable, Equatable {
    public let traceID: UUID
    public let spanID: UUID
    public let parentSpanID: UUID?
    public let conversationID: UUID
    public let turnID: UUID?
    public let deadline: ContinuousClock.Instant?

    public init(
        traceID: UUID,
        spanID: UUID,
        parentSpanID: UUID? = nil,
        conversationID: UUID,
        turnID: UUID? = nil,
        deadline: ContinuousClock.Instant? = nil
    ) { /* assign */ }

    public static func root(
        conversationID: UUID,
        turnID: UUID?,
        deadline: ContinuousClock.Instant? = nil
    ) -> Self { /* new traceID + root spanID */ }

    public func child(
        deadline: ContinuousClock.Instant? = nil
    ) -> Self { /* same traceID, new spanID, parent = self.spanID, earliest deadline */ }
}
```

`child` 的 deadline 必须取 parent 与传入 deadline 的较早值。root/child 是纯值创建，不写日志、不访问全局状态。

### 2.2 工具契约扩展

新建：

- `ToolExecutionLimits.swift`
- `ToolSideEffectScope.swift`
- `ToolArtifact.swift`

```swift
public struct ToolExecutionLimits: Sendable, Equatable {
    public let timeout: Duration?
    public let maxResultBytes: Int
    public let maxLivePreviewBytes: Int
    public let maxInlineImageBytes: Int

    public init(
        timeout: Duration? = nil,
        maxResultBytes: Int = 256 * 1024,
        maxLivePreviewBytes: Int = 16 * 1024,
        maxInlineImageBytes: Int = 2 * 1024 * 1024
    ) { /* precondition positive budgets */ }
}

public enum ToolSideEffectScope: String, Codable, Sendable {
    case readOnly
    case workspaceWrite
    case externalWrite
    case userInteraction
    case unknown
}
```

在 `SuperAgentTool` 中把以下能力声明为 **protocol requirements**，再在 extension 提供默认值：

```swift
func outputSchema(for language: LanguagePreference) -> [String: Any]?
func sideEffectScope(arguments: [String: ToolArgument]) -> ToolSideEffectScope
func executionLimits(arguments: [String: ToolArgument]) -> ToolExecutionLimits
```

默认行为：

- `outputSchema` 为 nil，表示 plain text/legacy result，不做 JSON object 校验。
- `parallelReadOnly → readOnly`，`interactive → userInteraction`，`serialSideEffect → unknown`。工具可精确声明 workspaceWrite/externalWrite，但 `executionCapability` 仍是唯一调度依据。
- `executionLimits` 为上面的保守默认值。Shell 可将现有配置映射进来，但不能降低 Shell 自身安全限制。

### 2.3 ToolExecutionContext 扩展

增加字段，并保留现有 jobID/回调/项目路径：

```swift
public let execution: AgentExecutionContext?
public let limits: ToolExecutionLimits
public let artifactStore: (any ToolArtifactStoring)?
```

initializer 默认 `execution = nil`、`limits = .init()`、`artifactStore = nil`，便于测试构造。生产 ToolManager 必须注入非 nil execution 与 ArtifactStore；缺 execution 时创建本地 root 仅作兼容，不得从当前选中会话猜测身份。

### 2.4 Artifact 契约

```swift
public struct ToolArtifactReference: Codable, Sendable, Equatable {
    public let id: UUID
    public let byteCount: Int64
    public let sha256: String
    public let mimeType: String
    public let fileName: String?
}

public protocol ToolArtifactStoring: Sendable {
    func put(
        _ data: Data,
        suggestedName: String?,
        mimeType: String
    ) async throws -> ToolArtifactReference
    func data(for id: UUID) async throws -> Data
}
```

Artifact reference 不包含本机绝对路径。模型只接收 preview、reference ID、原始/返回字节数；UI 通过 Store 异步解析 bytes。首版 HTML 导出刻意只包含安全转义的 preview 与 Artifact metadata，并明确标注“完整 Artifact 未包含在 HTML 中，请回 App 打开”，不内嵌 base64、不读取完整 bytes，因此同步 exporter 不需要也不应调用 async Store。

`ToolCallResult` 增加并兼容 Codable 旧数据：

```swift
public var artifacts: [ToolArtifactReference]
public var originalContentByteCount: Int?
public var isContentPreview: Bool
```

旧记录 decode 默认 `artifacts=[]`、`originalContentByteCount=nil`、`isContentPreview=false`。

### 2.5 执行终态

共享管线必须区分：

```text
completed               工具已返回，结果已 finalization
failed                  工具抛出错误，按现有规则形成 error result
cancelRequested         已请求取消；协作工具可返回 cancelled
cancelled               工具确认停止，未返回可继续使用的结果
timedOut                deadline 到期且已请求取消
lateCompleted           非协作工具在 timeout/cancel 后又返回，只写审计，不覆盖已发布结果
```

`timedOut` / `cancelRequested` 对 `workspaceWrite`、`externalWrite`、`unknown` 必须携带 `sideEffectOutcome = unknown`。只有工具明确返回或工具自身提供可靠幂等/状态查询，才能把副作用标为 completed/reverted。

## 3. Task 1：AgentExecutionContext 与协议动态分派

**Files:**

- Create: `Packages/KitAgentTool/Sources/AgentExecutionContext.swift`
- Create: `Packages/KitAgentTool/Sources/ToolExecutionLimits.swift`
- Create: `Packages/KitAgentTool/Sources/ToolSideEffectScope.swift`
- Modify: `Packages/KitAgentTool/Sources/SuperAgentTool.swift`
- Modify: `Packages/KitAgentTool/Sources/ToolExecutionContext.swift`
- Test: `Packages/KitAgentTool/Tests/AgentExecutionContextTests.swift`
- Test: `Packages/KitAgentTool/Tests/SuperAgentToolContractTests.swift`

### Step 1：写失败测试

1. root 的 traceID/spanID 非空，parent 为 nil。
2. child 保持 traceID，spanID 不同，parentSpanID 等于父 spanID。
3. 两层 child 形成正确链，deadline 永远取最早值。
4. 自定义 tool 通过 `any SuperAgentTool` 调用时，覆盖的 limits/sideEffectScope/outputSchema 被调用，而不是 extension 默认值。
5. 默认工具保持 serial/unknown、无 output schema、默认预算。
6. `ToolExecutionContext` 原 initializer 的现有调用仍编译，新字段有正确默认值。

### Step 2：确认失败

```bash
swift test --package-path Packages/KitAgentTool --filter AgentExecutionContextTests
swift test --package-path Packages/KitAgentTool --filter SuperAgentToolContractTests
```

预期：类型/requirement 不存在；动态分派测试在只写 extension 方法时必须失败，防止错误实现假绿。

### Step 3：最小实现

添加上述类型和 requirements。不要引入 KitLLM、Plugin 或全局 tracer。对预算 initializer 使用明确 precondition 或 throwing factory，测试非法零/负值不能进入生产管线。

### Step 4：确认通过

```bash
swift test --package-path Packages/KitAgentTool
swift test --package-path Packages/KitLLM
```

### Step 5：独立提交

```bash
git add Packages/KitAgentTool
git diff --cached --check
git commit -m "feat(KitAgentTool): add execution context and tool limits"
```

## 4. Task 2：ArtifactStore 与结果类型全链路字段

**Files:**

- Create: `Packages/KitAgentTool/Sources/ToolArtifact.swift`
- Modify: `Packages/KitAgentTool/Sources/ToolCallResult.swift`
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/FileToolArtifactStore.swift`
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolArtifactStoreError.swift`
- Modify: `Packages/ProviderMessage/Package.swift` for the direct KitAgentTool dependency
- Modify: `Packages/ProviderMessage/Sources/ProviderMessage/MessageModels.swift` (`MessageToolResult` projection)
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJob.swift` and `ToolJobRecord.swift` only where result projection requires it
- Modify: `Packages/PluginMessageRenderer/Package.swift` for the direct KitAgentTool dependency
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/MessageRendererPlugin.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Views/AssistantToolCallViews.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Models/ToolCallResultVisualState.swift`
- Modify: `Packages/PluginConversationExport/Package.swift` for the direct KitAgentTool dependency
- Modify: `Packages/PluginConversationExport/Sources/PluginConversationExport/Export/ConversationHTMLExporter.swift`
- Test: `Packages/KitAgentTool/Tests/ToolCallResultCodableTests.swift`
- Test: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/FileToolArtifactStoreTests.swift`
- Test: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ToolArtifactRenderingTests.swift`
- Test: `Packages/PluginConversationExport/Tests/PluginConversationExportTests/ConversationHTMLExporterTests.swift`

### Step 1：写失败测试

- 旧 JSON 无 artifact 字段可 decode；新字段 round-trip。
- Store 写入相同 bytes 生成稳定内容 hash，读取一致，ID 不可碰撞；路径不可通过 fileName 跳出 Artifact 根目录。
- 空文件、大文件、非法 MIME/fileName、读取不存在 ID 都有明确行为。
- MessageToolResult 与 ToolJob result 转换不丢 artifacts/original bytes/preview 标志。
- 渲染器显示 preview 标志和“打开 Artifact”，不尝试把 preview 当完整结果；点击后通过注入的 Store 异步读取同一 ID 的 bytes，读取失败显示错误，不伪造空文件。
- HTML 导出包含安全转义的 preview 与 artifact metadata，并明确标注完整 bytes 未包含在 HTML 中；exporter 保持同步且不访问 Store，测试用 throwing Store 证明导出不会意外触发读取。

### Step 2：确认失败

```bash
swift test --package-path Packages/KitAgentTool --filter ToolCallResultCodableTests
swift test --package-path Packages/ProviderToolManager --filter FileToolArtifactStoreTests
swift test --package-path Packages/PluginMessageRenderer --filter ToolArtifactRenderingTests
swift test --package-path Packages/PluginConversationExport --filter ConversationHTMLExporterTests
```

### Step 3：最小实现

File Store 放在 ProviderToolManager，供 Default/Plugin 两条执行路径和 Factory 共同复用。它使用调用方给的插件数据目录，按 `artifacts/<uuid>` 保存 bytes，metadata 可由文件名/manifest 持久化。写入采用临时文件 + atomic rename；`put` 返回前数据已落盘。fileName 只取 `lastPathComponent` 并移除控制字符。

`ProviderMessage`、`PluginMessageRenderer`、`PluginConversationExport` 都在 package manifest 与 target dependencies 中显式声明 KitAgentTool，不能依赖 SwiftPM 传递依赖碰巧可见。Renderer 的 `MessageRendererPlugin.onBoot` 从 Kernel 解析 `(any ToolArtifactStoring).self` 并注入工具视图/visual state；“打开 Artifact”用 `Task` await `data(for:)`，再复用现有跨平台文件打开能力处理临时导出文件。缺 Store 时按钮不可用并显示原因，不能退回读取本机绝对路径。

全仓搜索所有 `ToolCallResult(`、`MessageToolResult(` 和 result JSON 转换点，逐一迁移。不能只给结果 struct 加字段而遗漏渲染、ToolJob、导出或旧数据 decode。`ConversationExportViewModel` 与同步 `ConversationHTMLExporter.export` 不改签名、不接收 Store；首版 HTML 的完成定义就是 preview + metadata + 明确未内嵌提示，不把“没有 bytes”误报为数据损坏。

Artifact 内容属于功能数据，不应用诊断 sanitizer；访问权限沿用会话本机数据边界，不在诊断 archive 默认打包。

### Step 4：确认通过

```bash
swift test --package-path Packages/KitAgentTool
swift test --package-path Packages/ProviderMessage
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/PluginMessageRenderer
swift test --package-path Packages/PluginConversationExport
```

### Step 5：独立提交

```bash
git add Packages/KitAgentTool Packages/ProviderMessage Packages/ProviderToolManager Packages/PluginToolManager Packages/PluginMessageRenderer Packages/PluginConversationExport
git diff --cached --check
git commit -m "feat(KitAgentTool): persist large tool results as artifacts"
```

## 5. Task 3：共享结果 Finalizer 与 output schema 检查

**Files:**

- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolResultFinalizer.swift`
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolOutputSchemaValidator.swift`
- Test: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/ToolResultFinalizerTests.swift`
- Test: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/ToolOutputSchemaValidatorTests.swift`

### Step 1：写失败测试

用字节预算而不是字符构造用例：

| 输入 | 预期 |
|---|---|
| 小于 maxResultBytes 的 plain text | content 原样，无 Artifact，isPreview=false |
| 大于 maxResultBytes 且 Store 可用 | 完整 bytes 写入 Artifact；模型 content 只有 preview + 明确 metadata |
| 大于预算且 Store 不可用 | 返回 resultBudgetExceeded，不静默截断，不自动重跑工具 |
| Unicode 跨界 | preview 不超字节预算，原始 byte count 准确 |
| 超大 image | image bytes 写 Artifact，inline image 不突破预算 |
| `awaitingUserResponse=true` | 保留 interaction state，不被大文本处理吞掉 |
| outputSchema=nil | plain text 合法 |
| outputSchema type=object | 非 JSON、数组、 malformed JSON 产生 contract error |

最终模型提示必须包含：artifact ID、originalBytes、returnedBytes、isPreview；不要求模型读取本机路径。

### Step 2：确认失败

```bash
swift test --package-path Packages/ProviderToolManager --filter ToolResultFinalizerTests
swift test --package-path Packages/ProviderToolManager --filter ToolOutputSchemaValidatorTests
```

### Step 3：最小实现

Finalizer 是纯入口：

```swift
func finalize(
    _ result: ToolCallResult,
    tool: any SuperAgentTool,
    context: ToolExecutionContext
) async throws -> ToolCallResult
```

先检查 schema，再处理 images，再处理 content，最后重算 preview metadata。错误结果也受预算限制，不能因为 `isError=true` 绕过。output schema 首版只验证 JSON object 与必要的 JSON-compatible 编码，不宣称完整 JSON Schema。

### Step 4：确认通过

```bash
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/KitAgentTool
```

### Step 5：独立提交

```bash
git add Packages/ProviderToolManager Packages/KitAgentTool
git diff --cached --check
git commit -m "feat(ProviderToolManager): finalize bounded tool results"
```

## 6. Task 4：共享 Deadline/Cancellation 执行管线

**Files:**

- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolExecutionPipeline.swift`
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolExecutionOutcome.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionManager.swift`
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/DefaultToolManagerProviding.swift`
- Test: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/ToolExecutionPipelineTests.swift`
- Test: `Packages/PluginToolManager/Tests/PluginToolManagerTests/ToolExecutionManagerTests.swift`
- Test: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/DefaultToolManagerProvidingTests.swift`

### Step 1：写失败测试

至少包含：

1. 正常结果经过 finalizer，trace/job IDs 不变。
2. 工具 timeout 早于 parent deadline 时生效；parent 更早时 parent 生效。
3. 协作工具观察 `isCancelled` 后返回，终态为 cancelled。
4. 非协作工具在 timeout 后继续等待并最终返回；调用方及时得到 timedOut + sideEffect unknown，迟到结果不覆盖已发布 ToolJob/消息。
5. 非协作外部写工具不能得到“副作用已回滚”的描述。
6. 两条执行路径对同一 fake tool 产生同样 error mapping、preview 和 audit outcome。
7. PluginToolManager 的并行只读、副作用串行、授权挂起、重复 submit 幂等测试保持通过。
8. continuation 只 resume 一次；late completion 后 active registry 最终清理，无泄漏任务/悬挂等待者。

### Step 2：确认失败

```bash
swift test --package-path Packages/ProviderToolManager --filter ToolExecutionPipelineTests
swift test --package-path Packages/ProviderToolManager --filter DefaultToolManagerProvidingTests
swift test --package-path Packages/PluginToolManager --filter ToolExecutionManagerTests
```

预期：新共享管线不存在；当前直接路径无统一 deadline/finalizer。

### Step 3：最小实现

共享管线负责：

- 计算 `effectiveDeadline = min(parent.deadline, now + limits.timeout)`。
- 创建工具子 span，并构造带 ArtifactStore 的完整 Context。
- 管理实际 tool task、timeout/cancel 请求、单一结果发布与 late completion 审计。
- 调用共享 finalizer，再映射结果。

PluginToolManager 保留 `pendingExecutions`、jobs、runtime barrier 与事件顺序，只把“直接调用 tool + 自己拼结果”替换为 pipeline。DefaultToolManagerProviding 使用同一 pipeline，不得复制一份 deadline 逻辑。

实现可使用 actor 保护 `continuation/resultPublished/lateCompletion`，但不能用 unstructured task 后失去引用。timeout 后保留实际 task 的完成观察，直到它真正结束；这不阻塞调用方继续 AgentLoop。

### Step 4：确认通过

```bash
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/KitAgentTool
```

### Step 5：独立提交

```bash
git add Packages/ProviderToolManager Packages/PluginToolManager
git diff --cached --check
git commit -m "fix(ProviderToolManager): unify tool deadline and cancellation handling"
```

## 7. Task 5：Turn → LLM Request → ToolJob 的显式 Trace 传播

**Files:**

- Modify: `Packages/KitLLM/Sources/KitLLM/Core/LLMTypes.swift`
- Create: `Packages/KitLLM/Sources/KitLLM/Core/LLMRequest+Routing.swift` if it reduces repeated field copying
- Modify: `Packages/PluginLLMManager/Sources/PluginLLMManager/Managers/CustomLLMManager.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- Modify: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Providers/LLMNetworkProviderAdapter.swift`
- Modify: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Services/HTTPExchangeStore.swift` metadata only
- Test: `Packages/KitLLM/Tests/KitLLMTests/LLMRequestRoutingTests.swift`
- Test: `Packages/PluginLLMManager/Tests/PluginLLMManagerTests/CustomLLMManagerTests.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/AgentExecutionContextTests.swift`
- Test: `Packages/PluginNetworkManager/Tests/PluginNetworkManagerTests/LLMNetworkProviderAdapterRetryTests.swift`

### Step 1：写失败测试

- Turn root 固定 traceID；每个 LLM attempt 新 spanID，parent 为 Turn span。
- ToolJob 使用触发它的 attempt span 作为 parent；同一 Turn 多步请求 traceID 不变。
- `LLMRequest.routed(...)` 改 provider/model 后 executionContext 不丢。
- CustomLLMManager 的每个 request 重建路径都保留 context，包括 retry/fallback。
- HTTP 本地记录可关联 trace/span，但捕获的URLRequest headers 中没有自动新增 `x-trace-id` 等字段。
- retry 复用同一 attempt context；新 attempt 必须显式创建，不在网络层隐式创建。

### Step 2：确认失败

```bash
swift test --package-path Packages/KitLLM --filter LLMRequestRoutingTests
swift test --package-path Packages/PluginLLMManager --filter CustomLLMManagerTests
swift test --package-path Packages/PluginAgentLoop --filter AgentExecutionContextTests
swift test --package-path Packages/PluginNetworkManager --filter LLMNetworkProviderAdapterRetryTests
```

### Step 3：最小实现

给 `LLMRequest` 添加 `executionContext: AgentExecutionContext? = nil`。优先实现一个 `routed` helper 复制所有字段，再迁移 `CustomLLMManager` 全部构造点；全仓搜索 `LLMRequest(` 确认没有遗漏。

AgentLoop 在 startTurn 创建 root，在每次 LLM step 创建 child，把 attempt context 随 `TurnRuntime` 保存；工具提交读取同一 attempt context，不读取当前 UI 会话。

HTTPExchangeStore 的 trace 字段通过显式 metadata 参数传递，不塞入 URLRequest header。诊断 sanitizer 允许 UUID 字段，但仍禁止敏感正文。

### Step 4：确认通过

```bash
swift test --package-path Packages/KitLLM
swift test --package-path Packages/PluginLLMManager
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/PluginNetworkManager
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
```

### Step 5：独立提交

```bash
git add Packages/KitLLM Packages/PluginLLMManager Packages/PluginAgentLoop Packages/PluginNetworkManager Packages/ProviderToolManager Packages/PluginToolManager
git diff --cached --check
git commit -m "feat(PluginAgentLoop): propagate execution context across agent steps"
```

## 8. Task 6：MCP Context、Deadline 与 Advisory Cancel

**Files:**

- Modify: `Packages/KitMCP/Sources/KitMCP/MCPServerSession.swift`
- Modify: `Packages/KitMCP/Tests/KitMCPTests/MCPServerSessionTests.swift`
- Modify: `Packages/PluginMCP/Sources/PluginMCP/Models/MCPToolAdapter.swift`
- Test: `Packages/PluginMCP/Tests/PluginMCPTests/MCPToolAdapterTests.swift`

### Step 1：写失败测试

- `callTool` 接收 execution context/deadline；旧无 Context 入口可通过明确 default 转发，但生产 Adapter 必须走 Context 入口。
- deadline 到期时请求 SDK cancellation（若 SDK 支持），返回 stable timeout error。
- SDK 不响应 cancel 时，结果标记 external side effect unknown；不得显示服务器已撤销。
- 正常 MCP text/images/isError mapping 不回归。
- `MCPToolAdapter.executeResult` 在调用前后检查 `context.isCancelled`，透传 output/progress 能力与 trace IDs。
- 只读并行判定仍要求 readOnlyHint 且 safe/low；新增 sideEffectScope 不得放松该规则。

### Step 2：确认失败

```bash
swift test --package-path Packages/KitMCP --filter MCPServerSessionTests
swift test --package-path Packages/PluginMCP --filter MCPToolAdapterTests
```

### Step 3：最小实现

新增 context-aware requirement 到 MCP session 抽象，fake 与真实实现同时更新。取消通过 SDK 支持的 cancelRequest 发送，但只标 advisory；实际 Task 管理复用 ToolExecutionPipeline，不在 Adapter 内再实现超时竞赛。

不要默认把内部 trace IDs 写入 MCP `_meta`。如服务器已有独立 request ID，只保存在本地审计映射中。

### Step 4：确认通过

```bash
swift test --package-path Packages/KitMCP
swift test --package-path Packages/PluginMCP
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
```

### Step 5：独立提交

```bash
git add Packages/KitMCP Packages/PluginMCP Packages/ProviderToolManager Packages/PluginToolManager
git diff --cached --check
git commit -m "fix(PluginMCP): propagate tool deadlines and cancellation"
```

## 9. Task 7：生产装配与端到端验收

**Files:**

- Modify: `Packages/FactoryLumi/Package.swift` for the direct KitAgentTool dependency
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi/ProviderFactory.swift`
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift` only at the existing PluginToolManager replacement/configuration site
- Test: `Packages/FactoryLumi/Tests/FactoryLumiTests/AgentExecutionAssemblyTests.swift`
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolAuditEvent.swift` only if final trace/outcome fields need adjustment

### Step 1：写失败装配测试

验证 FactoryLumi 创建的真实 ToolManager：

- 所有生产 ToolExecutionContext 都有 ArtifactStore、正确 conversation/turn 与 execution context。
- Kernel 在插件 boot 前可解析 `(any ToolArtifactStoring).self`；Renderer 收到的实例与 ToolManager 相同，PluginToolManager 与 DefaultToolManagerProviding 不出现两套 Artifact 根目录或两套 audit 配置。
- App 重启后 Artifact reference 仍可读取；Renderer 的打开动作确实调用该 Store，而不是仅显示一个无行为按钮。
- ConversationExportPlugin 不需要 ArtifactStore；真实导出仍同步生成 preview + metadata + 未内嵌提示。
- 诊断记录中 traceID/spanID 可关联，外部请求没有新增内部 trace header。

### Step 2：确认失败并最小实现

```bash
swift test --package-path Packages/FactoryLumi --filter AgentExecutionAssemblyTests
```

在 `ProviderFactory.registerProviders` 中，取得 Storage 后只构造一次 `FileToolArtifactStore`，先 `kernel.registerProvider((any ToolArtifactStoring).self, store)`，再把同一实例注入默认 ToolManager；PluginFactory 替换为 PluginToolManager 时解析并复用同一注册实例，不得再次按插件创建根目录。Renderer 在后续 onBoot 从 Kernel 解析同一能力。只改现有 composition root，不让各工具自行决定全局路径。

### Step 3：运行完整相关矩阵

```bash
swift test --package-path Packages/KitAgentTool
swift test --package-path Packages/ProviderMessage
swift test --package-path Packages/KitLLM
swift test --package-path Packages/PluginLLMManager
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/KitMCP
swift test --package-path Packages/PluginMCP
swift test --package-path Packages/PluginNetworkManager
swift test --package-path Packages/PluginMessageRenderer
swift test --package-path Packages/PluginConversationExport
swift test --package-path Packages/FactoryLumi
```

### Step 4：真实 App 验证

1. 执行一个小文本只读工具：结果内联，trace/audit 完整。
2. 执行大输出 Shell：复用现有 Shell cap；若最终仍超工具预算，生成 Artifact，模型只看到 preview，UI 可打开完整内容。
3. 导出该会话：HTML 中转义正确，Artifact metadata、preview 标志与“完整 bytes 未内嵌”提示存在；回 App 点击打开仍取得完整 Artifact。
4. 运行一个可控 sleep 工具并停止：协作取消及时，后续 Turn 可继续。
5. 用 fake 非协作工具模拟 timeout 后 late return：UI 显示副作用未知，late result 不覆盖消息，审计有 lateCompleted。
6. 调用 MCP 只读工具并取消：服务器收到 advisory cancel（若支持），App 不宣称服务器已停止。
7. 验证文件写、授权、只读并发与副作用串行无回归。

### Step 5：独立提交

```bash
git add Packages/FactoryLumi Packages/ProviderToolManager
git diff --cached --check
git commit -m "test(FactoryLumi): verify agent execution context assembly"
```

## 10. 故障注入与完成定义

| 故障 | 必须结果 |
|---|---|
| deadline 与父取消同时发生 | 只有一个终态发布，错误码稳定 |
| 工具忽略取消并最终成功 | 调用方已收到 timeout/cancel；lateCompleted 仅审计；副作用标未知 |
| Artifact 写盘失败 | 不返回伪造 preview 成功；工具结果交付失败可见；不自动重跑副作用 |
| Artifact 进程内写入后崩溃 | 临时文件可清理，不暴露半条正式 reference；已完成 rename 的 bytes/hash 可读 |
| routed request 重建 | executionContext 完整保留 |
| MCP 不支持 cancel | 返回 timeout/unknown，不崩溃、不伪装已取消 |
| 旧 ToolCallResult JSON | decode 成功，Artifact 字段为空，原渲染可工作 |
| 第二条直接执行路径 | 与 Job 路径共享预算、deadline、错误映射，无行为漂移 |

完成本计划必须同时满足：

- 所有协议新增可覆盖能力均为 requirement，existential 测试证明动态分派。
- Turn/attempt/tool/MCP 本地 trace 链完整，且未自动泄漏到外部协议。
- 大结果不再靠无界字符串进入模型或 UI，Artifact 在模型、ToolJob、渲染、导出、持久化转换中不丢字段。
- 两条执行路径共享 pipeline；现有 ToolJob 调度和授权语义保持。
- 超时/取消不冒充副作用停止，不自动重放未知副作用。
