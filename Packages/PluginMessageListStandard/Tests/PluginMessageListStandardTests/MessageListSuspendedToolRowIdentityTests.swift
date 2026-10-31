import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListStandard

// MARK: - 挂起工具调用的行标识
//
// 复现用户报告的缺陷（2026-10-31 08:40:15）：
// 会话停在「等待你的输入…」，但界面上**没有任何授权卡片**可以回答。
//
// ## 真实时序（取自磁盘消息库）
//
// 同一回合内连续落库了 4 条「只含工具调用的助手消息」（正文为空）：
//
//   81296 | run_command          | 正文空
//   81298 | run_command          | 正文空
//   81300 | run_command          | 正文空
//   81302 | accessibility_observe | 正文空 | awaitingUserResponse = true
//                                       authorizationState = pendingAuthorization
//
// 数据层（`MessageListRowBuilder`）把连续多条「只含工具调用的助手消息」
// 合并成**一条**合成消息（`renderKind == "turn-activity"`），其 `toolCalls`
// 是各消息的平铺。
//
// ## 缺陷判据
//
// 合成消息复用**组内首条消息的 id**（`makeToolStepGroup`）。
// 当组内**新增成员**时（例如 81302 挂起授权后并入已有组），合成消息的
// `id` 不变、`content` 不变（仍为空），只有 `toolCalls` 变长了。
//
// 而 V2 列表用 `ForEach(viewModel.historyRows)` + `.id(message.id)`
// 作为行的身份：`Message.id` 不变 ⇒ SwiftUI 认为这一行没变 ⇒
// **不会重新物化**该行 ⇒ 新并入的挂起工具行（及其授权卡片）画不出来。
//
// 于是用户看到的是：底部挂着「等待你的输入…」，却找不到任何可以点击回答的卡片。
//
// ## 为什么单测足够
//
// 判据是**数据层合成结果的行标识**是否随组成员变化而变化，
// 这是纯函数行为（`MessageListRowBuilder` → `Message.id`），
// 不需要真实进程参与。UI 侧的行身份消费方（`ForEach` + `.id(message.id)`）
// 已由 `ListV2View` 固定。

/// 构造一条「只含工具调用、正文为空」的助手消息。
private func makeToolOnlyAssistantMessage(
    id: UUID,
    conversationID: UUID,
    turnID: UUID,
    toolCallID: String,
    createdAt: Date,
    awaitingUserResponse: Bool = false,
    authorizationState: String? = nil
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
                name: "accessibility_observe",
                arguments: "{}",
                result: MessageToolResult(
                    content: "{\"kind\":\"computer_use_authorization\"}",
                    awaitingUserResponse: awaitingUserResponse
                ),
                displayDescription: "读取应用控件",
                authorizationState: authorizationState
            )
        ]
    )
}

@MainActor
@Test("合并组新增成员后，合成消息的行标识必须随之变化")
func mergedGroupRowIdentityChangesWhenMemberJoins() {
    let conversationID = UUID()
    let turnID = UUID()
    let start = Date(timeIntervalSince1970: 1_000)
    let builder = MessageListRowBuilder()

    // 组内已有 3 条工具执行消息（正文全空）。
    let before = [
        makeToolOnlyAssistantMessage(
            id: UUID(),
            conversationID: conversationID,
            turnID: turnID,
            toolCallID: "call-1",
            createdAt: start
        ),
        makeToolOnlyAssistantMessage(
            id: UUID(),
            conversationID: conversationID,
            turnID: turnID,
            toolCallID: "call-2",
            createdAt: start.addingTimeInterval(1)
        ),
        makeToolOnlyAssistantMessage(
            id: UUID(),
            conversationID: conversationID,
            turnID: turnID,
            toolCallID: "call-3",
            createdAt: start.addingTimeInterval(2)
        ),
    ]

    // 随后一条挂起等待授权的工具消息并入同一组。
    let suspended = makeToolOnlyAssistantMessage(
        id: UUID(),
        conversationID: conversationID,
        turnID: turnID,
        toolCallID: "call-4-suspended",
        createdAt: start.addingTimeInterval(3),
        awaitingUserResponse: true,
        authorizationState: "pendingAuthorization"
    )
    let after = before + [suspended]

    let rowsBefore = builder.buildHistory(
        persisted: before,
        conversationID: conversationID,
        verbosity: .standard
    )
    let rowsAfter = builder.buildHistory(
        persisted: after,
        conversationID: conversationID,
        verbosity: .standard
    )

    #expect(rowsBefore.count == 1, "3 条连续的工具执行消息应合成 1 行")
    #expect(rowsAfter.count == 1, "4 条连续的工具执行消息应合成 1 行")

    // 合成行确实带上了新并入的挂起调用。
    let toolCallsAfter = rowsAfter[0].toolCalls ?? []
    #expect(
        toolCallsAfter.contains { $0.result?.awaitingUserResponse == true },
        "合成行必须包含挂起等待授权的工具调用"
    )

    // 缺陷判据：行标识不变 ⇒ SwiftUI 不会重新物化该行 ⇒ 授权卡片画不出来。
    #expect(
        rowsBefore[0].id != rowsAfter[0].id,
        "合并组新增成员后合成消息的 id 必须变化，否则 ListV2View 的 ForEach 加 .id(message.id) 会认为该行未变化，新并入的挂起工具行与授权卡片不会被重新物化"
    )
}

@MainActor
@Test("合并组的行标识在成员集合不变时保持稳定")
func mergedGroupRowIdentityStableWhenMembersUnchanged() {
    let conversationID = UUID()
    let turnID = UUID()
    let start = Date(timeIntervalSince1970: 1_000)
    let builder = MessageListRowBuilder()

    let messages = [
        makeToolOnlyAssistantMessage(
            id: UUID(),
            conversationID: conversationID,
            turnID: turnID,
            toolCallID: "call-1",
            createdAt: start
        ),
        makeToolOnlyAssistantMessage(
            id: UUID(),
            conversationID: conversationID,
            turnID: turnID,
            toolCallID: "call-2",
            createdAt: start.addingTimeInterval(1)
        ),
    ]

    let first = builder.buildHistory(
        persisted: messages,
        conversationID: conversationID,
        verbosity: .standard
    )
    let second = builder.buildHistory(
        persisted: messages,
        conversationID: conversationID,
        verbosity: .standard
    )

    // 成员不变 ⇒ 合成行身份必须稳定，否则每次重建都会让整列表重新物化。
    #expect(first[0].id == second[0].id, "成员集合不变时合成行 id 必须保持稳定")
}

@MainActor
@Test("挂起消息单独成组时，合成行必须保留该挂起调用")
func suspendedMessageAloneKeepsItsToolCall() {
    let conversationID = UUID()
    let turnID = UUID()
    let start = Date(timeIntervalSince1970: 1_000)
    let builder = MessageListRowBuilder()

    // 对照案例（消息库 56933，2026-10-22 19:24:14）：
    // 挂起消息之前是 user 消息，中间没有其他工具执行消息，
    // 因此它**单独**成组。
    let suspended = makeToolOnlyAssistantMessage(
        id: UUID(),
        conversationID: conversationID,
        turnID: turnID,
        toolCallID: "call-suspended",
        createdAt: start,
        awaitingUserResponse: true,
        authorizationState: "pendingAuthorization"
    )

    let rows = builder.buildHistory(
        persisted: [suspended],
        conversationID: conversationID,
        verbosity: .standard
    )

    #expect(rows.count == 1)
    #expect(
        rows[0].toolCalls?.contains { $0.result?.awaitingUserResponse == true } == true,
        "单独成组时挂起调用必须保留在合成行里"
    )
    #expect(rows[0].renderKind == "turn-activity")
}
