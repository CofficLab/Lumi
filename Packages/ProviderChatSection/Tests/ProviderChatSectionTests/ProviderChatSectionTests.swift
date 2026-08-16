import Combine
import Foundation
import ProviderConversation
import SwiftUI
import Testing
@testable import ProviderChatSection

@Suite("ProviderChatSection")
@MainActor
struct ProviderChatSectionTests {
    @Test("贡献按 order 排序并支持替换")
    func itemsAreSortedAndReplaced() {
        let provider = DefaultChatSectionProviding()
        provider.addItems([
            ChatSectionItem(id: "b", order: 20) { Text("B") },
            ChatSectionItem(id: "a", order: 10) { Text("A") },
        ])
        #expect(provider.items.map(\.id) == ["a", "b"])

        provider.addItems([ChatSectionItem(id: "a", order: 30) { Text("A2") }])
        #expect(provider.items.map(\.id) == ["b", "a"])
    }

    @Test("Bar contribution 按 order 排序")
    func barItemsAreSorted() {
        let provider = DefaultChatSectionProviding()
        provider.addBarItems([
            ChatSectionBarItem(id: "b", order: 2, placement: .actionTrailing) { Text("B") },
            ChatSectionBarItem(id: "a", order: 1, placement: .header) { Text("A") },
        ])
        #expect(provider.barItems.map(\.id) == ["a", "b"])
    }

    @Test("显隐和会话上下文状态可独立切换")
    func visibilityAndContextState() {
        let provider = DefaultChatSectionProviding()
        provider.setVisible(false)
        provider.setContextActive(true)
        #expect(provider.isVisible == false)
        #expect(provider.isContextActive == true)
        #expect(type(of: provider.makeChatSectionView()) == AnyView.self)
    }

    @Test("root wrapper 按 order 排序、替换与移除")
    func rootWrappersAreSortedReplacedAndRemoved() {
        let provider = DefaultChatSectionProviding()
        let id = AnyView(Text("id"))
        let inner = AnyView(Text("inner"))
        provider.addRootWrappers([
            ChatSectionRootWrapper(id: "b", order: 20) { _ in id },
            ChatSectionRootWrapper(id: "a", order: 10) { _ in inner },
        ])
        #expect(provider.rootWrappers.map(\.id) == ["a", "b"])

        // 同 id 替换
        provider.addRootWrappers([ChatSectionRootWrapper(id: "a", order: 30) { _ in id }])
        #expect(provider.rootWrappers.map(\.id) == ["b", "a"])

        provider.removeRootWrapper(id: "b")
        #expect(provider.rootWrappers.map(\.id) == ["a"])
    }

    @Test("header 可见性独立于容器激活状态")
    func headerVisibilityIsIndependent() {
        let provider = DefaultChatSectionProviding()
        #expect(provider.isHeaderVisible == true)

        provider.setContextActive(true)
        provider.setHeaderVisible(false)
        #expect(provider.isContextActive == true)
        #expect(provider.isHeaderVisible == false)

        provider.setHeaderVisible(true)
        #expect(provider.isHeaderVisible == true)
    }

    @Test("绑定会话选择后 header 可见性跟随选中状态")
    func bindingConversationSelectionTracksSelectedID() async throws {
        let provider = DefaultChatSectionProviding()
        let conversations = MockConversationManaging()
        conversations.selectedConversationID = UUID()

        provider.bindConversationSelection(conversations)
        #expect(provider.isHeaderVisible == true)

        // 取消选择 → objectWillChange → sink（main runloop）→ isHeaderVisible = false
        conversations.deselectConversation()
        await waitForMainRunloop()
        #expect(provider.isHeaderVisible == false)

        // 重新选择 → 恢复显示
        conversations.selectConversation(id: UUID())
        await waitForMainRunloop()
        #expect(provider.isHeaderVisible == true)
    }

    private func waitForMainRunloop() async {
        // Combine sink 通过 receive(on: .main) 异步投递，让出若干次主线程执行机会。
        for _ in 0..<5 {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

/// 最小 `ConversationManaging` 实现：仅测试需要的选中状态，其余返回默认值。
@MainActor
private final class MockConversationManaging: ConversationManaging {
    @Published var conversations: [LumiConversationSummary] = []
    @Published var selectedConversationID: UUID?

    var currentTitle: String { "Mock" }
    var dataDirectory: URL { URL(fileURLWithPath: "/tmp/mock-conversations") }
    var globalVerbosity: LumiResponseVerbosity = .standard
    var globalReasoningEffort: LumiReasoningEffort?
    var globalAutomationLevel: LumiAutomationLevel = .chat
    var globalLanguage: LumiConversationLanguage = .chinese

    func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID { UUID() }
    func selectConversation(id: UUID) { selectedConversationID = id }
    func deselectConversation() { selectedConversationID = nil }
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { true }
    func markConversationActive(id: UUID, messageDate: Date) {}
    func isSending(for conversationID: UUID?) -> Bool { false }
    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
    func setGlobalVerbosity(_ verbosity: LumiResponseVerbosity) { globalVerbosity = verbosity }
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { globalVerbosity }
    func setGlobalReasoningEffort(_ reasoningEffort: LumiReasoningEffort?) { globalReasoningEffort = reasoningEffort }
    func reasoningEffort(for conversationID: UUID?) -> LumiReasoningEffort { globalReasoningEffort ?? .high }
    func reasoningEffortOptional(for conversationID: UUID?) -> LumiReasoningEffort? { globalReasoningEffort }
    func setReasoningEffort(_ reasoningEffort: LumiReasoningEffort, for conversationID: UUID?) { globalReasoningEffort = reasoningEffort }
    func clearReasoningEffort(for conversationID: UUID?) { globalReasoningEffort = nil }
    func setGlobalAutomationLevel(_ automationLevel: LumiAutomationLevel) { globalAutomationLevel = automationLevel }
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { globalAutomationLevel }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
    func setGlobalLanguage(_ language: LumiConversationLanguage) { globalLanguage = language }
    func language(for conversationID: UUID?) -> LumiConversationLanguage { globalLanguage }
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
}
