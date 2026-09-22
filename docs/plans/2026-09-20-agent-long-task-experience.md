# Lumi 长任务 Agent 体验：设计与实施计划

日期：2026-09-20

状态：Proposed，待实现

审阅基线：`98d1a3b5b` 及当时工作区中的相关 Agent 代码

范围：桌面端 Agent 长任务执行、过程沟通、观察、验收和中断恢复；兼顾 ACP 输出一致性。

技术基础：Swift、Swift Concurrency、SwiftData、SwiftUI，以及现有 Provider / Plugin / Factory 分层。

本次交付：仅设计文档，没有实现本文提出的接口或行为。

## 1. 目标与结论

让用户把一个可能需要一小时的项目任务交给 Lumi 后，能持续理解：正在做什么、已经完成什么、哪里需要自己决定，以及最终结果是否经过验证。Lumi 应当能在后台工作尚未结束时继续观察、沟通和调整，而不是只能等待整批工具全部结束。

推荐架构是：**复用现有 ToolJob 后台执行能力，让长工具提前返回任务句柄，由同一个 Agent 在后续推理轮次中读取进展、作出决策，最终基于证据验收。** 宿主负责可靠调度、限流、状态和安全约束，不必先增加一个独立的 Supervisor LLM。

最重要的改动是把以下两件事分开：

- **本次工具调用已经返回**：模型可以继续推理了，返回值可能只是“仍在运行”。
- **后台工作已经结束**：进程退出或远程工作达到可信终态，可以检查结果了。

当前 Lumi 已经有后台执行、日志事件、取消、持久化和 Agent 状态机的基础。缺口主要在工具返回协议、Agent 的续跑条件、模型可用的观察工具，以及界面对过程消息和最终交付的区分，不是重新建设整套执行引擎。

### 1.1 “像 ChatGPT/Codex”在本文中的准确含义

本文对齐的是可观察的使用体验和公开的 Agent 循环模式，不声称复现 ChatGPT 私有实现。

公开的工具调用流程是：模型决定调用工具，宿主执行并返回结果，然后再次调用模型；这个循环可以重复。模型通常不是在工具执行的整段时间里持续运行。参见 [OpenAI Function calling](https://developers.openai.com/api/docs/guides/function-calling) 和 [Unrolling the Codex agent loop](https://openai.com/index/unrolling-the-codex-agent-loop/)。

“运行期间唤醒 LLM 观察和验收”是实现这种体验的一种编排机制，但不能概括成“ChatGPT 的基本原理就是一个 Supervisor 定时检查 Worker”。也可以由同一个 Agent 通过任务句柄、增量读取和事件续跑完成。后台模型请求的轮询，与应用工具任务的观察，是两个不同层次。

一小时的任务还要区分：

1. Agent 连续进行很多次短编辑、检索和测试，总耗时一小时。
2. 某一个命令或外部工作本身持续一小时。

前者需要可靠的多步循环、计划和过程说明；后者额外需要提前返回、后台任务控制和等待策略。两者都不能只靠增加一个定时器解决。

### 1.2 第一版的交付边界

第一版必须覆盖：

- 同一个 Agent 的连续多步工作与有依据的过程汇报。
- 本地 Shell 长任务提前返回、增量日志、状态查询、等待和取消。
- 运行中用户追加指令、审批、停止整个任务。
- 单一会话内严格的工具消息配对，跨会话的项目写操作隔离。
- 明确的最终交付门槛和验证证据。
- 应用重启后的诚实恢复：知道哪些结果可信、哪些执行状态未知，不自动重放副作用。
- 简洁模式、完整消息模式和 ACP 对过程/最终结果的一致表达。

第一版不要求：

- 独立 Supervisor 模型、多个编码 Agent 或 Agent 间自动协商。
- 应用退出后仍可靠运行的外部执行守护进程。
- 自动接管重启前遗留进程，或为所有 MCP 工具提供后台执行保证。
- 通过自动提交、推送、部署或通知外部人员证明任务完成；这些仍需要用户授权。

## 2. 当前实现与缺口

下表是代码审阅结论，不是运行中性能测量。实现前应在新基线上重跑测试并确认相关代码没有被其他工作修改。

| 位置 | 当前行为 | 对长任务体验的影响 |
| --- | --- | --- |
| `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`、`Packages/PluginAgentLoop/Sources/PluginAgentLoop/PluginAgentLoop.swift` | 生产环境注册 `PluginAgentLoop`；另有默认 Provider 实现 | 主改造点是插件中的真实循环，不能只修改 `DefaultAgentLoopProvider` |
| `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift` | 有 `executingTools`、`waitingForToolJobs`；待完成工具全部清空才重新请求模型；无工具调用的回复走完成 | 后台工作未结束时，模型通常无法继续；“没有工具调用”还被当成完成信号 |
| `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift` | `output`、`progress` 不推进模型；终态写工具结果并尝试继续 | 已有日志事件不等于模型已经观察日志 |
| `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift` | 等待 Job 时退出驱动分支；取消先标记回合取消，再取消 Job | 是逻辑等待，不是主线程一直阻塞；正确的取消顺序需要保留 |
| `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionManager.swift` | Job 去重、调度、输出缓冲、终态事件、记录持久化；`waitForResult` 等待终态 | 可以复用，但缺少有限等待和“调用已返回/工作未完成”的交付状态 |
| `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionRuntime.swift` | 在应用进程内运行异步工作 | 后台执行不代表应用退出后仍有可靠 Worker |
| `Packages/PluginToolManager/Sources/PluginToolManager/Tools/ShellTool.swift` | `run_command` 等执行结束才返回；有输出回调；默认执行超时 120 秒 | 长命令期间有日志但没有模型续跑；需要分离返回时限和执行超时 |
| 同上、`Packages/KitShell/Sources/ShellExecutor.swift` | 执行器有退出码、超时和取消信息；Shell 工具主要转成文本结果 | 不能依赖模型从文本猜成功；需要结构化退出原因和失败语义 |
| `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolManager.swift` | 注册 Shell、读写文件等内建工具 | 缺少通用、模型可调用的 Job 读取、等待和取消工具 |
| `Packages/PluginToolManager/Sources/PluginToolManager/Observers/ToolCallsObserver.swift` | 按自动执行/审批/阻止分类处理工具调用 | 改造时必须明确原始调用顺序和审批屏障，不能让后续写操作越过审批 |
| `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Views/AssistantToolCallViews.swift` | 未有 `toolCall.result` 才展示部分实时 Job 内容 | 若直接填入“仍在运行”的返回值，可能提前隐藏正在运行的详情 |
| `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/Services/AgentTurnSummaryBuilder.swift` | 非空、无工具调用的 assistant 消息可被识别为最终回复 | 运行中的过程说明容易被误判为最终交付 |
| `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/Views/AgentTurnView.swift` | 过程默认折叠；停止入口直接取消该回合 Jobs | 过程沟通可见性不足；只取消 Job 不等于停止 Agent，可能触发后续推理 |
| `Packages/PluginMessageSender/Sources/PluginMessageSender/Providers/MessageSender.swift` | 运行中消息进入待发送队列，主要在任务结束后排出 | 难以表达“在当前任务里立即调整方向” |
| `Packages/PluginACP/Sources/PluginACP/ACPStreamingBridge.swift` | 流式发送长度主要按 conversation 记录；最终回复抑制与曾流式输出有关 | 新增多个过程回复后，需防止后续较短消息丢失、最终回复被错误抑制 |
| `Packages/PluginAgentPlanStorage/Sources/PluginAgentPlanStorage/Services/PlanFileStorageService.swift` | 以文件保存计划文本 | 不是运行时结构化步骤状态，也没有验证证据与 Job 的绑定 |

### 2.1 必须保留和澄清的现有能力

- `submit` 已按 conversation、turn、toolCall ID 去重；不能在轮询时重新提交原命令。
- 已有输出上限和执行调度；新实现应强化而不是绕开这些限制。
- 当前读操作并行上限为 4，但仍受前面的串行/交互任务阻挡。仅把观察工具标为只读，**不能解决观察工具被长任务阻塞的问题**。
- 当前取消是先发出取消请求，再以实际结果进入终态；不能把“请求已发出”显示成“进程已停止”。
- 当前未完成 Job 在应用重启后不会自动重试，而是记录无法恢复。新版本应保留不擅自重放副作用的原则。
- 现有 FSM 中名为 Job ID 的使用位置需要核查：有路径实际传入 `toolCall.id`，而 Job 本身还有独立 UUID。迁移必须显式区分，不能仅重命名类型。
- 持久化写入目前有异步排队路径，不能把“已排入保存队列”当成“已经落盘”。

## 3. 用户体验与验收目标

这些是拟定目标值，不是现状指标。模型响应时间和外部服务延迟单独测量，不应伪装成宿主可保证的时延。

### 3.1 一个典型任务

用户：“完成这个功能，构建并测试，通过后给我结果。”

1. Lumi 说明理解、工作范围和验证方式；较复杂的任务展示 3–7 个计划步骤。
2. 开始编辑和检查，阶段切换或获得重要结果时给出简短说明。
3. 构建持续较久：很快显示“构建运行中”，工具在有限时间内返回 Job 句柄。
4. Agent 可以读取增量日志、判断是否失败、查看其他安全信息，并说明已确认的进展。
5. 无新证据时保留真实的运行状态，不反复生成“我还在等待”。
6. 用户补充“先不要改数据库”：作为当前任务的引导信息，在下一个安全边界被处理；界面显示已收到/待处理/已应用。
7. 构建结束，Agent 检查结构化退出结果，再执行任务所需的测试或检查产物。
8. 最后给出做了什么、验证了什么、仍有什么限制；此时才标记交付完成。

### 3.2 可检验的体验目标

| 目标 | 第一版验收口径 |
| --- | --- |
| 执行可见 | Job 创建后 1 秒内，界面出现状态；不等待下一次模型回复 |
| 长工具可让出控制权 | 默认约 5 秒返回运行句柄；宿主额外处理开销目标 P95 < 1 秒 |
| 真实过程沟通 | 一个跨多个阶段的任务，至少在开始、关键阶段变化、验证结果和最终交付处有对应表达；不规定每分钟必须说话 |
| 实时日志 | 有界缓冲，界面合并刷新；大量输出不冻结主线程，不为每个字符写数据库或调用模型 |
| 用户停止 | 1 秒内显示“正在停止”；实际终止时间按执行器宽限期测试，不提前宣布已停止 |
| 运行中引导 | 立即确认收到；在协议完整且可安全续跑的边界应用；模型/工具不可取消时明确等待原因 |
| 无输出长任务 | 显示运行时长和最后观测时间；不把沉默直接判定为失败，不生成虚构百分比 |
| 最终交付 | 无尚未解决的阻塞 Job、审批、用户引导；验证证据与当前工作版本匹配 |
| 一小时稳定性 | 有输出、无输出、失败、追加指令和取消场景均有长时测试；没有无限轮询、重复执行或失联状态 |

## 4. 总体架构与不变量

```text
用户指令 / 当前任务引导
          │
          ▼
AgentLoop：单一状态所有者、计划、事件收件箱、续跑调度
          │ 模型请求（同一会话最多一个在途请求）
          ▼
LLM：决定下一步、输出过程说明、请求工具、提交最终交付
          │ 工具调用
          ▼
ToolManager：权限、调用结果交付、工作调度、Job 查询
          │                         │
          ▼                         ▼
工作平面：Shell / 已适配工具       控制平面：read / wait / cancel
          │                         │ 不排在长命令后面
          └──── Job 事件与增量输出 ──┘
                         │
              持久化事件 / 安全边界续跑
                         │
          UI 与 ACP：过程、运行状态、验证、最终交付
```

### 4.1 三类状态必须独立

1. `pendingToolReplies`：当前模型响应中，尚未交付协议结果的工具调用。
2. `activeJobs`：已经交付句柄、但后台工作尚未达到可信终态的任务。
3. `observationInbox`：尚未被某次模型请求消费的状态变化、用户引导或恢复信息。

不能再用“有 activeJob”推导“模型必须等待”，也不能用“pendingToolReplies 为空”推导“整个用户任务已经完成”。

### 4.2 全局不变量

- 一个会话只有一个 AgentLoop 状态写入者，同一时刻最多一个模型请求。
- 同一个模型工具调用只有一个协议级结果；后续 Job 变化不是该调用的第二个结果。
- 下一次模型请求前，上一响应的全部工具调用都要有合法结果，或进入明确的审批/错误处理分支；禁止把悬空工具调用送给 Provider。
- 模型只能操作宿主注入的当前任务作用域内允许访问的 Job；不接受模型自报 conversation ID 作为授权依据。
- `queued/running/cancelling/unknown` 都不是成功完成。
- 任务取消后，旧模型响应、旧定时器和旧 Job 事件不能重新启动它。
- 长任务提前返回不释放实际工作的资源锁。
- 重试模型请求不重跑已经提交的副作用工具。
- UI 状态变化不意味着已调用模型；模型过程说明必须来自实际推理输出。
- 所有插件间协作走 Provider/Kit 协议和 Factory 装配，不让 Plugin A 直接依赖 Plugin B。

## 5. 数据模型与工具协议

以下类型名称是建议的新增契约，不表示当前代码已经存在。落地时优先扩展既有类型，避免创建语义重复的平行体系。

### 5.1 标识符和版本

| 字段 | 含义 |
| --- | --- |
| `conversationID` | 对话作用域 |
| `runID` | 一个用户任务；第一版可与现有 turnID 一一映射，不另建相互竞争的生命周期 |
| `stepID` / `requestID` | 每次模型推理步骤及请求；流式输出也按此隔离 |
| `toolCallID` | 模型生成的调用标识，用于协议配对 |
| `jobID` | ToolManager 分配的后台工作标识，不等于 toolCallID |
| `epoch` | 任务启动/取消/恢复代数，用于拒绝过期回调 |
| `revision` | Job 状态或有意义观测的单调版本 |
| `outputCursor` | 有界日志流中的不透明读取位置，不用字符串长度冒充稳定游标 |
| `deliveryID` | 一次调用结果或观测交付的持久化去重键 |
| `protocolVersion` | 本回合固定的协议版本，控制迁移和回滚 |

### 5.2 分离执行状态和交付状态

保留 Job 执行状态：queued、running、waitingForUser、cancelling、completed、failed、cancelled、timedOut。新增恢复所需的 `interrupted/unknown` 语义时，要同步修改持久化解码与所有 UI switch。

另设 `ToolReplyDeliveryState`：

- `pending`：还未向模型交付本调用结果。
- `terminalResultDelivered`：有限等待内已结束，交付最终工具结果。
- `runningHandleDelivered`：交付运行句柄，后台工作继续。

这两个状态机正交。Job 完成后可以更新 Job 记录和 UI，但不能把已交付给模型的运行句柄替换成另一条历史事实。

`ToolCallResult` 以向后兼容方式增加结构化运行引用、返回种类和退出信息；旧记录缺少字段时按旧终态结果解码。新增行为若通过 `SuperAgentTool` 扩展，必须在协议本身声明要求并提供默认实现，避免 Swift existential 调用时扩展方法没有动态派发。

### 5.3 长工具的一次调用怎样返回

```text
run_command(command, yield_ms, timeout)
  1. 检查授权，冻结工作目录与参数，持久化执行意图
  2. 使用原 toolCallID 去重提交 Job
  3. 最多等待 yield_ms，等待本身不占用主线程
  4a. 已到终态：竞争取得交付权，返回最终结果
  4b. 尚未结束：竞争取得交付权，返回运行句柄
  5. 后续 Job 事件只进入观测队列和 UI，不为原调用再补第二条 tool 消息
```

“计时到点”和“Job 恰好完成”可能同时发生，必须在同一个 actor/串行状态所有者上做一次性交付判定。持久化记录和消息插入通过稳定 `deliveryID` 与幂等 upsert 衔接；不能仅在内存设置一个布尔值。

示例返回值：

```json
{
  "version": 1,
  "return_kind": "running_handle",
  "job_id": "job-opaque-id",
  "status": "running",
  "revision": 4,
  "output_delta": "Compiling module A...",
  "next_cursor": "opaque-cursor",
  "output_truncated": false,
  "elapsed_ms": 5011,
  "suggested_poll_after_ms": 15000,
  "is_error": false
}
```

终态结果另含 `termination_reason`、`exit_code`（适用时）、`finished_at`。非零退出不能仍作为无条件成功的 ToolCallResult 返回；区分进程失败、超时、取消、启动失败和远程状态未知。OpenAI 的公开 Shell 接口也将退出与超时作为不同结果类型，参见 [Shell guide](https://developers.openai.com/api/docs/guides/tools-shell)。

原 assistant 消息中的工具结果可以保留句柄引用；实时状态由 Job 投影提供。模型历史中的已交付结果保持不可变，避免 UI 和模型看到不同版本的同一次调用结果。

一个合法的简化消息序列如下，后续查询有自己的调用 ID：

```text
assistant：run_command，toolCallID=A
tool(A)：running_handle，jobID=J
assistant：说明当前进展；wait_jobs(J)，toolCallID=B
tool(B)：J 已完成，exit_code=0，附增量输出
assistant：检查产物/运行必要测试，toolCallID=C
tool(C)：验证结果
assistant：final（宿主完成门槛通过）
```

不得在 `tool(A)` 后又补一条 `tool(A)` 表示 J 最终完成。若通过宿主事件续跑而非 wait_jobs，按第 6.3 节交付有来源标识的观测，不伪造 B。

### 5.4 模型可用的工具

| 工具 | 输入与默认限制 | 行为 |
| --- | --- | --- |
| `run_command` | 保留 `command`、`timeout`；新增 `yield_ms`，默认 5000，范围 0–10000 | 快命令直接返回终态；长命令返回句柄 |
| `read_job` | `job_id`、可选 `cursor`、`max_output_bytes` 默认 8192，上限 16384 | 立即读取当前快照和增量日志，不等待，不启动工作 |
| `wait_jobs` | 1–8 个 `{job_id, cursor, revision}`；`wait_ms` 默认 15000，范围 0–30000 | 等待所选任务的重要状态变化或截止时间；用户引导/取消也能使等待结束 |
| `cancel_job` | `job_id`、简短原因 | 请求取消指定工作，返回已接受/已终止/无法确认；不默认终止整个用户任务 |
| `update_plan` | 步骤 ID、文本、状态、验收条件及变更理由；建议最多 12 个活动步骤 | 维护结构化任务计划，不代替已有计划文件存储 |
| `report_progress` | 简短说明、可选步骤 ID 和证据引用 | 跨 Provider 的显式过程消息出口；由宿主保存为过程消息，工具结果只确认已记录 |

`report_progress` 不是每次调用前必须使用，也不能形成“汇报—再次汇报”的自激循环。与同一响应中的自然语言过程内容做去重。一般模型可先输出过程说明再调用实际工具；该工具用于缺少原生消息通道的稳定兼容路径。

第一版保留 `run_command.timeout` 现有默认值 120 秒，避免静默改变全部旧调用的资源上限；为明确的长构建允许显式指定更长时限，初始上限建议 7200 秒并可配置。提示模型为预期长任务明确设置执行超时。`yield_ms` 和 `wait_jobs.wait_ms` 到点都不杀进程，只有执行超时或取消才影响工作本身。

没有新输出时返回 `changed: false` 和建议等待间隔，不把它当作失败或要求立刻重试。返回中不得包含可执行的“继续调用某工具”指令，工具描述负责解释契约。

### 5.5 控制平面、队列和资源隔离

新增控制平面分类，例如 `controlPlane`，只允许内建观察、等待、取消和任务元数据工具使用。这些工具不能排在它们正在观察的串行长任务后面。

执行能力与返回策略应分开建模：

- 执行能力：串行副作用、可并行只读、交互、受限控制平面。
- 返回策略：等待终态、允许有限等待后返回句柄。

不能把任何自称只读的工具都提升为控制平面。控制工具自身的调用记录不得被计算成它要等待的后台工作，否则可能自我等待。

同一模型响应内的工具按原始顺序建立依赖与审批屏障。遇到未批准的副作用操作，后续有依赖或副作用的操作不能越过它；无依赖只读操作是否允许并行需由明确规则判断，而不是按权限分桶后自动重排。

项目文件写操作以冻结后的规范化项目根目录作为资源键，跨会话共享锁。第一版采取保守规则：同一项目已有活动串行工作时，新副作用操作快速返回 `resource_busy` 和关联句柄，由 Agent 等待或调整，不把新的模型调用无限挂起在队列里。观察工具保持可用。

锁在实际工作终止后释放，不在句柄返回时释放。状态未知的进程不能自动当成已释放；需要显式提示、恢复检查或用户处置。只读文件检查也要说明它看到的可能是构建过程中的瞬时状态，不能据此宣布最终产物已稳定。

### 5.6 增量日志与背压

- 为 stdout/stderr 保存序号、来源和有界字节缓冲；先明确两路日志合并顺序只保证宿主接收顺序。
- 模型按游标读取，多个消费者分别维护游标，UI 读取不能推进模型游标。
- 缓冲淘汰后，旧游标返回 `cursor_expired`、可用起点和截断说明，不静默遗漏。
- 保留现有 64 KiB 输出上限作为初始内存基线；更大日志若需落盘，另设总量上限、过期清理与路径权限。
- UI 刷新建议合并至每秒 4–10 次；持久化按时间/大小批次写入，终态强制刷新。
- 检查并替换无界 AsyncStream 和无限持久化任务排队；输出产生速度不能决定内存无限增长。
- 进度 revision 与每字节输出序号分开；不能每一行日志都触发模型续跑。

## 6. Agent 状态机与续跑调度

### 6.1 建议状态

| 状态 | 进入条件 | 可触发的下一步 |
| --- | --- | --- |
| `requestingLLM` | 上下文协议完整且有待决策工作 | 过程消息、工具调用、候选最终回复 |
| `awaitingToolReplies` | 上一响应的工具结果未全部交付 | 等有限返回、审批；不可发起下一模型请求 |
| `waitingForJobs` | 协议结果已齐，但仍有后台工作，暂时没有可执行决策 | 终态、重要变化、用户引导、受预算约束的检查 |
| `awaitingUser` | 需要审批或不可替代的用户选择 | 指定回复、取消；后台状态仍可更新 |
| `verifying` | 正在依据验收条件收集/判断证据 | 验证工具、修正实现、候选交付 |
| `cancelling` | 用户停止整个任务 | 发取消请求，拒绝旧事件续跑，等待实际处置结果 |
| `paused` / `interrupted` | 预算不足、应用恢复、执行状态不确定 | 用户决定继续或结束，不伪装已完成 |
| `completed` / `failed` / `cancelled` | 达到明确的任务终态 | 展示结果；新用户任务使用新 epoch |

这些是目标语义，不要求给每个状态都建立独立类。优先在现有 FSM 上演进，并让 `verifying` 可以是运行状态中的子阶段，避免重复状态源。

### 6.2 模型输出处理

1. 流式文本先作为暂定过程内容展示，尚不能给任务贴“已完成”。
2. 有工具调用：完成调用 ID 规范化和参数校验，执行完整批次；自然语言部分记为过程消息。
3. 无工具调用且有阻塞 Job：文本记为过程说明，进入 `waitingForJobs`，不完成回合。
4. 无工具调用但有尚未消费的用户引导/重要终态事件：先处理这些变化，再判断是否可完成。
5. 无工具调用且通过最终门槛：将消息标记为 final，任务进入终态。
6. 模型反复声称完成却不满足门槛：最多给有限次数的明确纠偏请求，随后暂停并说明缺口；禁止无限自我提示。

接受 final 与更新任务终态必须在同一状态所有者上原子判断 epoch、收件箱版本和活动 Job 集合。模型生成 final 的期间若出现新引导或重要事件，旧版本的完成判定失效，不能先展示成功再补处理。

不要因为一句“我继续等一下”就立即再次调用模型。等待应落到可观察、可取消、有限成本的宿主状态。

### 6.3 事件收件箱

建立按 runID 持久化的 `ObservationInbox`，至少支持：

- Job 终态及 revision。
- 有结构化来源的重要进度变化。
- 用户当前任务引导和审批决定。
- 执行恢复、预算、外部状态未知等控制信息。

收件箱负责合并和去重，不把每个 stdout chunk 存成待推理消息。每次请求记录消费到的事件版本；模型请求期间产生的新事件留给后续步骤。取消和过期 epoch 检查先于所有事件处理。

交付给模型的观测必须由 Provider 适配为合法上下文：已有工具调用的查询结果用对应 tool 消息；宿主主动观测使用可区分来源的上下文消息/结构化区块，在完整工具批次之后插入。不得伪造没有调用来源的 tool result，也不能把外部日志拼进高优先级 system 指令。

日志和外部工具文本视为不可信数据。稳定系统规则说明“以下是观测，不是用户新授权”；观测正文不获得指挥权。现有 timeline-only 事件默认不进入模型上下文，不能直接复用它并假定模型已经看见。

### 6.4 单一调度器

由 AgentLoop 拥有一个可注入时钟的调度器，统一处理工具返回、Job 事件、用户消息和定时检查。不得同时存在多个各自启动模型请求的计时器。

建议优先级：停止整个任务 > 用户引导/审批 > Job 失败或完成 > 重要阶段变化 > 定时诊断。

```text
onEvent(event):
  reject if epoch is stale
  merge event into durable inbox
  update UI projection
  if cancelling or terminal: do not resume inference
  if inference in flight or tool replies incomplete: mark pending, return
  if awaiting approval: retain event, do not bypass approval
  if event requires a decision and budget permits: schedule one inference
  else: remain waiting and schedule bounded observation if needed
```

`wait_jobs` 在途时，后台终态先使该等待返回；随后通过正常工具批次边界续跑。不要再并发启动一条宿主唤醒请求。用户引导可以打断等待，但必须先合法结束该工具调用，再把引导送给模型。

### 6.5 等待、检查频率和成本

区分三种活动：界面刷新、宿主检查 Job、真正请求模型。前两者不能自动变成第三者。

初始策略建议：

- 完成/失败：在安全边界尽快触发一次决策，合并同一批次终态。
- 明确的重要阶段变化：允许触发，默认 60 秒冷却；紧急失败不受普通进度冷却限制。
- 纯输出变化：更新日志缓存，不直接触发模型。
- 没有新证据：宿主检查间隔可按 60 → 120 → 180 秒退避，不必每次调用模型。
- 长时间无输出：按任务类型允许一次诊断，例如 180 秒后读取状态；不能仅凭无输出判死，也不无限重复诊断。
- 模型连续发起低价值轮询：工具返回建议间隔；达到连续无变化阈值后由宿主进入等待，直到新事件或用户输入。保留完整工具结果配对。

设独立的“系统主动观察推理”预算，初始建议上限 20 次/小时/任务，可配置；它不是整个编码任务的总推理次数上限。另有整个任务的 token/费用/时间预算。预算到达时停止自动新增推理并提示用户，仍追踪既有 Job，不暗中终止进程或谎称工作完成。

一小时无输出、无阶段变化的模拟命令，除了初始决策和最终验收，自动观察推理应不超过两次；这是一条回归指标，不应靠每分钟生成同义进度语句实现“活跃感”。

## 7. 过程沟通、计划和最终验收

### 7.1 消息语义

在现有 Message metadata 上先增加带版本的语义字段，必要时后续迁移为强类型字段：

- `agent.messageKind`：`progress`、`final`、`runtimeStatus`。
- `agent.source`：`model`、`host`。
- `agent.runID`、`agent.stepID`、`agent.deliveryID`。
- 可选 `agent.planStepID` 和验证证据引用。

普通 LLM Provider 仍使用它支持的 assistant/tool 等角色；不要假定所有模型都支持 OpenAI 特定的 commentary/final 原生通道。消息语义由运行时归一化，流式阶段先暂定，最终门槛通过后再确定 final。

旧记录采用原有启发式读取；新记录不得再仅凭“没有工具调用”判断 final。宿主的“运行 12 分钟”属于 runtimeStatus，不能装作 LLM 刚检查后得出的结论。推理内部内容不作为进度展示来源。

过程说明应该包含新信息，例如“构建已通过，正在检查数据库迁移”，而不是不带证据的“进度 80%”。对无法判断的情况明确说“命令仍在运行，目前没有新输出”。

### 7.2 结构化计划

`TaskPlan` 由 AgentLoop 管理，通过 Provider 暴露，步骤包含稳定 ID、说明、pending/inProgress/completed/blocked、验收条件和相关 Job/证据。已完成步骤若因后续修改失效，应重新打开并记录原因。

既有 `write_plan` 继续负责文件内容。不要把计划文件的文本解析当成唯一可靠状态源，也不要要求每个简单问题都创建计划。第一版允许模型创建/更新计划，宿主校验 ID、大小和状态迁移，不替模型凭空估算百分比。

### 7.3 验收证据与完成门槛

建立轻量的 `VerificationEvidence`：证据 ID、步骤 ID、Job ID、命令/检查类型、开始结束时间、退出原因、产物引用、观察到的工作区版本标记，以及 pass/fail/inconclusive。

机械可检查的门槛：

1. 所有已发出的工具调用都有协议结果。
2. 所有本任务阻塞 Job 已到可信终态，或经过用户明确允许转为任务外工作；第一版不提供隐式脱离任务。
3. 没有未处理的审批、当前任务引导和重要状态事件。
4. 要求执行的验证已经获得证据；失败不能自动转成通过。
5. 验证后若发生相关编辑，证据应标记过期并重新验证；版本标记不能只依赖 HEAD，因为工作区可能有未提交修改。
6. 最终回复包含实际结果与未解决限制，不能把超时、跳过、无法运行测试称为测试通过。

语义上“功能是否符合用户要求”仍需要模型判断和必要的人类验收。退出码 0 只证明该命令成功退出，不证明整个需求完成。若验证受环境限制，可以交付“已实现但未完整验证”的明确结果，而不是永远挂起；此时任务终态和计划状态必须保留这个限制。

验证要求与任务相称：解释代码不需要强制执行测试；构建任务必须检查构建结果；修改项目代码应选择相关测试及必要的产物检查。不得为满足门槛擅自扩大到部署、推送或破坏性操作。

## 8. 用户引导、停止、失败和恢复

### 8.1 运行中追加消息

消息发送层明确区分：

- `steerCurrentRun`：用于当前任务的补充/方向修正；运行中默认入口应清楚表达这一点。
- `enqueueNextRun`：作为下一项独立任务排队。
- 审批/ask_user 回复：关联既有请求，不混入普通引导队列。

引导信息带消息 ID、接收时间、应用状态和 runID。先持久化，再显示收到；只在安全模型边界消费一次。不能让 MessageSender 排队一份、AgentLoop 再消费一份，也不能由运行中 MessageObserver 直接忽略。

用户改变要求不必立即杀掉所有进程。Agent 判断现有工作是否仍适用；如果明确要求“停止”，走宿主停止动作。不得通过匹配普通句子里的“stop”等字符串执行取消。新约束不会追溯撤销已经发生的副作用，界面和回复应明确这一点。

### 8.2 停止整个任务

UI 的“停止任务”统一调用 `AgentLoop.cancelTurn` 等任务级入口：

1. 原子标记取消并提升 epoch，阻止旧响应续跑。
2. 取消在途模型请求和调度等待。
3. 对本任务 Jobs 发出取消请求。
4. 展示正在停止，收集实际终态或无法确认状态。
5. 结束任务，保留已经产生的文件与日志，说明未回滚的工作。

单个 `cancel_job` 则可以是 Agent 工作的一部分，例如终止失败构建后进行修复；不能与停止整个任务混为一谈。无论哪条路径，都不能把发出信号等价为已成功终止整个子进程树。

### 8.3 失败与重试

- 模型网络失败：重试模型步骤，复用事件消费和工具提交去重状态。
- 工具失败：把结构化失败交给 Agent 决定修复，不由框架自动重放任意副作用工具。
- 部分批次已执行、部分需要审批：保留每项真实状态，审批后只推进未执行项。
- Provider 不支持某种消息组织：适配层应提前验证请求，不依赖线上错误后反复重试。
- 持续空轮询、重复失败或预算耗尽：有限重试后暂停并说明需要什么条件，不能无限生成“继续”。

与 `PluginAgentLoopRetry` 共用任务 epoch 和状态门槛，取消/完成后的任务不能被重试协调器重新激活。

### 8.4 持久化和应用重启

持久化最少包括：任务目标/计划、协议版本、最后一步、活动 Job、交付状态、事件游标、未应用引导、验证证据、预算和下一检查时间。采用应用运行中的单调时钟计算间隔，持久化的墙钟时间仅用于恢复判断，防止系统时间变化造成密集唤醒。

提交副作用前持久化执行意图；消息交付使用 outbox/稳定 deliveryID 幂等恢复。这只能减少重复，**不能声称对任意外部副作用实现跨崩溃 exactly-once**。例如进程已经启动但启动确认尚未落盘时崩溃，恢复后执行状态可能未知。

第一版恢复规则：

- 已有可信终态和结果：恢复展示及尚未完成的幂等交付。
- 应用重启前仍在执行：标记 interrupted/unknown，不假定它已停止，也不自动重新执行。
- 展示“上次执行中断，是否继续分析/重新执行”；重新执行副作用需要新的明确决定。
- 不仅凭 PID 接管进程：PID 可能复用，工作目录和进程归属也可能不匹配。
- 正常退出应用应尝试取消并等待有限宽限期；强制退出/崩溃无法在当前进程内执行清理，必须诚实提示这一边界。
- 睡眠/唤醒后重新检查进程和执行时限，只调度一个恢复步骤，不补发所有错过的定时器。

若产品要求“应用退出一小时后仍可靠工作”，作为第二阶段引入独立执行服务和进程身份协议，不应把这个承诺塞进第一版。

### 8.5 MCP 和其他外部工具

现有 MCP 适配不能因为有 `callTool` 就被认为有可恢复的 Job、日志或真正取消能力。新返回策略必须显式声明支持；没有保证的工具保留等待终态路径。

远程请求取消只表示本地停止等待时，状态要表达 `cancelRequested/remoteStateUnknown`，不能显示远程操作已撤销。第一版支持本地 Shell 的完整路径，其他工具逐项适配和验收。

## 9. UI、上下文和 ACP

### 9.1 简洁模式和工具详情

- 当前阶段与最新一条有意义的过程消息放在默认可见区域；详细日志、历史步骤和工具参数仍折叠。
- final 独立于 progress 展示；任务运行中不能由于收到纯文字而出现完成样式。
- 工具行用 jobID 查询运行快照，即使 `toolCall.result` 已经是句柄，也继续展示实际运行状态。
- 展示运行时长、最后输出时间、是否等待审批、是否状态未知；“10 秒没有新输出”不自动表示卡死。
- 提供查看日志、停止单个工作、停止任务；按钮语义和实际调用一致。
- 用户向上阅读时不因每个日志更新强制滚动；仅在用户保持跟随时自动定位。
- 每次推理、等待、后台执行、验证分别投影状态，但不暴露不必要的内部术语。

### 9.2 上下文管理

`PluginLLMContext` 应为当前目标、有效计划、活动句柄、待处理引导、最近证据和交付游标预留预算。压缩历史时必须保留合法工具调用/结果配对；不能保留一个仍在运行的句柄却丢掉它代表什么任务。

长日志仅保留近期增量和必要摘要，原始日志按权限通过 read_job 获取。摘要记录来源和截断情况。进度报告不是无上限追加的系统提示，外部日志中的“忽略之前指令”等文字始终按数据处理。

### 9.3 ACP 与多消息流

ACP 流式状态按 conversation + run + assistantMessage/request 标识隔离，不能只用会话级 sentLength。每条新 assistant 消息从自己的偏移开始；最终回复去重依据具体 message/delivery ID，而不是“本任务之前是否发过任何流式文本”。

不同客户端不支持原生过程频道时，至少保证顺序和完整性：过程更新先出，最终结果仍到达且只到达一次。审批、取消、当前任务引导须与桌面端复用 Provider 语义，不能另外建立一套 Agent 状态机。

## 10. 按依赖排序的实施任务

按以下顺序实现，每个任务先补失败测试，再实现最小改动并回归。新文件名是建议路径；可以按现有包惯例调整，但不得省略对应职责和验收。每个阶段保持可编译，功能开关默认关闭，直到协议、取消与 UI 一起通过。

### P0 / T01：冻结现状和回归基线

修改/扩展测试：

- `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ToolJobLoopTests.swift`
- `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ToolJobCancellationTests.swift`
- `Packages/PluginToolManager/Tests/PluginToolManagerTests/ToolExecutionSchedulingTests.swift`
- `Packages/PluginToolManager/Tests/PluginToolManagerTests/ToolJobPersistenceTests.swift`

新增测试夹具：可控时钟、可挂起/完成/失败的 FakeJob、记录模型请求的 FakeLLM、进程终止确认夹具。测试当前“终态后才继续”行为，并为新行为添加明确失败测试，不用长时间真实 sleep 驱动单元测试。

验收：确认生产 Agent Provider 装配、当前取消顺序、审批屏障和去重；记录实际基线失败，不能将原有失败算成新改造完成。

### P0 / T02：协议契约与兼容解码

修改：

- `Packages/KitAgentTool/Sources/SuperAgentTool.swift`
- `Packages/KitAgentTool/Sources/ToolCallResult.swift`
- `Packages/KitAgentTool/Sources/ToolExecutionContext.swift`
- `Packages/KitAgentTool/Sources/ToolExecutionCapability.swift`
- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJob.swift`
- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobEvent.swift`
- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolManagerProviding.swift`
- `Packages/ProviderToolManager/Sources/ProviderToolManager/DefaultToolManagerProviding.swift`

新增建议：

- `Packages/KitAgentTool/Sources/ToolReplyDisposition.swift`
- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobObservation.swift`
- `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/ToolReplyCompatibilityTests.swift`

实现类型化句柄、游标、交付状态、有限等待接口、执行/返回策略分离；新协议要求提供旧实现可用的默认行为。旧记录解码不得崩溃。

验收：旧工具不改实现仍按旧路径执行；新工具通过协议引用调用时正确使用新策略；jobID 与 toolCallID 不混用。

### P0 / T03：Job 观测存储、有限等待与控制平面

修改：

- `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionManager.swift`
- `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionRuntime.swift`
- `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolManager+Run.swift`
- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobRecord.swift`
- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobRecordModel.swift`
- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobRecordStore.swift`

新增建议：

- `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolJobOutputBuffer.swift`
- `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolJobWaitRegistry.swift`
- `Packages/PluginToolManager/Tests/PluginToolManagerTests/ToolJobObservationTests.swift`

实现有限等待者的注册/取消/终态清理、输出游标、状态 revision、背压、交付竞争判定、控制工具绕过工作队列。加入规范化项目资源锁；冻结提交时的项目路径，不能执行时再读用户当前选中的项目。

验收：长串行任务运行时 read/wait/cancel 可响应；等待读超时不终止 Job；并发完成与截止时间只有一个结果；多消费者游标独立；输出洪峰内存有界。

### P0 / T04：Shell 提前返回与真实终态

修改：

- `Packages/PluginToolManager/Sources/PluginToolManager/Tools/ShellTool.swift`
- `Packages/KitShell/Sources/ShellExecutor.swift`
- `Packages/KitShell/Tests/KitShellTests.swift`

新增建议：

- `Packages/PluginToolManager/Tests/PluginToolManagerTests/ShellYieldTests.swift`
- `Packages/PluginToolManager/Tests/PluginToolManagerTests/ShellTerminationTests.swift`

保留执行器的进程控制职责，有限返回由 ToolManager 协调，避免工具和管理器各自建立一个 Job。落实非零退出、timeout、cancelled、launch failure 结构化结果。核查进程组建立与子进程取消时序，不能只测父进程退出。

验收：短命令直接返回；长命令约 5 秒让出；读取不重跑；非零退出是失败；取消后实际子进程终止或明确报告无法确认；默认执行超时兼容。

### P0 / T05：通用 Job 工具与审批顺序

修改：

- `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolManager.swift`
- `Packages/PluginToolManager/Sources/PluginToolManager/Observers/ToolCallsObserver.swift`

新增建议：

- `Packages/PluginToolManager/Sources/PluginToolManager/Tools/ReadJobTool.swift`
- `Packages/PluginToolManager/Sources/PluginToolManager/Tools/WaitJobsTool.swift`
- `Packages/PluginToolManager/Sources/PluginToolManager/Tools/CancelJobTool.swift`
- `Packages/PluginToolManager/Tests/PluginToolManagerTests/JobControlToolsTests.swift`

完善模型可读说明、参数限制、当前任务授权和错误返回。审批按原调用顺序建立屏障，控制工具只观察已授权工作，不替新副作用取得权限。

验收：跨会话 Job ID 拒绝访问；无效/过期句柄不泄漏信息；取消可重复调用；审批后不重复提交已执行项。

### P0 / T06：Agent 状态拆分与一次性交付

修改：

- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopManager.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Message.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Observers/ToolJobObserver.swift`
- `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentLoopProviding.swift`
- `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/DefaultAgentLoopProvider.swift`

新增建议：

- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/ToolReplyDeliveryCoordinator.swift`
- `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ToolReplyDeliveryTests.swift`
- `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/LongRunningTurnTests.swift`

分离 pendingToolReplies 与 activeJobs，运行句柄也能完成协议等待；终态不重复插入原 tool result；候选 final 经过运行门槛。消息写入采用稳定 deliveryID 去重，必要时通过 ProviderMessage 增加幂等接口，由 PluginMessageManager 实现。

默认 Provider 要么支持同一契约，要么显式声明不支持新模式并保留旧行为；不能两个实现同时消费同一事件。Factory 集成测试证明生产只注册一个有效循环。

验收：所有 Job 未完成时模型已能进行下一合法步骤；任意时序下每个 toolCall 只有一个结果；取消后没有复活；多工具批次不会发送半配对历史。

### P1 / T07：事件收件箱、续跑调度和预算

新增建议：

- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentObservationInbox.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentResumeScheduler.swift`
- `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentObservationPolicy.swift`
- `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/AgentResumeSchedulerTests.swift`

接入 Job/用户事件，统一去重、冷却、退避与预算。更新 `AgentLoopProvider+Tool.swift` 的上下文构造，保证观测落在合法消息边界。时钟与随机抖动可注入，单元测试确定性运行。

验收：模型在途时不并发唤醒；终态与 wait 返回同时发生只续跑一次；无变化不持续消耗模型；达到预算后仍可查看和取消工作。

### P1 / T08：过程消息、结构化计划与验证证据

修改：

- `Packages/ProviderMessage/Sources/ProviderMessage/MessageModels.swift`
- `Packages/PluginMessageManager/Sources/PluginMessageManager/Models/MessageModel.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/PluginAgentLoop.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`

新增建议：

- `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentTaskPlan.swift`
- `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentVerificationEvidence.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Tools/UpdatePlanTool.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Tools/ReportProgressTool.swift`
- `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/AgentCompletionGateTests.swift`

由 PluginAgentLoop 通过 ToolManager Provider 注册它拥有的计划/沟通工具；不反向引入插件依赖。明确 progress/final/runtimeStatus，加入证据有效性与最终交付校验。

验收：没有原生 commentary 的 Provider 也工作；过程消息不结束任务；验证后编辑使证据过期；模型宣称通过但执行失败时不能标记全部完成。

### P1 / T09：运行中引导和任务级停止

修改：

- `Packages/ProviderMessageSender/Sources/ProviderMessageSender/MessageSendingProviding.swift`
- `Packages/ProviderMessageSender/Sources/ProviderMessageSender/DefaultMessageSender.swift`
- `Packages/PluginMessageSender/Sources/PluginMessageSender/Providers/MessageSender.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Observers/MessageObserver.swift`
- `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/Views/AgentTurnView.swift`

新增建议：

- `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentRunSteering.swift`
- `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/AgentRunSteeringTests.swift`

同步调整 `Packages/PluginConversationPendingMessage` 中排队消息入口和展示；实现当前任务/下一任务的明确选择及消费去重。所有“停止任务”按钮走 AgentLoop 取消，不只调用 cancelJobs。

验收：引导在等待、推理、审批三种状态都不丢失、不重复；停止和终态竞态不会再发起模型请求；已执行副作用不谎称被撤销。

### P1 / T10：界面状态投影与简洁模式

修改：

- `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Observers/ToolJobActivityModels.swift`
- `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Views/AssistantToolCallViews.swift`
- `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Models/ToolCallResultVisualState.swift`
- `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/Services/AgentTurnSummaryBuilder.swift`
- `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/ViewModels/AgentTurnVM.swift`
- `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/Views/AgentTurnView.swift`
- `Packages/ProviderConversationState/Sources/ProviderConversationState/ConversationStateProviding.swift`
- `Packages/PluginConversationState/Sources/PluginConversationState/Observers/AgentLoopStateObserver.swift`
- `Packages/PluginConversationState/Sources/PluginConversationState/Observers/ToolManagerStateObserver.swift`

扩展现有 `AgentTurnVMTests.swift`、`AgentActivityProjectionTests.swift`、`MessageListSendPositioningTests.swift`，并增加句柄已返回但 Job 仍运行的渲染测试。

验收：默认可见当前阶段和最新进度；历史可折叠；无提前完成；输出不抢滚动；单 Job 停止与任务停止可区分；旧历史正常显示。

### P1 / T11：上下文压缩、Provider 和 ACP 兼容

修改：

- `Packages/PluginLLMContext/Sources/PluginLLMContext/Providers/LLMContextProvider.swift`
- `Packages/PluginACP/Sources/PluginACP/ACPStreamingBridge.swift`
- `Packages/PluginACP/Sources/PluginACP/ACPTurnCoordinator.swift`
- `Packages/PluginACP/Tests/PluginACPTests/ACPTurnCoordinatorTests.swift`

新增建议：

- `Packages/PluginACP/Tests/PluginACPTests/ACPProgressStreamingTests.swift`
- `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/LongTaskContextCompatibilityTests.swift`

先针对当前项目实际启用的 OpenAI-compatible 和 Anthropic 路径验证请求组织；不要求接入新模型。增加工具配对校验器，覆盖压缩和恢复之后的请求。

验收：长任务上下文压缩后句柄/目标/证据仍在；连续长、短过程消息与最终消息完整送达；流式与非流式不能重复最终回复。

### P1 / T12：恢复、重试与持久化一致性

修改：

- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobRecordStore.swift`
- `Packages/PluginAgentLoopRetry/Sources/PluginAgentLoopRetry/Managers/AgentLoopRetryCoordinator.swift`
- `Packages/PluginAgentLoopRetry/Sources/PluginAgentLoopRetry/AgentLoopRetryPlugin.swift`

新增建议：

- `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentRunRecord.swift`
- `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentRunRecordStore.swift`
- `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentRunRecoveryCoordinator.swift`
- `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/AgentRunRecoveryTests.swift`

参考现有 ToolJobRecordStore 的数据库注册方式接入任务记录；若数据库统一注册有额外入口，一并修改相应 Factory/存储 Provider，不能临时另建不可迁移的全局文件缓存。定义旧 schema 的读取/迁移测试。

验收：在提交、句柄交付、结果插入和终态通知之间分别模拟崩溃；不重复消息、不重放副作用；无法恢复的进程明确 unknown；睡眠唤醒不突发补发定时任务。

### P2 / T13：观测指标、功能开关与集成验收

修改：

- `Packages/ProviderPerformanceMetrics/Sources/ProviderPerformanceMetrics/PerformanceMetricsProviding.swift` 及其默认实现（若需要扩展契约）。
- `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`、`Packages/FactoryLumi/Sources/FactoryLumi/ProviderFactory.swift` 的装配/能力配置。
- ACP Factory 的能力装配，确保与桌面端协议版本一致。

新增建议：

- `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentRuntimeFeaturePolicy.swift`
- `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/LongTaskExperienceIntegrationTests.swift`
- `docs/testing/agent-long-task-acceptance.md`

记录首个状态时延、句柄返回时延、模型唤醒原因、无变化轮询次数、输入/输出 token、日志丢弃量、取消确认时延、重复交付抑制次数、恢复不确定次数。默认不记录原始命令输出/文件内容，避免遥测泄露。

验收：完整执行第 11 节矩阵和一小时浸泡测试；先内部开关开启，再逐步放量。T01–T12 的安全与兼容门槛未过，不因 UI 已经可见就单独发布。

## 11. 测试矩阵与执行方式

### 11.1 必须覆盖的场景

| 场景 | 断言 |
| --- | --- |
| 快速成功命令 | 一次调用、一次终态结果，不强制句柄绕行 |
| 长命令持续输出 | 先返回句柄，持续读取增量，无重复执行 |
| 长命令没有输出 | 显示仍运行，不虚报失败；模型唤醒符合预算 |
| 完成恰好撞上 yield 截止 | 只有一个协议结果，没有漏续跑 |
| 多工具混合长短任务 | 全部调用先合法配对，仍可观察未完 Job |
| 原命令的迟到终态 | 更新 Job 和收件箱，不补第二条原 tool result |
| 等待工具自身被记录 | 不计为被观察的活动工作，不自我等待 |
| 长串行工作占用资源 | read/wait/cancel 响应；新的写操作明确 busy |
| 不同会话写同一项目 | 写资源锁生效，不绕过批准边界 |
| 审批与自动操作交错 | 保留顺序和依赖，批准后不重复已执行部分 |
| 读取其他任务句柄 | 作用域校验失败，无信息泄露 |
| 输出洪峰与游标淘汰 | 内存/数据库写入有界，明确截断和过期 |
| 单 Job 取消 | 实际终态可信，Agent 可按任务需求继续 |
| 停止整个任务 | UI、模型、等待和 Job 一致取消，无迟到复活 |
| 进程有子进程 | 验证实际终止范围，无法确认则保留限制 |
| Shell 非零退出/超时/启动失败 | 结构化区分，不宣称通过 |
| 模型中途纯文本说“完成” | 有阻塞工作时仍为 progress，不结束 |
| 验证后继续修改文件 | 旧证据失效，需要重新验证或明确未验证 |
| 运行中收到补充要求 | 安全边界处理一次，可见应用状态 |
| 审批期间收到普通引导 | 不代替审批、不意外授权 |
| 模型重试 | 不重跑已提交的副作用工具 |
| 输出含指令诱导文字 | 作为日志数据，不提升为系统/用户授权 |
| 压缩后继续观察 | 工具配对合法，活动句柄和目标没有丢失 |
| ACP 多条长短过程消息 | 每条完整；最终回复仍到达一次 |
| 崩溃发生于不同持久化边界 | 恢复交付幂等，未知工作不自动重放 |
| 系统睡眠、时钟调整 | 不连续补发唤醒，不谎称停止 |
| 功能开关关闭/升级旧历史 | 保留旧模式；运行中任务固定版本 |
| 预算耗尽 | 暂停自动推理，仍可观察/取消，明确通知 |
| 一小时组合任务 | 无内存持续增长、重复副作用、日志失联或过早 final |

### 11.2 包级测试命令

从仓库根目录执行，独立包可在资源允许时并行；同一个包不要并发写同一 `.build`。实际包构建若要求项目特定工具链或环境，以仓库当时文档为准，并记录差异。

```sh
swift test --package-path Packages/KitAgentTool
swift test --package-path Packages/KitShell
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/PluginMessageListBrief
swift test --package-path Packages/PluginACP
```

首次实现 T06 时可聚焦 `swift test --package-path Packages/PluginAgentLoop --filter ToolJob`，但不能用局部测试替代最终全包回归。涉及 ProviderMessage、上下文、消息发送和重试的包也需要运行各自测试；若目前缺少 target，应在相应任务补建并更新 Package.swift。

### 11.3 手工验收脚本的要求

使用临时测试项目，不能拿用户真实项目执行故障注入。准备可控的命令夹具：短成功、短失败、持续输出、静默等待、输出洪峰、派生子进程。测试参数能把一小时流程压缩为数秒用于 CI，同时保留真实一小时浸泡模式。

每次手工验收保存：版本、开关、Provider/模型、关键状态时间线、实际模型调用次数、最终文件变化、验证证据、取消后进程检查。不能只截图一个进度条就判定通过。

第一版发布的硬门槛：工具配对错误为零、重复副作用为零、取消后模型复活为零、假成功/提前 final 为零；这些门槛优先于进度文案和视觉润色。

## 12. 架构决策、发布和后续演进

### 12.1 ADR 摘要

| 决策 | 选择 | 原因与代价 |
| --- | --- | --- |
| ADR-01：谁观察任务 | 同一 Agent + 宿主调度 | 复用上下文和权限，避免双模型协调；未来可另加专用 Worker |
| ADR-02：长工具怎样继续 | 有限等待后返回 Job 句柄 | 模型可以继续工作；必须新增协议交付状态和去重 |
| ADR-03：谁触发续跑 | 单一事件调度器，定时检查辅助 | 避免重复请求和高频成本；需要可测试时钟和事件收件箱 |
| ADR-04：日志如何使用 | 增量有界读取，不逐 chunk 推理 | 控制成本与内存；需要游标过期和截断语义 |
| ADR-05：如何保证取消 | 任务取消先封闭续跑，再终止工作 | 防止取消后复活；实际停止仍依赖执行器/远程能力 |
| ADR-06：重启后怎么办 | 不自动重放未知副作用 | 保守可靠；第一版不能承诺退出后持续执行 |
| ADR-07：如何判断完成 | 显式消息语义 + 宿主门槛 + 模型验收 | 防止无工具回复误完成；机械证据不能代替所有语义判断 |
| ADR-08：后台写任务并行 | 第一版项目级保守互斥 | 避免文件竞态；牺牲部分并行度，未来再引入更细资源声明 |

以上均为 Proposed；各阶段验收后在对应实施提交中记录 Accepted 或修订原因。

### 12.2 发布与回滚

使用一个任务级协议版本和总功能开关控制新模式，子开关仅供开发调试。开始任务时固定版本，不能在任务运行中切换旧 FSM/新 FSM。

发布顺序：测试环境 → 内部真实项目只读/低风险任务 → 本地 Shell 编码任务 → 更广工具适配。关闭总开关只影响新任务；已有新模式任务按已固定版本继续受控结束，或明确中断，不能丢掉活动句柄。

回滚必须仍能读取新记录的基本状态，至少显示“不支持恢复此协议版本”。数据库新增字段应向后兼容，不用删除旧历史来修复升级问题。遥测发现重复副作用、错误 final 或停止后复活时停止放量。

### 12.3 风险与处理

- **范围膨胀**：先做本地 Shell 单 Agent 闭环，不把多 Agent、远程守护进程纳入第一版前置条件。
- **协议碎片化**：所有 Provider 经过同一配对校验与归一化层，不能每个 UI/ACP 自行解释是否完成。
- **模型高频轮询**：宿主预算、无变化退避和有限纠偏共同约束，不能只依赖提示词。
- **恢复假保证**：承认崩溃窗口和未知外部状态，不宣称任意副作用 exactly-once。
- **并行开发冲突**：按包和契约顺序落地；本文编写时工作区还有独立的 Editor 迁移，实施时不得覆盖其改动。
- **模型行为不稳定**：工具描述、结构化结果和硬门槛共同约束；最终以多 Provider 场景测试而非单次演示验收。

### 12.4 后续可选能力

第一版稳定后再评估独立执行服务、显式可恢复的远程工作协议、多个 Worker、细粒度资源锁、计划级并行和更丰富的产物验证。它们可以改善规模与容错，但不应成为解决当前“模型一直在等”体验的前置条件。

最终完成标准：用户能看到真实的工作推进；Agent 在长工具运行时具备继续观察和决策的机会；没有新信息时安静等待；停止确实阻止继续行动；最终交付以可追溯的结果和验证为依据。
