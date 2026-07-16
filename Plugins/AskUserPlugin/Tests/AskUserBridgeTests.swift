import Foundation
import LumiCoreKit
import Testing
@testable import AskUserPlugin

// MARK: - Resume Notification Tests
//
// AskUserBridge.resume(...) 通过 NotificationCenter 发送 `.lumiAskUserDidAnswer`
// 通知，由 ChatService 监听并恢复 Agent 循环。这里验证通知的 userInfo 携带的字段
// 与调用方传入的参数一致。

@Suite(.serialized) @MainActor struct AskUserBridgeResumeTests {

    @Test func resumePostsAskUserDidAnswerNotification() async throws {
        // Given
        let conversationId = UUID().uuidString
        let toolCallId = "call-resume-1"
        let answer = "Yes"

        let received = NotificationExpectation()
        let observer = NotificationCenter.default.addObserver(
            forName: .lumiAskUserDidAnswer,
            object: nil,
            queue: .main
        ) { notification in
            received.userInfo = notification.userInfo
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // When
        AskUserBridge.shared.resume(conversationId: conversationId, toolCallId: toolCallId, answer: answer)

        // 通知在主队列异步派发，等待一拍
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then
        let userInfo = try #require(received.userInfo)
        #expect(userInfo[LumiAskUserNotification.conversationIDKey] as? String == conversationId)
        #expect(userInfo[LumiAskUserNotification.toolCallIDKey] as? String == toolCallId)
        #expect(userInfo[LumiAskUserNotification.answerKey] as? String == answer)
    }

    @Test func resumePropagatesArbitraryAnswerText() async throws {
        // 自由文本回答（含中文/特殊字符）应原样进入通知
        let answer = "我觉得是「方案 B」，对吧？"
        let received = NotificationExpectation()
        let observer = NotificationCenter.default.addObserver(
            forName: .lumiAskUserDidAnswer,
            object: nil,
            queue: .main
        ) { notification in
            received.userInfo = notification.userInfo
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        AskUserBridge.shared.resume(
            conversationId: UUID().uuidString,
            toolCallId: "call-free",
            answer: answer
        )
        try await Task.sleep(nanoseconds: 100_000_000)

        let userInfo = try #require(received.userInfo)
        #expect(userInfo[LumiAskUserNotification.answerKey] as? String == answer)
    }
}

// MARK: - Shared Instance Tests

@Suite @MainActor struct AskUserBridgeSharedInstanceTests {

    @Test func sharedInstanceExists() {
        // Given & When & Then
        // AskUserBridge.shared 是非可选值，这里只断言它能被取到，避免 `!= nil` 警告。
        _ = AskUserBridge.shared
    }

    @Test func sharedInstanceIsSameObject() {
        // Given
        let bridge1 = AskUserBridge.shared
        let bridge2 = AskUserBridge.shared

        // Then
        #expect(bridge1 === bridge2)
    }
}

// MARK: - Helpers

/// 捕获一次通知 userInfo 的轻量辅助类型。
@MainActor
private final class NotificationExpectation {
    var userInfo: [AnyHashable: Any]?
}
