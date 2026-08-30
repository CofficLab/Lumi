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

    @Test("状态变化会发送语义事件，并支持取消监听")
    func stateChangesNotifyObservers() {
        let provider = DefaultChatSectionProviding()
        var events: [String] = []
        let handle = provider.addObserver { event in
            switch event {
            case .itemsChanged: events.append("items")
            case .barItemsChanged: events.append("bars")
            case .rootWrappersChanged: events.append("wrappers")
            case .visibilityChanged: events.append("visibility")
            case .contextActiveChanged: events.append("context")
            case .activeContextChanged: events.append("active-context")
            case .headerVisibilityChanged: events.append("header")
            }
        }

        provider.addItems([ChatSectionItem(id: "item") { Text("Item") }])
        provider.addBarItems([ChatSectionBarItem(id: "bar", placement: .header) { Text("Bar") }])
        provider.addRootWrappers([ChatSectionRootWrapper(id: "wrapper") { $0 }])
        provider.setVisible(false)
        provider.setContextActive(true)
        provider.setActiveContext(ChatContext(id: "plugin.story", title: "Story"))
        provider.setHeaderVisible(false)

        #expect(events == ["items", "bars", "wrappers", "visibility", "context", "active-context", "header"])

        handle.cancel()
        provider.setVisible(true)
        #expect(events == ["items", "bars", "wrappers", "visibility", "context", "active-context", "header"])
    }

    @Test("贡献作用域只匹配当前聊天上下文")
    func contributionScopeMatchesContext() {
        let context = ChatContext(id: "plugin.story", title: "Story")

        #expect(ChatSectionScope.global.matches(nil))
        #expect(ChatSectionScope.global.matches(context))
        #expect(ChatSectionScope.context(context.id).matches(context))
        #expect(!ChatSectionScope.context(context.id).matches(nil))
        #expect(!ChatSectionScope.context(context.id).matches(ChatContext.defaultChat))
    }

    @Test("可切换当前聊天上下文")
    func activeContextCanChange() {
        let provider = DefaultChatSectionProviding()
        let context = ChatContext(id: "plugin.story", title: "Story")

        provider.setActiveContext(context)

        #expect(provider.activeContext == context)
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

    @Test("首次激活使用推荐宽度，拖拽后按插件 ID 恢复")
    func widthProfileRestoresSavedWidth() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderChatSectionTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("chat-section-width.plist")
        defer { try? FileManager.default.removeItem(at: directory) }

        let recommended = ChatSectionWidth(minWidth: 280, idealWidth: 360, maxWidth: 520)
        let firstProvider = DefaultChatSectionProviding(
            widthStore: FileChatSectionWidthStore(fileURL: fileURL)
        )

        firstProvider.activateWidthProfile(ownerID: "plugin.resume", recommended: recommended)
        #expect(firstProvider.chatSectionWidth.idealWidth == 360)

        firstProvider.saveCurrentWidth(440)
        let secondProvider = DefaultChatSectionProviding(
            widthStore: FileChatSectionWidthStore(fileURL: fileURL)
        )
        secondProvider.activateWidthProfile(ownerID: "plugin.resume", recommended: recommended)

        #expect(secondProvider.chatSectionWidth.idealWidth == 440)
    }

    @Test("没有磁盘值时使用推荐宽度，保存值超出新范围时被限制")
    func widthProfileUsesRecommendationAndClampsRestoredValue() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderChatSectionTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("chat-section-width.plist")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileChatSectionWidthStore(fileURL: fileURL)
        let provider = DefaultChatSectionProviding(widthStore: store)
        let recommended = ChatSectionWidth(minWidth: 280, idealWidth: 360, maxWidth: 520)

        provider.activateWidthProfile(ownerID: "plugin.new", recommended: recommended)
        #expect(provider.chatSectionWidth.idealWidth == 360)

        provider.saveCurrentWidth(500)
        let reloaded = DefaultChatSectionProviding(
            widthStore: FileChatSectionWidthStore(fileURL: fileURL)
        )
        reloaded.activateWidthProfile(
            ownerID: "plugin.new",
            recommended: ChatSectionWidth(minWidth: 300, idealWidth: 340, maxWidth: 400)
        )

        #expect(reloaded.chatSectionWidth.idealWidth == 400)
    }

    @Test("旧插件释放宽度时不会覆盖新插件")
    func staleDeactivationDoesNotResetCurrentProfile() {
        let provider = DefaultChatSectionProviding()
        provider.activateWidthProfile(
            ownerID: "plugin.first",
            recommended: ChatSectionWidth(minWidth: 280, idealWidth: 320, maxWidth: 440)
        )
        provider.activateWidthProfile(
            ownerID: "plugin.second",
            recommended: ChatSectionWidth(minWidth: 300, idealWidth: 380, maxWidth: 520)
        )

        provider.deactivateWidthProfile(ownerID: "plugin.first")

        #expect(provider.chatSectionWidth.idealWidth == 380)
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
    @Published var conversations: [ConversationSummary] = []
    @Published var selectedConversationID: UUID?

    var currentTitle: String { "Mock" }
    var dataDirectory: URL { URL(fileURLWithPath: "/tmp/mock-conversations") }
    var globalVerbosity: ResponseVerbosity = .standard
    var globalReasoningEffort: ReasoningEffort?
    var globalAutomationLevel: AutomationLevel = .chat
    var globalLanguage: ConversationLanguage = .chinese

    func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID { UUID() }
    func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?, parentConversationID: UUID?) throws -> UUID { UUID() }
    func selectConversation(id: UUID) { selectedConversationID = id }
    func deselectConversation() { selectedConversationID = nil }
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { true }
    func markConversationActive(id: UUID, messageDate: Date) {}
    func isSending(for conversationID: UUID?) -> Bool { false }
    func addSelectedConversationObserver(_ callback: @escaping (UUID?) -> Void) -> any SelectedConversationObserverHandle {
        NoopSelectedConversationObserverHandle()
    }
    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
    func setGlobalVerbosity(_ verbosity: ResponseVerbosity) { globalVerbosity = verbosity }
    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {}
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { globalVerbosity }
    func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?) { globalReasoningEffort = reasoningEffort }
    func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort { globalReasoningEffort ?? .high }
    func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? { globalReasoningEffort }
    func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?) { globalReasoningEffort = reasoningEffort }
    func clearReasoningEffort(for conversationID: UUID?) { globalReasoningEffort = nil }
    func setGlobalAutomationLevel(_ automationLevel: AutomationLevel) { globalAutomationLevel = automationLevel }
    func automationLevel(for conversationID: UUID?) -> AutomationLevel { globalAutomationLevel }
    func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?) {}
    func setGlobalLanguage(_ language: ConversationLanguage) { globalLanguage = language }
    func language(for conversationID: UUID?) -> ConversationLanguage { globalLanguage }
    func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {}
}
