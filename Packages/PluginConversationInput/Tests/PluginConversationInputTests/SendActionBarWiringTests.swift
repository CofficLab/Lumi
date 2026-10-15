import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderConversationInput
import ProviderConversationState
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationInput

@MainActor
@Suite("SendActionBarWiring")
struct SendActionBarWiringTests {
    /// 复刻 `ConversationInputPlugin.onBoot` 中决定 Action Bar 装配的判定。
    ///
    /// 该判定一旦写错，用户会看到「Provider 缺失」红点却其实能力齐备，
    /// 或者反之：能力缺失却渲染出一个永远点不动的发送按钮。
    @Test("四个 Provider 齐备时创建发送栏 ViewModel")
    func allProvidersPresentCreatesViewModel() throws {
        let (capability, missing) = makeCapability(includeInput: true, includeSender: true, includeConversations: true, includeState: true)

        #expect(missing.isEmpty)
        #expect(SendActionBarViewModel(capability: capability) != nil)
    }

    @Test("缺少发送器时不创建发送栏 ViewModel")
    func missingSenderDisablesViewModel() throws {
        let (capability, missing) = makeCapability(includeInput: true, includeSender: false, includeConversations: true, includeState: true)

        #expect(!missing.isEmpty)
        #expect(!Self.createsActionBarViewModel(
            includeInput: true,
            includeSender: false,
            includeConversations: true,
            includeState: true
        ))
    }

    @Test("缺少会话状态时不创建发送栏 ViewModel")
    func missingConversationStateDisablesViewModel() throws {
        #expect(!Self.createsActionBarViewModel(includeInput: true, includeSender: true, includeConversations: true, includeState: false))
    }

    @Test("缺少输入能力时不创建发送栏 ViewModel")
    func missingInputDisablesViewModel() throws {
        #expect(!Self.createsActionBarViewModel(includeInput: false, includeSender: true, includeConversations: true, includeState: true))
    }

    @Test("缺少会话管理时不创建发送栏 ViewModel")
    func missingConversationManagingDisablesViewModel() throws {
        #expect(!Self.createsActionBarViewModel(includeInput: true, includeSender: true, includeConversations: false, includeState: true))
    }

    // MARK: - Support

    /// 与 `ConversationInputPlugin.onBoot` 中同一条件的镜像。
    private static func createsActionBarViewModel(
        includeInput: Bool,
        includeSender: Bool,
        includeConversations: Bool,
        includeState: Bool
    ) -> Bool {
        includeInput && includeSender && includeConversations && includeState
    }

    private func makeCapability(
        includeInput: Bool,
        includeSender: Bool,
        includeConversations: Bool,
        includeState: Bool
    ) -> (ConversationInputCapabilityAdapter, [String]) {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let capability = ConversationInputCapabilityAdapter(
            input: includeInput ? DefaultConversationInputProvider() : nil,
            sender: includeSender
                ? DefaultMessageSender(
                    conversations: conversations,
                    messages: messages,
                    agentLoop: WiringTestAgentLoop()
                )
                : nil,
            conversations: includeConversations ? conversations : nil,
            conversationState: includeState ? WiringTestConversationState() : nil,
            metrics: nil
        )

        var missing: [String] = []
        if !includeInput { missing.append("ConversationInputProviding") }
        if !includeSender { missing.append("MessageSendingProviding") }
        if !includeConversations { missing.append("ConversationManaging") }
        if !includeState { missing.append("ConversationStateProviding") }
        return (capability, missing)
    }
}

@MainActor
private final class WiringTestAgentLoop: AgentLoopProviding {
    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        WiringTestAgentLoopHandle()
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }
    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome { .completed }
    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func isAutoReplySuppressed(for conversationID: UUID) -> Bool { false }
    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}
    func retryTurn(
        in conversationID: UUID,
        after failedTurnID: UUID
    ) async throws -> AgentLoopOutcome { .completed }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class WiringTestAgentLoopHandle: AgentLoopObserverHandle {
    func cancel() {}
}

/// 始终报告空闲的会话状态源。
@MainActor
private final class WiringTestConversationState: ConversationStateProviding {
    func state(for conversationID: UUID) -> ConversationStateSnapshot {
        ConversationStateSnapshot(conversationID: conversationID)
    }

    var states: [UUID: ConversationStateSnapshot] { [:] }
}
