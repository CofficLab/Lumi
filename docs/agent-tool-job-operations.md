# Tool Job 运行与故障排查指南

本文描述 Lumi 当前 Tool Job 的运行模型、状态含义、取消/超时语义、重启恢复策略以及常用排查方法。

## 1. 运行模型

AgentLoop 收到 LLM 的 `tool_call` 后，不再把整个回合挂在一次长时间的 `executeBatch()` 上。`ToolManager` 将调用提交给 `ToolExecutionManager`，后者立即创建 Job，并由独立的后台 `Task` 执行工具。

```text
LLM tool_call
    ↓
ToolManager.submit()
    ↓ 立即返回 ToolJob 快照
ToolExecutionManager
    ├─ started / output / progress
    └─ completed / failed / cancelled / timedOut
    ↓
AgentLoop 回写 tool result，并继续请求 LLM
```

Job 的幂等键是 `toolCall.id`。同一个 ID 再次提交时，会复用已有 Job，不会重新执行工具。

## 2. Job 状态

| 状态 | 含义 | 是否终态 |
| --- | --- | --- |
| `queued` | 已创建，等待调度。副作用工具可能因为前序 Job 尚未完成而停在这里。 | 否 |
| `running` | 工具已经开始执行。Shell 工具此时可能有持续的 stdout/stderr 输出。 | 否 |
| `waitingForUser` | 工具需要用户授权或交互。 | 否 |
| `completed` | 工具成功返回结果。 | 是 |
| `failed` | 工具启动失败、参数无效或执行抛出普通错误。 | 是 |
| `cancelled` | 用户或 Agent 回合主动取消。 | 是 |
| `timedOut` | Shell 工具超过请求的 timeout。 | 是 |

终态 Job 不会再次执行。重复的完成、失败、取消或超时事件也不会重复写入工具消息或再次唤醒 AgentLoop。

## 3. 调度规则

- 同一回合的只读工具最多并行 4 个。
- 副作用工具按提交顺序串行执行。
- 交互工具和副作用工具会形成前后屏障，后续工具不会越过未完成的前序工具。
- 不同会话之间不会因为某个会话的长工具而互相阻塞。
- 旧的同步 `execute` / `executeBatch` API 仍保留，主要用于兼容授权和旧调用方；新的 AgentLoop 路径使用 Job 提交与事件恢复。

## 4. 输出、进度和大小限制

- Job 快照只保存最近 64 KiB 的输出尾部，超过部分会被丢弃。
- `outputByteCount` 记录累计收到的 UTF-8 字节数，因此它可以大于 `latestOutput` 的字节数。
- 实时输出事件仍按到达顺序发出；64 KiB 限制只作用于快照、持久化记录和最终聚合结果，不阻止运行中的 UI 收到输出。
- stdout 和 stderr 分开标记；Shell 工具最终结果会合并两者用于回传 LLM。
- Shell 进程退出后最多等待 0.5 秒排空继承的管道，避免子进程没有关闭文件描述符时无限等待。

## 5. 取消语义

取消有三层入口：

1. 单个工具行的停止按钮调用 `cancelJob(jobID)`。
2. AgentLoop 停止按钮调用 `cancelJobs(forTurnID:)`。
3. 删除会话时调用 `cancelJobs(forConversationID:)`，并删除该会话的 Job 与旧工具调用记录。

取消会先把 Job 标记为 `cancelled` 并唤醒等待者，再向后台执行 Task 发送取消信号。ShellExecutor 收到取消后会：

1. 向 Shell 进程组发送 `SIGTERM`；
2. 同时终止顶层 `Process`；
3. 等待最多 2 秒宽限期；
4. 仍存在时向进程组和顶层进程发送 `SIGKILL`。

因此取消按钮不应只检查 Swift `Task` 是否结束，还应观察 Job 是否进入 `cancelled`，必要时使用系统进程检查确认没有残留子进程。

## 6. 超时语义

`run_command` 的默认超时是 120 秒，也可以在工具参数中传入整数秒的 `timeout`。超时与普通失败不同：

- ShellExecutor 把进程树终止后抛出 timeout 错误；
- ToolExecutionManager 将 Job 置为 `timedOut`；
- AgentLoop 收到 `isError == true` 的可解释工具结果；
- AgentLoop 可以据此继续让 LLM 决策，或者按当前回合策略失败，但不能永久保持 loading。

## 7. 持久化与应用重启

Job 快照保存在独立的 `tool_jobs.sqlite` 中，内容包括状态、参数指纹、输出尾部、时间戳、错误和最终结果。

应用启动并重新挂载 Job Store 时：

- 已完成、失败、取消、超时的 Job 会恢复到内存索引，可直接复用结果；
- `queued`、`running`、`waitingForUser` 等未完成 Job 会被安全标记为 `failed`，错误信息说明它无法跨进程恢复；
- 未完成 Job 不会因为重启而自动重跑，避免文件修改、删除、网络请求等副作用被重复执行；
- 如果用户随后再次提交相同的 `toolCall.id`，仍优先复用已经持久化的终态结果。

当前 Job 记录中的 `processID` 字段是为进程诊断预留的；应用重启后不会尝试接管旧进程。可靠恢复依赖重新规划一次工具调用，而不是恢复旧进程的执行现场。

## 8. 安全与日志边界

- 工具调用与 Job 使用参数指纹做幂等比较，不把完整参数作为唯一比较依据。
- 工具调用日志中的原始参数最多保留 4,000 个字符，并使用现有 sanitized 规则。
- Job 输出持久化最多保留 64 KiB 尾部。
- Shell 环境会合并当前进程环境和工具传入环境，但当前 Job 日志不记录完整环境变量。
- 不应在新增日志中写入 Authorization header、API key、完整环境变量或未截断的工具输出。
- 高风险工具的授权判断仍由 ToolManager 负责，UI 只展示状态和发起用户操作。

## 9. 常用排查步骤

### 9.1 Job 没有出现

确认：

1. AgentLoop 是否收到 `toolCallsReceived`；
2. 当前会话自动化策略是否允许提交；
3. 工具名称是否已注册；
4. 工具参数是否为 JSON object；
5. `ToolExecutionManager` 是否发出了 `created` / `started` 事件。

未知工具和参数解码失败会创建一个立即终止的错误 Job，而不是留下永久等待状态。

### 9.2 Job 一直是 `queued`

检查同一会话/回合中是否存在更早的未完成副作用工具或交互工具。只读工具还要检查是否已达到 4 个并行上限。

### 9.3 Job 已完成但 Agent 没继续

检查：

- 终态事件是否只到达了当前 `conversationID` 和 `turnID`；
- AgentLoop 是否仍处于对应的 `waitingForToolJobs`；
- 工具消息是否已经写回；
- 是否因为回合已取消而正确忽略了迟到完成事件；
- LLM 请求是否进入 `requestingLLM`，或记录了不可恢复的 LLM 错误。

### 9.4 点击停止后进程仍存在

先观察 Job 是否已为 `cancelled`，再按工具参数中的命令片段查找进程：

```bash
ps -axo pid,ppid,pgid,stat,command | rg 'run_command|sleep|zsh -lc'
```

Shell 进程组取消有 2 秒宽限期；超过该时间仍存在时，应重点检查进程是否脱离了原进程组，或是否是继承管道的子进程在退出排空阶段短暂存活。

### 9.5 应用重启后 Job 被标记失败

这是当前设计的安全行为，不代表工具又执行了一次。查看该 Job 的 `latestOutput` 和 `errorMessage`，确认它是“无法恢复”的启动结算；需要继续工作时，让 Agent 重新评估并产生新的工具调用。

## 10. 验证命令

受影响 Package 的测试：

```bash
swift test --package-path Packages/KitAgentTool
swift test --package-path Packages/KitShell
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/PluginMessageList
swift test --package-path Packages/FactoryLumi
```

手工验证实时输出、自动续跑和取消：

```bash
for i in 1 2 3 4 5; do echo "tick-$i"; sleep 1; done
sleep 60
```

建议故障注入顺序：工具启动失败 → 输出超过 64 KiB → 执行中取消 → 重启恢复 → 重复完成事件 → LLM 错误 → 删除会话。

## 11. 当前已知限制

- 工具运行期间不会因为每个输出 chunk 而再次调用 LLM；LLM 在 Job 完成前只由 AgentLoop 事件驱动恢复。
- 应用重启不会接管旧的外部进程，也不会自动重跑未完成 Job。
- 实时输出回调目前没有独立的背压协议；快照和持久化有上限，但极高频输出仍可能增加事件分发压力。
- `FactoryLumi` 的既有插件装配测试已补齐隔离状态目录、宿主持有 Provider 和插件注销清理，覆盖默认插件装配、贡献撤回与重启流程。
