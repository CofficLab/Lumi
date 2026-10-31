import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderConversation
import ProviderDeveloperMode
import ProviderMessage
import ProviderMessageRendering
import ProviderToolManager
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// error 消息 header 上「重试」按钮的可重试判定。
///
/// 该按钮是失败回合唯一的用户侧重试入口：判定一旦恒为 false，用户点击就完全
/// 没有反应（`retryTurn` 被 `guard` 挡掉），而且不会报任何错，极难被发现。
/// 这里把判定从 View 抽成纯函数后直接覆盖，锁住各条分支。
@MainActor
private final class StubRendererCapability: MessageRendererCapability {
    var retryableTurnIDs: Set<UUID> = []
    private(set) var retryRequests: [(turnID: UUID, conversationID: UUID)] = []

    func toolCallResult(
        for toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult? {
        nil
    }

    func resendMessage(content: String, conversationID: UUID) async {}

    func canRetryTurn(turnID: UUID, conversationID: UUID) -> Bool {
        retryableTurnIDs.contains(turnID)
    }

    func retryTurn(turnID: UUID, conversationID: UUID) async {
        retryRequests.append((turnID, conversationID))
    }

    func toolCallRenderer(for toolCall: ToolCall) -> (any ToolCallRowRenderer)? { nil }

    func makeToolJobActivityModel(
        toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) -> ToolJobActivityModel {
        ToolJobActivityModel(
            manager: nil,
            toolCallID: toolCallID,
            conversationID: conversationID,
            turnID: turnID
        )
    }

    var isDeveloperModeEnabled: Bool { false }

    func addDeveloperModeObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle {
        NoopDeveloperModeProvidingObserverHandle()
    }
}

private func errorMessage(
    conversationID: UUID = UUID(),
    turnID: UUID?,
    content: String = "Request failed."
) -> Message {
    Message(
        conversationID: conversationID,
        role: .error,
        content: content,
        turnID: turnID,
        isError: true
    )
}

@Suite("RetryTurnButton 可重试判定")
@MainActor
struct RetryTurnButtonTests {
    @Test("失败回合仍在当前回合上时可重试")
    func retryableWhenTurnMatches() throws {
        let turnID = UUID()
        let capability = StubRendererCapability()
        capability.retryableTurnIDs = [turnID]

        let message = errorMessage(turnID: turnID)
        #expect(RetryTurnButton.retryableTurnID(message: message, capability: capability) == turnID)
    }

    @Test("回合已被新回合取代后不可重试")
    func notRetryableAfterTurnSuperseded() throws {
        let staleTurnID = UUID()
        let capability = StubRendererCapability()
        // capability 只承认新回合，旧失败回合不在集合中。
        capability.retryableTurnIDs = [UUID()]

        let message = errorMessage(turnID: staleTurnID)
        #expect(RetryTurnButton.retryableTurnID(message: message, capability: capability) == nil)
    }

    @Test("消息缺少 turnID 时不可重试")
    func notRetryableWithoutTurnID() {
        let capability = StubRendererCapability()
        let message = errorMessage(turnID: nil)

        #expect(RetryTurnButton.retryableTurnID(message: message, capability: capability) == nil)
    }

    @Test("没有 capability 时不可重试（插件未装配 AgentLoop）")
    func notRetryableWithoutCapability() {
        let message = errorMessage(turnID: UUID())

        #expect(RetryTurnButton.retryableTurnID(message: message, capability: nil) == nil)
    }

    @Test("重试请求携带触发消息的回合 ID 与会话 ID")
    func retryRequestCarriesTurnAndConversation() async throws {
        let turnID = UUID()
        let conversationID = UUID()
        let capability = StubRendererCapability()
        capability.retryableTurnIDs = [turnID]

        let message = errorMessage(conversationID: conversationID, turnID: turnID)
        let resolved = try #require(
            RetryTurnButton.retryableTurnID(message: message, capability: capability)
        )
        await capability.retryTurn(turnID: resolved, conversationID: message.conversationID)

        #expect(capability.retryRequests.count == 1)
        #expect(capability.retryRequests.first?.turnID == turnID)
        #expect(capability.retryRequests.first?.conversationID == conversationID)
    }

    @Test("不可重试的消息不应发出任何重试请求")
    func noRetryRequestWhenNotRetryable() async throws {
        let capability = StubRendererCapability()
        let message = errorMessage(turnID: UUID())

        // 复刻 RetryTurnButton.retry() 的 guard：不可重试时直接 return。
        guard let turnID = RetryTurnButton.retryableTurnID(message: message, capability: capability) else {
            #expect(capability.retryRequests.isEmpty)
            return
        }
        Issue.record("不可重试的消息不应解析出回合 ID：\(turnID.uuidString)")
    }
}