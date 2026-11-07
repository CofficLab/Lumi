import SwiftUI
import Testing
@testable import ProviderToolbar

/// `setHiddenCategories(_:for:)` 的多来源叠加语义。
///
/// 多个来源（插件、工作区上下文）各自请求隐藏一批分类，最终可见分类是
/// 「基线集合减去所有来源隐藏集合的并集」。传空集合表示撤销该来源的请求。
@Suite("Toolbar 分类隐藏叠加")
@MainActor
struct ToolbarHiddenCategoryTests {

    private func item(
        _ id: String,
        category: ToolbarItemCategory = .global,
        ownerPluginID: String? = nil,
        order: Int = 200
    ) -> ProviderToolbar.ToolbarItem {
        ProviderToolbar.ToolbarItem(
            id: id,
            title: id,
            category: category,
            ownerPluginID: ownerPluginID,
            order: order
        ) { Text(id) }
    }

    @Test("单个来源的隐藏分类从可见集合中扣除")
    func singleSourceHidesCategories() {
        let provider = DefaultToolbarProviding()

        provider.setHiddenCategories([.chat, .project], for: "source-a")

        #expect(!provider.visibleCategories.contains(.chat))
        #expect(!provider.visibleCategories.contains(.project))
        #expect(provider.visibleCategories.contains(.editor))
    }

    @Test("多个来源的隐藏分类取并集")
    func multipleSourcesUnionTheirHiddenSets() {
        let provider = DefaultToolbarProviding()

        provider.setHiddenCategories([.chat], for: "source-a")
        provider.setHiddenCategories([.project], for: "source-b")

        #expect(!provider.visibleCategories.contains(.chat))
        #expect(!provider.visibleCategories.contains(.project))
        #expect(provider.visibleCategories.contains(.editor))
    }

    @Test("同一来源重复设置以最后一次为准")
    func sameSourceOverwritesPrevious() {
        let provider = DefaultToolbarProviding()

        provider.setHiddenCategories([.chat, .project], for: "source-a")
        provider.setHiddenCategories([.chat], for: "source-a")

        #expect(!provider.visibleCategories.contains(.chat))
        #expect(provider.visibleCategories.contains(.project))
    }

    @Test("传空集合撤销该来源的隐藏请求")
    func emptySetClearsSourceRequest() {
        let provider = DefaultToolbarProviding()
        provider.setHiddenCategories([.chat], for: "source-a")
        #expect(!provider.visibleCategories.contains(.chat))

        provider.setHiddenCategories([], for: "source-a")

        #expect(provider.visibleCategories.contains(.chat))
    }

    @Test("撤销一个来源不影响其他来源的隐藏")
    func clearingOneSourceKeepsOthers() {
        let provider = DefaultToolbarProviding()
        provider.setHiddenCategories([.chat], for: "source-a")
        provider.setHiddenCategories([.project], for: "source-b")

        provider.setHiddenCategories([], for: "source-a")

        #expect(provider.visibleCategories.contains(.chat))
        #expect(!provider.visibleCategories.contains(.project))
    }

    @Test("隐藏分类对可见项列表生效")
    func hiddenCategoriesFilterVisibleItems() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([
            item("chat-1", category: .chat),
            item("editor-1", category: .editor),
        ])
        #expect(provider.visibleToolbarItems.count == 2)

        provider.setHiddenCategories([.chat], for: "source-a")

        #expect(provider.visibleToolbarItems.map(\.id) == ["editor-1"])
    }

    @Test("隐藏分类变化发布 visibleCategoriesChanged 事件")
    func publishesCategoryChangeEvent() {
        let provider = DefaultToolbarProviding()
        var events: [String] = []
        let handle = provider.addToolbarObserver { event in
            switch event {
            case .toolbarItemsChanged: events.append("items")
            case .visibleCategoriesChanged: events.append("categories")
            }
        }

        provider.setHiddenCategories([.chat], for: "source-a")

        #expect(events == ["categories"])
        handle.cancel()
    }

    @Test("隐藏集合未实际变化时不发事件")
    func noEventWhenEffectiveSetUnchanged() {
        let provider = DefaultToolbarProviding()
        provider.setHiddenCategories([.chat], for: "source-a")
        var events = 0
        let handle = provider.addToolbarObserver { _ in events += 1 }

        // 另一个来源重复隐藏同一分类 → 并集不变 → 不应发事件。
        provider.setHiddenCategories([.chat], for: "source-b")

        #expect(events == 0)
        handle.cancel()
    }

    @Test("设置相同基线分类不发事件")
    func noEventWhenBaseUnchanged() {
        let provider = DefaultToolbarProviding()
        var events = 0
        let handle = provider.addToolbarObserver { _ in events += 1 }

        provider.setVisibleCategories(Set(ToolbarItemCategory.allCases))

        #expect(events == 0)
        handle.cancel()
    }

    @Test("init 可指定初始可见分类")
    func initAcceptsInitialCategories() {
        let provider = DefaultToolbarProviding(visibleCategories: [.global, .editor])

        #expect(provider.visibleCategories == [.global, .editor])
    }

    @Test("基线分类与隐藏分类叠加后再改基线")
    func baseChangeRespectsHiddenRequests() {
        let provider = DefaultToolbarProviding(visibleCategories: [.chat, .editor])
        provider.setHiddenCategories([.chat], for: "source-a")

        provider.setVisibleCategories([.chat, .editor, .project])

        // chat 仍被 source-a 隐藏。
        #expect(provider.visibleCategories == [.editor, .project])
    }
}

/// `inferredOwnerPluginID` 的隐式 owner 推断。
///
/// 插件未显式声明 `ownerPluginID` 时，provider 依据 item id 的
/// `<pluginID>.<suffix>` 前缀推断归属，实现「插件被禁用 → 贡献自动消失」。
/// 前缀重叠时取最长匹配（最具体的插件）。
@Suite("Toolbar owner 推断")
@MainActor
struct ToolbarOwnerInferenceTests {

    private func item(_ id: String, ownerPluginID: String? = nil) -> ProviderToolbar.ToolbarItem {
        ProviderToolbar.ToolbarItem(id: id, title: id, ownerPluginID: ownerPluginID) { Text(id) }
    }

    @Test("显式 ownerPluginID 被尊重")
    func explicitOwnerIsRespected() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([item("x", ownerPluginID: "plugin-a")])
        provider.setPluginState(
            knownPluginIDs: ["plugin-a"],
            disabledPluginIDs: ["plugin-a"]
        )

        #expect(provider.visibleToolbarItems.isEmpty)
    }

    @Test("显式 owner 优先于前缀推断")
    func explicitOwnerWinsOverInference() {
        let provider = DefaultToolbarProviding()
        // id 前缀指向 plugin-a，但显式声明属于 plugin-b。
        provider.registerToolbarItems([item("plugin-a.action", ownerPluginID: "plugin-b")])
        provider.setPluginState(
            knownPluginIDs: ["plugin-a", "plugin-b"],
            disabledPluginIDs: ["plugin-a"]
        )

        #expect(provider.visibleToolbarItems.map(\.id) == ["plugin-a.action"])
    }

    @Test("无显式 owner 时按 id 前缀推断归属")
    func infersOwnerFromIDPrefix() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([item("plugin-a.run")])
        provider.setPluginState(
            knownPluginIDs: ["plugin-a"],
            disabledPluginIDs: ["plugin-a"]
        )

        #expect(provider.visibleToolbarItems.isEmpty)
    }

    @Test("owner 插件重新启用后贡献恢复")
    func contributionReturnsWhenPluginReenabled() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([item("plugin-a.run")])
        provider.setPluginState(knownPluginIDs: ["plugin-a"], disabledPluginIDs: ["plugin-a"])
        #expect(provider.visibleToolbarItems.isEmpty)

        provider.setPluginState(knownPluginIDs: ["plugin-a"], disabledPluginIDs: [])

        #expect(provider.visibleToolbarItems.map(\.id) == ["plugin-a.run"])
    }

    @Test("前缀重叠时取最长匹配的插件")
    func picksLongestMatchingPrefix() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([item("com.example.plugin.sub.run")])
        // "com.example.plugin" 与 "com.example.plugin.sub" 都是前缀，取后者。
        provider.setPluginState(
            knownPluginIDs: ["com.example.plugin", "com.example.plugin.sub"],
            disabledPluginIDs: ["com.example.plugin"]
        )

        #expect(provider.visibleToolbarItems.map(\.id) == ["com.example.plugin.sub.run"])
    }

    @Test("id 前缀不匹配任何已知插件时保持可见")
    func unmatchedPrefixStaysVisible() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([item("standalone.action")])
        provider.setPluginState(
            knownPluginIDs: ["plugin-a"],
            disabledPluginIDs: ["plugin-a"]
        )

        #expect(provider.visibleToolbarItems.map(\.id) == ["standalone.action"])
    }

    @Test("ownerPluginID 为 nil 的宿主贡献不受插件状态影响")
    func hostContributionUnaffectedByPluginState() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([item("host-only")])
        provider.setPluginState(
            knownPluginIDs: ["plugin-a"],
            disabledPluginIDs: ["plugin-a"]
        )

        #expect(provider.visibleToolbarItems.map(\.id) == ["host-only"])
    }

    @Test("setPluginState 状态未变时不发事件")
    func noEventWhenPluginStateUnchanged() {
        let provider = DefaultToolbarProviding()
        provider.setPluginState(knownPluginIDs: ["a"], disabledPluginIDs: [])
        var events = 0
        let handle = provider.addToolbarObserver { _ in events += 1 }

        provider.setPluginState(knownPluginIDs: ["a"], disabledPluginIDs: [])

        #expect(events == 0)
        handle.cancel()
    }

    @Test("setPluginState 变化时发布 toolbarItemsChanged")
    func publishesItemsChangedOnPluginStateChange() {
        let provider = DefaultToolbarProviding()
        var events: [String] = []
        let handle = provider.addToolbarObserver { event in
            switch event {
            case .toolbarItemsChanged: events.append("items")
            case .visibleCategoriesChanged: events.append("categories")
            }
        }

        provider.setPluginState(knownPluginIDs: ["a"], disabledPluginIDs: ["a"])

        #expect(events == ["items"])
        handle.cancel()
    }
}

/// `addToolbarItems` / `removeToolbarItems` 的合并语义。
@Suite("Toolbar 项合并语义")
@MainActor
struct ToolbarItemMergeTests {

    private func item(_ id: String, order: Int = 200) -> ProviderToolbar.ToolbarItem {
        ProviderToolbar.ToolbarItem(id: id, title: id, order: order) { Text(id) }
    }

    @Test("addToolbarItems 追加并按 order 排序")
    func appendsAndSorts() {
        let provider = DefaultToolbarProviding()

        provider.addToolbarItems([item("c", order: 300)])
        provider.addToolbarItems([item("a", order: 100)])
        provider.addToolbarItems([item("b", order: 200)])

        #expect(provider.toolbarItems.map(\.id) == ["a", "b", "c"])
    }

    @Test("order 相同时保持注册顺序")
    func stableForEqualOrder() {
        let provider = DefaultToolbarProviding()

        provider.addToolbarItems([item("first", order: 100)])
        provider.addToolbarItems([item("second", order: 100)])

        #expect(provider.toolbarItems.map(\.id) == ["first", "second"])
    }

    @Test("同 id 去重保留先注册者")
    func dedupesKeepingFirst() {
        let provider = DefaultToolbarProviding()
        provider.addToolbarItems([item("dup", order: 100)])

        provider.addToolbarItems([item("dup", order: 900)])

        #expect(provider.toolbarItems.count == 1)
        #expect(provider.toolbarItems.first?.order == 100)
    }

    @Test("removeToolbarItems 按 id 撤回")
    func removesByID() {
        let provider = DefaultToolbarProviding()
        provider.addToolbarItems([item("a"), item("b"), item("c")])

        provider.removeToolbarItems(ids: ["b"])

        #expect(provider.toolbarItems.map(\.id) == ["a", "c"])
    }

    @Test("移除不存在的 id 不影响其余项")
    func removingUnknownIDIsNoop() {
        let provider = DefaultToolbarProviding()
        provider.addToolbarItems([item("a")])

        provider.removeToolbarItems(ids: ["missing"])

        #expect(provider.toolbarItems.map(\.id) == ["a"])
    }
}

/// `ToolbarProviding` 协议扩展的兜底实现。
///
/// 宿主可能提供只实现最小契约（`registerToolbarItems` / `makeToolbarView`）的
/// 轻量 provider，此时分类过滤与增删方法必须由协议扩展兜底，且不崩掉。
@Suite("ToolbarProviding 协议兜底")
@MainActor
struct ToolbarProvidingFallbackTests {

    /// 只实现最小契约的自定义 provider。
    private final class MinimalProvider: ToolbarProviding {
        private(set) var toolbarItems: [ProviderToolbar.ToolbarItem] = []
        private(set) var setVisibleCallCount = 0
        private(set) var setHiddenCallCount = 0

        func registerToolbarItems(_ items: [ProviderToolbar.ToolbarItem]) {
            toolbarItems = items
        }

        func makeToolbarView() -> AnyView { AnyView(EmptyView()) }
    }

    /// 自行提供 `visibleCategories` 的 provider，用于验证协议默认的
    /// `visibleToolbarItems` 只按分类过滤、不感知 owner。
    private final class CategoryAwareProvider: ToolbarProviding {
        var toolbarItems: [ProviderToolbar.ToolbarItem] = []
        var visibleCategories: Set<ToolbarItemCategory> = [.editor]

        func registerToolbarItems(_ items: [ProviderToolbar.ToolbarItem]) {
            toolbarItems = items
        }

        func makeToolbarView() -> AnyView { AnyView(EmptyView()) }
    }

    @Test("默认 visibleCategories 为全部分类")
    func defaultsToAllCategories() {
        let provider = MinimalProvider()

        #expect(provider.visibleCategories == Set(ToolbarItemCategory.allCases))
    }

    @Test("默认 visibleToolbarItems 仅按分类过滤")
    func defaultVisibleItemsFilterByCategoryOnly() {
        let provider = CategoryAwareProvider()
        provider.registerToolbarItems([
            ProviderToolbar.ToolbarItem(id: "chat", title: "chat", category: .chat) { Text("chat") },
            ProviderToolbar.ToolbarItem(id: "editor", title: "editor", category: .editor) { Text("editor") },
        ])

        #expect(provider.visibleToolbarItems.map(\.id) == ["editor"])
    }

    @Test("默认 setVisibleCategories 为空操作")
    func setVisibleIsNoop() {
        let provider = MinimalProvider()

        provider.setVisibleCategories([.editor])

        #expect(provider.setVisibleCallCount == 0)
        #expect(provider.visibleCategories == Set(ToolbarItemCategory.allCases))
    }

    @Test("默认 setHiddenCategories 为空操作")
    func setHiddenIsNoop() {
        let provider = MinimalProvider()

        provider.setHiddenCategories([.chat], for: "source")

        #expect(provider.setHiddenCallCount == 0)
        #expect(provider.visibleCategories.contains(.chat))
    }

    @Test("默认 addToolbarItems 合并并稳定排序")
    func defaultAddMergesWithStableOrder() {
        let provider = MinimalProvider()
        provider.registerToolbarItems([
            ProviderToolbar.ToolbarItem(id: "b", title: "b", order: 200) { Text("b") },
        ])

        provider.addToolbarItems([
            ProviderToolbar.ToolbarItem(id: "a", title: "a", order: 100) { Text("a") },
            ProviderToolbar.ToolbarItem(id: "c", title: "c", order: 200) { Text("c") },
        ])

        #expect(provider.toolbarItems.map(\.id) == ["a", "b", "c"])
    }

    @Test("默认 addToolbarItems 同 id 去重保留先注册者")
    func defaultAddDedupesKeepingFirst() {
        let provider = MinimalProvider()
        provider.addToolbarItems([
            ProviderToolbar.ToolbarItem(id: "dup", title: "dup", order: 100) { Text("dup") },
        ])

        provider.addToolbarItems([
            ProviderToolbar.ToolbarItem(id: "dup", title: "dup", order: 900) { Text("dup") },
        ])

        #expect(provider.toolbarItems.count == 1)
        #expect(provider.toolbarItems.first?.order == 100)
    }

    @Test("默认 removeToolbarItems 按 id 撤回")
    func defaultRemoveByID() {
        let provider = MinimalProvider()
        provider.registerToolbarItems([
            ProviderToolbar.ToolbarItem(id: "a", title: "a") { Text("a") },
            ProviderToolbar.ToolbarItem(id: "b", title: "b") { Text("b") },
        ])

        provider.removeToolbarItems(ids: ["a", "missing"])

        #expect(provider.toolbarItems.map(\.id) == ["b"])
    }

    @Test("默认 addToolbarObserver 返回可安全取消的空句柄")
    func defaultObserverHandleIsSafe() {
        let provider = MinimalProvider()

        let handle = provider.addToolbarObserver { _ in
            Issue.record("默认实现不应触发回调")
        }
        handle.cancel()
        handle.cancel()
    }
}

/// `DefaultIOSNavigationBarProviding` 的分类过滤与 owner 推断。
@Suite("iOS 导航栏 provider")
@MainActor
struct IOSNavigationBarProvidingTests {

    private func item(
        _ id: String,
        category: ToolbarItemCategory = .global,
        ownerPluginID: String? = nil,
        order: Int = 200
    ) -> IOSNavigationBarItem {
        IOSNavigationBarItem(
            id: id,
            title: id,
            category: category,
            ownerPluginID: ownerPluginID,
            order: order
        ) { Text(id) }
    }

    @Test("默认可见全部已注册项")
    func showsAllRegisteredByDefault() {
        let provider = DefaultIOSNavigationBarProviding()
        provider.registerNavigationBarItems([item("a"), item("b")])

        #expect(provider.visibleNavigationBarItems.map(\.id) == ["a", "b"])
    }

    @Test("隐藏分类过滤可见项")
    func hiddenCategoryFiltersItems() {
        let provider = DefaultIOSNavigationBarProviding()
        provider.registerNavigationBarItems([
            item("chat-1", category: .chat),
            item("editor-1", category: .editor),
        ])

        provider.setHiddenCategories([.chat], for: "source-a")

        #expect(provider.visibleNavigationBarItems.map(\.id) == ["editor-1"])
    }

    @Test("多来源隐藏取并集，撤销单个来源不影响其他")
    func unionsAndClearsSources() {
        let provider = DefaultIOSNavigationBarProviding()
        provider.setHiddenCategories([.chat], for: "a")
        provider.setHiddenCategories([.project], for: "b")
        #expect(!provider.visibleCategories.contains(.chat))
        #expect(!provider.visibleCategories.contains(.project))

        provider.setHiddenCategories([], for: "a")

        #expect(provider.visibleCategories.contains(.chat))
        #expect(!provider.visibleCategories.contains(.project))
    }

    @Test("owner 插件禁用后贡献隐藏")
    func hidesContributionOfDisabledPlugin() {
        let provider = DefaultIOSNavigationBarProviding()
        provider.registerNavigationBarItems([
            item("plugin-a.run"),
            item("host-only"),
        ])

        provider.setPluginState(
            knownPluginIDs: ["plugin-a"],
            disabledPluginIDs: ["plugin-a"]
        )

        #expect(provider.visibleNavigationBarItems.map(\.id) == ["host-only"])
    }

    @Test("owner 插件重新启用后贡献恢复")
    func restoresContributionWhenReenabled() {
        let provider = DefaultIOSNavigationBarProviding()
        provider.registerNavigationBarItems([item("plugin-a.run")])
        provider.setPluginState(knownPluginIDs: ["plugin-a"], disabledPluginIDs: ["plugin-a"])
        #expect(provider.visibleNavigationBarItems.isEmpty)

        provider.setPluginState(knownPluginIDs: ["plugin-a"], disabledPluginIDs: [])

        #expect(provider.visibleNavigationBarItems.map(\.id) == ["plugin-a.run"])
    }

    @Test("addNavigationBarItems 追加并按 order 排序、同 id 去重")
    func addMergesAndSorts() {
        let provider = DefaultIOSNavigationBarProviding()
        provider.registerNavigationBarItems([item("b", order: 200)])

        provider.addNavigationBarItems([item("a", order: 100), item("b", order: 999)])

        #expect(provider.navigationBarItems.map(\.id) == ["a", "b"])
        #expect(provider.navigationBarItems.first?.order == 100)
    }

    @Test("removeNavigationBarItems 按 id 撤回")
    func removesByID() {
        let provider = DefaultIOSNavigationBarProviding()
        provider.registerNavigationBarItems([item("a"), item("b")])

        provider.removeNavigationBarItems(ids: ["a"])

        #expect(provider.navigationBarItems.map(\.id) == ["b"])
    }

    @Test("显式 owner 优先于前缀推断")
    func explicitOwnerWinsOverInference() {
        let provider = DefaultIOSNavigationBarProviding()
        provider.registerNavigationBarItems([
            item("plugin-a.action", ownerPluginID: "plugin-b"),
        ])
        provider.setPluginState(
            knownPluginIDs: ["plugin-a", "plugin-b"],
            disabledPluginIDs: ["plugin-a"]
        )

        #expect(provider.visibleNavigationBarItems.map(\.id) == ["plugin-a.action"])
    }
}

/// `IOSNavigationBarProviding` 协议扩展的兜底实现。
@Suite("IOSNavigationBarProviding 协议兜底")
@MainActor
struct IOSNavigationBarProvidingFallbackTests {

    /// 只实现最小契约的自定义 provider。
    private final class MinimalProvider: IOSNavigationBarProviding {
        var navigationBarItems: [IOSNavigationBarItem] = []
        private(set) var setVisibleCallCount = 0
        private(set) var setHiddenCallCount = 0

        func registerNavigationBarItems(_ items: [IOSNavigationBarItem]) {
            navigationBarItems = items
        }
    }

    @Test("默认 visibleCategories 为全部分类")
    func defaultsToAllCategories() {
        let provider = MinimalProvider()

        #expect(provider.visibleCategories == Set(ToolbarItemCategory.allCases))
    }

    @Test("默认 setVisibleCategories / setHiddenCategories 为空操作")
    func categorySettersAreNoop() {
        let provider = MinimalProvider()

        provider.setVisibleCategories([.editor])
        provider.setHiddenCategories([.chat], for: "source")

        #expect(provider.setVisibleCallCount == 0)
        #expect(provider.setHiddenCallCount == 0)
        #expect(provider.visibleCategories == Set(ToolbarItemCategory.allCases))
    }

    @Test("默认 addNavigationBarItems 合并并稳定排序")
    func addMergesWithStableOrder() {
        let provider = MinimalProvider()
        provider.registerNavigationBarItems([
            IOSNavigationBarItem(id: "first", title: "first", order: 100) { Text("first") },
        ])

        provider.addNavigationBarItems([
            IOSNavigationBarItem(id: "second", title: "second", order: 100) { Text("second") },
            IOSNavigationBarItem(id: "third", title: "third", order: 50) { Text("third") },
        ])

        #expect(provider.navigationBarItems.map(\.id) == ["third", "first", "second"])
    }

    @Test("默认 removeNavigationBarItems 按 id 撤回")
    func removeByID() {
        let provider = MinimalProvider()
        provider.registerNavigationBarItems([
            IOSNavigationBarItem(id: "a", title: "a") { Text("a") },
            IOSNavigationBarItem(id: "b", title: "b") { Text("b") },
        ])

        provider.removeNavigationBarItems(ids: ["a", "missing"])

        #expect(provider.navigationBarItems.map(\.id) == ["b"])
    }
}
