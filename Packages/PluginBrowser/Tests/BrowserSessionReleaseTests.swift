import Foundation
import ProviderConversation
import Testing
@testable import BrowserPlugin

/// Regression coverage for issue #929: deleting a conversation must release its
/// BrowserSession/WKWebView instead of keeping them alive until plugin shutdown.
@Suite("Browser 会话释放")
@MainActor
struct BrowserSessionReleaseTests {

    @Test("删除会话后释放对应 BrowserSession")
    func deletedConversationReleasesBrowserSession() {
        let manager = BrowserSessionManager()
        let conversationID = UUID()
        weak var weakSession = manager.session(for: conversationID)
        #expect(weakSession != nil)

        manager.handleConversationEvent(.deleted(conversationID))

        #expect(weakSession == nil, "删除会话后 BrowserSession 仍被强引用")
        #expect(!manager.hasSession(for: conversationID), "删除会话后仍保留其浏览器实例")
    }

    @Test("删除当前活动会话会清空活动状态")
    func deletingActiveConversationClearsActiveState() {
        let manager = BrowserSessionManager()
        let conversationID = UUID()
        _ = manager.session(for: conversationID)
        manager.selectConversation(conversationID)
        #expect(manager.activeSession != nil)

        manager.closeSession(for: conversationID)

        #expect(manager.activeConversationID == nil)
        #expect(manager.activeSession == nil)
        #expect(!manager.hasSession(for: conversationID))
    }

    @Test("删除其它会话不影响当前活动的 Browser 会话")
    func deletingOtherConversationKeepsActiveSession() {
        let manager = BrowserSessionManager()
        let active = UUID()
        let background = UUID()
        _ = manager.session(for: active)
        _ = manager.session(for: background)
        manager.selectConversation(active)

        manager.closeSession(for: background)

        #expect(manager.activeConversationID == active)
        #expect(manager.activeSession?.conversationID == active)
        #expect(manager.hasSession(for: active))
        #expect(!manager.hasSession(for: background))
    }

    @Test("非删除类会话事件不会释放 BrowserSession")
    func unrelatedConversationEventsKeepSession() {
        let manager = BrowserSessionManager()
        let conversationID = UUID()
        _ = manager.session(for: conversationID)

        manager.handleConversationEvent(.updated(conversationID))
        manager.handleConversationEvent(.listChanged)

        #expect(manager.hasSession(for: conversationID))
    }
}
