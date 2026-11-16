import Foundation
import Testing
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import ProviderAgentLoop
@testable import PluginConversationNew

/// 建议卡片「在新对话中开始」的目标存在校验与失败收敛回归（**#185**）。
///
/// 用户删除工具创建的目标会话后，原会话的建议卡片仍可点击。修复前 `start()`
/// 不校验目标存在、`startIn` 用 `try?` 吞错并无条件 `phase = .opened`，会向已
/// 删除 ID 写入消息并启动不可见回合。修复后：点击先校验存在；缺失或发送失败
/// 则保留/恢复原选中态、不写不启动、返回失败。
@Suite("建议卡片目标存在校验（#185）")
@MainActor
struct NewConversationSuggestionCardTargetTests {
    private func makeSuggestion(_ id: UUID) -> NewConversationSuggestion {
        NewConversationSuggestion(conversationID: id, title: "B", starter: "Do an unrelated task here")
    }

    @Test("conversationExists 反映会话是否仍在列表（删除后为 false）")
    func conversationExistsReflectsDeletion() throws {
        let manager = DefaultConversationManager()
        let capability = NewChatCapabilityAdapter(conversations: manager)
        let id = try manager.createConversation(title: "B", projectPath: nil, providerID: nil, modelName: nil)
        #expect(capability.conversationExists(id: id))
        manager.deleteConversation(id: id)
        #expect(capability.conversationExists(id: id) == false, "已删除会话不得再被视为存在")
    }

    @Test("目标已删除时不切换不发送，返回失败（**回归 #185**）")
    func deletedTargetDoesNotSelectOrSend() async throws {
        let capability = MockNewChatCapability()
        let sourceID = UUID()
        let targetID = UUID()
        capability.existingConversationIDs = [sourceID]
        capability.restoreSelection(to: sourceID)
        let sender = StubStarting(result: true)

        let opened = await NewConversationSuggestionCard.performStart(
            suggestion: makeSuggestion(targetID),
            conversations: capability,
            sender: sender
        )

        #expect(opened == false)
        #expect(sender.calls.isEmpty, "不得向已删除目标发送消息")
        #expect(capability.selections.isEmpty, "不得切换到已删除目标")
        #expect(capability.selectedConversationID == sourceID, "必须保留当前会话")
    }

    @Test("发送失败时恢复原选中态并返回失败（**回归 #185**）")
    func sendFailureRestoresSelection() async throws {
        let capability = MockNewChatCapability()
        let sourceID = UUID()
        let targetID = UUID()
        capability.existingConversationIDs = [sourceID, targetID]
        capability.restoreSelection(to: sourceID)
        let sender = StubStarting(result: false)

        let opened = await NewConversationSuggestionCard.performStart(
            suggestion: makeSuggestion(targetID),
            conversations: capability,
            sender: sender
        )

        #expect(opened == false)
        #expect(sender.calls == [targetID])
        #expect(capability.selectedConversationID == sourceID, "发送失败必须恢复原选中态")
    }

    @Test("目标存在且发送成功时切换并返回成功")
    func successSelectsTargetAndReturnsTrue() async throws {
        let capability = MockNewChatCapability()
        let sourceID = UUID()
        let targetID = UUID()
        capability.existingConversationIDs = [sourceID, targetID]
        capability.restoreSelection(to: sourceID)
        let sender = StubStarting(result: true)

        let opened = await NewConversationSuggestionCard.performStart(
            suggestion: makeSuggestion(targetID),
            conversations: capability,
            sender: sender
        )

        #expect(opened == true)
        #expect(sender.calls == [targetID])
        #expect(capability.selectedConversationID == targetID)
    }

    @Test("startIn 发送成功返回 true，且走显式空附件入口")
    func startInReturnsTrueOnSuccess() async throws {
        let stub = RecordingSenderStub()
        let adapter = NewChatStartingAdapter(sender: stub)
        let targetID = UUID()

        let succeeded = await adapter.startIn(conversationID: targetID, content: "task")

        #expect(succeeded == true)
        let call = try #require(stub.explicitCalls.first)
        #expect(call.conversationID == targetID)
        #expect(call.imageAttachments.isEmpty)
        #expect(call.fileAttachments.isEmpty)
    }

    @Test("startIn 发送抛错时返回 false，不得吞错（**回归 #185**）")
    func startInReturnsFalseOnSendError() async throws {
        let stub = RecordingSenderStub()
        stub.shouldThrow = true
        let adapter = NewChatStartingAdapter(sender: stub)

        let succeeded = await adapter.startIn(conversationID: UUID(), content: "task")

        #expect(succeeded == false, "发送抛错必须上报失败，不得显示已打开")
    }

    @Test("startIn 发送器缺失时返回 false")
    func startInReturnsFalseWhenSenderMissing() async throws {
        let adapter = NewChatStartingAdapter(sender: nil)
        let succeeded = await adapter.startIn(conversationID: UUID(), content: "task")
        #expect(succeeded == false)
    }
}

// MARK: - 测试替身

/// 可配置成功/失败的 `NewChatStarting` 替身，记录发送目标。
@MainActor
private final class StubStarting: NewChatStarting {
    private let result: Bool
    private(set) var calls: [UUID] = []

    init(result: Bool) {
        self.result = result
    }

    @discardableResult
    func startIn(conversationID: UUID, content: String) async -> Bool {
        calls.append(conversationID)
        return result
    }
}

/// 最小 `MessageSendingProviding` 替身：显式发送重载可配置抛错，其余成员仅为满足协议。
@MainActor
private final class RecordingSenderStub: MessageSendingProviding {
    struct ExplicitCall: Equatable {
        let text: String
        let imageAttachments: [UserImageAttachment]
        let fileAttachments: [UserFileAttachment]
        let conversationID: UUID?
    }

    struct SendError: Error {}

    var shouldThrow = false
    private(set) var explicitCalls: [ExplicitCall] = []

    func sendMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws {
        explicitCalls.append(
            ExplicitCall(
                text: content,
                imageAttachments: imageAttachments,
                fileAttachments: fileAttachments,
                conversationID: conversationID
            )
        )
        if shouldThrow { throw SendError() }
    }

    // MARK: 未使用的协议成员

    var isSending: Bool { false }
    var pendingImageAttachments: [UserImageAttachment] { [] }
    var pendingFileAttachments: [UserFileAttachment] { [] }
    func addImageAttachment(_ attachment: UserImageAttachment) {}
    func removeImageAttachment(id: UUID) {}
    func clearImageAttachments() {}
    func addFileAttachment(_ attachment: UserFileAttachment) {}
    func removeFileAttachment(id: UUID) {}
    func clearFileAttachments() {}
    func addSendingStateObserver(_ callback: @escaping (Bool) -> Void) -> any SendingStateObserverHandle {
        NoopSendingStateHandle()
    }
    func pendingMessages(for conversationID: UUID) -> [PendingChatMessage] { [] }
    func cancelPendingMessage(id: UUID, in conversationID: UUID) {}
    func commitUserMessage(_ content: String, conversationID: UUID?) throws -> MessageSendCommit? { nil }
    func commitUserMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) throws -> MessageSendCommit? { nil }
    func commitUserMessageInBackground(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws -> MessageSendCommit? { nil }
    func startTurn(for commit: MessageSendCommit) async {}
    func sendMessage(_ content: String, conversationID: UUID?) async throws {}
    func cancelCurrentRequest() {}
    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        throw SendError()
    }
}

@MainActor
private final class NoopSendingStateHandle: SendingStateObserverHandle {
    func cancel() {}
}