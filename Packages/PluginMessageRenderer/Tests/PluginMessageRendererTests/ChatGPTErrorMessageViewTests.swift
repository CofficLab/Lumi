import Foundation
import ProviderMessage
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// V5（ChatGPT）内联错误呈现规格测试。
///
/// 基准是 V5 方案第 2.6 节：
/// - 错误内联显示在对应 turn；
/// - 只在**真实可重试**的失败回合上提供重试；
/// - 成功回复绝不出现重试。
@Suite("V5 内联错误规格")
@MainActor
struct ChatGPTErrorMessageViewTests {

    private func failedMessage(turnID: UUID?) -> Message {
        Message(
            conversationID: UUID(),
            role: .error,
            content: "请求失败",
            turnID: turnID,
            isError: true
        )
    }

    @Test("真实可重试的失败回合提供重试")
    func realFailedTurnCanRetry() {
        let turnID = UUID()
        let capability = ChatGPTAssistantStubCapability(retryableTurnIDs: [turnID])
        let message = failedMessage(turnID: turnID)

        #expect(ChatGPTErrorStyle.retryableTurnID(message: message, capability: capability) == turnID)
    }

    @Test("回合已失效时不提供重试")
    func staleTurnCannotRetry() {
        let turnID = UUID()
        let capability = ChatGPTAssistantStubCapability(retryableTurnIDs: [])
        let message = failedMessage(turnID: turnID)

        #expect(ChatGPTErrorStyle.retryableTurnID(message: message, capability: capability) == nil)
    }

    @Test("没有 turnID 时不提供重试")
    func missingTurnIDCannotRetry() {
        let capability = ChatGPTAssistantStubCapability(retryableTurnIDs: [])
        let message = failedMessage(turnID: nil)

        #expect(ChatGPTErrorStyle.retryableTurnID(message: message, capability: capability) == nil)
    }

    @Test("没有 capability 时不提供重试")
    func missingCapabilityCannotRetry() {
        let turnID = UUID()
        let message = failedMessage(turnID: turnID)

        #expect(ChatGPTErrorStyle.retryableTurnID(message: message, capability: nil) == nil)
    }

    @Test("几何符合 V5 token")
    func metrics() {
        #expect(ChatGPTErrorStyle.cornerRadius == 10)
        #expect(ChatGPTErrorStyle.contentPadding == 10)
        #expect(ChatGPTErrorStyle.contentSpacing == 6)
    }
}
