import Testing
import SwiftUI
import KernelCore
import ProviderActivityBar
@testable import PluginActivityBar

/// PluginActivityBar 单元测试。
///
/// 覆盖点：
/// - 自定义 provider 替换默认实现后，`kernel.resolveProvider` 拿到的是本插件实现；
/// - 在 `onReady` 阶段注入的 builtin 入口会被保留；
/// - 业务插件继续 `addItems` 时，builtin 入口不会被覆盖。
@Suite("PluginActivityBar")
@MainActor
struct PluginActivityBarTests {

    // MARK: - ActivityBarProvider

    @Test("ActivityBarProvider 暴露 items 并按 order 排序")
    func customProviderStoresItems() {
        let provider = ActivityBarProvider()
        provider.registerItems([
            ActivityBarItem(id: "b", title: "B", systemImage: "b", order: 200),
            ActivityBarItem(id: "a", title: "A", systemImage: "a", order: 100),
        ])

        #expect(provider.items.count == 2)
        #expect(provider.items.map(\.id) == ["a", "b"])
    }

    @Test("ActivityBarProvider.makeActivityBarView 返回 AnyView")
    func customProviderRendersView() {
        let provider = ActivityBarProvider()
        provider.registerItems([
            ActivityBarItem(id: "a", title: "A", systemImage: "folder"),
        ])

        #expect(type(of: provider.makeActivityBarView()) == AnyView.self)
    }

    @Test("ActivityBarProvider.activateItem 委托内部默认实现")
    func customProviderActivates() {
        let provider = ActivityBarProvider()
        provider.registerItems([
            ActivityBarItem(id: "a", title: "A", systemImage: "a"),
            ActivityBarItem(id: "b", title: "B", systemImage: "b"),
        ])

        provider.activateItem(id: "b")

        #expect(provider.activeItemID == "b")
    }

    @Test("bootstrapBuiltInItems 注入一条 builtin 入口")
    func bootstrapInjectsBuiltInItem() {
        let provider = ActivityBarProvider()
        provider.bootstrapBuiltInItems()

        #expect(provider.items.count == 1)
        #expect(provider.items.first?.id == "com.coffic.lumi.plugin.activity-bar.welcome")
    }

    // MARK: - PluginActivityBar

    @Test("PluginActivityBar.onBoot 替换默认 ActivityBarProviding")
    func pluginReplacesDefaultProvider() throws {
        let kernel = KernelCoreContainer()
        let defaultProvider = DefaultActivityBarProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, defaultProvider)

        let plugin = PluginActivityBar()
        try plugin.onBoot(kernel: kernel)

        let resolved = kernel.resolveProvider((any ActivityBarProviding).self)
        #expect(resolved is ActivityBarProvider)
        #expect(type(of: resolved) != DefaultActivityBarProviding.self)
    }

    @Test("PluginActivityBar.onBoot 之后 onReady 注入 builtin 入口")
    func pluginBootstrapsBuiltInItemsOnReady() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginActivityBar()
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        let resolved = kernel.resolveProvider((any ActivityBarProviding).self) as? ActivityBarProvider
        #expect(resolved?.items.contains(where: { $0.id == "com.coffic.lumi.plugin.activity-bar.welcome" }) == true)
    }

    @Test("onReady 之后，业务插件继续 addItems 不会覆盖 builtin 入口")
    func subsequentAddItemsPreservesBuiltIn() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginActivityBar()
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        guard let provider = kernel.resolveProvider((any ActivityBarProviding).self) else {
            Issue.record("ActivityBarProviding not resolved")
            return
        }

        provider.addItems([
            ActivityBarItem(id: "business.entry", title: "Business", systemImage: "briefcase", order: 200),
        ])

        #expect(provider.items.contains(where: { $0.id == "com.coffic.lumi.plugin.activity-bar.welcome" }))
        #expect(provider.items.contains(where: { $0.id == "business.entry" }))
        #expect(provider.items.count == 2)
    }

    // MARK: - 旧实例迁移

    @Test("ActivityBarProvider(preloadedItems:activeItemID:) 预填数据并保留激活态")
    func preloadedInitKeepsItemsAndActive() {
        let provider = ActivityBarProvider(
            preloadedItems: [
                ActivityBarItem(id: "x", title: "X", systemImage: "x", order: 100),
                ActivityBarItem(id: "y", title: "Y", systemImage: "y", order: 200),
            ],
            activeItemID: "y"
        )

        #expect(provider.items.count == 2)
        #expect(provider.items.map(\.id) == ["x", "y"])
        #expect(provider.activeItemID == "y")
    }

    @Test("ActivityBarProvider(preloadedItems:activeItemID:) 忽略未知 activeItemID")
    func preloadedInitIgnoresUnknownActive() {
        let provider = ActivityBarProvider(
            preloadedItems: [
                ActivityBarItem(id: "x", title: "X", systemImage: "x", order: 100),
            ],
            activeItemID: "missing"
        )

        #expect(provider.items.count == 1)
        #expect(provider.activeItemID == "x")
    }

    @Test("PluginActivityBar.onBoot 替换时不丢失旧实例已注册的 items")
    func pluginPreservesLegacyItemsOnReplace() throws {
        let kernel = KernelCoreContainer()
        let legacy = DefaultActivityBarProviding()
        legacy.addItems([
            ActivityBarItem(id: "legacy.chat", title: "Chat", systemImage: "bubble.left", order: 200),
            ActivityBarItem(id: "legacy.files", title: "Files", systemImage: "folder", order: 300),
        ])
        legacy.activateItem(id: "legacy.files")
        try kernel.registerProvider((any ActivityBarProviding).self, legacy)

        #expect(legacy.items.count == 2)

        let plugin = PluginActivityBar()
        try plugin.onBoot(kernel: kernel)

        let resolved = kernel.resolveProvider((any ActivityBarProviding).self)
        #expect(resolved is ActivityBarProvider)
        let custom = try #require(resolved as? ActivityBarProvider)
        #expect(custom.items.count == 2)
        #expect(Set(custom.items.map(\.id)) == ["legacy.chat", "legacy.files"])
        #expect(custom.activeItemID == "legacy.files")
    }

    @Test("PluginActivityBar.onBoot 之后，旧实例再被 addItems 不会回到新实例")
    func legacyInstanceIsDetachedAfterReplace() throws {
        let kernel = KernelCoreContainer()
        let legacy = DefaultActivityBarProviding()
        legacy.addItems([
            ActivityBarItem(id: "legacy.chat", title: "Chat", systemImage: "bubble.left", order: 200),
        ])
        try kernel.registerProvider((any ActivityBarProviding).self, legacy)

        let plugin = PluginActivityBar()
        try plugin.onBoot(kernel: kernel)

        legacy.addItems([
            ActivityBarItem(id: "legacy.late", title: "Late", systemImage: "l", order: 400),
        ])

        let custom = try #require(kernel.resolveProvider((any ActivityBarProviding).self) as? ActivityBarProvider)
        #expect(custom.items.map(\.id) == ["legacy.chat"])
        #expect(!custom.items.contains(where: { $0.id == "legacy.late" }))
    }

    @Test("PluginActivityBar.onBoot + onReady 全部路径后，迁移数据 + builtin 入口都存在")
    func migrationPlusBootstrapCoexist() throws {
        let kernel = KernelCoreContainer()
        let legacy = DefaultActivityBarProviding()
        legacy.addItems([
            ActivityBarItem(id: "legacy.chat", title: "Chat", systemImage: "bubble.left", order: 200),
        ])
        try kernel.registerProvider((any ActivityBarProviding).self, legacy)

        let plugin = PluginActivityBar()
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        let custom = try #require(kernel.resolveProvider((any ActivityBarProviding).self) as? ActivityBarProvider)
        #expect(custom.items.contains(where: { $0.id == "legacy.chat" }))
        #expect(custom.items.contains(where: { $0.id == "com.coffic.lumi.plugin.activity-bar.welcome" }))
    }
}
