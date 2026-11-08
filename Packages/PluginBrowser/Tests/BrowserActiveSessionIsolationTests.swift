import Foundation
import Testing
@testable import BrowserPlugin

/// Regression coverage for issue #928: a background conversation running a
/// read-only browser tool must not take over the Browser workspace that the
/// user is looking at.
@Suite("Browser 活动会话隔离")
@MainActor
struct BrowserActiveSessionIsolationTests {

    @Test("后台会话的只读工具不会切换当前 Browser 会话")
    func readOnlyToolsDoNotHijackActiveConversation() async throws {
        let manager = BrowserSessionManager()
        let selected = UUID()
        let background = UUID()
        manager.selectConversation(selected)
        _ = manager.session(for: background)

        _ = try? await manager.read(conversationID: background, maxCharacters: 500)
        #expect(manager.activeConversationID == selected, "browser_read 切换了活动会话")
        #expect(manager.activeSession == nil)

        _ = try? await manager.snapshot(interactiveOnly: false, conversationID: background)
        #expect(manager.activeConversationID == selected, "browser_snapshot 切换了活动会话")

        _ = try? await manager.findElements(
            role: nil,
            name: nil,
            text: nil,
            limit: 5,
            conversationID: background
        )
        #expect(manager.activeConversationID == selected, "browser_find 切换了活动会话")

        _ = try? await manager.evaluate(script: "document.title", conversationID: background)
        #expect(manager.activeConversationID == selected, "browser_evaluate 切换了活动会话")

        _ = try? await manager.screenshot(fullPage: false, conversationID: background)
        #expect(manager.activeConversationID == selected, "browser_screenshot 切换了活动会话")
    }

    @Test("用户显式选择会话仍然会切换 Browser 工作区")
    func explicitSelectionStillSwitchesActiveConversation() {
        let manager = BrowserSessionManager()
        let second = UUID()
        _ = manager.session(for: second)

        manager.selectConversation(second)

        #expect(manager.activeConversationID == second)
        #expect(manager.activeSession?.conversationID == second)
    }
}
