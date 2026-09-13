import KernelCore
import ProviderToolbar
import SwiftUI
import Testing
@testable import PluginToolbar

/// PluginToolbar 单元测试。
///
/// 覆盖点：
/// - `ToolbarProvider` 的 items / 分类过滤 / 观察事件语义；
/// - `PluginToolbar.onBoot` 替换默认实现且不丢失旧实例贡献。
@Suite("PluginToolbar")
@MainActor
struct PluginToolbarTests {

    // MARK: - ToolbarProvider

    @Test("ToolbarProvider 注入 items 后可读取")
    func providerStoresInjectedItems() {
        let provider = ToolbarProvider()

        provider.registerToolbarItems([
            ToolbarItem(id: "a", title: "A", placement: .leading) { Text("A") },
            ToolbarItem(id: "b", title: "B", placement: .trailing) { Text("B") },
        ])

        #expect(provider.toolbarItems.map(\.id) == ["a", "b"])
    }

    @Test("追加工具栏项按 order 从小到大排列且同 id 去重")
    func appendedItemsAreSortedAndDeduplicated() {
        let provider = ToolbarProvider()
        provider.registerToolbarItems([
            ToolbarItem(id: "settings", title: "Settings", order: 300) { Text("Settings") },
        ])

        provider.addToolbarItems([
            ToolbarItem(id: "conversation-list", title: "Chats", order: 200) { Text("Chats") },
            ToolbarItem(id: "new-chat", title: "New Chat", order: 30) { Text("New Chat") },
            ToolbarItem(id: "settings", title: "Settings", order: 1) { Text("Duplicate") },
        ])

        #expect(provider.toolbarItems.map(\.id) == ["new-chat", "conversation-list", "settings"])
    }

    @Test("按 id 撤回工具栏项")
    func removesItemsByID() {
        let provider = ToolbarProvider()
        provider.registerToolbarItems([
            ToolbarItem(id: "a", title: "A") { Text("A") },
            ToolbarItem(id: "b", title: "B") { Text("B") },
        ])

        provider.removeToolbarItems(ids: ["a"])

        #expect(provider.toolbarItems.map(\.id) == ["b"])
    }

    @Test("工具栏状态变化会发布类型化观察事件")
    func changesAreObservable() {
        let provider = ToolbarProvider()
        var events: [String] = []
        let handle = provider.addToolbarObserver { event in
            switch event {
            case .toolbarItemsChanged:
                events.append("items")
            case .visibleCategoriesChanged:
                events.append("categories")
            }
        }

        provider.registerToolbarItems([
            ToolbarItem(id: "global", title: "Global") { Text("Global") }
        ])
        provider.setVisibleCategories([.global])
        provider.setVisibleCategories([])

        #expect(events == ["items", "categories", "categories"])

        handle.cancel()
        provider.registerToolbarItems([])
        #expect(events == ["items", "categories", "categories"])
    }

    @Test("按可见分类过滤工具栏项")
    func filtersItemsByVisibleCategories() {
        let provider = ToolbarProvider()
        provider.registerToolbarItems([
            ToolbarItem(id: "global", title: "Global", category: .global) { Text("Global") },
            ToolbarItem(id: "project", title: "Project", category: .project) { Text("Project") },
            ToolbarItem(id: "chat", title: "Chat", category: .chat) { Text("Chat") },
        ])

        provider.setVisibleCategories([.global, .project])

        #expect(provider.visibleToolbarItems.map(\.id) == ["global", "project"])
        #expect(provider.toolbarItems.count == 3)
    }

    @Test("临时隐藏分类叠加在基础分类之上，多来源取并集")
    func hiddenCategoriesOverlayBaseCategories() {
        let provider = ToolbarProvider()
        provider.setVisibleCategories([.global, .chat, .project, .system])

        provider.setHiddenCategories([.project], for: "empty-state")
        #expect(provider.visibleCategories == [.global, .chat, .system])

        provider.setHiddenCategories([.system], for: "another-feature")
        #expect(provider.visibleCategories == [.global, .chat])

        // 清除一个来源后，仅该来源请求的隐藏分类恢复；其他来源仍然生效。
        provider.setHiddenCategories([], for: "empty-state")
        #expect(provider.visibleCategories == [.global, .chat, .project])
        // 基础分类被后续修改时，仍会扣除其他来源尚未清除的隐藏请求。
        provider.setVisibleCategories([.global, .project])
        #expect(provider.visibleCategories == [.global, .project])
    }

    @Test("注入 items 后返回可渲染的工具栏视图")
    func rendersToolbarView() {
        let provider = ToolbarProvider()
        provider.registerToolbarItems([
            ToolbarItem(id: "a", title: "A", placement: .leading) { Text("A") },
        ])

        #expect(type(of: provider.makeToolbarView()) == AnyView.self)
    }

    @Test("可作为 any ToolbarProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any ToolbarProviding = ToolbarProvider()
        provider.registerToolbarItems([
            ToolbarItem(id: "x", title: "X") { Text("X") },
        ])

        #expect(provider.toolbarItems.count == 1)
        #expect(type(of: provider.makeToolbarView()) == AnyView.self)
    }

    @Test("预填旧实现的数据并保留可见分类")
    func preloadedInitKeepsItemsAndCategories() {
        let provider = ToolbarProvider(
            preloadedItems: [
                ToolbarItem(id: "b", title: "B", order: 200) { Text("B") },
                ToolbarItem(id: "a", title: "A", order: 100) { Text("A") },
            ],
            visibleCategories: [.global, .chat]
        )

        #expect(provider.toolbarItems.map(\.id) == ["a", "b"])
        #expect(provider.visibleCategories == [.global, .chat])
    }

    // MARK: - PluginToolbar

    @Test("PluginToolbar.onBoot 替换默认 ToolbarProviding")
    func pluginReplacesDefaultProvider() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ToolbarProviding).self, DefaultToolbarProviding())

        let plugin = PluginToolbar()
        try plugin.onBoot(kernel: kernel)

        let resolved = kernel.resolveProvider((any ToolbarProviding).self)
        #expect(resolved is ToolbarProvider)
        #expect(plugin.metadata.policy == .alwaysOn)
    }

    @Test("替换时不丢失旧实现已注册的 items 与可见分类")
    func pluginPreservesLegacyContributions() throws {
        let kernel = KernelCoreContainer()
        let legacy = DefaultToolbarProviding()
        legacy.addToolbarItems([
            ToolbarItem(id: "settings", title: "Settings", order: 300) { Text("Settings") },
            ToolbarItem(id: "projects", title: "Projects", category: .project, order: 100) { Text("Projects") },
        ])
        legacy.setVisibleCategories([.global])
        try kernel.registerProvider((any ToolbarProviding).self, legacy)

        let plugin = PluginToolbar()
        try plugin.onBoot(kernel: kernel)

        let custom = try #require(kernel.resolveProvider((any ToolbarProviding).self) as? ToolbarProvider)
        #expect(custom.toolbarItems.map(\.id) == ["projects", "settings"])
        #expect(custom.visibleCategories == [.global])
        #expect(custom.visibleToolbarItems.map(\.id) == ["settings"])
    }

    @Test("替换后旧实例再追加不会同步到新实例")
    func legacyInstanceIsDetachedAfterReplace() throws {
        let kernel = KernelCoreContainer()
        let legacy = DefaultToolbarProviding()
        legacy.addToolbarItems([
            ToolbarItem(id: "settings", title: "Settings") { Text("Settings") },
        ])
        try kernel.registerProvider((any ToolbarProviding).self, legacy)

        let plugin = PluginToolbar()
        try plugin.onBoot(kernel: kernel)

        legacy.addToolbarItems([
            ToolbarItem(id: "late", title: "Late") { Text("Late") },
        ])

        let custom = try #require(kernel.resolveProvider((any ToolbarProviding).self) as? ToolbarProvider)
        #expect(custom.toolbarItems.map(\.id) == ["settings"])
    }

    @Test("PluginToolbar.onShutdown 清空业务贡献并支持重新启动")
    func pluginClearsContributionsOnShutdown() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginToolbar()
        try kernel.registerPlugin(plugin)
        try plugin.onBoot(kernel: kernel)

        let custom = try #require(kernel.resolveProvider((any ToolbarProviding).self) as? ToolbarProvider)
        custom.addToolbarItems([
            ToolbarItem(id: "settings", title: "Settings") { Text("Settings") },
        ])

        try plugin.onShutdown(kernel: kernel)

        #expect(custom.toolbarItems.isEmpty)

        // Provider 由宿主持有：重新启动插件后仍可继续接收贡献。
        try plugin.onBoot(kernel: kernel)
        let restarted = try #require(kernel.resolveProvider((any ToolbarProviding).self) as? ToolbarProvider)
        #expect(restarted !== custom)
        restarted.addToolbarItems([
            ToolbarItem(id: "settings", title: "Settings") { Text("Settings") },
        ])
        #expect(restarted.toolbarItems.map(\.id) == ["settings"])
    }
}
