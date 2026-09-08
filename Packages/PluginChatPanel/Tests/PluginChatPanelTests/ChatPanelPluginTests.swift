import Foundation
import KernelCore
import PluginChatPanel
import ProviderActivityBar
import ProviderChatSection
import ProviderRootView
import ProviderRailView
import ProviderStorage
import SwiftUI
import Testing

@Suite("ChatPanelPlugin")
@MainActor
struct ChatPanelPluginTests {

    @Test("激活 Chat 时隐藏 RootView 内容，切换入口时恢复")
    func chatActivationTogglesRootContentVisibility() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rootView = DefaultRootViewProvider()
        let railView = DefaultRailViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(rootView.isContentViewHidden)
        #expect(chat.isVisible)
        #expect(railView.visibleCategories == [.chat, .fileTree])

        let otherEntryID = "test.other.entry"
        activityBar.addItems([ActivityBarItem(
            id: otherEntryID,
            title: "Other",
            systemImage: "square"
        )])
        activityBar.activateItem(id: otherEntryID)

        #expect(!rootView.isContentViewHidden)
        #expect(!chat.isVisible)
        #expect(railView.visibleCategories == Set(RailViewCategory.allCases))

        activityBar.activateItem(id: plugin.id + ".entry")
        #expect(rootView.isContentViewHidden)
        #expect(railView.visibleCategories == [.chat, .fileTree])
        try plugin.onShutdown(kernel: kernel)

        #expect(!rootView.isContentViewHidden)
        #expect(!chat.isVisible)
        #expect(railView.visibleCategories == Set(RailViewCategory.allCases))
    }

    @Test("Chat 激活时恢复上次保存的 Rail active tab")
    func chatRestoresLastActiveRailTab() throws {
        let storageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatPanelPluginTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storageRoot) }

        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rootView = DefaultRootViewProvider()
        let railView = DefaultRailViewProviding()
        let storage = DefaultStorageProvider(dataRootDirectory: storageRoot)
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)
        try kernel.registerProvider((any StorageProviding).self, storage)

        // Register two chat-category tabs so we can switch between them.
        railView.registerTabs([
            RailTabItem(id: "chat.tab-a", category: .chat, title: "A", systemImage: "a.circle") { AnyView(EmptyView()) },
            RailTabItem(id: "chat.tab-b", category: .chat, title: "B", systemImage: "b.circle") { AnyView(EmptyView()) },
        ])

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)

        // Initial boot: reconcileActiveTab picks the first visible tab.
        #expect(railView.activeTabID == "chat.tab-a")

        // Simulate user switching to tab B.
        railView.activateTab(id: "chat.tab-b")
        #expect(railView.activeTabID == "chat.tab-b")

        // Switch away from Chat, then back.
        let otherEntryID = "test.other.entry"
        activityBar.addItems([ActivityBarItem(
            id: otherEntryID, title: "Other", systemImage: "square"
        )])
        activityBar.activateItem(id: otherEntryID)
        // After re-activation, tab B should be restored.
        activityBar.activateItem(id: plugin.id + ".entry")
        #expect(railView.activeTabID == "chat.tab-b")

        try plugin.onShutdown(kernel: kernel)
    }

    @Test("Chat 在 tab 延迟注册后仍恢复保存的 Rail active tab")
    func chatRestoresTabRegisteredAfterReady() throws {
        let storageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatPanelPluginDelayedRestoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storageRoot) }

        func registerProviders(
            in kernel: KernelCoreContainer,
            activityBar: DefaultActivityBarProviding,
            chat: DefaultChatSectionProviding,
            rootView: DefaultRootViewProvider,
            railView: DefaultRailViewProviding,
            storage: DefaultStorageProvider
        ) throws {
            try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
            try kernel.registerProvider((any ChatSectionProviding).self, chat)
            try kernel.registerProvider((any RootViewProviding).self, rootView)
            try kernel.registerProvider((any RailViewProviding).self, railView)
            try kernel.registerProvider((any StorageProviding).self, storage)
        }

        let firstKernel = KernelCoreContainer()
        let firstActivityBar = DefaultActivityBarProviding()
        let firstChat = DefaultChatSectionProviding()
        let firstRootView = DefaultRootViewProvider()
        let firstRailView = DefaultRailViewProviding()
        let storage = DefaultStorageProvider(dataRootDirectory: storageRoot)
        try registerProviders(
            in: firstKernel,
            activityBar: firstActivityBar,
            chat: firstChat,
            rootView: firstRootView,
            railView: firstRailView,
            storage: storage
        )

        firstRailView.registerTabs([
            RailTabItem(id: "chat.tab-a", category: .chat, title: "A", systemImage: "a.circle") { AnyView(EmptyView()) },
            RailTabItem(id: "chat.tab-b", category: .chat, title: "B", systemImage: "b.circle") { AnyView(EmptyView()) },
        ])
        let firstPlugin = ChatPanelPlugin()
        try firstPlugin.onBoot(kernel: firstKernel)
        firstRailView.activateTab(id: "chat.tab-b")
        try firstPlugin.onShutdown(kernel: firstKernel)

        let secondKernel = KernelCoreContainer()
        let secondActivityBar = DefaultActivityBarProviding()
        let secondChat = DefaultChatSectionProviding()
        let secondRootView = DefaultRootViewProvider()
        let secondRailView = DefaultRailViewProviding()
        try registerProviders(
            in: secondKernel,
            activityBar: secondActivityBar,
            chat: secondChat,
            rootView: secondRootView,
            railView: secondRailView,
            storage: DefaultStorageProvider(dataRootDirectory: storageRoot)
        )

        let secondPlugin = ChatPanelPlugin()
        try secondPlugin.onBoot(kernel: secondKernel)
        try secondPlugin.onReady(kernel: secondKernel)

        // 模拟真实启动：ConversationListPlugin 在 ChatPanel onReady 之后才动态注入 tab。
        secondRailView.registerTabs([
            RailTabItem(id: "chat.tab-a", category: .chat, title: "A", systemImage: "a.circle") { AnyView(EmptyView()) },
        ])
        #expect(secondRailView.activeTabID == "chat.tab-a")

        secondRailView.registerTabs([
            RailTabItem(id: "chat.tab-a", category: .chat, title: "A", systemImage: "a.circle") { AnyView(EmptyView()) },
            RailTabItem(id: "chat.tab-b", category: .chat, title: "B", systemImage: "b.circle") { AnyView(EmptyView()) },
        ])

        #expect(secondRailView.activeTabID == "chat.tab-b")
        try secondPlugin.onShutdown(kernel: secondKernel)
    }
}
