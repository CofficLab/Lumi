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
        let rootView = DefaultRootViewProviding()
        let railView = DefaultRailViewProviding()
        var railViewChanges = 0
        let rootObserver = rootView.addRootViewObserver { event in
            if case .railViewChanged = event {
                railViewChanges += 1
            }
        }
        defer { rootObserver.cancel() }
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(rootView.isContentViewHidden)
        #expect(chat.isVisible)
        #expect(railView.visibleCategories == [.chat, .fileTree])
        #expect(railViewChanges == 1)

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
        let rootView = DefaultRootViewProviding()
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

    @Test("Chat 激活时 Rail 视图已注入且可见")
    func chatActivationInjectsAndShowsRailView() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rootView = DefaultRootViewProviding()
        let railView = DefaultRailViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)

        // Rail 必须「可渲染」而不仅是可见：WorkbenchSplitView 的判据是
        // `railView != nil && isRailViewVisible`，两者缺一 Rail 都不出现。
        #expect(rootView.view(for: .rail) != nil)
        #expect(rootView.isRailViewVisible)
        try plugin.onShutdown(kernel: kernel)
    }

    /// 全新安装态：宿主 `bindRailViewVisibility` 用 `hasVisibleTabs == false`
    /// 覆盖 Chat 的可见性，Chat 必须把 Rail 拉回来。
    ///
    /// - Important: 这是真实启动顺序（`ViewFactory.makeMainView` 在
    ///   `kernel.start` 之后才执行绑定），也是最容易回归的一条——观察者
    ///   一旦漏掉 `.railViewVisibilityChanged(false)`，全新用户的 Chat 首屏
    ///   就会没有 Rail 栏，且不会报任何错。
    @Test("无任何可见 Rail tab 的全新安装态下，Chat 仍保持 Rail 可见")
    func chatKeepsRailVisibleWhenHostBindsWithoutVisibleTabs() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rootView = DefaultRootViewProviding()
        let railView = DefaultRailViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)

        // 对话列表 / 项目文件树尚未注册 tab，`hasVisibleTabs` 为 false。
        #expect(!railView.hasVisibleTabs)

        // 宿主视图工厂在插件启动后绑定 Rail 可见性。
        rootView.bindRailViewVisibility(to: railView)

        #expect(rootView.view(for: .rail) != nil)
        #expect(rootView.isRailViewVisible)
        try plugin.onShutdown(kernel: kernel)
    }

    /// 其它插件异步收敛 Rail tab 时也会写 `setRailViewVisible(hasVisibleTabs)`，
    /// Chat 激活期间必须能顶回。
    @Test("Chat 激活期间 Rail 可见类别被清空时仍保持 Rail 可见")
    func chatKeepsRailVisibleWhenVisibleCategoriesEmpty() throws {
        let storageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatPanelPluginRailVisibilityTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storageRoot) }

        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rootView = DefaultRootViewProviding()
        let railView = DefaultRailViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)
        try kernel.registerProvider(
            (any StorageProviding).self,
            DefaultStorageProvider(dataRootDirectory: storageRoot)
        )

        railView.registerTabs([
            RailTabItem(id: "chat.tab-a", category: .chat, title: "A", systemImage: "a.circle") { AnyView(EmptyView()) },
        ])

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)
        rootView.bindRailViewVisibility(to: railView)
        #expect(rootView.isRailViewVisible)

        // 某个插件把 Chat 可见类别全部过滤掉 → Rail 内容变空。
        railView.setVisibleCategories([])
        #expect(!railView.hasVisibleTabs)
        // Rail 栏本身必须仍在（内容区空白），否则 Chat 首屏布局整体左移。
        #expect(rootView.isRailViewVisible)
        #expect(rootView.view(for: .rail) != nil)

        try plugin.onShutdown(kernel: kernel)
    }

    /// 切走再切回 Chat：Rail 必须重新出现，不能停留在别的插件留下的隐藏态。
    @Test("切到其它入口再切回 Chat 时 Rail 恢复可见")
    func railRestoresWhenReactivatingChat() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rootView = DefaultRootViewProviding()
        let railView = DefaultRailViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)

        // 模拟一个「全屏插件」激活：清空 Rail 可见 tab 并隐藏 Rail。
        activityBar.addItems([ActivityBarItem(
            id: "test.other.entry", title: "Other", systemImage: "square"
        )])
        activityBar.activateItem(id: "test.other.entry")
        railView.setVisibleCategories([])
        #expect(!rootView.isRailViewVisible)

        activityBar.activateItem(id: plugin.id + ".entry")
        #expect(rootView.view(for: .rail) != nil)
        #expect(rootView.isRailViewVisible)
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
            rootView: DefaultRootViewProviding,
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
        let firstRootView = DefaultRootViewProviding()
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
        let secondRootView = DefaultRootViewProviding()
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
