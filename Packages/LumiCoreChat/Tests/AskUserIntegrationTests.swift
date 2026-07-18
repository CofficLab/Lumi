import Foundation
import LumiCoreKit
import Testing
@testable import LumiChatKit

@MainActor
@Test func expandingToolResultsSkipsPendingAskUserContent() {
    let conversationID = UUID()
    let messages = [
        LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [
                LumiToolCall(
                    id: "call-1",
                    name: "ask_user",
                    arguments: "{}",
                    result: LumiToolResult(
                        content: "\(LumiAskUserMarkers.pendingPrefix)\n{\"question\":\"Continue?\"}"
                    )
                )
            ]
        )
    ]

    let expanded = ChatService.messagesByExpandingToolResults(messages)

    #expect(expanded.count == 1)
    #expect(expanded[0].role == .assistant)
}

@MainActor
@Test func resumeAfterAskUserReplacesPendingResult() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiChatKitAskUser-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let service = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    let conversationID = service.createConversation(title: "Ask User")
    let assistantID = UUID()
    let toolCallID = "call-ask-user"

    service.append(
        LumiChatMessage(
            id: assistantID,
            conversationID: conversationID,
            role: .assistant,
            content: "Need your input",
            toolCalls: [
                LumiToolCall(
                    id: toolCallID,
                    name: "ask_user",
                    arguments: "{\"question\":\"Continue?\"}",
                    result: LumiToolResult(
                        content: """
                        \(LumiAskUserMarkers.pendingPrefix)
                        {"toolCallId":"\(toolCallID)","question":"Continue?","options":["Yes","No"],"allowFreeInput":false,"conversationId":"\(conversationID.uuidString)"}
                        """
                    )
                )
            ]
        )
    )

    await service.resumeAfterAskUser(conversationID: conversationID, toolCallID: toolCallID, answer: "Yes")

    let toolResult = service.messages(for: conversationID)
        .first(where: { $0.id == assistantID })?
        .toolCalls?
        .first(where: { $0.id == toolCallID })?
        .result

    #expect(toolResult?.content == "Yes")
    #expect(LumiAskUserMarkers.isPendingResponse(toolResult?.content ?? "") == false)
}
