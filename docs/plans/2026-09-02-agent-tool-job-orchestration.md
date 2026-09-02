# Agent Tool Job Orchestration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Lumi 的长时间工具调用从 AgentLoop 的同步等待链中拆出，建立可观察、可取消、可恢复，并能在工具完成后自动唤醒 Agent 的 Tool Job 执行系统。

**Architecture:** 保留“LLM 产生工具调用 → 宿主执行工具 → 结果回传 LLM”的基本协议，但把工具执行改造成由 `ToolExecutionManager` 管理的独立 Job。AgentLoop 只负责决策和等待 Job 事件，不再持有一条等待 `executeBatch()` 返回的长任务链；Shell 工具通过独立进程、流式输出和进程组终止实现可靠取消。第一阶段只做事件驱动的完成唤醒，不在工具运行期间反复调用 LLM，避免把进度流量变成无意义的模型调用。

**Tech Stack:** Swift 6, Swift Concurrency, Swift Testing, Swift Package Manager, SwiftData, Foundation `Process`, `KitAgentTool`, `KitShell`, `ProviderToolManager`, `PluginToolManager`, `PluginAgentLoop`, SwiftUI, LumiUI.

---

## 1. 背景与现状

### 1.1 用户问题

当工具执行时间较长时，用户目前只能看到一个笼统的“正在执行工具…”状态：

- 不知道具体执行了什么；
- 不知道已经运行了多久；
- 不知道工具是否仍然有输出；
- 无法只停止当前工具；
- 点击停止 Agent 后，不能确定底层 Shell 子进程是否真的退出；
- 工具完成前，AgentLoop 没有可靠的中间状态和恢复入口。

用户感知到的结果就是：Agent Loop 像“断了”，但实际是它被挂在一个没有 Job 控制面的 `await` 上。

### 1.2 当前代码链路

当前主要路径如下：

```text
LLM 返回 tool_calls
    ↓
AgentLoop 进入 executingTools
    ↓
ToolCallsObserver 收到 toolCallsReceived
    ↓
Task { await toolManager.executeBatch(...) }
    ↓
executeBatch 顺序 await execute(toolCall)
    ↓
tool.executeResult(arguments:) 长时间等待
    ↓
batchCompleted
    ↓
AgentLoop 继续请求 LLM
```

关键位置：

- `Packages/PluginToolManager/Sources/PluginToolManager/Observers/ToolCallsObserver.swift:37-96`
- `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolManager+Run.swift:18-121`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift:17-142`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift:12-35`
- `Packages/KitShell/Sources/ShellExecutor.swift:393-523`

### 1.3 目标链路

```text
LLM 返回 tool_calls
    ↓
AgentLoop 进入 waitingForToolJobs(jobIDs)
    ↓
ToolExecutionManager.submit 批量创建 Job
    ↓
submit 立即返回，Job 在后台执行
    ├── job.started
    ├── job.output / job.progress
    ├── job.completed / failed / cancelled
    └── 用户可随时 status / cancel / tail
    ↓
Tool Job 完成事件唤醒 AgentLoop
    ↓
AgentLoop 写回工具结果并请求 LLM
```

### 1.4 设计边界

本方案明确区分三件事：

1. **Job 独立运行：** 宿主能观察和控制工具，即使 LLM 当前没有推理。
2. **Agent 自动续跑：** Job 完成后，事件驱动地唤醒 AgentLoop。
3. **LLM 中途观察：** 工具运行期间主动再次调用 LLM，只作为后续增强能力，不属于 P0。

Codex 的标准循环本质上仍然是模型调用和工具执行交替进行；它的体验优势主要来自独立进程、输出事件、取消接口和后台任务管理。Lumi 不应把“后台 Job”误解成“同一个 LLM 同时继续思考”。

### 1.5 参考资料

- OpenAI 对 Codex Agent Loop 的拆解：<https://openai.com/index/unrolling-the-codex-agent-loop/>
- Codex Exec Server 的进程 API：<https://github.com/openai/codex/blob/main/codex-rs/exec-server/README.md>
- Codex Shell 执行、取消和输出上限实现：<https://github.com/openai/codex/blob/main/codex-rs/core/src/exec.rs>
- Codex 关于后台进程完成后唤醒 Agent 的讨论：<https://github.com/openai/codex/issues/32188>
- OpenAI Responses API 的后台、状态和取消接口：<https://developers.openai.com/api/reference/cli/resources/responses/methods/create>

## 2. 非目标与实施原则

### 2.1 P0 不做的事情

- 不替换现有 LLM provider 协议；OpenCode 当前主要使用 Chat Completions/Anthropic 兼容路径，不能假设所有 provider 都支持 Responses API 的 `background`。
- 不在每个 Shell 输出 chunk 到达时调用一次 LLM。
- 不允许同一个会话同时有两个 Agent 决策者修改消息历史。
- 不一次性重写所有已有工具；旧工具通过兼容默认实现逐步迁移。
- 不把 Swift `Task` 当作进程隔离的替代品；外部进程必须由 `Process`/进程组显式管理。

### 2.2 必须遵守的原则

- `toolCall.id` 是 Job 的幂等主键，重连和重试不得重复执行副作用工具。
- Job 的状态、输出和完成事件由 ToolExecutionManager 统一管理，UI 不自行推断状态。
- AgentLoop 是每个会话的单一写入者；Job 事件必须在 MainActor 上串行应用。
- 事件要幂等：重复的完成、取消、超时通知不能重复写消息或重复唤醒 LLM。
- 所有日志和持久化结果都必须限制大小，不能让一个失控命令耗尽内存。
- 高风险工具的授权逻辑保持在 ToolManager，不由 UI 或 AgentLoop 重复推断。

## 3. 目标公共模型

以下模型是实现时应优先确定的协议。命名可微调，但语义不要改变。

### 3.1 ToolJob

建议新建在 `ProviderToolManager`，因为 AgentLoop、UI 和 ToolManager 都需要读取它。

```swift
public enum ToolJobStatus: String, Codable, Sendable {
    case queued
    case running
    case waitingForUser
    case completed
    case failed
    case cancelled
    case timedOut
}

public struct ToolJob: Identifiable, Codable, Sendable, Equatable {
    public let id: String                 // 与 ToolCall.id 相同
    public let conversationID: UUID
    public let turnID: UUID?
    public let toolCall: ToolCall

    public var status: ToolJobStatus
    public var createdAt: Date
    public var startedAt: Date?
    public var updatedAt: Date
    public var completedAt: Date?
    public var latestOutput: String
    public var outputByteCount: Int
    public var exitCode: Int32?
    public var errorMessage: String?
}
```

约束：

- `id` 不要另造 UUID；直接使用模型生成的 `toolCall.id`，这样消息、Job、结果和恢复逻辑天然关联。
- `latestOutput` 只保存受限尾部，例如最多 64 KiB；完整日志另行保存或继续由 Shell 的结果记录处理。
- 终态为 `completed`、`failed`、`cancelled`、`timedOut`；终态 Job 不能再次执行。

### 3.2 ToolJobEvent

```swift
public enum ToolJobEvent: Sendable {
    case created(ToolJob)
    case started(ToolJob)
    case output(jobID: String, stream: ToolOutputStream, chunk: String, snapshot: ToolJob)
    case progress(jobID: String, progress: ToolJobProgress, snapshot: ToolJob)
    case waitingForUser(ToolJob)
    case completed(jobID: String, result: ToolCallResult, snapshot: ToolJob)
    case failed(jobID: String, result: ToolCallResult, snapshot: ToolJob)
    case cancelled(jobID: String, result: ToolCallResult, snapshot: ToolJob)
    case timedOut(jobID: String, result: ToolCallResult, snapshot: ToolJob)
}

public enum ToolOutputStream: String, Sendable {
    case stdout
    case stderr
}

public struct ToolJobProgress: Sendable, Equatable {
    public let message: String
    public let completed: Int?
    public let total: Int?
    public let fraction: Double?
}
```

事件订阅需要提供取消句柄或 `AsyncStream`，二选一即可。建议公共契约采用 callback 以兼容当前 `@MainActor` Provider 体系，内部 Job 管理采用 `AsyncStream` 或 actor mailbox。

### 3.3 ToolExecutionContext

建议新增到 `KitAgentTool`，避免 `KitAgentTool` 依赖 `ProviderToolManager` 形成反向依赖。

```swift
public struct ToolExecutionContext: Sendable {
    public let jobID: String
    public let conversationID: UUID
    public let turnID: UUID?

    public let isCancelled: @Sendable () -> Bool
    public let reportOutput: @Sendable (ToolOutputStream, String) async -> Void
    public let reportProgress: @Sendable (ToolJobProgress) async -> Void
}
```

为了避免一次性修改全部工具，保留旧接口，并新增带 Context 的默认实现：

```swift
public protocol SuperAgentTool: Sendable {
    // 现有要求保持不变
    func execute(arguments: [String: ToolArgument]) async throws -> String
    func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult

    // 新增，默认转发到旧接口
    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult
}

public extension SuperAgentTool {
    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        _ = context
        return try await executeResult(arguments: arguments)
    }
}
```

### 3.4 ToolManagerProviding 增量 API

不要删除现有 `execute` 和 `executeBatch`，先让它们成为兼容包装器。新增：

```swift
@MainActor
public protocol ToolManagerProviding: AnyObject {
    @discardableResult
    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle

    func submit(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) -> [ToolJob]

    func job(for jobID: String) -> ToolJob?
    func jobs(for turnID: UUID) -> [ToolJob]
    func cancelJob(_ jobID: String)
    func cancelJobs(for turnID: UUID)
    func cancelJobs(for conversationID: UUID)

    // 现有 API 继续保留
    func execute(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult

    func executeBatch(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) async -> [BatchToolResult]
}
```

`submit` 只负责授权决策、创建 Job、入队和返回快照，不等待工具完成。若调用属于 `.blockAll` 或需要用户授权，应产生对应的即时结果/挂起事件，而不是创建一个会永远等待的 Job。

## 4. 分阶段实施任务

下面每个 Task 都是一个可独立提交的阶段。优先严格按照顺序执行；除非某个 Task 明确要求，否则不要跨阶段改 AgentLoop。

### Task 1: 建立基线和 Job 协议测试

**Files:**
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJob.swift`
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobEvent.swift`
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobObserver.swift`
- Create: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/ToolJobTests.swift`
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolManagerProviding.swift`

**Steps:**

1. 先运行现有测试，记录基线：

   ```bash
   swift test --package-path Packages/ProviderToolManager
   ```

   Expected: 当前测试全部通过。

2. 写 `ToolJobStatus`、`ToolJob`、`ToolJobProgress` 和输出流模型的编码/解码测试。

3. 写状态转换测试，明确以下状态允许性：

   ```text
   queued → running → completed
   queued → cancelled
   running → failed / cancelled / timedOut
   completed / failed / cancelled / timedOut → 任何状态：禁止
   ```

4. 写 Job ID 幂等测试：两个同一 `toolCall.id` 的提交请求只能对应一个逻辑 Job。

5. 增加 `ToolJobObserverHandle` 和 Provider 增量协议；为协议新方法提供兼容的默认 no-op 实现，保证现有测试 doubles 先能编译。

6. 再次运行：

   ```bash
   swift test --package-path Packages/ProviderToolManager
   ```

   Expected: 新测试和旧测试全部 PASS。

7. Commit：

   ```bash
   git add Packages/ProviderToolManager
   git commit -m "feat(tool-job): define observable tool job contracts"
   ```

### Task 2: 增加工具执行上下文并保持旧工具兼容

**Files:**
- Create: `Packages/KitAgentTool/Sources/ToolExecutionContext.swift`
- Modify: `Packages/KitAgentTool/Sources/SuperAgentTool.swift`
- Create: `Packages/KitAgentTool/Tests/ToolExecutionContextTests.swift`

**Steps:**

1. 写一个只实现旧 `execute(arguments:)` 的测试工具，验证默认 Context 实现仍能返回相同文本结果。

2. 写一个实现新 Context 接口的测试工具，验证它能够调用 `reportProgress` 和 `reportOutput`，但不直接接触 Provider 层类型。

3. 把 Context 加入 `SuperAgentTool` 的协议要求，并提供默认转发实现。

4. 验证既有工具无需修改即可编译：

   ```bash
   swift test --package-path Packages/KitAgentTool
   swift test --package-path Packages/PluginToolManager
   ```

5. Commit：

   ```bash
   git add Packages/KitAgentTool
   git commit -m "feat(agent-tool): add cancellable execution context"
   ```

### Task 3: 修复 KitShell 的取消、进程组和输出边界

**Files:**
- Modify: `Packages/KitShell/Sources/ShellExecutor.swift`
- Modify: `Packages/KitShell/Sources/ShellTypes.swift`
- Modify: `Packages/KitShell/Tests/KitShellTests.swift`

**Steps:**

1. 先补写失败测试：执行一个会启动子进程的长命令，调用取消后，主进程和子进程都应在宽限期内退出。

2. 将当前基于 `pkill -P <pid>` 的直接子进程清理改为进程组策略：

   - 启动 Shell 时创建独立 process group/session；
   - 记录 process group ID；
   - 取消和超时时对整个进程组发送 `SIGTERM`；
   - 宽限期后发送 `SIGKILL`；
   - 不依赖只杀一层 direct child 的 `pkill -P`。

3. 保证取消发生在 `Process` 尚未启动和已经启动两种时序下都不会留下未处理的 continuation。

4. 为 stdout/stderr 增加保留上限：实时 callback 可以继续收到 chunk，但内部聚合结果必须截断并记录是否发生截断。

5. 为读管道增加排空超时，避免孙进程继承文件描述符后导致 `readDataToEndOfFile()` 永久等待。

6. 验证以下测试：

   ```bash
   swift test --package-path Packages/KitShell --filter ShellExecutorTests
   ```

   Expected: 长命令取消、超时、子进程清理、输出流和超大输出测试全部 PASS。

7. Commit：

   ```bash
   git add Packages/KitShell
   git commit -m "fix(shell): make process cancellation group-aware"
   ```

### Task 4: 让 ShellTool 使用流式输出

**Files:**
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Tools/ShellTool.swift`
- Modify: `Packages/PluginToolManager/Tests/PluginToolManagerTests/PluginToolManagerTests.swift`

**Steps:**

1. 写一个测试用工具执行 `printf` + 延迟输出，验证 Job Context 的 `reportOutput` 能收到中间 chunk，而不是只在最终结果返回时收到全部内容。

2. 在 ShellTool 中覆盖新的：

   ```swift
   executeResult(context:arguments:)
   ```

3. 使用 `ShellExecutor.executeStreaming`，stdout/stderr 分别报告为 `.stdout` / `.stderr`。

4. 最终 `ToolCallResult.content` 仍然保留兼容的聚合结果；实时 chunk 只走事件，不重复拼接到消息历史。

5. 在 ShellTool 的描述/schema 中明确：命令可能长时间运行、支持取消、输出会被限制。

6. 运行：

   ```bash
   swift test --package-path Packages/PluginToolManager --filter PluginToolManagerTests
   ```

7. Commit：

   ```bash
   git add Packages/PluginToolManager
   git commit -m "feat(shell-tool): stream output through tool jobs"
   ```

### Task 5: 实现 ToolExecutionManager 的最小闭环

**Files:**
- Create: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionManager.swift`
- Create: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionRuntime.swift`
- Create: `Packages/PluginToolManager/Tests/PluginToolManagerTests/ToolExecutionManagerTests.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolManager.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolManager+Run.swift`

**Architecture decision:** `ToolManager` 继续是 `@MainActor` 的注册和授权门面；真正的 Job runtime 由独立的 actor/后台任务持有。工具值、解码后的参数和 Context 必须在提交时冻结，后台执行期间不能回读 MainActor 上的注册表。

**Steps:**

1. 写一个 `SleepTool` 测试工具，支持在开始后等待数秒，并在等待期间检查取消状态。

2. 写 Job manager 测试：

   - `submit` 在 100 ms 内返回 Job 快照；
   - Job 最终变成 `completed`；
   - `started`、`completed` 各只出现一次；
   - output/progress 事件能被观察到；
   - `cancelJob` 让 Job 变成 `cancelled`；
   - 重复 `cancelJob` 不产生第二个完成事件；
   - 已有结果的 toolCall 再提交时复用结果，不重复执行。

3. 实现 Job runtime：

   ```swift
   @MainActor
   final class ToolExecutionManager {
       func submit(...) -> [ToolJob]
       func job(for:) -> ToolJob?
       func cancelJob(_:)
       func cancelJobs(for: UUID)
   }
   ```

   Job 的实际执行 Task 由 runtime 保存；每次状态变化都通过统一的 `emit` 函数更新快照并发布事件。

4. 将工具执行包装成 `Task`，并将 `Task` 的取消传递给工具 Context。对 `ShellExecutor` 来说，Task 取消必须继续触发底层 Process 的终止。

5. 为每个 Job 增加一次性终态闸门，例如 `finishIfNeeded`，避免超时、取消和 Process termination handler 竞争时重复完成。

6. 把 `ToolManager.execute` 改成：创建/复用 Job → 等待该 Job 终态 → 返回 `ToolCallResult`。

7. 把旧 `executeBatch` 改成兼容包装器：内部可以使用 Job manager，但在 API 返回前仍等待批次完成。这样旧调用方和旧测试暂时不变。

8. 运行：

   ```bash
   swift test --package-path Packages/PluginToolManager
   ```

   Expected: 新 Job 测试、已有工具授权测试和记录测试全部 PASS。

9. Commit：

   ```bash
   git add Packages/PluginToolManager
   git commit -m "feat(tool-job): add cancellable execution manager"
   ```

### Task 6: 将 ToolCallsObserver 切换为 submit，不再等待批次

**Files:**
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Observers/ToolCallsObserver.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolManager.swift`
- Modify: `Packages/PluginToolManager/Tests/PluginToolManagerTests/PluginToolManagerTests.swift`

**Steps:**

1. 写失败测试：发送一个长时间工具调用，`ToolCallsObserver.handle` 返回后，Job 必须已经创建，但调用方不应等待工具完成。

2. 将当前：

   ```swift
   Task { await toolManager.executeBatch(...) }
   ```

   改为调用非阻塞的：

   ```swift
   _ = toolManager.submit(...)
   ```

3. 保留现有的 `.chat`、`.autonomous`、`.build` 授权策略；不要把审批逻辑搬到 UI。

4. 处理空执行列表时必须显式通知 AgentLoop：

   - 如果所有调用都需要审批，进入等待用户状态；
   - 如果全部被阻止，产生对应的 blocked 结果；
   - 不能仅仅 `return`，否则 AgentLoop 会永远停在 pending。

5. 保留旧 `batchCompleted` 给兼容路径，但新路径要以单 Job 终态事件为主，避免同时消费 `completed` 和 `batchCompleted` 造成重复写回。

6. 运行：

   ```bash
   swift test --package-path Packages/PluginToolManager
   ```

7. Commit：

   ```bash
   git add Packages/PluginToolManager
   git commit -m "refactor(tool-job): submit tool calls without batch blocking"
   ```

### Task 7: 扩展 AgentTurnFSM，加入 waitingForToolJobs

**Files:**
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopManager.swift`
- Create or modify: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ToolJobLoopTests.swift`

**Target state:**

```swift
case waitingForToolJobs(
    turnID: UUID,
    assistantMessageID: UUID,
    pendingToolCalls: [MessageToolCall],
    jobIDs: Set<String>
)
```

**Steps:**

1. 先写 reducer 测试：

   - 工具调用返回后进入 `waitingForToolJobs`；
   - Job 完成一个，仍保留其他 pending；
   - 全部 Job 完成后回到 `requestingLLM`；
   - Job 失败也必须移除 pending，并把失败结果回写给模型；
   - 取消时所有 Job 都收到 cancel，最终进入 `cancelled`；
   - 过期 turn 的 Job 事件被忽略。

2. 把 `TurnPhase.executingTools` 的含义收窄为“已经收到工具调用、正在提交/授权”，把长时间等待改为 `waitingForToolJobs`。

3. `launchAdvance` 只负责 LLM 请求；工具执行期间不创建一个持续等待的 Agent Task。

4. 在 `AgentLoopManager` 中订阅 ToolJobEvent，并将事件转成 MainActor 上的内部事件：

   ```text
   job.completed → toolJobCompleted
   job.failed    → toolJobCompleted(error)
   job.cancelled → toolJobCompleted(cancelled)
   ```

5. 处理单个工具完成：

   - 更新 assistant message 中对应的嵌套 toolCall result；
   - 插入兼容的 `.tool` 结果消息；
   - 通过 reducer 移除对应 pending；
   - 若仍有 pending，不请求 LLM；
   - 若全部完成，才启动下一轮 LLM。

6. 取消流程必须先调用 `toolManager.cancelJobs(for: turnID)`，再将 AgentLoop 置为 `cancelled`。不能只取消 AgentLoop 自己的 Task。

7. 处理 Job 事件晚于 AgentLoop 取消/完成的情况：使用 `conversationID + turnID + jobID` 三重校验，忽略 stale event。

8. 运行：

   ```bash
   swift test --package-path Packages/PluginAgentLoop
   ```

   Expected: 既有完整 AgentLoop 测试和 Tool Job Loop 测试全部 PASS。

9. Commit：

   ```bash
   git add Packages/PluginAgentLoop
   git commit -m "feat(agent-loop): resume turns from tool job events"
   ```

### Task 8: 加入并发策略，但默认保持安全串行

**Files:**
- Create: `Packages/KitAgentTool/Sources/ToolExecutionCapability.swift`
- Modify: `Packages/KitAgentTool/Sources/SuperAgentTool.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionManager.swift`
- Modify: built-in tools under `Packages/PluginToolManager/Sources/PluginToolManager/Tools/`
- Create: `Packages/PluginToolManager/Tests/PluginToolManagerTests/ToolExecutionSchedulingTests.swift`

**Steps:**

1. 增加工具能力声明，默认使用最安全的串行策略：

   ```swift
   public enum ToolExecutionCapability: Sendable {
       case serialSideEffect
       case parallelReadOnly
       case interactive
   }
   ```

2. 标记内置工具：

   - `ReadFileTool`、`ReadImageTool`、`ListDirectoryTool`、`GlobTool`：`parallelReadOnly`；
   - `WriteFileTool`、`EditFileTool`、`ShellTool`：`serialSideEffect`；
   - `ask_user` 或类似工具：`interactive`。

3. 调度规则：

   - 同一个 turn 内，read-only Job 可并行，最大并发数先固定为 4；
   - side-effect Job 按提交顺序串行；
   - interactive Job 暂停后续 Job；
   - 不同 conversation 可以并行；
   - 同一 conversation 同一 turn 只能有一个 AgentLoop 决策者。

4. 写测试验证并行读工具总耗时接近单个工具耗时，写工具仍保持顺序。

5. 如果任何自定义工具没有声明能力，必须走 `.serialSideEffect` 默认值，而不是猜测它是安全的。

6. 运行：

   ```bash
   swift test --package-path Packages/PluginToolManager --filter ToolExecutionSchedulingTests
   ```

7. Commit：

   ```bash
   git add Packages/KitAgentTool Packages/PluginToolManager
   git commit -m "feat(tool-job): schedule read-only tools safely in parallel"
   ```

### Task 9: 持久化运行中的 Job 和幂等恢复

**Files:**
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobRecord.swift`
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobRecordModel.swift`
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobRecordStore.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionManager.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/PluginToolManager.swift`
- Create: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/ToolJobRecordStoreTests.swift`

**Persistence decision:** 不要强行把正在运行的 Job 字段塞进既有 `ToolCallRecordModel`。既有调用日志是“完成后记录”，运行中的 Job 是“可恢复状态”；使用独立的 `tool_jobs.sqlite`，避免历史日志 schema 迁移和语义混淆。

**Steps:**

1. 定义持久化字段：Job ID、conversation ID、turn ID、tool name、arguments hash、status、startedAt、updatedAt、latest output、process ID、cancel requested、completedAt、result/error。

2. 写 store 测试：创建、状态更新、输出尾部更新、按 conversation/turn 查询、终态查询、删除 conversation。

3. 在 Job 创建时先写 `queued`，启动进程前更新为 `running`，终态写入 result。

4. 启动应用时加载非终态 Job：

   - 能确认底层进程仍存在且属于当前进程组：重新绑定 watcher；
   - 无法确认进程：标记为 `failed`，错误为“应用重启后无法恢复工具进程”，不能静默重跑；
   - 对有副作用的 Job 永远不根据历史记录自动重新执行。

5. `submit` 遇到已有同 ID Job 时：

   - 已完成：直接复用结果；
   - 正在运行：返回已有 Job；
   - 失败/取消：只有用户显式重试才允许创建新的 attempt，且 attempt ID 与原 toolCall ID 分开记录。

6. 运行：

   ```bash
   swift test --package-path Packages/ProviderToolManager
   swift test --package-path Packages/PluginToolManager
   ```

7. Commit：

   ```bash
   git add Packages/ProviderToolManager Packages/PluginToolManager
   git commit -m "feat(tool-job): persist and recover execution state"
   ```

### Task 10: 接入会话状态和实时 UI

**Files:**
- Modify: `Packages/ProviderConversationState/Sources/ProviderConversationState/ConversationStateProviding.swift`
- Modify: `Packages/PluginConversationState/Sources/PluginConversationState/Observers/ToolManagerStateObserver.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Models/MessageListServices.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/AgentTurnViewModel.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Models/ToolCallResultVisualState.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Helpers/ToolStepGroupSummary.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Views/AssistantToolCallViews.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Views/CollapsibleToolStepGroup.swift`
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Views/ToolJobOutputPopover.swift`
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Views/ToolJobStopButton.swift`
- Create: `Packages/PluginMessageList/Tests/PluginMessageListTests/ToolJobActivityProjectionTests.swift`
- Create: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ToolJobSummaryTests.swift`

**Steps:**

1. 先写纯 UI 状态测试：

   ```text
   queued      → 排队中
   running     → 执行中 + elapsed
   waiting     → 等待用户
   completed   → 已完成
   failed      → 失败
   cancelled   → 已停止
   timedOut    → 已超时
   ```

2. 在 `ToolManagerStateObserver` 中订阅 ToolJobEvent，不再只依赖 `.started` / `.batchCompleted` 推断全局工具状态。

3. 会话状态至少增加：当前 Job 数量、运行中 Job 数量、最近 Job 描述、最近 Job 更新时间。保留旧 `activity` 字段以兼容现有页面。

4. 将 `MessageListServices.activityMessage` 从固定的“正在执行工具…”改为动态内容，例如：

   ```text
   正在执行：npm test · 已运行 2 分 18 秒
   正在执行 2 个任务 · 已完成 1 个
   等待工具输出…
   ```

5. 工具行在没有最终 result 时显示 Job snapshot：

   - 工具名称/操作描述；
   - 运行时长；
   - 最新进度；
   - 输出查看入口；
   - 停止按钮。

6. `Stop` 按钮只调用 `cancelJob(toolCall.id)`；AgentLoop 的全局停止按钮调用 `cancelJobs(for: turnID)`。

7. 输出 Popover 只显示受限尾部，使用 LumiUI 现有的 `AppSurface`、`AppButton`、`AppIconButton`、`AppLoadingOverlay` 等组件，不新建独立视觉体系。

8. V1 折叠摘要改为：

   ```text
   执行中 · 1/3 · 2分钟18秒
   已停止 · 1个失败
   执行了3个步骤 · 4分钟02秒
   ```

9. 运行相关测试和构建：

   ```bash
   swift test --package-path Packages/PluginMessageList
   swift test --package-path Packages/PluginToolManager
   xcodebuild \
     -project Lumi.xcodeproj \
     -scheme Lumi \
     -configuration Debug \
     -sdk macosx \
     -disableAutomaticPackageResolution \
     -onlyUsePackageVersionsFromResolvedFile \
     build
   ```

10. Commit：

   ```bash
   git add Packages/ProviderConversationState Packages/PluginConversationState Packages/PluginMessageList Packages/PluginMessageRenderer
   git commit -m "feat(tool-job): show live execution state and stop controls"
   ```

### Task 11: 完成 AgentLoop 取消、超时和异常路径

**Files:**
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopManager.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift`
- Modify: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/PluginAgentLoopTests.swift`
- Create: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ToolJobCancellationTests.swift`

**Steps:**

1. 写取消测试：运行 `sleep` 类型工具，调用 `cancelTurn` 后验证：

   - AgentLoop 状态为 cancelled；
   - Job 状态为 cancelled；
   - Shell 进程组不存在；
   - 不会再次请求 LLM；
   - 不会晚到一个 stale completion 把 turn 重新推进。

2. 写超时测试：工具超过 timeout 后变为 `timedOut`，AgentLoop 收到一个可解释的工具错误结果，并继续或失败，行为必须由策略明确决定，不能卡住。

3. 写工具抛错测试：抛错必须转成终态 `failed` 和 `ToolCallResult(isError: true)`，仍然唤醒 AgentLoop。

4. 写 AgentLoop 任务泄漏测试：完成、失败、取消和挂起四条路径结束后，runtime 中不能保留无主 task、completion waiter 或 Job observer。

5. 避免 `finishTurn` 与 Job completion 并发重复结束；所有终态操作都要校验当前 turn ID。

6. 运行：

   ```bash
   swift test --package-path Packages/PluginAgentLoop
   ```

7. Commit：

   ```bash
   git add Packages/PluginAgentLoop
   git commit -m "fix(agent-loop): cancel and finalize tool jobs reliably"
   ```

### Task 12: 集成验证、故障注入和文档收尾

**Files:**
- Modify: `docs/plans/2026-09-02-agent-tool-job-orchestration.md` only if implementation decisions differ
- Create: `docs/agent-tool-job-operations.md`
- Create or modify: package integration tests under affected packages

**Steps:**

1. 运行所有受影响 Package：

   ```bash
   swift test --package-path Packages/KitAgentTool
   swift test --package-path Packages/KitShell
   swift test --package-path Packages/ProviderToolManager
   swift test --package-path Packages/PluginToolManager
   swift test --package-path Packages/PluginAgentLoop
   swift test --package-path Packages/PluginMessageList
   swift test --package-path Packages/FactoryLumi
   ```

2. 运行完整 Debug build：

   ```bash
   xcodebuild \
     -project Lumi.xcodeproj \
     -scheme Lumi \
     -configuration Debug \
     -sdk macosx \
     -disableAutomaticPackageResolution \
     -onlyUsePackageVersionsFromResolvedFile \
     build
   ```

3. 手工验收长 Shell 命令：

   ```bash
   for i in 1 2 3 4 5; do echo "tick-$i"; sleep 1; done
   ```

   Expected：

   - Job 在 1 秒内出现；
   - 每个 tick 能在 UI 输出中逐步出现；
   - UI 显示运行时长；
   - 工具完成后 Agent 自动继续；
   - 最终结果只写入一次。

4. 手工验收取消：

   ```bash
   sleep 60
   ```

   Expected：点击停止后 2 秒左右内 Job 进入 cancelled，`ps` 中没有对应的 shell/child process。

5. 故障注入：

   - 工具启动失败；
   - stdout 持续输出超过上限；
   - 工具进程启动后 App 取消；
   - App 重启时存在 running Job；
   - Job 完成事件重复到达；
   - LLM 在工具完成前返回错误；
   - 用户在等待 Job 时删除会话。

6. 检查日志和持久化：

   - 不记录 Authorization header、API key、完整环境变量；
   - 工具参数按现有 sanitized 规则记录；
   - Job 输出受限；
   - 删除会话后 Job watcher、缓存和记录都被清理；
   - 取消后的 Job 不会被应用重启逻辑自动重新执行。

7. 在 `docs/agent-tool-job-operations.md` 记录：Job 状态含义、取消语义、输出大小、超时默认值、重启恢复策略、排查命令和已知限制。

8. Commit：

   ```bash
   git add docs/agent-tool-job-operations.md
   git commit -m "docs(tool-job): document runtime operations and recovery"
   ```

## 5. 验收标准

实现完成后，以下标准必须全部满足。

### 5.1 用户体验

- 长工具启动后，用户在 100 ms～1 s 内看到明确的工具 Job；
- 页面显示工具描述、状态、运行时长和最近进度；
- Shell stdout/stderr 可以实时查看；
- 用户可以停止单个 Job，也可以停止整个 Agent turn；
- 工具完成后，Agent 自动继续，不需要用户再次发送消息；
- 工具失败、超时、取消都有明确文案。

### 5.2 AgentLoop 正确性

- AgentLoop 不再等待 `executeBatch()` 持续数分钟；
- 每个 toolCall 的结果只写回一次；
- Job 完成顺序可以与提交顺序不同；
- stale event 不会推进旧 turn；
- 取消后不会再次请求 LLM；
- Job 完成、失败、取消均能结束 pending 状态，不会永久 loading。

### 5.3 进程安全

- 取消会终止整个 Shell 进程组，而非只终止一层 wrapper；
- 超时会执行 TERM → grace period → KILL；
- stdout/stderr 有大小上限和排空超时；
- 不留下 orphan process；
- App 退出或会话删除时，不留下不可见后台任务。

### 5.4 幂等与恢复

- `toolCall.id` 是 Job 幂等键；
- 已完成的副作用工具不会因重连重跑；
- 重启后无法恢复的 Job 会明确标记失败，而不是静默重试；
- 取消状态不会被恢复逻辑误判为待执行；
- AgentLoop 和 ToolManager 的终态事件都是幂等的。

## 6. 建议的提交顺序

```text
1. feat(tool-job): define observable tool job contracts
2. feat(agent-tool): add cancellable execution context
3. fix(shell): make process cancellation group-aware
4. feat(shell-tool): stream output through tool jobs
5. feat(tool-job): add cancellable execution manager
6. refactor(tool-job): submit tool calls without batch blocking
7. feat(agent-loop): resume turns from tool job events
8. feat(tool-job): schedule read-only tools safely in parallel
9. feat(tool-job): persist and recover execution state
10. feat(tool-job): show live execution state and stop controls
11. fix(agent-loop): cancel and finalize tool jobs reliably
12. docs(tool-job): document runtime operations and recovery
```

每完成一个提交，都先运行对应 Package 的 focused tests，再进入下一阶段。若某个阶段需要改变前一阶段的公共契约，应先更新测试和本方案中的模型说明，再继续实现。

## 7. 后续增强：LLM 中途观察

P0～P1 完成后，如果仍希望让 LLM 在工具执行期间拥有“全局认知”，再增加一个显式的观察机制，而不是让 LLM 隐式并行思考。

建议新增 Agent 内部动作：

```text
Tool Job running
    ↓ 发生重要进度 / 用户主动询问 / 超过观察间隔
创建 bounded observation turn
    ↓
向 LLM 提供：jobID、状态、运行时长、进度、截断输出
    ↓
LLM 可以决定：继续等待、取消、补充工具、向用户报告
```

约束：

- 默认关闭，只对声明支持 observation 的工具启用；
- 观察间隔至少 2～5 秒，并做 debounce；
- 同一 conversation 同时只能有一个 LLM decision turn；
- 观察结果不能直接改变正在执行的副作用 Job；
- 用户主动停止的优先级高于任何模型建议；
- 每次 observation 都限制输入大小和调用次数；
- Job 完成附近如果已经收到完成事件，不再创建重复 continuation。

这部分完成后，Lumi 才具备接近“Agent 能看到长期任务全局进展”的能力；但前提仍然是先完成可靠的 Job、事件和取消基础设施。
