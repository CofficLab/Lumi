import Foundation
import Testing
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import ProviderAgentLoop
import ProviderLifecycleHooks
@testable import PluginConversationNew

/// 「在新对话中开始」建议卡片的附件隔离回归（**#591**）。
///
/// 卡片只应发送工具参数里自包含的 task 文本。隐式 `sendMessage(_:conversationID:)`
/// 会快照全局挂起附件池，把当前对话输入框里未发送的图片/文件带进新对话的首条
/// 消息并清空输入框，附件可能落到另一个项目/模型上下文。适配器必须走显式空附件入口。
@Suite("NewChatStartingAdapter（#591）")
@MainActor
struct NewChatStartingAttachmentTests {
    @Test("startIn 只发送 task 文本，不带走当前输入框未发送的附件（**回归 #591**）")
    func startInDoesNotConsumeUnsentComposerAttachments() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        let sourceID = try conversations.createConversation(title: "A", projectPath: nil, providerID: nil, modelName: nil)
        conversations.selectConversation(id: sourceID)
        let targetID = try conversations.createConversation(title: "B", projectPath: nil, providerID: nil, modelName: nil)

        // 用户在 A 的输入框里挂了附件但还没发送。
        let image = UserImageAttachment(
            mimeType: "image/png",
            base64Data: Data("unsent-image".utf8).base64EncodedString(),
            fileName: "unsent.png"
        )
        let file = UserFileAttachment(fileName: "unsent.txt", mimeType: "text/plain", textContent: "未发送")
        sender.addImageAttachment(image)
        sender.addFileAttachment(file)

        let adapter = NewChatStartingAdapter(sender: sender)
        await adapter.startIn(conversationID: targetID, content: "Do an unrelated task here")

        let firstMessage = try #require(
            messages.messages(for: targetID).first { $0.role == .user && $0.content == "Do an unrelated task here" }
        )
        #expect(
            UserAttachmentMetadata.decodeImageAttachments(from: firstMessage.metadata).isEmpty,
            "新对话首条消息不得带走输入框里未发送的图片附件"
        )
        #expect(
            UserAttachmentMetadata.decodeFileAttachments(from: firstMessage.metadata).isEmpty,
            "新对话首条消息不得带走输入框里未发送的文件附件"
        )
        #expect(sender.pendingImageAttachments.map(\.id) == [image.id], "未发送的图片附件应原样留在输入框")
        #expect(sender.pendingFileAttachments.map(\.id) == [file.id], "未发送的文件附件应原样留在输入框")
    }
}

/// 测试用 AgentLoop 桩：落库 user 消息后通知回合完成，不跑真实模型。
@MainActor
private final class StubAgentLoop: AgentLoopProviding {
    private var observers: [UUID: (AgentLoopEvent) -> Void] = [:]
    private var messageObserver: (any MessageInsertedObserverHandle)?

    init(messages: any MessageManaging) {
        messageObserver = messages.addMessageInsertedObserver { [weak self] message, conversationID in
            guard message.role == .user else { return }
            Task { @MainActor in
                _ = try? await self?.runTurn(in: conversationID)
            }
        }
    }

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        let id = UUID()
        observers[id] = callback
        return StubAgentLoopObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        let event = AgentLoopEvent.completed(conversationID: conversationID, turnID: UUID())
        for observer in observers.values {
            observer(event)
        }
        return .completed
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        throw AgentLoopError.invalidResumeRequest
    }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class StubAgentLoopObserverHandle: AgentLoopObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: @escaping () -> Void) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}