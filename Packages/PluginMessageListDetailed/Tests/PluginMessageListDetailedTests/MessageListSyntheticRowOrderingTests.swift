import Foundation
import ProviderMessage
import Testing
import KitMessageList
@testable import PluginMessageListDetailed

// MARK: - 合成行跨文本消息吞并后续工具组（授权卡片「之后又继续跑」的错觉）
//
// ## 用户报告的现象（2026-11-03）
//
// 会话 `E709F960-3711-4BDA-88B2-0049F83398D8`（A3 完全授权，MiniMax-M3.1-Flash）：
//
// - 08:35:09，`accessibility_observe` 读 Cisum 命中未授权应用 → 工具挂起
//   （`awaitingUserResponse = true`，`kind = computer_use_authorization`）。
// - 08:35:10 回合 suspended；**此后 41 分钟没有任何新消息**——Agent 确实停了。
// - 09:16:50 用户点「始终允许」，回合恢复。
//
// 但界面上授权卡片**下方**紧接着 08:30 / 08:31 的旧内容，
// 视觉上像「授权后没暂停，继续往下跑」。
//
// ## 真实时序（磁盘消息库，同一 turn `A27FC1BB-...`）
//
//   08:29:43 TOOL   （正文空）
//   08:29:49 TOOL   （正文空）
//   08:29:56 TOOL   （正文空）
//   08:30:02 TEXT   PluginAudioCopy uses the Lumi ProviderStorage protocol
//   08:30:17 TEXT   PluginPluginManager and PluginAudioCopy use Lumi's ...
//   ...
//   08:34:05 TOOL   （正文空）
//   08:34:28 TOOL   （正文空）
//   08:34:42 TOOL   （正文空）
//   08:35:09 TOOL   （正文空，awaitingUserResponse = true）← 授权卡片在这里
//
// ## 根因：同 turn 的工具消息**跨文本消息**被合并成一组
//
// `mergeConsecutiveToolExecutionMessages` 遇到带 `turnID` 的消息时，
// 走的是「按 turnID 分桶」路径：
//
// ```swift
// if message.isToolExecutionOnly {
//     if let turnID = message.turnID {
//         flushGroup()                       // ← 只清空**无 turnID** 的旧组
//         turnGroups[turnID, default: []].append(message)
//         let group = turnGroups[turnID] ?? []
//         if let index = turnGroupIndices[turnID] {
//             result[index] = makeToolStepGroup(from: group)   // ← 整组回填
//         } else {
//             turnGroupIndices[turnID] = result.count
//             result.append(makeToolStepGroup(from: group))
//         }
//     }
// ```
//
// 「连续」在这里的真实含义是**同一个 turn 内**，而不是**时间上相邻**。
// 中间的文本消息（08:30:02 / 08:30:17）被 `flushGroup()` 跳过——
// 它们不是工具消息，不进任何组，但**也不会终止**当前 turn 的工具组。
//
// 于是 08:29:43 ~ 08:29:56 的三条工具消息与 08:34:05 ~ 08:35:09 的四条
// 工具消息（含授权挂起那条）被合并进**同一组**，合成行落在**组首**
// （08:29:43）的位置。
//
// ## 缺陷判据
//
// 合成行的位置由组内**最早**成员决定，而它承载的**全部**工具调用
// （包括 08:35 的授权挂起点）都被拉到了那个位置。
//
// 结果：08:30 / 08:31 的文本消息（时间上在 08:29:43 之后、08:34 之前）
// 被渲染到合成行**下方**——也就是授权卡片的**下方**。
// 视觉上就是「授权卡片之后，旧内容继续跑」。
//
// 正确行为：工具组应当只合并**时间上相邻**的「只含工具调用」消息。
// 文本消息必须**终止**当前的工具组。

/// 构造一条「只含工具调用、正文为空」的助手消息。
private func makeToolOnlyAssistantMessage(
    id: UUID,
    conversationID: UUID,
    turnID: UUID?,
    toolCallID: String,
    createdAt: Date
) -> Message {
    Message(
        id: id,
        conversationID: conversationID,
        role: .assistant,
        content: "",
        createdAt: createdAt,
        turnID: turnID,
        toolCalls: [
            MessageToolCall(
                id: toolCallID,
                name: "run_command",
                arguments: "{}",
                result: MessageToolResult(content: "result of \(toolCallID)"),
                displayDescription: "运行 \(toolCallID)"
            )
        ]
    )
}

/// 构造一条「正文非空」的助手消息。
private func makeTextAssistantMessage(
    id: UUID,
    conversationID: UUID,
    turnID: UUID,
    content: String,
    createdAt: Date
) -> Message {
    Message(
        id: id,
        conversationID: conversationID,
        role: .assistant,
        content: content,
        createdAt: createdAt,
        turnID: turnID
    )
}

@MainActor
@Test("同一 turn 内被文本消息隔开的两组工具消息不得合并成一行")
func toolGroupsSeparatedByTextMessageMustNotMerge() {
    let conversationID = UUID()
    let turnID = UUID()
    let base = Date(timeIntervalSince1970: 1_000)
    let builder = MessageListRowBuilder()

    // 第一组工具消息：08:29:43 / 08:29:49 / 08:29:56。
    let groupOne = [
        makeToolOnlyAssistantMessage(id: UUID(), conversationID: conversationID, turnID: turnID,
                                     toolCallID: "t-082943", createdAt: base.addingTimeInterval(0)),
        makeToolOnlyAssistantMessage(id: UUID(), conversationID: conversationID, turnID: turnID,
                                     toolCallID: "t-082949", createdAt: base.addingTimeInterval(6)),
        makeToolOnlyAssistantMessage(id: UUID(), conversationID: conversationID, turnID: turnID,
                                     toolCallID: "t-082956", createdAt: base.addingTimeInterval(13)),
    ]

    // 中间的文本消息：08:30:02 / 08:30:17。
    let text = [
        makeTextAssistantMessage(id: UUID(), conversationID: conversationID, turnID: turnID,
                                 content: "PluginAudioCopy uses the Lumi ProviderStorage protocol",
                                 createdAt: base.addingTimeInterval(19)),
        makeTextAssistantMessage(id: UUID(), conversationID: conversationID, turnID: turnID,
                                 content: "PluginPluginManager and PluginAudioCopy use Lumi's ProviderStorage",
                                 createdAt: base.addingTimeInterval(34)),
    ]

    // 第二组工具消息：08:34:05 ~ 08:35:09（末条是授权挂起点）。
    let groupTwo = [
        makeToolOnlyAssistantMessage(id: UUID(), conversationID: conversationID, turnID: turnID,
                                     toolCallID: "t-083405", createdAt: base.addingTimeInterval(242)),
        makeToolOnlyAssistantMessage(id: UUID(), conversationID: conversationID, turnID: turnID,
                                     toolCallID: "t-083509", createdAt: base.addingTimeInterval(306)),
    ]

    let rows = builder.buildHistory(
        persisted: groupOne + text + groupTwo,
        conversationID: conversationID,
        verbosity: .standard
    )

    // 缺陷判据：两组工具消息被文本消息隔开，必须是**两个**合成行。
    // 现状：它们被合并成一行（同一 turn 的工具桶跨文本消息延续）。
    let syntheticRows = rows.filter { $0.renderKind == "turn-activity" }
    #expect(
        syntheticRows.count == 2,
        "被文本消息隔开的两组工具消息必须合成 2 行，实际 \(syntheticRows.count) 行"
    )
}

@MainActor
@Test("合成行的位置不得早于它所承载的授权挂起点")
func syntheticRowMustNotPrecedeItsSuspensionPoint() {
    let conversationID = UUID()
    let turnID = UUID()
    let base = Date(timeIntervalSince1970: 1_000)
    let builder = MessageListRowBuilder()

    let groupOne = [
        makeToolOnlyAssistantMessage(id: UUID(), conversationID: conversationID, turnID: turnID,
                                     toolCallID: "t-082943", createdAt: base.addingTimeInterval(0)),
    ]
    let text = [
        makeTextAssistantMessage(id: UUID(), conversationID: conversationID, turnID: turnID,
                                 content: "PluginAudioCopy uses the Lumi ProviderStorage protocol",
                                 createdAt: base.addingTimeInterval(19)),
    ]
    let suspended = makeToolOnlyAssistantMessage(id: UUID(), conversationID: conversationID, turnID: turnID,
                                                 toolCallID: "t-083509-suspended", createdAt: base.addingTimeInterval(306))

    let rows = builder.buildHistory(
        persisted: groupOne + text + [suspended],
        conversationID: conversationID,
        verbosity: .standard
    )

    // 找出承载挂起调用的那一行。
    guard let suspensionRow = rows.first(where: {
        ($0.toolCalls ?? []).contains { $0.id == "t-083509-suspended" }
    }) else {
        Issue.record("合成行必须保留挂起的工具调用")
        return
    }

    // 承载 08:35 挂起点的行，其位置不得早于 08:30 的文本消息——
    // 否则旧内容会被渲染到授权卡片下方。
    let textRow = rows.first { $0.content.hasPrefix("PluginAudioCopy") }
    #expect(textRow != nil, "文本消息必须保留为独立行")
    #expect(
        textRow!.createdAt < suspensionRow.createdAt,
        "文本消息（+19s）必须排在承载 08:35 挂起点（+306s）的行之前；实际 合成行=\(Int(suspensionRow.createdAt.timeIntervalSince(base)))s"
    )
}

@MainActor
@Test("无 turnID 的工具消息仍按时间相邻合并")
func toolOnlyMessagesWithoutTurnIDStillMergeConsecutively() {
    let conversationID = UUID()
    let base = Date(timeIntervalSince1970: 1_000)
    let builder = MessageListRowBuilder()

    let messages = (0..<3).map { index in
        makeToolOnlyAssistantMessage(id: UUID(), conversationID: conversationID, turnID: nil,
                                     toolCallID: "call-\(index)", createdAt: base.addingTimeInterval(Double(index)))
    }

    let rows = builder.buildHistory(
        persisted: messages,
        conversationID: conversationID,
        verbosity: .standard
    )

    #expect(rows.count == 1, "连续的工具消息应合成 1 行")
    #expect(rows[0].renderKind == "tool-step-group")
    #expect(rows[0].toolCalls?.count == 3)
}
