# Lumi 对话流畅度优化 · 第一阶段方案（纯加速，不改用户可见行为）

## 背景与范围

目标：降低 TTFT（点击发送到首个 token 到达）和回合内重复开销。**第一阶段只做不改变用户可见行为的优化**——流式期间仍显示静态"正在思考…"，但后端链路更快。第二阶段（开启流式逐字显示）单独审批，本方案末尾写清依赖关系。

工具并行**暂不纳入**（`ToolManaging` 是 `@MainActor`，`ToolManaging.swift:11`，并行只重叠 IO、CPU 仍被序列化，且 suspend 语义复杂）。

## 本阶段不碰的前提

- `MessageStreamingStore` 的 `@MainActor` 隔离**保留**（第二阶段才改造它）
- SwiftUI `MessageListPlugin` 不订阅流式 store —— 保留
- `AgentTurnRunner` 整体 `@MainActor` —— 不动
- `NetworkProvider.stream` 的字节循环在主线程 —— 不动（改它风险高、影响面大，留到二阶段连同流式一起）

---

## 改动项（按收益/风险排序）

### 改动 1：SwiftData save 移出 send 关键路径【最高收益、最低风险】

**问题**：`AgentTurnRecordStore.record()`（`AgentTurnRecordStore.swift:103-123`）在 `sendStreaming` **之前**被 `await`（`AgentTurnRunner.swift:610`），内部 `try modelContext.save()`（`:119`）是磁盘 I/O（SwiftData + NSFileCoordinator）。注释 `AgentTurnRunner.swift:608` 自己承认这记录只"用于设置界面回看"。每轮 LLM 请求（含工具回合后的每一轮）都白白付一次磁盘写延迟，直接拉长 TTFT。

**改法**：把记录写入从「同步阻塞 send」改为「请求发出后 fire-and-forget」。

- `AgentTurnRunner.swift:608-615`：把当前的
  ```swift
  await AgentTurnRunnerRecordStoreBridge.shared.store?.record(request:..., turnID:..., providerID:...)
  ```
  移到 `sendStreaming` **之后**（`:666` 落库 assistantMessage 附近），并改为**不 await**（用 `Task { ... }` 后台补记，或 `Task.detached(.utility)`）。
- `AgentTurnRecordStore.record`（`:103`）：保持现有 `insert + save` 不变（记录完整性需要 save，但已不在关键路径上）。
- **注意 turnID 完整性**：record 依赖 `turnID`（`AgentTurnRunner.swift:614`），在 `executeTurnLoop` 作用域内已可用（`:492`），移位后仍可捕获，无需改签名。

**风险**：极低。记录丢失不影响对话正确性（仅设置页回看）。唯一要确认：`request` 是值类型 `LumiLLMRequest`，跨 Task 捕获安全（需确认其 `Sendable`；若不是，先 `let snapshot = request` 在 MainActor 上拷贝再传入 Task）。

**验证**：发一条消息，确认设置页「请求记录」仍出现、内容完整；用 Instruments Time Profiler 确认 send 前不再有 SwiftData save 帧占用。

---

### 改动 2：turn 内 history snapshot 复用，消除重复 fetch+排序【中等收益、低风险】

**问题**：`MessageManager.messages(for:)`（`MessageManager.swift:118`）每次调用都 `store?.fetchMessages`（全量）+ 合并 pending + 全量排序。在 `executeTurnLoop` 一个 LLM 迭代内，这一方法被反复调用：主循环 `AgentTurnRunner.swift:523`，加上工具执行路径 `+ToolExecution.swift:15`（`incompleteToolCallMessage`）、`:30`（`latestAssistantToolCalls`）、`:136`（`persistedSuspension`）。同一段历史在一个 turn 内被反复 fetch+排序 3-5 次，长对话放大明显。

注意：它是 `nonisolated`，**不阻塞主线程**（读已在后台）。问题是重复劳动。

**改法**：在 `executeTurnLoop` 每个迭代顶部取一次 history 快照，后续辅助方法接受 snapshot 参数，避免各自重查。

- `AgentTurnRunner.swift:523`：已有 `let history = ...`。把这一行作为该迭代后续所有调用的共享 snapshot。
- 新增内部辅助：把 `incompleteToolCallMessage(in:)`、`latestAssistantToolCalls(in:)`、`persistedSuspension(for:suspensionID:)` 改为接受 `messages: [LumiChatMessage]` 参数的重载（`+ToolExecution.swift:14,29,132`），在 `executeTurnLoop` 调用处传入已有的 `history`/迭代内快照。
- 主循环 `:507` 的 `incompleteToolCallMessage` 调用：这一处在迭代顶部，可用刚取的 messages。
- `executePendingToolCalls`（`:41`）：它内部 `:55` 又取了一次 messages，改为接受参数传入。

**风险**：低。`messages(for:)` 本身是 read-your-writes（合并 pending，`MessageManager.swift:118-141`），snapshot 在迭代内语义一致；只要迭代内不跨「写消息」事件复用即可。需逐个确认调用点是否在「插入了新消息之后」——若是，则该处必须重新取（不能复用）。关键检查点：`:507`（before）、`:523`（迭代开始）、工具结果落库后的下一迭代（自然重新取）。

**验证**：长对话（100+ 条消息）+ 多工具回合，对比改动前后 `messages(for:)` 调用次数（加临时 log 或 Instruments）。

---

### 改动 3：图片 base64 解码结果缓存【中等收益、低风险，多模态场景】

**问题**：`LumiVisionMessageSupport.messageImages(from:)`（`MessageBridge.swift:54-70`）对每条历史消息调 `Data(base64Encoded:)`（`:62`）。`preparedMessages`（`:18`）每轮请求对**全部历史消息**重新解码所有图片。多模态长对话里每轮重解，CPU 密集。`preparedMessages` 在 provider 路径调用，运行在后台（非主线程阻塞），但仍是重复 CPU。

**改法**：在 `LumiChatMessage` 上加一个 `transient`（非持久化）缓存字段，或在 `MessageBridge` 用进程级 `NSCache`（key=message id）缓存解码后的 `[MessageImage]`。

- 方案 A（推荐）：`MessageBridge.swift` 内新增 `private static let imageCache = NSCache<NSString, CachedImages>()`，`messageImages(from:)` 命中则返回。key 需稳定——但 metadata 是 `imageAttachments` JSON 字符串本身变化才需重解，可对 JSON 字符串做 hash 或直接用 `message.id`（同一消息图片不变）。用 `message.id` 最简单：改 `convert(_:)`（`:41`）调用处传 `message.id`，`messageImages(from:messageID:)`。
- 注意 `attachRequestImages`（`:76`）也调了 `messageImages(from:)`，需一并改造。
- `NSCache` 线程安全、内存压力自动驱逐，适合此场景。

**风险**：低。解码是幂等的（同一 base64 → 同一 Data）。只需保证 key 正确（图片内容变 = id 变或 hash 变）。`MessageImage` 需确认 `Sendable`/可放入 NSCache（若是 struct 值类型，包一层 `final class CachedImages: NSObject { let images: [MessageImage] }`）。

**验证**：构造多图历史对话，发多轮，确认图片只解码一次（log）；图片显示正常。

---

### 改动 4：消除流式 token 的「白写」`@Published`【低收益、极低风险】

**问题**：`MessageStreamingStore.states`（`MessageStreamingStore.swift:20`）是 `@Published`，`appendContent`/`appendThinking`（`:47,54`）每个 token 写一次触发 `objectWillChange`。但当前生产 UI（SwiftUI `MessageListPlugin`）**不订阅**它（已确认），唯一的订阅者是 `.disabled` 状态的 AppKit 插件。每个 token 在主线程白发一次 `objectWillChange`——纯浪费。

**改法（仅限第一阶段）**：把 `@Published private var states` 改为 `private var states`（去掉 `@Published`）。`MessageStreaming` 协议（`MessageStreaming.swift:15`）要求 `ObservableObject`，去掉 `@Published` 不破坏协议，只是不再自动广播；AppKit 插件订阅的 `objectWillChange.sink`（`AppKitMessageListCoordinator.swift:390`）将收不到自动信号——但该插件当前 `.disabled`，无影响。

**⚠️ 关键约束**：这条**与第二阶段冲突**。第二阶段开启流式显示时，SwiftUI 订阅需要变更通知——届时方向是「后台聚合 + 节拍推送」，而不是恢复 `@Published`。所以本条只是「现状下的清理」，若你计划很快推进第二阶段，**这条可以跳过**，避免改了又改。

**风险**：极低（改一个属性修饰符）。唯一的下游影响是 `.disabled` 的 AppKit 插件，已确认不启用。

**验证**：发消息对话正常；`MessageStreamingStore` 单测通过。

---

### 改动 5（可选）：`willSendToLLM` 中不依赖最新 user 消息的注入做会话级缓存【中等收益、中风险，列为可选】

**问题**：`executeTurnLoop`（`AgentTurnRunner.swift:566-571`）每个 LLM 迭代串行跑所有插件的 `willSendToLLM`。其中 MemoryPlugin 每次 O(记忆×词) 全量检索（虽走 actor 不阻塞主线程，但在串行链上）。其他注入（ProjectsPlugin 的 project path、SkillPlugin 的 skill 列表、Verbosity/Language）基本不变。

**改法**：对「不依赖最新 user 消息内容」的 system 注入做会话级缓存。但 `willSendToLLM` 是插件协议级钩子，在 `AgentTurnRunner` 侧做透明缓存会破坏插件「每次都可能变化」的语义，风险偏高。

**建议**：本条**列为可选/不在第一阶段做**。更稳妥的做法是在各插件**内部**各自加缓存（如 MemoryPlugin 按 query 字符串缓存检索结果；SkillPlugin 已有 30s TTL）。第一阶段只做改动 1-4。

---

## 实施顺序与依赖

```
改动 1（save 移位）  ← 独立，先做，收益最高
改动 2（history snapshot）← 独立，可与 1 并行
改动 3（图片缓存）   ← 独立，可与 1/2 并行
改动 4（去掉白写 @Published）← 独立；若二阶段很快做则跳过
改动 5（willSendToLLM 缓存）← 可选，建议留到后续
```

无相互依赖，可单独提交、单独回滚。

---

## 第二阶段（不在本次执行）的依赖说明

开启 SwiftUI 流式逐字显示需要的前置（本阶段不动，但为其铺路）：

1. **`MessageStreamingStore` 改造为「后台聚合 + 节拍推送」**：把 `appendContent/appendThinking` 从「每 token 写 `@Published`」改为后台 actor 累积原始文本、每 ~16ms 推一次合并后的快照。这是防止重新踩当年 LazyVStack 活锁的关键。
2. **`NetworkProvider.stream` 字节循环脱离主线程**：当前 `stream`（`NetworkProvider.swift`）整体 `@MainActor`，SSE 字节读取循环占主线程。流式显示对主线程流畅度敏感，需要先把字节循环挪到后台（`Task.detached` 或把 `NetworkProvider` 改 nonisolated）。
3. **SwiftUI `MessageListPlugin` 订阅流式 store**：复用已就绪的 `MarkdownBlockRenderer.streamingSlot`（`MarkdownBlockRenderer.swift:243-289`）增量解析 + 独立流式行，复用 `MessageListTailRefreshGate` 事件合并。

本阶段改动 1（save 移位）直接降低 TTFT，对第二阶段无冲突；改动 2-3 是通用加速；改动 4 视二阶段时机决定是否做。

---

## 不改的地方（避免误改，列出供 review）

- `LLMAPIService` 的 `.sortedKeys` + system 合并成单条：为 prompt cache 命中，正确，保留。
- `MessageManager` 的 write-behind + read-your-writes 设计：正确，保留。
- `messages(for:)` 的 `nonisolated`：读在后台，正确，保留（改动 2 只减少调用次数）。
- 聊天代码块不跑 tree-sitter：避免了流式渲染头号杀手，保留。
- `ScrollViewBottomTracker` 的 AppKit 层判定：避开了 SwiftUI 布局活锁，保留。

---

## 验证策略

- 每个改动独立提交、独立测试。
- 主观验证：发消息、工具回合、多模态对话，确认行为无变化。
- 客观验证：Instruments Time Profiler 对比改动前后「点击发送→首个 token」期间主线程占用；长对话（100+ 消息）多工具回合的 `messages(for:)` 调用次数。
- 回归：`MessageStreamingStore`、`AgentTurnRunner`、`MessageManager` 现有单测全绿。