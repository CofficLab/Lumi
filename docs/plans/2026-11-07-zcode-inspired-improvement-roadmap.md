# ZCode-Inspired Agent Reliability Improvement Roadmap

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在不重写 Lumi 现有 Kernel / Provider / Plugin、AgentLoop、ToolJob、MCP 与压缩体系的前提下，引入 ZCode 已验证的输入账本、执行契约、流式恢复、诊断治理和测试边界。

**Architecture:** 先关闭敏感诊断数据与持久一致性的高风险缺口，再统一执行上下文和流式提交边界，最后用故障注入、真实装配测试和渐进架构门禁固化行为。功能数据、诊断数据与 Artifact 分开治理；所有持久化承诺限定在实际同一事务内。

**Tech Stack:** Swift 6、Swift Testing、Swift Package Manager、SwiftData、SQLite、OSLog、KitLLM、KitAgentTool、PluginAgentLoop、PluginMessageManager、PluginToolManager。

---

## 1. 这份路线图怎么用

本文件只决定顺序、依赖和共同约束。具体实现必须进入对应专项计划，逐 Task 执行，不要把多份计划合并成一次大改。

| 顺序 | 专项计划 | 优先级 | 可并行性 | 完成后的核心保证 |
|---|---|---|---|---|
| 1 | [敏感诊断数据治理](2026-11-07-sensitive-diagnostics-governance.md) | P0 | 可独立开始 | 新诊断记录默认 metadata-only、脱敏、有界；导出再次脱敏 |
| 2 | [持久 ConversationInput 与幂等 Promotion](2026-11-07-durable-conversation-input.md) | P0/P1 | 可与 1 并行 | 点击发送先生成稳定 command，账本与用户消息同事务提交 |
| 3 | [AgentExecutionContext 与工具契约](2026-11-07-agent-execution-context-and-tool-contract.md) | P0/P1 | 可与 1、2 并行 | Trace 显式传播；两条工具执行路径共享 deadline、取消与结果收尾 |
| 4 | [Stream Attempt 与断流恢复](2026-11-07-stream-attempt-recovery.md) | P1 | 依赖 2、3 的接口 | 只从已提交锚点恢复；旧 attempt 不能覆盖新 attempt；工具事件有持久化屏障 |
| 5 | [Agent 测试与渐进架构治理](2026-11-07-agent-test-and-architecture-governance.md) | P1 | 先写测试骨架，随 1–4 补充 | 故障注入、FactoryLumi 真实装配、核心包依赖规则进入 CI |
| 6 | [Steering 与只读 Explore 子代理](2026-11-07-agent-steering-and-explore-subagent.md) | P2 | 必须在 2–5 验收后 | 复用输入账本和 AgentLoop，提供安全边界的插队与只读子任务 |

### 强制阶段门

- 阶段 1–3 任一未完成验收，不得开始阶段 4 的集成切换。
- 阶段 4 未完成崩溃恢复与工具副作用未知测试，不得开始阶段 6。
- 每个 Task 按“失败测试 → 最小实现 → 通过测试 → 独立提交”执行。
- 不以全量测试通过替代真实 App 验证；至少执行专项计划列出的手工路径。
- 不自动 push。每个实施阶段的提交和推送分别遵循用户当次指令。

## 2. 源码事实基线

实施前先读当前文件，不能仅凭本计划假设代码仍未变化。若现状与计划不同，先记录差异，再保持本计划的状态语义调整最小实现。

### Lumi 已有能力，不重建

- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift` 已有 Turn 状态机、恢复预算、工具等待与挂起状态。
- `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionManager.swift` 已有独立 ToolJob、幂等提交、只读并发与副作用串行屏障。
- `Packages/KitShell/Sources/KitShell/ShellExecutor.swift` 已有 Shell 超时、取消、进程树终止和输出限制。
- `Packages/PluginMessageManager/Sources/PluginMessageManager/Managers/MessageManager.swift` 已有 write-behind 消息时间线；它不等于 durable commit 确认。
- `Packages/PluginConversationResume/Sources/PluginConversationResume/Managers/ResumeCoordinator.swift` 已有回合记录和孤儿 tool call 修复。
- `Packages/KitMCP` 与 `Packages/PluginMCP` 已有 MCP stdio / Streamable HTTP 与工具适配。
- 现有上下文压缩计划与实现继续有效；本路线图不另建 compact 引擎。

### ZCode 参考点

参考源码位于 ZCode 仓库；以下是仓库内路径，不要求把 ZCode 放进 Lumi 的构建图：

- `apps/zcode-cli/packages/contracts/src/tools/contract.ts`：工具声明、预算、超时、取消、Trace。
- `apps/zcode-cli/packages/bootstrap/src/zcode-protocol-v4/command-inbox.ts`：命令 schema、去重、FIFO、终态共享。
- `apps/zcode-cli/packages/core/src/runtime/command-queue.ts`：`now / next / later` 与 guide/queue。
- `apps/zcode-cli/packages/adapters/src/storage/session-store/repositories/session-inputs.ts`：同事务 promotion 与 CAS settle。
- `apps/zcode-cli/packages/core/src/runtime/methods/streaming-recovery.ts`：committed anchor、tail discard、新 assistant attempt。
- `apps/zcode-cli/packages/core/src/compact/microcompact.ts`：保留最近结果、最低节省阈值、默认保留错误与媒体。
- `apps/zcode-cli/packages/core/src/tool/executor/result-serialization.ts`：大结果 Artifact 与模型 preview。
- `apps/zcode-cli/packages/contracts/src/tracing/tracer.ts`：parent/child TraceContext。
- `packages/provider/src/registry-service.ts`：revision、single-flight、原子 snapshot。
- `architecture-policy.yaml`：managed 模块渐进治理。

借鉴的是不变量和边界，不是 TypeScript 代码翻译，也不是引入一套平行运行时。

## 3. 共同不变量

### 3.1 状态所有权

| 事实 | 唯一所有者 | 其他模块只能做什么 |
|---|---|---|
| ConversationInput command、队列顺序、promotion、dispatch 状态 | MessageSender 使用的持久输入协调器 | UI 提交快照；MessageStore 执行事务；AgentLoop 报告回合状态 |
| 用户/assistant/tool 功能消息 | MessageManager + MessageStore | Sender/AgentLoop 调用明确 durable API；诊断模块不得重写 |
| Turn phase、恢复预算、当前 attempt | AgentLoop | Resume 读取快照；Sender 不复制一套 Turn FSM |
| ToolJob、授权、执行终态 | ToolExecutionManager / ToolManagerProviding | AgentLoop 等待事件；子代理不直接执行绕过授权的工具 |
| HTTP/工具/file log 诊断记录 | 各自 Store | 共享 sanitizer；功能恢复逻辑不得依赖这些记录 |
| Artifact 字节 | ArtifactStore | 消息与导出只保存引用和必要 preview |

### 3.2 持久化语义

1. `ConversationInputModel`、`MessageModel` 和后续 `StreamAttemptAnchorModel` 必须加入同一个 `Schema` / `ModelContainer`，需要原子更新的字段在同一个 `ModelContext` 中只调用一次 `save()`。
2. Conversation SQLite、消息 SwiftData、ToolJob 存储、Resume JSON 之间**不存在原子事务**。跨存储流程只能使用稳定 ID、durable upsert、状态机、恢复扫描和明确顺序。
3. `MessageChange.inserted` 当前表示进入内存 buffer，不能作为 durable accept、promotion 或 stream final 的确认。
4. durable API 只有在 `context.save()` 成功后才返回成功；失败必须抛错并保留可重试状态。
5. 所有持久状态转换带 `revision` 或等价 CAS 条件；迟到 worker 不得把新状态回退。

### 3.3 执行与恢复语义

1. 不承诺 LLM 请求 exactly-once，不承诺工具副作用 exactly-once。
2. LLM 已发出但进程崩溃时，恢复结果是“可能已产生上游副作用/计费”；不得静默声称未执行。
3. 通用 OpenAI/Anthropic 兼容供应商不支持 token 级续流。恢复使用最后 durable prefix + 新 attempt，不伪造供应商 continuation。
4. 工具开始执行后若结果未知，禁止自动重放副作用；显示可操作的未知状态，由用户或工具专属幂等逻辑决定下一步。
5. 取消请求不等于外部副作用已经停止。非协作工具超时/取消后，记录 `cancellationRequested` 与真实终态的区别。
6. 工具参数或结果 unknown 时采取保守调度：只有明确只读的工具可并行。

### 3.4 Trace 与诊断语义

1. `traceID` 在一次用户 turn 及其子工具/子 Agent 中保持不变；每个执行单元有新的 `spanID` 和可选 `parentSpanID`。
2. Trace 值通过参数显式传递。不得依赖 `TaskLocal` 跨越 `Task.detached`、URLSession 回调、MCP SDK 或线程跳转。
3. 内部 trace ID 默认只写本地结构化审计。不得自动加到上游 HTTP header、MCP `_meta` 或第三方请求体；未来如需传播，单独做隐私与协议评审。
4. 诊断默认不保存 Authorization、Cookie、API Key、URL 敏感 query、完整 prompt、工具参数或结果正文。
5. 对功能消息、ToolJob 恢复参数、模型上下文和 Artifact 不得套用“诊断截断后即完成”的逻辑。模型 preview、完整功能结果、诊断审计是三种不同数据。
6. 所有采集有字节预算；尽量在源头不采集，而不是先保存完整内容再截断展示。

### 3.5 Swift 协议与并发

- 新增到 protocol extension 且允许具体类型覆盖的能力，必须同时声明为 protocol requirement。否则 `any SuperAgentTool` / `any MessageSendingProviding` 可能静态分派到默认实现。
- `LLMRequest` 的 `executionContext` 等字段必须在所有 routed request 重建点复制；优先用统一 `routed(...)` helper 防止漏字段。
- 不在 MainActor 上做大附件编码、全量历史解码或批量脱敏。
- 不用 detached task 的“已开始”作为状态已提交的证据。

## 4. 包边界与依赖方向

允许方向保持：

```text
Kit / Provider  →  基础契约与实现所需底层包
Plugin          →  Provider / Kit
FactoryLumi     →  真实 Plugin 装配与生命周期
App             →  FactoryLumi
```

禁止新增：

- Kit 或 Provider 反向 import Plugin。
- MessageSender 直接操作 SwiftData `ModelContext`；事务由 MessageManager/Store 能力完成。
- AgentLoop 直接写 HTTP 诊断库或 ToolCall 审计库。
- 为子代理另建 ToolManager、Turn FSM、权限系统或消息数据库。
- 为输入账本另建与 MessageStore 不同数据库文件的“伪同事务”。

新增类型放在能同时被 KitLLM 与工具包依赖的最底层；当前 `KitLLM` 已依赖 `KitAgentTool`，所以共享 `AgentExecutionContext` 可放在 `KitAgentTool`，不能反向放入依赖 KitLLM 的包。

## 5. 实施工作区纪律

实施 agent 开始前必须运行：

```bash
git status --short --branch
git diff --stat
git diff -- <本 Task 将修改的文件>
```

要求：

1. 保留用户已有改动；发现目标文件已修改时，先理解并在其基础上改，禁止 checkout、restore 或 reset 覆盖。
2. 每个 Task 只暂存该 Task 的文件；提交前检查 `git diff --cached --stat` 和完整 staged diff。
3. 不提交 `.build`、`DerivedData`、临时数据库、导出的诊断 zip、真实 fixture 密钥或本机绝对路径。
4. 测试中的 token 使用明显虚构值，例如 `test-secret-do-not-use`；测试结束不得把它写入真实日志文件。
5. 提交信息匹配仓库英文 Conventional Commit 风格，例如 `fix(PluginNetworkManager): redact persisted HTTP diagnostics`。
6. 某测试因环境无法运行时，明确列为“未验证”，不能用编译通过替代。

## 6. 共享验证矩阵

从 Lumi 仓库根目录运行。每个专项只要求相关子集；阶段 5 收尾运行以下核心集合：

```bash
swift test --package-path Packages/ProviderDiagnostics
swift test --package-path Packages/KitAgentTool
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/KitMCP
swift test --package-path Packages/PluginMCP
swift test --package-path Packages/KitLLM
swift test --package-path Packages/PluginLLMManager
swift test --package-path Packages/PluginNetworkManager
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/ProviderMessage
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/PluginMessageSender
swift test --package-path Packages/PluginConversationResume
swift test --package-path Packages/PluginMessageRenderer
swift test --package-path Packages/PluginFileLog
swift test --package-path Packages/PluginConversationExport
swift test --package-path Packages/FactoryLumi
```

全包回归使用现有入口，并在测试治理 Task 4 修复退出码之前同时检查失败清单：

```bash
Scripts/run-all-package-tests.sh
test ! -s .test-logs/FAILED.txt
```

测试治理 Task 4 验收后，脚本自身必须在任一失败时非零退出；`FAILED.txt` 检查仍可作为审计证据，但不能被 `cat` 的成功退出码替代。

构建使用仓库当前有效 scheme/配置；若本地 Xcode 与 CI 不一致，记录实际命令和版本。CI 的权威构建继续复用 `.github/scripts/archive-lumi.sh`，不要为测试新造一套 release 构建脚本。

## 7. 故障注入总表

专项计划必须覆盖适用行，并可用确定性 hook 代替真的 kill；至少一条集成测试使用独立进程退出模拟崩溃。

| 故障点 | 必须观察到的结果 | 禁止结果 |
|---|---|---|
| accept 保存前失败 | UI 草稿仍在；无 user 消息；可复用 commandID 重试 | 清空草稿或生成重复 command |
| promotion save 前崩溃 | queued 仍在；重启后只产生预分配 userMessageID | 两条 user 消息 |
| promotion save 后、通知前崩溃 | 重启按稳定 ID 重建投影 | 再插入一条 user 消息 |
| dispatch 已调用、状态未收尾时崩溃 | 标为结果未知/待确认，不盲目重放 | 静默第二次 LLM 调用 |
| SSE 已提交 prefix 后断流 | 旧 attempt interrupted；新 attempt 新 assistantMessageID | 把未提交 tail 当事实续接 |
| 旧 stream 回调晚于新 attempt | revision/attempt guard 丢弃 | 新正文被旧正文覆盖 |
| assistant tool call 已收到、持久化失败 | 不提交工具执行 | 未落库 tool_use 已产生副作用 |
| 工具已执行、结果保存失败 | ToolJob/回合显示未知或失败；不自动重放 | 副作用工具再次运行 |
|  queued 取消与 promotion 并发 | CAS 只允许一个胜者 | cancelled 又变 promoted，或删除已公开 user 消息 |
| 同一 command 并发 submit | 共享同一 acceptance/终态 | 两个 Turn 或两条 user 消息 |
| 诊断包含 token/cookie/prompt | 入库和导出均无敏感值，正文默认 nil | 仅 UI 显示时打码 |
| 非协作工具超时 | 请求取消并记录未知外部副作用 | 立即宣称进程/远程写已停止 |

## 8. 非目标与后续触发条件

### 本路线图不做

- 不重写 AgentTurnFSM、ToolJob、ShellExecutor、MCP、Resume 或 compact。
- 不引入跨存储分布式事务、两阶段提交或 exactly-once 宣传。
- 不把所有日志改为不可诊断的空记录；保留时间、状态码、字节数、错误码、trace/span 与预算信息。
- 不在第一阶段开发完整的可视化 Trace 产品；先让本地审计可关联。
- 不为了实现 ZCode 对齐而替换 Swift 并发、SwiftData 或 Kernel 插件系统。

### 条件性后续

- **Provider Registry 原子 snapshot**：只有出现多来源异步刷新导致部分 provider/model 列表可见、选择解析瞬态失败时再立项。参考 ZCode revision + single-flight + 保留上一份完整 snapshot；不要提前重写当前 LLMManager。
- **microcompact 扩展**：先用现有 compact 指标证明旧工具结果导致上下文压力，再增加保留最近 N 个结果、最低节省阈值、错误/媒体默认保留。必须扩展现有计划，不另建压缩入口。
- **输出 continuation**：只有供应商明确支持且能验证 continuation token/response ID 语义时实现；通用路径仍使用新 attempt。
- **外部 Trace 传播**：仅在隐私评审、供应商兼容与 opt-in 配置完成后进行。
- **完整 Artifact UI**：基础引用与导出必须先正确，再考虑缩略图、下载管理和跨会话浏览。

## 9. 路线图总验收

每个专项验收均完成后，按以下顺序做一次端到端验证：

1. 全新安装：创建会话，发送带附件消息，durable accept 后草稿清空，只有一个 userMessageID。
2. 忙碌会话连续发送三条：账本 FIFO 与 UI 顺序一致；取消一条 queued 不影响已 promoted 消息。
3. 同一 command 重试与并发提交：只有一条用户消息、一个逻辑 Turn。
4. 流式输出中断：保留已提交 prefix，旧 attempt 不再更新，新 attempt 明确标识恢复。
5. 工具调用：授权、只读并发、副作用串行、deadline、取消与超时语义均符合契约。
6. 工具副作用后模拟结果保存失败：重启不自动重放，用户能看到未知状态与处理入口。
7. Trace：turn → LLM attempt → tool job → MCP call 的本地审计可用同一 traceID 关联，span 父子关系正确。
8. 诊断：新 HTTP/工具/file log 记录无测试 secret，正文有界；导出再次扫描通过。
9. 旧版本数据：消息、ToolJob、会话正常打开；派生 Resume/诊断缓存可重建，不作为唯一事实。
10. CI：核心 package tests、FactoryLumi 装配、架构边界检查和现有双架构 release validation 均通过。

完成证据应包含实际测试命令、结果、手工验证步骤和未覆盖限制；不得只写“理论上可恢复”。
