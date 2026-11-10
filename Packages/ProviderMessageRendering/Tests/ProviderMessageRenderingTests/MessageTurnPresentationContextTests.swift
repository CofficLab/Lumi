import Foundation
import SwiftUI
import Testing
@testable import ProviderMessageRendering

/// `MessageTurnPresentationContext` 的传递契约测试。
///
/// 关键约束：V1–V3 不传 context（默认 nil），因此行为完全不变；
/// V4 传入时必须无损地把 turn 身份、轮尾标记与复制文本送到渲染层。
@Suite("MessageTurnPresentationContext 环境传递")
struct MessageTurnPresentationContextTests {

    @Test("环境默认值是 nil context 与 false hover")
    func defaultsAreNilAndNotHovered() {
        let values = EnvironmentValues()

        #expect(values.messageTurnPresentation == nil)
        #expect(values.messageTurnIsHovered == false)
    }

    @Test("环境能无损传递 context 的全部字段")
    func environmentPassesEveryFieldLosslessly() {
        let agentTurnID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let context = MessageTurnPresentationContext(
            turnKey: "turn:11111111-2222-3333-4444-555555555555",
            agentTurnID: agentTurnID,
            isTailAssistantText: true,
            isRunning: false,
            assistantCopyText: "第一段\n\n第二段",
            completedAt: completedAt
        )

        var values = EnvironmentValues()
        values.messageTurnPresentation = context
        values.messageTurnIsHovered = true

        let received = values.messageTurnPresentation
        #expect(received == context)
        #expect(received?.turnKey == "turn:11111111-2222-3333-4444-555555555555")
        #expect(received?.agentTurnID == agentTurnID)
        #expect(received?.isTailAssistantText == true)
        #expect(received?.isRunning == false)
        #expect(received?.assistantCopyText == "第一段\n\n第二段")
        #expect(received?.completedAt == completedAt)
        #expect(values.messageTurnIsHovered == true)
    }

    @Test("未设置 context 时读取结果仍是 nil")
    func unsetContextReadsBackAsNil() {
        var values = EnvironmentValues()
        values.messageTurnIsHovered = true

        #expect(values.messageTurnPresentation == nil)
    }

    @Test("hover 可以独立于 context 被设置")
    func hoverIsIndependentFromContext() {
        var values = EnvironmentValues()
        values.messageTurnIsHovered = true

        #expect(values.messageTurnIsHovered == true)
        #expect(values.messageTurnPresentation == nil)
    }

    @Test("context 的相等性只由字段决定")
    func equalityIsFieldBased() {
        let base = MessageTurnPresentationContext(
            turnKey: "message:1",
            agentTurnID: nil,
            isTailAssistantText: false,
            isRunning: true,
            assistantCopyText: "",
            completedAt: nil
        )
        let same = MessageTurnPresentationContext(
            turnKey: "message:1",
            agentTurnID: nil,
            isTailAssistantText: false,
            isRunning: true,
            assistantCopyText: "",
            completedAt: nil
        )
        let different = MessageTurnPresentationContext(
            turnKey: "message:2",
            agentTurnID: nil,
            isTailAssistantText: false,
            isRunning: true,
            assistantCopyText: "",
            completedAt: nil
        )

        #expect(base == same)
        #expect(base != different)
    }

    @Test("context 能通过 EnvironmentValues 往返而不被裁剪")
    func contextRoundTripsThroughEnvironmentValues() {
        let context = MessageTurnPresentationContext(
            turnKey: "message:abc",
            agentTurnID: nil,
            isTailAssistantText: true,
            isRunning: false,
            assistantCopyText: "hello",
            completedAt: nil
        )

        var values = EnvironmentValues()
        values.messageTurnPresentation = context
        values.messageTurnIsHovered = true

        // 模拟一次「读取 → 重新注入」的往返，字段不允许丢失。
        var reInjected = EnvironmentValues()
        reInjected.messageTurnPresentation = values.messageTurnPresentation
        reInjected.messageTurnIsHovered = values.messageTurnIsHovered

        #expect(reInjected.messageTurnPresentation == context)
        #expect(reInjected.messageTurnPresentation?.assistantCopyText == "hello")
        #expect(reInjected.messageTurnIsHovered == true)
    }
}
