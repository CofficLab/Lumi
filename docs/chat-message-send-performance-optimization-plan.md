# 聊天消息发送链路流畅度优化方案

## 1. 目标

用户在聊天输入框按下 Return 后，应尽快看到自己的消息出现在消息列表中。

本方案的核心目标是：

- 回车到用户消息可见尽量控制在一帧内；
- 用户消息显示不依赖数据库落盘完成；
- 数据库、标题生成、统计计算、会话列表刷新等非关键任务让出资源；
- 流式回复、工具调用和历史消息较多时，发送动作仍保持稳定；
- 所有优化都可以分阶段验证和回滚。

## 2. 性能边界

### 2.1 关键路径

关键路径只允许执行轻量的内存和 UI 状态操作：

```text
Return
  -> 捕获输入文本和附件快照
  -> 清空输入框
  -> 创建用户 Message
  -> 写入内存时间线
  -> 通知消息列表
  -> 消息列表追加新行并滚动到底部
```

关键路径不应等待以下操作：

- SwiftData 查询或保存；
- 全量消息解码、排序和比较；
- 自动标题 LLM 请求；
- 会话列表全量刷新和排序；
- 缓存命中率、速度、上下文 token 等统计计算；
- Markdown 预热和历史消息重新渲染。

### 2.2 后台路径

```text
用户消息已显示
  ├─ 后台落盘
  ├─ 后台更新会话 lastMessageAt
  ├─ 低优先级生成标题
  ├─ 低优先级刷新统计
  ├─ 必要时刷新侧栏
  └─ 启动 AgentLoop / LLM 请求
```

注意：`Task(priority: .utility) { @MainActor in ... }` 并不等于后台执行。
如果任务内部调用了同步数据库查询，它仍然会阻塞主线程。真正的数据库读取需要放入非 MainActor 的异步查询层或 `Task.detached`。

## 3. 当前实现链路

当前主要链路如下：

```text
ConversationInputView.send()
  -> Task { @MainActor }
  -> MessageSender.sendMessage()
  -> MessageManager.insertMessage()
       -> ConversationManager.markConversationActive()
       -> pending buffer
       -> MessageManager.objectWillChange
       -> 多个消息插入观察者
       -> 后台持久化
  -> ListV2/V3 refreshTail()
       -> MessageManager.messagePage()
       -> 同步 SwiftData fetchMessagePage()
       -> SwiftUI 列表更新
```

当前已经具备的正确方向：

- `MessageManager` 使用 pending buffer 实现 write-behind；
- 用户消息不必等待落盘即可从读路径读取；
- 消息列表采用分页；
- 流式消息使用独立尾行；
- 流式更新有帧级合并；
- AgentLoop 获取 LLM 历史时已有异步入口 `messagesForLLM`。

## 4. 问题分级

### P0：必须优先处理

#### P0-1：消息列表刷新仍然同步查询数据库

位置：

- `Packages/PluginMessageManager/Sources/PluginMessageManager/Managers/MessageManager.swift`
- `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV2ViewModel.swift`
- `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV3ViewModel.swift`

`insertMessage` 已经把消息放入 pending buffer，但列表收到 `objectWillChange` 后仍通过 `refreshTail()` 查询最近消息页。`messagePage()` 最终调用同步 SwiftData 查询，发生在 MainActor。

影响：

- 每次新消息至少多一次数据库读取；
- 长消息、工具调用和图片 metadata 会增加解码成本；
- 用户消息明明已经在内存中，却要绕一圈数据库才能显示。

目标：消息列表收到插入事件后直接使用事件中的 Message，不再为首帧显示查询数据库。

#### P0-2：`messages(for:)` 在 MainActor 全量读取消息

当前该接口会：

1. 从 SwiftData 读取整个会话；
2. 解码所有消息；
3. 合并 pending 消息；
4. 全量排序。

该接口被标题、速度、缓存命中率、上下文大小、V1 消息列表以及部分 AgentLoop 恢复路径使用。

目标：

- UI 高频路径不再调用全量 `messages(for:)`；
- 历史读取改为异步分页；
- 统计功能改用轻量查询或增量快照。

### P1：紧接着处理

#### P1-1：消息事件信息量不足，导致消费者重复查询

当前 `objectWillChange` 不携带：

- 会话 ID；
- 变化类型；
- 消息内容；
- 消息 ID 或版本号。

因此列表只能收到“可能变了”的信号，再主动重新读取数据库。

目标：增加类型化消息变化事件，例如：

```swift
enum MessageChange: Sendable {
    case inserted(Message, conversationID: UUID)
    case updated(Message, conversationID: UUID)
    case deleted(messageID: UUID, conversationID: UUID)
}
```

消息列表只处理当前会话的事件，并直接更新内存窗口。

#### P1-2：同一条消息可能触发多条刷新链路（已完成）

V2/V3 同时监听消息管理器和发送器的状态变化。消息插入、发送状态改变、Agent 状态改变可能分别触发刷新。

当前 `MessageListTailRefreshGate` 能合并部分并发刷新，但仍可能产生一次或多次不必要的尾部查询。

目标：

- 消息列表只以消息变化事件作为历史行刷新来源；
- 发送状态只更新 activity/status；
- 流式状态只更新独立 streaming row；
- 一次消息变化最多产生一次 UI 数据更新。

已完成：V2/V3 不再监听 `sender.objectWillChange` 来触发 `refreshTail()`；发送状态由 `conversationState` 更新 activity，流式状态由独立 streaming row 更新，消息列表只保留消息事件和编辑/删除兼容兜底刷新。

#### P1-3：更新会话排序会触发侧栏刷新（已完成）

`MessageManager.insertMessage` 会调用 `markConversationActive`，继而通知会话列表刷新。会话排序对首帧消息显示不是必要条件，应让位于消息时间线更新。

目标：

- 先更新当前会话的内存摘要；
- 数据库写入放到 utility 队列；
- 侧栏刷新做 100～300ms 去抖；
- 优先更新当前会话的侧栏 item，避免全量 reload。

已完成：`markConversationActive` 立即更新内存摘要，但将 `conversationsDidChange` 通知延迟 200ms 并合并；创建、删除、标题更新等明确结构变化仍然立即通知，避免影响侧栏最终一致性。

#### P1-4：低优先级统计任务仍在主线程执行同步读取（已完成）

重点检查：

- `PluginConversationTitle/Services/TitleService.swift`：寻找第一条用户消息时全量读取；
- `PluginConversationCacheHitRate/CacheHitRateToolbarView.swift`：全量读取后计算命中率；
- `PluginConversationContextSize/ContextSizeToolbarView.swift`：全量读取后找 token；
- `PluginConversationSpeed/Observers/SpeedMessageObserver.swift`：utility Task 内仍调用同步消息读取；
- `PluginActivityHeatmap/ActivityHeatmapPlugin.swift`：统计查询应避免落在聊天交互时段的主线程。

目标：

- 标题生成直接使用插入事件中的第一条用户消息；
- token、消息数量、命中率维护增量快照或使用轻量 SQL 查询；
- 大型统计只在对应设置页打开时加载；
- 所有完整消息扫描都从 MainActor 移走。

已完成：Activity Heatmap 使用后台日统计 API，统计查询只投影必要字段；标题服务通过事件消息和单条首用户消息校验，避免扫描整段历史；缓存命中率、上下文大小、速度统计的消息变化刷新均做去抖和取消，避免发送期间堆积重复快照任务。

#### P1-5：V1/brief 模式每次刷新扫描全量消息（已完成）

位置：

`Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV1ViewModel.swift`

V1 已改为维护有限的消息窗口：首次激活、尾部兜底刷新和加载更早内容均使用异步分页；turn 记录和展示项只从当前窗口重建。新消息通过带 payload 的插入事件直接合并到窗口，编辑/删除继续使用 `objectWillChange` 兜底刷新，因此 brief 模式不再因一次刷新扫描整段历史。

实现记录见 [`docs/plans/2026-09-02-v1-window-pagination.md`](plans/2026-09-02-v1-window-pagination.md)。

### P2：完成主路径后处理

#### P2-1：发送入口通过无优先级 MainActor Task 延后提交（已完成）

当前位置：

`Packages/PluginConversationInput/Sources/PluginConversationInput/Views/ConversationInputView.swift`

当前实现已拆分提交阶段和回合阶段。输入入口同步捕获文本与附件、提交用户消息并发布插入事件；只有回合跟踪被放入后续 `MainActor Task`。旧的 `sendMessage` API 仍会等待完整回合，保持已有调用方行为。

目标：提供“快速提交”语义：

```text
send() 同步捕获并提交用户消息
  -> UI 立即可见
  -> 再启动 AgentLoop
```

如果保留 async API，则 UI 层不应等待完整 AgentLoop 回合；发送 API 的完成点应定义为“用户消息已提交”，而不是“LLM 回答完成”。

实现记录见 [`docs/plans/2026-09-02-fast-message-commit.md`](plans/2026-09-02-fast-message-commit.md)。

#### P2-2：附件编码在 MainActor（已完成）

纯文字消息影响很小，但图片 base64、文件 metadata 可能较大。应先在主线程完成轻量快照，再将编码工作放到后台。

已完成：图片文件读取和 base64 编码均在附件准备任务中执行；带附件发送时，附件 JSON metadata 通过 `.utility` 任务编码，编码完成后才回主线程提交消息。纯文本发送不创建编码任务，继续走同步提交路径。

实现记录见 [`docs/plans/2026-09-02-attachment-encoding.md`](plans/2026-09-02-attachment-encoding.md)。

#### P2-3：持久化队列应明确设置 QoS（已完成）

消息持久化属于 eventual consistency，已使用 `.utility` 串行队列，避免与用户交互争抢调度资源，同时保留顺序保证和失败补偿机制。error、user、assistant、tool 等非瞬时消息统一先进入 pending，再排队落盘；删除和清空操作继续同步排空该队列，避免旧写入复活已删除消息。

实现记录见 [`docs/plans/2026-09-02-persistence-queue-qos.md`](plans/2026-09-02-persistence-queue-qos.md)。

## 5. 推荐实施顺序

### 阶段一：建立可观测基线

先不改变产品行为，增加 signpost 和计时：

```text
ReturnKey
SendStarted
UserMessageCommitted
MessageChangePublished
MessageRowApplied
FirstFrameAfterSend
```

记录：

- Return → UserMessageCommitted；
- UserMessageCommitted → MessageRowApplied；
- MessageRowApplied → FirstFrameAfterSend；
- 主线程同步耗时；
- 消息数据库查询次数；
- 单次查询解码消息数和文本字符数。

### 阶段二：消息列表走内存事件

1. 在 `MessageManaging` 增加类型化变化观察接口；
2. `MessageManager.insertMessage` 发布 `inserted` 事件；
3. V2/V3 对当前会话直接追加消息；
4. 对更新、删除和跨会话事件补齐处理；
5. 保留 `refreshTail()` 作为启动、恢复和异常情况下的兜底；
6. 首帧路径禁止调用同步 `messagePage()`。

验收：用户消息进入内存后，列表不查询数据库也能显示。

### 阶段三：数据库查询异步化

1. 将历史分页读取改为异步 API；
2. 在后台读取并解码，再回 MainActor 应用快照；
3. 保证切换会话后丢弃过期查询结果；
4. 为 pending 消息保留 read-your-writes；
5. 为删除、重启恢复和数据库失败保留兜底逻辑。

### 阶段四：拆分和合并刷新源

建立以下明确规则：

| 变化 | 唯一消费者 | UI 更新内容 |
|---|---|---|
| 新增/更新/删除消息 | MessageList | 历史消息窗口 |
| Agent 状态 | ConversationState | activity/status |
| 流式 token | MessageStreaming | 独立 streaming row |
| 发送状态 | SendActionBar | 发送/停止按钮 |
| 会话排序 | ConversationList | 侧栏摘要 |

避免一个状态变化同时触发多个消费者全量刷新。

### 阶段五：统计和标题后台化

1. 标题服务直接消费第一条用户消息事件；
2. 统计插件订阅增量摘要；
3. 低优先级任务增加去抖和取消；
4. 完整消息扫描全部移出 MainActor；
5. 设置页未打开时不执行重统计。

### 阶段六：发送 API 语义调整

将发送动作分成两个阶段：

```swift
let message = sender.commitUserMessage(...)
// commit 返回后，UI 已可显示
sender.startAgentTurn(for: message)
```

错误处理也拆分为：

- 提交错误：立即反馈输入框；
- Agent/LLM 错误：作为消息或状态异步反馈，不影响用户消息显示。

## 6. 验收指标

### 6.1 交互指标

- Return → UserMessageCommitted：目标 < 8ms；
- UserMessageCommitted → MessageRowApplied：目标 < 8ms；
- 正常场景 Return → 首次可见：目标一帧内；
- 发送过程中输入框可继续输入，不被 LLM 或统计任务阻塞；
- 连续快速发送 10 条消息不丢失、不乱序。

### 6.2 压力场景

至少覆盖：

- 1,000 条历史消息；
- 10,000 条历史消息；
- 单条 100KB 长文本；
- 含图片附件的消息；
- 含多个工具调用和工具结果的回合；
- 自动标题开启；
- 缓存命中率、上下文大小、速度工具栏同时开启；
- 流式输出期间继续发送新消息；
- ask_user 挂起后继续输入；
- 数据库落盘延迟或失败。

### 6.3 正确性指标

- 用户消息先显示、后落盘，重启后仍能恢复；
- pending 消息不会在列表刷新时消失；
- Assistant/tool 消息不会因异步落盘顺序错乱；
- 切换会话时不会把旧会话消息追加到新会话；
- 侧栏排序最终与数据库一致；
- AgentLoop 始终能读取最新用户消息。

## 7. 风险与回滚

### 风险

- 事件直写 UI 后，数据库查询不再是唯一事实来源，需处理更新和删除；
- 异步历史查询可能返回过期会话数据；
- pending buffer 与数据库合并逻辑可能产生重复消息；
- 发送 API 拆分后，错误反馈时序会变化；
- V1、V2、V3 三套列表实现可能出现行为不一致。

### 回滚策略

- 保留 `refreshTail()` 作为 feature flag 兜底；
- 新事件路径异常时回退到一次尾部刷新；
- 先只启用 V2/V3，验证后再处理 V1；
- 每个阶段单独提交，避免把事件模型、数据库异步化和 UI 改造混在一个变更中。

## 8. 代码检查清单

每次优化完成后检查：

- [ ] Return 回调没有同步 I/O；
- [ ] 用户消息进入内存后即可读到；
- [ ] 首次显示不依赖 SwiftData 查询；
- [ ] MainActor 上没有 `messages(for:)` 全量读取；
- [ ] 低优先级任务没有“utility Task + MainActor 同步扫描”；
- [ ] 消息列表不会同时响应多条重复刷新链路；
- [ ] 数据库写入失败不会让消息从 UI 消失；
- [ ] 快速连续发送、切换会话、流式回复均有回归测试；
- [ ] Instruments 中主线程没有新的长耗时尖峰；
- [ ] 关键路径的 signpost 数据有改善。

## 9. 建议的第一批改动

这三项已完成。后续优化按本文档中 P1/P2 的顺序继续推进：

1. 优先补齐发送入口的同步快速提交语义；
2. 再处理附件编码、首帧预算和 Instruments signpost 验证；
3. 对 V1 的 turn 边界和大历史滚动补充性能基准。

完成这三项后，再处理统计、标题和会话列表等后台消费者。
