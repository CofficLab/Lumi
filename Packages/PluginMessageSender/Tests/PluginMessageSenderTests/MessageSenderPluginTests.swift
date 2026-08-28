import Foundation
import KernelCore
import ProviderLifecycleHooks
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginMessageSender

@Suite("PluginMessageSender")
@MainActor
struct MessageSenderPluginTests {

    @Test("onBoot 解析基础 Provider 并注册自带 MessageSender 实现")
    func pluginRegistersMessageSendingProvider() throws {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages)
        let agentLoop = StubAgentLoop(messages: messages)
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)

        // 走真实装配路径：`start(plugins:)` 会设置 activePluginID，
        // 使 `registerProvider` 记录 provider 归属（ownedByPlugin）。
        let plugin = MessageSenderPlugin()
        try kernel.start(plugins: [plugin])

        let sender = kernel.resolveProvider((any MessageSendingProviding).self)
        #expect(sender != nil)
        // 注册的是插件自带的实现，而不是 ProviderMessageSender 的 DefaultMessageSender。
        #expect(sender is MessageSender)
        // 注册的实例归属于本插件，可被插件管理卸载/撤回
        #expect(kernel.isProvider((any MessageSendingProviding).self, ownedByPlugin: plugin.id))
    }

    @Test("缺依赖时 onBoot 不抛错且不注册（no-op 降级）")
    func pluginNoOpsWithoutDependencies() throws {
        let kernel = KernelCoreContainer()

        let plugin = MessageSenderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(kernel.resolveProvider((any MessageSendingProviding).self) == nil)
    }

    @Test("注册后可通过 sendMessage 走完整发送链路")
    func registeredSenderSendsMessage() async throws {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages)
        let agentLoop = StubAgentLoop(messages: messages)
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)

        let plugin = MessageSenderPlugin()
        try plugin.onBoot(kernel: kernel)

        let messageObserver = messages.addMessageInsertedObserver { message, conversationID in
            guard message.role == .user else { return }
            Task { @MainActor in
                let outcome = (try? await agentLoop.runTurn(in: conversationID)) ?? .cancelled
                agentLoop.notify(.completed(
                    conversationID: conversationID,
                    turnID: agentLoop.currentTurnID(for: conversationID) ?? UUID()
                ))
                _ = outcome
            }
        }
        defer { messageObserver.cancel() }

        let sender = try #require(kernel.resolveProvider((any MessageSendingProviding).self))
        try await sender.sendMessage("hello", conversationID: nil)
        let id = try #require(conversations.selectedConversationID)
        #expect(messages.messages(for: id).map(\.content) == ["hello", "response"])
        #expect(sender.isSending == false)
    }
}

/// 测试用 AgentLoop 桩：最小实现，直接返回预设内容。
@MainActor
private final class StubAgentLoop: AgentLoopProviding {
    private let messages: any MessageManaging
    private var observers: [UUID: (AgentLoopEvent) -> Void] = [:]
    var responseContent: String = "response"

    init(messages: any MessageManaging) {
        self.messages = messages
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

    func notify(_ event: AgentLoopEvent) {
        for callback in observers.values { callback(event) }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        messages.insertMessage(
            Message(conversationID: conversationID, role: .assistant, content: responseContent),
            to: conversationID
        )
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
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}
