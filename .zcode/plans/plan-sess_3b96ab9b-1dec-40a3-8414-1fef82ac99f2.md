## 根因

V1 不显示用户消息，是两个缺陷叠加：

1. **结构层**：`AgentTurnSummaryItem` 只有一个 `message`（turn 最后一条消息），没有用户消息的位置。
2. **数据层**：`AgentTurnRecord.triggerMessageID` 几乎总是 nil——它的推导（`AgentTurnRunner.swift:406-411`）只在 `message.turnID == turnID` 的消息里找用户消息，但用户消息不携带 turnID（`MessageSender` 在 turnID 生成前就存了用户消息），所以永远匹配不到。

## 决策：在展示层解决，不动运行时/持久化

不动 `AgentTurnRunner` / `MessageSender` / 消息模型（核心运行时，风险大）。改在 V1 的展示层：

`rebuildItems` 已拉取整个会话的消息 `messages = messageManager.messages(for:)`（`:178`）。对每个 turn，按时间顺序找 **`record.startedAt` 之前最近的一条 `.user` 消息**作为该 turn 的用户输入——天然就是触发该 turn 的用户消息，不依赖 turnID 也不依赖 triggerMessageID。

## 改动清单

### 1. `Models/AgentTurnSummaryItem.swift` — 增加用户消息字段
```swift
struct AgentTurnSummaryItem: Identifiable, Equatable, Sendable {
    let record: AgentTurnRecord
    let userMessage: LumiChatMessage?   // 新增：触发该 turn 的用户消息（按时间推导，可能为 nil）
    let message: LumiChatMessage        // turn 的最终回复 / 运行中占位
    var id: UUID { record.id }
}
```

### 2. `Services/AgentTurnSummaryBuilder.swift` — 关联用户消息 + 运行中 turn 产出行
- `build(records:messages:)`：
  - 不再用 `messagesByTurn` 分组（用户消息无 turnID 分不进去）。改为：把会话消息按时间排序后，对每个 record 找 `startedAt` 之前最近的 `.user` 消息作为 `userMessage`；turn 自身的消息仍按 `turnID` 分组取 `summaryMessage`。
  - 用一个 helper `userMessage(before: messages, startedAt:)` 做时间回溯匹配。
- `summaryMessage(for:messages:)`：
  - `.idle` / `.running` 不再返回 nil。改为：若有 `latestAssistant`（中间结果）就返回它；否则返回 nil（由 build 层在 `message` 为 nil 时合成一个"思考中…"占位 `LumiChatMessage`，role=.status，附在 record 上）。
- `build` 里：若 `summaryMessage` 返回 nil（running 且无任何中间消息），合成占位 message，确保运行中的 turn 也产出一行。
- 删除 `legacyConclusions(from:)` 及 V1 里 `usesTurnProjection` / `legacyConclusionRows` / `conclusionMessages` legacy 分支（顺带清掉冗余，让 V1 纯粹是 turn 列表）。

### 3. `ViewModels/MessageListV1ViewModel.swift` — 精简
- `MessageListV1Presentation` 去掉 `legacyConclusions` 字段，保留 `turnItems` + `statusMessage`（statusMessage 暂保留，作为兼容；下一步可由运行中 turn 行内占位替代）。
- 删除 `usesTurnProjection`、`conclusionMessages`；`displayMessages` 改为 `items.map(\.message)`。
- `rebuildItems` 去掉 `legacyConclusions` 构造与对应赋值。

### 4. `Views/ListV1View.swift` — 每行渲染用户消息 + 回复
- `turnSummaryRows` 的 `ForEach` 内：对每个 item，先渲染 `userMessage`（若非 nil）的 `MessageRowView`，再渲染 `message` 的 `MessageRowView`。两行各用稳定 id（`item.id` + `item.id` 的派生）。
- 删除 `historyRows` 里的 `usesTurnProjection` 分支与 `legacyConclusionRows`，直接用 turn rows。

## 不改动
- `AgentTurnRunner` / `MessageSender` / `LumiChatMessage` / `AgentTurnRecord`：核心运行时与持久化不动。
- V2 / V3：不受影响（它们用各自的 viewmodel + rowBuilder）。

## 验证
1. 编译 Lumi.app (Debug)。
2. V1 模式（verbosity=.brief）：发一条消息，确认列表里同时显示「用户问题」+「助手回复」。
3. 多轮对话：确认每个 turn 都正确配对到它前面那条用户消息。
4. turn 运行中：确认列表底部出现该 turn 的一行（占位/中间消息），不再只有漂浮 status。
5. 向上翻页、切会话、空会话空态，确认正常。