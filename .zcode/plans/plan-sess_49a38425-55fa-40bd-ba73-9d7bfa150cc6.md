# Lumi 对话流畅度优化 · 第二阶段（流式逐字显示 + NetworkProvider 脱离主线程）

## 背景与目标

第一阶段已完成的 4 个改动（TTFT 降低、重复劳动消除）在本分支 `perf/conversation-latency-stage1` 上。第二阶段在此基础上实现：

- **核心交付**：让 SwiftUI 消息列表（`MessageListPlugin`，V2 standard / V3 detailed）支持流式逐字显示——LLM 回复期间用户能看到模型逐字吐字，而不是干等静态"正在思考…"。
- **并行子系统改造**：`NetworkProvider` 脱离主线程，把 SSE 字节循环和 HTTP 交换记录写入（SwiftData）移出主线程。

两部分相对独立，**分两个子分支依次落地**，核心交付先行。

## 设计决策（已确认）

1. **流式通知机制**：订阅 `objectWillChange` + ViewModel 侧单飞帧门禁（16ms）。与 AppKit 范本一致。
2. **brief 模式**：不显示流式行（与 AppKit 范本一致，brief 的 `streamingRow` 强制 nil）。只改 V2/V3。
3. **流式行独立于历史行**：不混进 `persistedMessages`/`historyRows`（否则 `HistoryBuildSignature` 含 contentLength，每个 token 触发全量 rebuild，重新踩活锁）。流式行是独立的 published 属性。
4. **复用现成设施**：`LumiStreamingRowID`（进程级稳定常量 id）、`ObservableMessageStreamingBox`（SwiftUI 订阅桥接）、`MarkdownBlockCache.streamingSlot`（前缀追加增量解析）、`MessageListTailRefreshGate`（事件合并）。

---

# 第一部分：SwiftUI 流式逐字显示（核心交付）

## 前置：部分回退第一阶段改动 4

第一阶段改动 4 去掉了 `MessageStreamingStore.states` 的 `@Published`。现在要订阅 `objectWillChange`，store 必须重新广播变更。

**改法**：不恢复 `@Published`（那会每个 token 自动广播）。改为在 `appendContent`/`appendThinking`/`startStreaming`/`endStreaming` 内**手动** `objectWillChange.send()`。配合 ViewModel 的帧门禁，每个 token 触发一次广播但被合并成每帧最多 1 次刷新——开销可控，且语义精确（我们明确知道何时广播）。

**文件**：`Plugins/MessageStreamingPlugin/Sources/MessageStreamingPlugin/MessageStreamingStore.swift`
- 在 `startStreaming`/`appendContent`/`appendThinking`/`endStreaming` 的状态变更后，显式调用 `objectWillChange.send()`。
- 保留 `private var states`（不加回 `@Published`）——手动广播比 `@Published` 更可控，注释说明原因。
- 更新第一阶段改动 4 写的长注释，说明现在有了订阅方（SwiftUI V2/V3 ViewModel）。

**对 AppKit 插件的影响**：它的订阅（`AppKitMessageListCoordinator.swift:390`）现在能真正收到事件了（之前 store 静默）。但 AppKit 插件 `.disabled`，无影响；未来若启用，它自己的帧门禁同样工作。

## 改动 A：ListV2ViewModel 接入流式行

**文件**：`Plugins/MessageListPlugin/Sources/ViewModels/ListV2ViewModel.swift`

### A1. 新增独立的流式行状态
在 `@Published` 区域新增（与 `historyRows` 平级，**不**进 `persistedMessages`）：
```swift
/// 流式临时行（独立于历史行）。仅在 thinking/generating 阶段非 nil。
/// 用 LumiStreamingRowID 作为稳定 id，落库行用随机 UUID，两者永不冲突。
@Published private(set) var streamingRow: LumiChatMessage?
```

### A2. 新增流式订阅 + 帧门禁
在 `bindServicesIfNeeded()`（`:310`）里新增一段（参考 `AppKitMessageListCoordinator.swift:390-399` + `:414-430`）：
- 用 `kernel.messageStreaming` 订阅 `objectWillChange`。
- 回调里调 `scheduleStreamingRefresh()`——单飞门禁：若已有挂起的刷新 Task 则直接返回；否则新建 `Task { @MainActor }`，`Task.sleep(16_000_000)`（16ms），醒来后读 `streamingRow(for:)` / `streamingStage(for:)` 更新 `self.streamingRow`，清空挂起 Task。
- 新增字段：`private var streamingRefreshTask: Task<Void, Never>?`
- `streamingRow` 的更新规则（对照 `TimelineProjector.shouldShowStreamingRow`，`TimelineProjector.swift:85-88`）：
  - `stage == .thinking || stage == .generating` 且 row 非空 → `streamingRow = row`
  - 否则 → `streamingRow = nil`（`.idle`/`.sending`/无状态）
- **会话过滤**：只处理 `selectedConversationID` 匹配的流式状态，避免别的会话的流式串扰。

### A3. brief 模式不显示流式行
在 `scheduleStreamingRefresh` 的刷新逻辑里，`guard verbosity != .brief` 时强制 `streamingRow = nil`（对照 `AppKitMessageListCoordinator.swift:282-284`）。V2 是 standard，本身不走 brief 分支，但保险起见加判定。

### A4. 流式行出现/消失时触发 scroll-to-bottom
流式行从 nil→非 nil（开始流式）和非 nil 内容增长期间，应跟随滚动到底（如果用户在底部）。在 `streamingRow` 的 `didSet` 里，或帧门禁醒来后，通知 View 层滚动（通过现有的 `scrollTick` 机制或新增回调）。注意：**只在流式开始时强制滚**，内容增长期间沿用 `atBottomBox` 判定（用户上滑则不跟随）。

### A5. 切换会话时清空流式行
在 `activate(conversationID:)`（`:143`）里，切换会话时 `streamingRow = nil`，避免上个会话的残留行显示。

## 改动 B：ListV2View 渲染流式行

**文件**：`Plugins/MessageListPlugin/Sources/Views/ListV2View.swift`

### B1. ForEach 后追加流式行渲染
在 `messageScrollView` 的 `List` 里，`ForEach(viewModel.historyRows)` 之后，追加：
```swift
if let streaming = viewModel.streamingRow {
    MessageRowView(kernel: kernel, message: streaming, verbosity: viewModel.verbosity)
        .id(LumiStreamingRowID)  // 进程级稳定常量 id
        .plainMessageListRow()
}
```
- 流式行用 `LumiStreamingRowID` 作为 `.id()`，与历史行的 `message.id`（随机 UUID）永不冲突。
- 落库时：真实行（新 UUID）出现 + 流式行（`endStreaming` 后 `streamingRow = nil`）消失，SwiftUI diff 作为两次独立动画处理，**天然无闪烁、无双行**（已由 `AppKitStreamingIntegrationTests.streamingToPersistedSwap` 验证此模型）。

### B2. status 行 drop 规则
流式行可见（`streamingRow != nil`）期间，历史行里的 `.status` 消息（"正在思考…"）应被隐藏——否则会同时显示 status 行和流式行。
- 在 `rebuildHistoryRows`（`ListV2ViewModel.swift:361`）或 `MessageListRowBuilder` 里，当 `streamingRow != nil` 时过滤掉 `.status` 行。
- **注意**：这会让 `rebuildHistoryRows` 依赖 `streamingRow`。为避免每个 token 都触发 rebuild（`streamingRow` 是独立 published，它的变化不触发 `persistedMessages.didSet`），**只在 `streamingRow` 从 nil↔非 nil 切换时**调一次 `rebuildHistoryRows()`，内容增长期间不调（因为 status 行的显隐只取决于"有没有流式行"，不取决于流式内容）。

### B3. 更新"纯数据库驱动"注释
`ListV2View.swift:74-80` 和 `ListV2ViewModel.swift:32-35` 的注释声明"ForEach 只含稳定落库 id / 纯数据库驱动"。现在流式行加入，需更新注释说明新的设计（流式行独立、id 隔离、为何不会活锁）。

## 改动 C：ListV3ViewModel / ListV3View 同步改造

V3（detailed）与 V2 结构同构，做相同改动。V3 额外渲染 `reasoningContent`（`AssistantMessageView.swift:62-98`）——流式 thinking 阶段，`streamingRow.reasoningContent` 会增长，`MarkdownBlockRenderer` 自动命中 `streamingSlot` 增量解析，无需额外处理。
- **补齐 V3 的 `.id()`**：当前 V3 的 ForEach（`ListV3View.swift:192-199`）没有显式 `.id(message.id)`，V2 有。流式行接入前补齐一致性，避免 diff 不稳定。

## 改动 D：渲染层确认（预计无需改动）

`AssistantMessageView`（`MessageRendererPlugin/.../Renderers/AssistantMessageView.swift`）用 `MarkdownBlockRenderer(markdown: message.content, ...)`。流式行 content 增长时，`MarkdownBlockCache.blocks(for:)` 自动走 `streamingSlot` 路径（前缀追加增量解析，`MarkdownBlockRenderer.swift:254-274`）。**无需改动**，但需测试验证：
- 流式行（`role == .assistant`）能命中 `core-assistant-message` 渲染器（`canRender` 按 role，`OnBoot.swift:100-111`）。
- `MessageViewChrome` 的 header（时间戳、toolCall 计数）在流式期间不抖动。

## 改动 E：单元测试

**文件**：新增 `Plugins/MessageListPlugin/Tests/MessageListPluginTests/StreamingIntegrationTests.swift`（范本：`AppKitStreamingIntegrationTests.swift`）

测试用例（移植 AppKit 的 4 个测试语义到 SwiftUI ViewModel 层）：
1. `v2TokenUpdatesOnlyStreamingRow`：token 追加后 `streamingRow` 内容更新、`historyRows` 不变。
2. `streamingToPersistedSwap`：`endStreaming` + 落库通知后，`streamingRow == nil`、`historyRows` 出现真实行、id ≠ `LumiStreamingRowID`。
3. `briefHidesStreamingRow`：brief 模式下 `streamingRow` 始终 nil。
4. `frameCoalescing`：连续多次 `appendContent`，16ms 内只触发一次刷新。

测试需要 mock `MessageStreaming`——参考 `MessageListPlugin/Tests/.../Support/MockMessageServices.swift`（已有 `MockMessageStreaming`，需确认它的 append 是否触发 `objectWillChange`）。

---

# 第二部分：NetworkProvider 脱离主线程（并行子系统）

⚠️ **这部分风险更高、工程量更大，且与流式显示耦合不深。建议在第一部分验证通过后，作为独立分支单独落地。** 下面是设计，但标注为"第二部分（独立分支）"。

## 问题根因（已确认）

`NetworkProviding` 协议（`NetworkProviding.swift:9`）和 `NetworkProvider` 类（`NetworkProvider.swift:7`）都标 `@MainActor`。`stream` 方法（`:76-186`）的 SSE 字节循环跑在主线程。但真正的成本不是字节循环（CPU 工作很轻），而是：
- `HTTPExchangeStore.begin`（`:41-63`）和 `finish`（`:392-427`）是 `@MainActor` 同步方法，内部 `context.insert` + `save()`（磁盘 I/O）在主线程执行。
- 每个 LLM 请求至少 2 次主线程 SwiftData 写（begin + finish）。

## 改动 F：去掉 NetworkProviding 协议的 @MainActor

**文件**：`Packages/LumiKernel/Sources/LumiKernel/Providers/NetworkProviding.swift:9`
- 去掉协议级 `@MainActor`。Swift 强制协议隔离传递，这是让单个 `stream` 方法能 nonisolated 的前提。
- **影响面评估（已确认安全）**：协议有 6 个方法（`request`/`stream`/`get`/`post`/`json`/`download`），但只有 `NetworkProvider` 一个符合实现的类，且它没有 `var` 存储属性（只有 `let session`/`let exchangeStore`）。`get`/`post`/`json`/`download` 是默认实现，都委托给 `request`。
- **调用方无需改动**：所有调用点（10+ 个 LLM provider）已经是 `try await network.stream(...)`，去掉 `@MainActor` 后 `await` 自然绑定到调用方上下文，反而省掉了不必要的 hop。

## 改动 G：去掉 NetworkProvider 类的 @MainActor

**文件**：`Plugins/NetworkManagerPlugin/Sources/Services/NetworkProvider.swift:7`
- 去掉类级 `@MainActor`。类本身结构安全（无 var，session 是 Sendable，exchangeStore 是不可变引用）。
- `request`/`stream` 变成 nonisolated 方法。

## 改动 H：HTTPExchangeStore.begin/finish 改用后台 ModelContext（核心难点）

**文件**：`Plugins/NetworkManagerPlugin/Sources/Services/HTTPExchangeStore.swift`

**问题**：`begin` 返回 `HTTPExchangeRecord`（`@Model` 对象），`stream` 把它存起来传给 `finish`。如果 begin/finish 用不同后台 context，model 对象跨 context 失效。

**改法**：把 `begin`/`finish` 改为 `async`，内部用 `makeBackgroundContext()`（已有，`:288`）各自创建独立 context，通过 **record id**（而非 model 对象）衔接：
1. `begin` 改为返回 `String?`（record 的 id/persistentModelID 字符串），而非 `HTTPExchangeRecord?`。在后台 context insert + save 后返回 id。
2. `finish` 接收 record id（`String`），在新的后台 context 里按 id fetch 出 record，修改后 save。
3. `stream`（`NetworkProvider.swift:90,99,170,183`）改为持有 `String?`（record id）而非 `HTTPExchangeRecord?`，begin/finish 调用加 `await`。
4. `request`（`NetworkProvider.swift:18-74`）同样改造（它也调 begin/finish）。

**通知发布**：`NotificationCenter.default.post` 线程安全，可从后台发。订阅方（`HTTPExchangeSettingsView`）已通过 `Task.detached` + 快照读重载，兼容后台发布。审计其他订阅方确认无 `@MainActor` 假设。

**风险**：
- `HTTPExchangeRecord` 需有稳定 id 字段（确认 `@Model` 的 `id` 或加一个）。需读 `HTTPExchangeRecord.swift` 确认。
- `begin`/`finish` 变 async 后，`stream`/`request` 内部调用点都要 await（已确认它们是 async 方法，改动局部）。
- 后台 context 的 save 失败处理（已有 `save()` 的 catch，保持）。

## 改动 I：验证 NetworkProvider 改动不破坏现有行为

- `NetworkProvider` 构造（`NetworkManagerPlugin.swift:34` 的 onBoot）从 `@MainActor` 调用 nonisolated init——合法，无需改。
- 确认 `session.bytes(for:)` 的 AsyncBytes yield 在后台（已确认：URLSession 内部队列），nonisolated 后循环体跑在后台。
- 跑 `NetworkManagerPlugin` 现有测试（如有）确认 HTTP 交换记录仍然正确写入、设置页能读到。

---

# 实施顺序与分支策略

```
分支 perf/conversation-latency-stage1（已完成第一阶段 4 改动）
  │
  ├─ 分支 perf/streaming-display（第一部分：流式显示）
  │    改动: 前置回退(手动广播) → A(V2 ViewModel) → B(V2 View) → C(V3) → E(测试)
  │    验证: 手动发消息看逐字显示 + 单元测试 + 确认无活锁
  │
  └─ 分支 perf/network-off-main（第二部分：NetworkProvider，独立）
       改动: F(协议) → G(类) → H(begin/finish 后台 context) → I(验证)
       验证: HTTP 交换记录正常 + 设置页正常 + 无主线程阻塞回归
```

**第一部分先行**，验证通过后再做第二部分。两部分可独立合并。

---

# 风险与回滚

## 第一部分（流式显示）风险
- **AttributeGraph 活锁回归**：这是当年退回纯数据库驱动的原因。缓解：流式行独立 diff（不触发 `historyRows` rebuild）+ 帧门禁（每帧最多 1 次刷新）+ 复用 `streamingSlot`（不全量重解析 Markdown）。若仍活锁，可通过 `UserDefaults` 开关快速回退到静态"正在思考…"。
- **建议加运行时开关**：`UserDefaults` flag `lumiStreamingDisplayEnabled`（默认 true），出问题可一键关闭回到旧行为。**纳入改动 A。**

## 第二部分（NetworkProvider）风险
- `@Model` 跨 context 衔接重构（改动 H）是最易出错点。缓解：begin/finish 各自独立 context + id 衔接，不共享 model 对象。
- 协议去 `@MainActor` 影响面虽已评估为安全，但仍需全量编译 + 网络相关功能回归。

---

# 验证策略

## 第一部分
- **主观**：发一条长回复消息，确认逐字显示流畅、无卡顿、无闪烁；流式结束落库行平滑替换流式行；思考内容（V3）实时显示。
- **客观**：单元测试（改动 E）；Instruments Time Profiler 确认流式期间主线程占用平稳（无 100% 尖峰）。
- **回归**：现有 `MessageListPluginTests` 全绿；AppKit 流式测试仍全绿。

## 第二部分
- **主观**：发消息、用各 LLM provider、检查网络设置页 HTTP 交换记录完整。
- **客观**：Instruments 确认 `stream` 期间主线程无 SwiftData save 帧。
- **回归**：`NetworkManagerPlugin` 测试（如有）；HTTP 交换记录的统计图表正常。

---

# 不改的地方

- `MarkdownBlockCache.streamingSlot` 机制：已就绪，直接复用。
- `MessageStreamingStore` 的 `@MainActor` 隔离：保留（手动广播 + 帧门禁）。
- `AgentTurnRunner` 的 `onChunk` 写 store 逻辑：保留（每 token hop 主线程，被帧门禁合并）。
- `ScrollViewBottomTracker` / `MessageListTailRefreshGate`：保留。
- `LumiStreamingRowID`：直接复用。
- 第一阶段的 4 个改动：保留，无冲突。