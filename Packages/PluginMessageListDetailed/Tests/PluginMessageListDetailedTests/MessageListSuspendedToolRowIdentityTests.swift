import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListDetailed

// MARK: - 挂起工具调用的行标识（V3）
//
// V3 与 V2 共用同一套「连续工具执行消息合并成合成行」的机制，
// 因此共享同一个缺陷：合成行若复用首条消息的 id，组内新增成员时
// 行身份不变，SwiftUI 不会重新物化该行，新并入的挂起工具行
// （及其授权卡片）就画不出来。
//
// 真实案例：2026-10-31 08:40:15，`accessibility_observe` 对 Dock 的
// 授权请求并入已有工具组后，界面底部挂着「等待你的输入…」，
// 却没有任何可点击回答的授权卡片。

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

    let suspended = makeToolOnlyAssistantMessage(
        id: UUID(),
        conversationID: conversationID,
        turnID: turnID,
        toolCallID: "call-4-suspended",
        createdAt: start.addingTimeInterval(3),
        awaitingUserResponse: true,
        authorizationState: "pendingAuthorization"
    )

    let rowsBefore = builder.buildHistory(
        persisted: before,
        conversationID: conversationID,
        verbosity: .detailed
    )
    let rowsAfter = builder.buildHistory(
        persisted: before + [suspended],
        conversationID: conversationID,
        verbosity: .detailed
    )

    #expect(rowsBefore.count == 1, "3 条连续的工具执行消息应合成 1 行")
    #expect(rowsAfter.count == 1, "4 条连续的工具执行消息应合成 1 行")
    #expect(
        rowsAfter[0].toolCalls?.contains { $0.result?.awaitingUserResponse == true } == true,
        "合成行必须包含挂起等待授权的工具调用"
    )
    #expect(
        rowsBefore[0].id != rowsAfter[0].id,
        "合并组新增成员后合成消息的 id 必须变化，否则 ListV3View 的 ForEach 加 .id(message.id) 会认为该行未变化，新并入的挂起工具行与授权卡片不会被重新物化"
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
        verbosity: .detailed
    )
    let second = builder.buildHistory(
        persisted: messages,
        conversationID: conversationID,
        verbosity: .detailed
    )

    #expect(first[0].id == second[0].id, "成员集合不变时合成行 id 必须保持稳定")
}

@MainActor
@Test("挂起消息单独成组时，合成行必须保留该挂起调用")
func suspendedMessageAloneKeepsItsToolCall() {
    let conversationID = UUID()
    let turnID = UUID()
    let start = Date(timeIntervalSince1970: 1_000)
    let builder = MessageListRowBuilder()

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
        verbosity: .detailed
    )

    #expect(rows.count == 1)
    #expect(
        rows[0].toolCalls?.contains { $0.result?.awaitingUserResponse == true } == true,
        "单独成组时挂起调用必须保留在合成行里"
    )
    #expect(rows[0].renderKind == "turn-activity")
}
