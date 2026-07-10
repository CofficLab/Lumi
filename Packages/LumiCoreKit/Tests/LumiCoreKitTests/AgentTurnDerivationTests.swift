import Foundation
import LumiCoreKit
import Testing

@Suite("AgentTurnDerivation")
struct AgentTurnDerivationTests {
    private let conversationId = UUID()

    @Test("pending user message allows dequeue when idle")
    func dequeueWhenIdle() {
        let messages = [
            AgentChatMessage(role: .user, conversationId: conversationId, content: "hi", queueStatus: .pending),
        ]
        #expect(AgentTurnDerivation.shouldDequeueNextTurn(messages: messages, phase: .idle))
    }

    @Test("does not dequeue while processing")
    func noDequeueWhenBusy() {
        let messages = [
            AgentChatMessage(role: .user, conversationId: conversationId, content: "hi", queueStatus: .pending),
        ]
        #expect(!AgentTurnDerivation.shouldDequeueNextTurn(messages: messages, phase: .processing))
    }

    @Test("assistant error ends turn as failed")
    func assistantErrorIsFailedTurn() {
        let messages = [
            AgentChatMessage(role: .user, conversationId: conversationId, content: "hi"),
            AgentChatMessage(role: .assistant, conversationId: conversationId, content: "503", isError: true),
        ]
        #expect(AgentTurnDerivation.turnEndReason(messages: messages) == .failed("503"))
        #expect(AgentTurnDerivation.isTurnComplete(messages: messages))
    }

    @Test("successful assistant without tools completes turn")
    func assistantCompletesTurn() {
        let messages = [
            AgentChatMessage(role: .user, conversationId: conversationId, content: "hi"),
            AgentChatMessage(role: .assistant, conversationId: conversationId, content: "done"),
        ]
        #expect(AgentTurnDerivation.turnEndReason(messages: messages) == .completed)
    }

    @Test("assistant with pending tool calls is not complete")
    func assistantWithToolsIsIncomplete() {
        let messages = [
            AgentChatMessage(role: .user, conversationId: conversationId, content: "hi"),
            AgentChatMessage(
                role: .assistant,
                conversationId: conversationId,
                content: "",
                toolCalls: [AgentChatToolCall(id: "1", name: "read", arguments: "{}")]
            ),
        ]
        #expect(AgentTurnDerivation.turnEndReason(messages: messages) == nil)
        #expect(AgentTurnDerivation.shouldExecuteTools(messages: messages, phase: .processing))
    }
}

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

    @Test("agent turn lifecycle posts structured notifications")
    @MainActor
    func agentTurnLifecycleNotifications() async {
        let conversationID = UUID()
        var finishedReason: LumiTurnEndReason?
        var completedFired = false

        let finishedObserver = NotificationCenter.default.addObserver(
            forName: .lumiTurnFinished,
            object: nil,
            queue: .main
        ) { notification in
            finishedReason = LumiTurnEndReason(notificationUserInfo: notification.userInfo)
        }
        let completedObserver = NotificationCenter.default.addObserver(
            forName: .lumiTurnCompleted,
            object: nil,
            queue: .main
        ) { _ in
            completedFired = true
        }
        defer {
            NotificationCenter.default.removeObserver(finishedObserver)
            NotificationCenter.default.removeObserver(completedObserver)
        }

        AgentTurnLifecycle.postTurnFinished(conversationID: conversationID, reason: .failed("503"))
        await Task.yield()
        #expect(finishedReason == .failed)
        #expect(completedFired == false)

        completedFired = false
        AgentTurnLifecycle.postTurnFinished(conversationID: conversationID, reason: .completed)
        await Task.yield()
        #expect(finishedReason == .completed)
        #expect(completedFired == true)
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

@Suite("AgentChatMessage.isEmptyResponse")
struct AgentChatMessageIsEmptyResponseTests {
    private let conversationId = UUID()

    @Test("normal text is not empty")
    func normalTextIsNotEmpty() {
        let msg = AgentChatMessage(role: .assistant, conversationId: conversationId, content: "Hello")
        #expect(!msg.isEmptyResponse)
    }

    @Test("empty string is empty")
    func emptyStringIsEmpty() {
        let msg = AgentChatMessage(role: .assistant, conversationId: conversationId, content: "")
        #expect(msg.isEmptyResponse)
    }

    @Test("with toolCall is not empty")
    func withToolCallIsNotEmpty() {
        let msg = AgentChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: "",
            toolCalls: [AgentChatToolCall(id: "1", name: "read", arguments: "{}")]
        )
        #expect(!msg.isEmptyResponse)
    }

    @Test("error message is not empty")
    func errorMessageIsNotEmpty() {
        let msg = AgentChatMessage(role: .assistant, conversationId: conversationId, content: "", isError: true)
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

@Suite("AgentTurnDerivation empty response")
struct AgentTurnDerivationEmptyResponseTests {
    private let conversationId = UUID()

    @Test("empty assistant without toolCall is failed")
    func emptyAssistantIsFailed() {
        let messages = [
            AgentChatMessage(role: .user, conversationId: conversationId, content: "hi"),
            AgentChatMessage(role: .assistant, conversationId: conversationId, content: ""),
        ]
        #expect(AgentTurnDerivation.turnEndReason(messages: messages) == .failed(""))
    }

    @Test("non-empty assistant completes")
    func nonEmptyAssistantCompletes() {
        let messages = [
            AgentChatMessage(role: .user, conversationId: conversationId, content: "hi"),
            AgentChatMessage(role: .assistant, conversationId: conversationId, content: "done"),
        ]
        #expect(AgentTurnDerivation.turnEndReason(messages: messages) == .completed)
    }
}
