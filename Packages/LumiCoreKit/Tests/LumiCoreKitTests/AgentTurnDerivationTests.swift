import Foundation
import LumiCoreKit
import Testing

@Suite("LumiAgentTurnDerivation")
struct LumiAgentTurnDerivationTests {
    private let conversationId = UUID()

    @Test("provider error in current turn is failed")
    func providerErrorIsFailed() {
        let messages = [
            LumiChatMessage(conversationID: conversationId, role: .user, content: "hi"),
            LumiChatMessage(conversationID: conversationId, role: .error, content: "503", isError: true),
        ]
        #expect(LumiAgentTurnDerivation.turnEndReason(in: messages) == .failed)
    }

    @Test("detects update_task in current turn")
    func detectsUpdateTaskCall() {
        let messages = [
            LumiChatMessage(conversationID: conversationId, role: .user, content: "hi"),
            LumiChatMessage(
                conversationID: conversationId,
                role: .assistant,
                content: "",
                toolCalls: [LumiToolCall(id: "1", name: "update_task", arguments: "{}")]
            ),
        ]
        let turnMessages = LumiAgentTurnDerivation.turnMessagesSinceLastUser(in: messages)
        #expect(LumiAgentTurnDerivation.assistantCalledTool(named: "update_task", in: turnMessages))
        #expect(LumiAgentTurnDerivation.turnEndReason(in: messages) == nil)
    }

    @Test("failed turn does not allow automatic continuation")
    func failedTurnBlocksContinuation() {
        #expect(LumiTurnEndReason.failed.allowsAutomaticContinuation == false)
        #expect(LumiTurnEndReason.completed.allowsAutomaticContinuation == true)
    }

    @Test("LumiTurnEndReason reconstructs from notification userInfo")
    @MainActor
    func turnEndReasonRoundTripsThroughUserInfo() {
        // 订阅方（如 AgentTurnNotificationPlugin）依赖 `LumiTurnEndReason(notificationUserInfo:)`
        // 从 `.lumiTurnFinished` 的 userInfo 重建原因；这是 SendPipeline 作为唯一发送方
        // 时仍需保持的契约。
        for reason in [LumiTurnEndReason.completed, .failed, .userRejection,
                       .awaitingUserResponse, .cancelled] {
            let userInfo: [AnyHashable: Any] = [
                LumiMessageSavedNotification.conversationIDKey: UUID(),
                LumiTurnFinishedNotification.reasonKey: reason.rawValue,
            ]
            #expect(LumiTurnEndReason(notificationUserInfo: userInfo) == reason)
        }
        #expect(LumiTurnEndReason(notificationUserInfo: nil) == nil)
        #expect(LumiTurnEndReason(notificationUserInfo: [:]) == nil)
    }
}

// MARK: - isEmptyResponse Tests

@Suite("LumiChatMessage.isEmptyResponse")
struct LumiChatMessageIsEmptyResponseTests {
    private let conversationId = UUID()

    @Test("normal text message is not empty")
    func normalTextIsNotEmpty() {
        let msg = LumiChatMessage(conversationID: conversationId, role: .assistant, content: "Hello")
        #expect(!msg.isEmptyResponse)
    }

    @Test("empty string is empty")
    func emptyStringIsEmpty() {
        let msg = LumiChatMessage(conversationID: conversationId, role: .assistant, content: "")
        #expect(msg.isEmptyResponse)
    }

    @Test("whitespace-only is empty")
    func whitespaceOnlyIsEmpty() {
        let msg = LumiChatMessage(conversationID: conversationId, role: .assistant, content: "  \n  ")
        #expect(msg.isEmptyResponse)
    }

    @Test("with toolCall is not empty")
    func withToolCallIsNotEmpty() {
        let msg = LumiChatMessage(
            conversationID: conversationId,
            role: .assistant,
            content: "",
            toolCalls: [LumiToolCall(id: "1", name: "read", arguments: "{}")]
        )
        #expect(!msg.isEmptyResponse)
    }

    @Test("error message is not empty")
    func errorMessageIsNotEmpty() {
        let msg = LumiChatMessage(conversationID: conversationId, role: .error, content: "", isError: true)
        #expect(!msg.isEmptyResponse)
    }

    @Test("thinking-only without content is empty")
    func thinkingOnlyIsEmpty() {
        let msg = LumiChatMessage(
            conversationID: conversationId,
            role: .assistant,
            content: "",
            reasoningContent: "Let me think..."
        )
        #expect(msg.isEmptyResponse)
    }

    @Test("normal text with toolCall is not empty")
    func textWithToolCallIsNotEmpty() {
        let msg = LumiChatMessage(
            conversationID: conversationId,
            role: .assistant,
            content: "Let me check",
            toolCalls: [LumiToolCall(id: "1", name: "read", arguments: "{}")]
        )
        #expect(!msg.isEmptyResponse)
    }
}

// MARK: - Turn Derivation with Empty Response

@Suite("LumiAgentTurnDerivation empty response")
struct LumiAgentTurnDerivationEmptyResponseTests {
    private let conversationId = UUID()

    @Test("empty assistant without toolCall is failed")
    func emptyAssistantIsFailed() {
        let messages = [
            LumiChatMessage(conversationID: conversationId, role: .user, content: "hi"),
            LumiChatMessage(conversationID: conversationId, role: .assistant, content: ""),
        ]
        #expect(LumiAgentTurnDerivation.turnEndReason(in: messages) == .failed)
    }

    @Test("whitespace-only assistant is failed")
    func whitespaceOnlyAssistantIsFailed() {
        let messages = [
            LumiChatMessage(conversationID: conversationId, role: .user, content: "hi"),
            LumiChatMessage(conversationID: conversationId, role: .assistant, content: "  \n  "),
        ]
        #expect(LumiAgentTurnDerivation.turnEndReason(in: messages) == .failed)
    }

    @Test("non-empty assistant completes")
    func nonEmptyAssistantCompletes() {
        let messages = [
            LumiChatMessage(conversationID: conversationId, role: .user, content: "hi"),
            LumiChatMessage(conversationID: conversationId, role: .assistant, content: "done"),
        ]
        #expect(LumiAgentTurnDerivation.turnEndReason(in: messages) == .completed)
    }

    @Test("assistant with toolCall is incomplete")
    func assistantWithToolCallIsIncomplete() {
        let messages = [
            LumiChatMessage(conversationID: conversationId, role: .user, content: "hi"),
            LumiChatMessage(
                conversationID: conversationId,
                role: .assistant,
                content: "",
                toolCalls: [LumiToolCall(id: "1", name: "read", arguments: "{}")]
            ),
        ]
        #expect(LumiAgentTurnDerivation.turnEndReason(in: messages) == nil)
    }
}

