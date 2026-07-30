## 目标

实现逐 token 实时显示(打字机效果),用增量推送(不重查库)。已定方案:**新增流式 Notification + 节流** / **纯内存临时行(不写库)** / **结束时用返回的完整消息写一次**。

## 已核实的关键事实

- `sendStreaming(_:onChunk:)` 已存在,`onChunk: @Sendable (LumiStreamChunk) async -> Void`。`LumiStreamChunk` 有 `content`(文本/思考增量)、`isThinking`、`isDone`、`eventTitle`、`stopReason`。**注意:tool-call 增量不通过 onChunk 推送**,只在内部累积——所以流式只能显示文本/思考,toolCalls 在最终落库时才完整。
- runner 当前调 `send`(丢弃 chunk),返回的完整消息用 provider 新生成的 UUID。流式期间**没有** assistant id。
- 无任何流式/partial 事件;`.lumiMessagesDidChange` 仅带 `conversationID`。
- `LumiStreamChunk`、`LumiStreamChunk.swift` 在 kernel;`EventManager` 是 NotificationCenter 包装。
- `MessageListView` 用 VStack(注释说明流式高频更新会致 LazyVStack 活锁),`.onReceive(.lumiMessagesDidChange)` → `refreshTail`(重查最近页)。

## 设计:三段式流式生命周期(全程不查库,只 patch 那一条)

新增一个 Notification:`.lumiMessageStreaming`,userInfo: `conversationID`、`messageID`、`kind`(`"start"` / `"delta"` / `"end"`)、`content`(累积全文)、`isThinking`。由 runner 在 `onChunk` 里**节流后**发出(~50ms 一次)。`MessageListView` 订阅它,按 `messageID` 原地 patch `messages` 里那一条,**不调 refreshTail、不查库**。

**生命周期:**
1. **start**:runner 调 LLM 前生成 `assistantID = UUID()`,发 `kind=start`(content=""  )。UI 收到后 append 一条临时 assistant 消息(用 assistantID),滚到底。
2. **delta**:onChunk 累积文本(区分 thinking/content),每 ~50ms 发 `kind=delta`(带累积全文)。UI 按 id 原地替换该消息的 content/reasoningContent,VStack 只 diff 这一条,滚到底(仅当 isAtBottom)。
3. **end**:`sendStreaming` 返回完整消息 → runner 用预生成的 `assistantID` 重建 → `insertMessage` 一次 → 发 `.lumiMessagesDidChange`(既有机制)。UI 的 `refreshTail` 用最终消息覆盖临时行(id 相同 → 平滑替换,无闪烁)。

## 改动文件

### 1. kernel:`LumiStreamChunk.swift` 同目录或 `Notification+Lumi` 加流式事件
- 在 `LumiKernelEvent` enum 加 `messageStreaming = "com.coffic.lumi.messageStreaming"` + `.lumiMessageStreaming` 别名。
- `LumiNotificationUserInfoKey` 加 `messageID`、`streamingKind`、`content`、`isThinking`。
- `Notification` 扩展加便捷访问器 `lumiStreamingMessageID` 等。

### 2. `AgentTurnRunner.executeTurnLoop`(核心)
- `:342` 前生成 `let assistantID = UUID()`,发 `kind=start`。
- 把 `targetProvider.send(request)` 改为 `sendStreaming(request)`,onChunk 里:
  - 维护本地累积变量(`contentAccumulator`、`thinkingAccumulator`),按 `chunk.isThinking` 分别累积 `chunk.content`。
  - 节流:记录 `lastEmitTime`,距上次 ≥50ms 才发 `kind=delta`(带累积全文);或用 `DispatchSourceTimer`/简单时间戳判断。
  - `chunk.isDone` 时不强制立即发(delta 节流足够)。
- `sendStreaming` 返回 final message 后:用 `assistantID` 重建(`LumiChatMessage(id: assistantID, ...final 各字段...)`)→ `insertMessage` → 发 `.lumiMessagesDidChange`。发 `kind=end` 可省略(由 messagesDidChange 兜底)。
- ⚠️ tool-call 情况:返回的消息可能带 toolCalls(不通过 onChunk)。流式期间 UI 只看到文本;最终落库时 toolCalls 正确写入。UI 最终 refreshTail 拿到带 toolCalls 的完整行,渲染器会正确显示。**这与当前"一次性显示"行为一致,只是多了流式过程。**

### 3. `MessageListView`
- 新增 `@State private var streamingMessageID: UUID?`(当前正在流式的临时行 id)。
- 新订阅 `.onReceive(.lumiMessageStreaming)`:
  - `start`:若属当前会话,append 一条临时 `LumiChatMessage(id: messageID, role: .assistant, content: "")` 到 `messages` 尾部,记 `streamingMessageID`,滚到底。
  - `delta`:若 `messageID == streamingMessageID`,原地替换 `messages` 中该条(更新 content/reasoningContent),仅当 isAtBottom 滚到底(无动画,避免抖动)。
- 流式行结束靠既有 `.lumiMessagesDidChange` → `refreshTail` 处理(临时行 id == 最终行 id,refreshTail 的 overlap 合并会平滑覆盖)。清空 `streamingMessageID`。
- 切会话时清掉残留的 streamingMessageID/临时行。

### 4. 节流实现
- runner onChunk 里用 `Date()` 时间戳做简单节流(每次更新 `lastEmit`,差 ≥50ms 才发)。**节流必须确保最后一个 delta 不丢**:在 `sendStreaming` 返回后(完整消息到手)立即补发一次最终 delta(或直接靠 messagesDidChange 覆盖,因为最终全文一定在返回的消息里)。**选后者**(messagesDidChange 兜底),简化节流——即使丢了最后一个 delta,最终落库也会纠正。

## 不改的
- provider 层(`sendStreaming` 已就绪,无需改任何 provider)。
- `MessageStore`/`MessageManager`(只在结束时 insertMessage 一次,流式期间不碰库)。
- `MessageRowView`(原地 patch content 后,VStack diff 自然重渲染那一行)。
- 现有 `.lumiMessagesDidChange` → `refreshTail` 机制保留,用于"流式结束/新消息插入/工具消息"等低频场景。

## 关键风险与取舍(如实说明)
1. **节流丢最后一帧**:靠 messagesDidChange 兜底(最终全文一定在返回消息里),可接受。流式末尾可能瞬时空一帧,但立即被最终消息覆盖。
2. **VStack diff 高频**:每次 delta 替换整条消息 → VStack diff 整个列表。这正是当前用 VStack(非 LazyVStack)的原因——一次性 diff 比 LazyVStack 活锁稳。配合 50ms 节流(~20次/秒),可接受。**若实测仍卡,可进一步把临时行单独渲染(不在 messages 数组里),避免整列表 diff——但先按当前方案,实测再定。**
3. **思考内容(reasoning)流式**:onChunk 的 `isThinking` 增量需累积进 `reasoningContent`。UI 行渲染器要支持流式 reasoning 显示(确认 renderer 对部分 reasoning 的处理)。
4. **tool-call 回合**:tool 消息不流式(协议限制),tool 执行期间无流式反馈——这与现状一致。

## 验证
- `swift build` MessageListPlugin + AgentTurnRunnerPlugin + kernel。
- 整体 `swift build --product LumiFactory`。
- 实测:发消息 → 看助手回复逐字出现(打字机)、滚动跟随、结束后消息完整(含 toolCalls 如有)、切会话无残留临时行。

## 实施顺序
1. kernel:加 `.lumiMessageStreaming` 事件 + userInfo keys + 便捷访问器。
2. AgentTurnRunner:`send`→`sendStreaming`,加 assistantID + 节流发 delta。
3. MessageListView:订阅流式事件,start/delta patch 临时行。
4. 构建 + 你实测流式效果。

确认后开始(kernel→runner→UI)。