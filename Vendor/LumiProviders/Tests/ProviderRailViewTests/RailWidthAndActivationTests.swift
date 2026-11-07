import Combine
import SwiftUI
import Testing
@testable import ProviderRailView

/// 记录收到的 Rail 宽度存取调用。
@MainActor
private final class SpyWidthStore: RailViewWidthStoring {
    private(set) var loadCalls: [String] = []
    private(set) var saveCalls: [(CGFloat, String)] = []
    private(set) var removeCalls: [String] = []
    var stored: [String: CGFloat]

    init(stored: [String: CGFloat] = [:]) {
        self.stored = stored
    }

    func loadWidth(ownerID: String) -> CGFloat? {
        loadCalls.append(ownerID)
        return stored[ownerID]
    }

    func saveWidth(_ width: CGFloat, ownerID: String) {
        saveCalls.append((width, ownerID))
        stored[ownerID] = width
    }

    func removeWidth(ownerID: String) {
        removeCalls.append(ownerID)
        stored.removeValue(forKey: ownerID)
    }
}

/// `RailViewWidth` 的夹取与构造规则。
@Suite("RailViewWidth 约束")
@MainActor
struct RailViewWidthTests {

    @Test("standard 使用固定档位")
    func standardValues() {
        #expect(RailViewWidth.standard.minWidth == 180)
        #expect(RailViewWidth.standard.idealWidth == 240)
        #expect(RailViewWidth.standard.maxWidth == 400)
    }

    @Test("init 把 idealWidth 夹取到 [min, max]")
    func initClampsIdealWidth() {
        let tooSmall = RailViewWidth(minWidth: 200, idealWidth: 50, maxWidth: 400)
        #expect(tooSmall.idealWidth == 200)

        let tooLarge = RailViewWidth(minWidth: 200, idealWidth: 900, maxWidth: 400)
        #expect(tooLarge.idealWidth == 400)
    }

    @Test("init 把负数 minWidth 归零")
    func initClampsNegativeMin() {
        let width = RailViewWidth(minWidth: -50, idealWidth: 100, maxWidth: 400)

        #expect(width.minWidth == 0)
    }

    @Test("max 小于 min 时抬升为 min")
    func initRaisesMaxToMin() {
        let width = RailViewWidth(minWidth: 300, idealWidth: 100, maxWidth: 200)

        #expect(width.maxWidth == 300)
        #expect(width.idealWidth == 300)
    }

    @Test("非有限 maxWidth 视为无穷")
    func initHandlesInfiniteMax() {
        let width = RailViewWidth(minWidth: 100, idealWidth: 5000, maxWidth: .infinity)

        #expect(width.maxWidth == .infinity)
        #expect(width.idealWidth == 5000)
    }

    @Test("非有限 idealWidth 回落到 minWidth")
    func initHandlesNonFiniteIdeal() {
        let nan = RailViewWidth(minWidth: 100, idealWidth: .nan, maxWidth: 400)
        #expect(nan.idealWidth == 100)

        let infinite = RailViewWidth(minWidth: 100, idealWidth: .infinity, maxWidth: 400)
        #expect(infinite.idealWidth == 100)
    }

    @Test("clamped 把宽度限制到 [min, max]")
    func clampedConstrains() {
        let width = RailViewWidth(minWidth: 200, idealWidth: 300, maxWidth: 400)

        #expect(width.clamped(100) == 200)
        #expect(width.clamped(999) == 400)
        #expect(width.clamped(250) == 250)
        #expect(width.clamped(.nan) == 200)
    }

    @Test("withIdealWidth 保留 min/max 只换 ideal")
    func withIdealWidthKeepsBounds() {
        let width = RailViewWidth(minWidth: 200, idealWidth: 300, maxWidth: 400)

        let updated = width.withIdealWidth(350)

        #expect(updated.idealWidth == 350)
        #expect(updated.minWidth == 200)
        #expect(updated.maxWidth == 400)
    }
}

/// 宽度档位（width profile）的激活、切换与持久化。
///
/// 插件激活时通过 `activateWidthProfile` 接管 Rail 宽度；用户拖拽宽度后
/// `saveCurrentWidth` 写回插件注入的 store；`deactivateWidthProfile` 只允许
/// 当前 owner 撤销自己，避免旧插件覆盖新插件的配置。
@Suite("Rail 宽度档位")
@MainActor
struct RailWidthProfileTests {

    private let wide = RailViewWidth(minWidth: 200, idealWidth: 320, maxWidth: 500)
    private let narrow = RailViewWidth(minWidth: 150, idealWidth: 200, maxWidth: 300)

    @Test("初始宽度为 standard")
    func startsAtStandard() {
        let provider = DefaultRailViewProviding()

        #expect(provider.railWidth == .standard)
    }

    @Test("激活档位应用推荐宽度")
    func activationAppliesRecommendedWidth() {
        let provider = DefaultRailViewProviding()

        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: nil)

        #expect(provider.railWidth.idealWidth == 320)
        #expect(provider.railWidth.minWidth == 200)
    }

    @Test("空 ownerID 被忽略")
    func emptyOwnerIDIsIgnored() {
        let provider = DefaultRailViewProviding()

        provider.activateWidthProfile(ownerID: "", recommended: wide, store: nil)

        #expect(provider.railWidth == .standard)
    }

    @Test("store 中有保存值时优先于推荐值")
    func storeValueWinsOverRecommended() {
        let store = SpyWidthStore(stored: ["plugin-a": 260])
        let provider = DefaultRailViewProviding()

        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: store)

        #expect(provider.railWidth.idealWidth == 260)
        #expect(store.loadCalls == ["plugin-a"])
    }

    @Test("恢复的宽度仍被夹取到档位边界")
    func restoredWidthIsClamped() {
        let store = SpyWidthStore(stored: ["plugin-a": 9999])
        let provider = DefaultRailViewProviding()

        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: store)

        #expect(provider.railWidth.idealWidth == 500)
    }

    @Test("store 为 nil 时不读取磁盘，回落推荐值")
    func nilStoreFallsBackToRecommended() {
        let provider = DefaultRailViewProviding()

        provider.activateWidthProfile(ownerID: "plugin-a", recommended: narrow, store: nil)

        #expect(provider.railWidth.idealWidth == 200)
    }

    @Test("宽度未变化时不发 widthChanged")
    func noEventWhenWidthUnchanged() {
        let provider = DefaultRailViewProviding()
        provider.activateWidthProfile(ownerID: "plugin-a", recommended: narrow, store: nil)
        var events = 0
        let handle = provider.addObserver { _ in events += 1 }

        // 再次激活同一推荐宽度 → 解析结果相同 → 不发事件。
        provider.activateWidthProfile(ownerID: "plugin-a", recommended: narrow, store: nil)

        #expect(events == 0)
        handle.cancel()
    }

    @Test("宽度变化时发 widthChanged 事件")
    func emitsWidthChangedEvent() {
        let provider = DefaultRailViewProviding()
        var events: [RailViewProvidingEvent] = []
        let handle = provider.addObserver { events.append($0) }

        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: nil)

        #expect(events.count == 1)
        guard case let .widthChanged(width) = events[0] else {
            Issue.record("Expected widthChanged event")
            return
        }
        #expect(width.idealWidth == 320)
        handle.cancel()
    }

    @Test("停用档位回落到 standard")
    func deactivationResetsToStandard() {
        let provider = DefaultRailViewProviding()
        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: nil)

        provider.deactivateWidthProfile(ownerID: "plugin-a")

        #expect(provider.railWidth == .standard)
    }

    @Test("非 owner 停用不影响当前档位")
    func nonOwnerDeactivationIsIgnored() {
        let provider = DefaultRailViewProviding()
        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: nil)

        provider.deactivateWidthProfile(ownerID: "plugin-b")

        #expect(provider.railWidth.idealWidth == 320)
    }

    @Test("已在 standard 时停用不发事件")
    func deactivationAtStandardEmitsNoEvent() {
        let provider = DefaultRailViewProviding()
        var events = 0
        let handle = provider.addObserver { _ in events += 1 }

        provider.deactivateWidthProfile(ownerID: "plugin-a")

        #expect(events == 0)
        handle.cancel()
    }

    @Test("saveCurrentWidth 写回 owner 的 store")
    func saveWritesToOwnerStore() {
        let store = SpyWidthStore()
        let provider = DefaultRailViewProviding()
        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: store)

        provider.saveCurrentWidth(280)

        #expect(store.saveCalls.count == 1)
        #expect(store.saveCalls[0].0 == 280)
        #expect(store.saveCalls[0].1 == "plugin-a")
        #expect(provider.railWidth.idealWidth == 280)
    }

    @Test("saveCurrentWidth 夹取超出边界的宽度")
    func saveClampsOutOfBounds() {
        let store = SpyWidthStore()
        let provider = DefaultRailViewProviding()
        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: store)

        provider.saveCurrentWidth(9999)

        #expect(store.saveCalls[0].0 == 500)
        #expect(provider.railWidth.idealWidth == 500)
    }

    @Test("未激活档位时 saveCurrentWidth 不写盘")
    func saveWithoutActiveProfileIsNoop() {
        let store = SpyWidthStore()
        let provider = DefaultRailViewProviding()
        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: store)
        provider.deactivateWidthProfile(ownerID: "plugin-a")

        provider.saveCurrentWidth(280)

        #expect(store.saveCalls.isEmpty)
        #expect(provider.railWidth == .standard)
    }

    @Test("store 为 nil 时 saveCurrentWidth 仍更新内存宽度")
    func saveWithoutStoreUpdatesMemory() {
        let provider = DefaultRailViewProviding()
        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: nil)

        provider.saveCurrentWidth(260)

        #expect(provider.railWidth.idealWidth == 260)
    }

    @Test("新插件接管后旧插件停用不覆盖新配置")
    func newOwnerTakesOverAndSurvivesOldDeactivation() {
        let provider = DefaultRailViewProviding()
        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: nil)
        provider.activateWidthProfile(ownerID: "plugin-b", recommended: narrow, store: nil)
        #expect(provider.railWidth.idealWidth == 200)

        // 旧插件迟到地停用，不应把 plugin-b 的档位清掉。
        provider.deactivateWidthProfile(ownerID: "plugin-a")

        #expect(provider.railWidth.idealWidth == 200)
    }

    @Test("init 注入的默认 store 用于未显式传 store 的激活")
    func initStoreIsUsedWhenNoExplicitStore() {
        let store = SpyWidthStore(stored: ["plugin-a": 250])
        let provider = DefaultRailViewProviding(widthStore: store)

        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: nil)

        #expect(provider.railWidth.idealWidth == 250)
        #expect(store.loadCalls == ["plugin-a"])
    }

    @Test("显式传入的 store 优先于 init 的默认 store")
    func explicitStoreOverridesDefaultStore() {
        let defaultStore = SpyWidthStore(stored: ["plugin-a": 250])
        let explicitStore = SpyWidthStore(stored: ["plugin-a": 420])
        let provider = DefaultRailViewProviding(widthStore: defaultStore)

        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: explicitStore)

        #expect(provider.railWidth.idealWidth == 420)
        #expect(defaultStore.loadCalls.isEmpty)
    }

    @Test("railWidthPublisher 在宽度变化时推送新值")
    func widthPublisherEmitsChanges() {
        let provider = DefaultRailViewProviding()
        var received: [RailViewWidth] = []
        let cancellable = provider.railWidthPublisher.sink { received.append($0) }

        provider.activateWidthProfile(ownerID: "plugin-a", recommended: wide, store: nil)
        provider.deactivateWidthProfile(ownerID: "plugin-a")

        #expect(received.count >= 3) // 初值 + 激活 + 停用
        #expect(received.contains { $0.idealWidth == 320 })
        #expect(received.contains { $0 == .standard })
        cancellable.cancel()
    }
}

/// `activateTab` 与 `activateTabWhenAvailable` 的选中与暂存语义。
///
/// `activateTab` 只对**当前可见**的 tab 生效，未知 id 直接忽略；
/// `activateTabWhenAvailable` 允许先记下请求，等 tab 注册后再自动激活
/// （用于启动恢复）。
@Suite("Rail tab 激活")
@MainActor
struct RailTabActivationTests {

    private func tab(
        _ id: String,
        category: RailViewCategory = .chat,
        order: Int = 200
    ) -> RailTabItem {
        RailTabItem(id: id, category: category, title: id, systemImage: "square", order: order) {
            Text(id)
        }
    }

    @Test("registerTabs 按 order 排序并自动选中首个")
    func registersAndActivatesFirstTab() {
        let provider = DefaultRailViewProviding()

        provider.registerTabs([tab("b", order: 200), tab("a", order: 100)])

        #expect(provider.tabs.map(\.id) == ["a", "b"])
        #expect(provider.activeTabID == "a")
        #expect(provider.hasVisibleTabs)
    }

    @Test("activateTab 切换到指定可见 tab")
    func activatesVisibleTab() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a", order: 100), tab("b", order: 200)])

        provider.activateTab(id: "b")

        #expect(provider.activeTabID == "b")
    }

    @Test("activateTab 忽略未知 id")
    func ignoresUnknownTab() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a")])

        provider.activateTab(id: "missing")

        #expect(provider.activeTabID == "a")
    }

    @Test("activateTab 忽略被分类过滤掉的 tab")
    func ignoresFilteredTab() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a", category: .chat), tab("b", category: .project)])
        provider.setVisibleCategories([.chat])

        provider.activateTab(id: "b")

        #expect(provider.activeTabID == "a")
    }

    @Test("activateTab(nil) 清空选中")
    func activatingNilClearsSelection() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a")])

        provider.activateTab(id: nil)

        #expect(provider.activeTabID == nil)
    }

    @Test("activateTab(nil) 在无变化时不发事件")
    func activatingNilTwiceEmitsOnce() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a")])
        provider.activateTab(id: nil)
        var events = 0
        let handle = provider.addObserver { event in
            if case .activeTabChanged = event { events += 1 }
        }

        provider.activateTab(id: nil)

        #expect(events == 0)
        handle.cancel()
    }

    @Test("activateTabWhenAvailable 立即激活已存在的 tab")
    func activatesWhenAvailableImmediately() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a"), tab("b")])

        provider.activateTabWhenAvailable(id: "b")

        #expect(provider.activeTabID == "b")
    }

    @Test("activateTabWhenAvailable 暂存未注册的请求并在注册后激活")
    func defersUntilTabRegistered() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a")])

        provider.activateTabWhenAvailable(id: "later")
        #expect(provider.activeTabID == "a")

        provider.registerTabs([tab("a"), tab("later", order: 300)])

        #expect(provider.activeTabID == "later")
    }

    @Test("暂存的请求取消后不激活")
    func cancelDeferredRequest() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a")])
        provider.activateTabWhenAvailable(id: "later")

        provider.activateTabWhenAvailable(id: nil)
        provider.registerTabs([tab("a"), tab("later", order: 300)])

        #expect(provider.activeTabID == "a")
    }

    @Test("暂存请求覆盖已有的 activeTab")
    func deferredRequestOverridesCurrentSelection() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a", order: 100), tab("b", order: 200)])
        provider.activateTab(id: "a")

        provider.activateTabWhenAvailable(id: "b")

        #expect(provider.activeTabID == "b")
    }

    @Test("当前 activeTab 变为不可见时回退到首个可见 tab")
    func fallsBackWhenActiveBecomesInvisible() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            tab("a", category: .chat, order: 100),
            tab("b", category: .project, order: 200),
        ])
        provider.activateTab(id: "b")
        #expect(provider.activeTabID == "b")

        provider.setVisibleCategories([.chat])

        #expect(provider.activeTabID == "a")
    }

    @Test("所有 tab 不可见时 activeTab 被清空")
    func clearsActiveWhenNothingVisible() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a", category: .chat)])

        provider.setVisibleCategories([.project])

        #expect(provider.activeTabID == nil)
        #expect(provider.hasVisibleTabs == false)
    }

    @Test("registerTabs 空数组清空选中")
    func emptyRegistrationClearsSelection() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a")])

        provider.registerTabs([])

        #expect(provider.activeTabID == nil)
        #expect(provider.hasVisibleTabs == false)
    }

    @Test("registerTabs 发 tabsChanged / activeTabChanged / visibilityChanged")
    func emitsExpectedEvents() {
        let provider = DefaultRailViewProviding()
        var events: [String] = []
        let handle = provider.addObserver { event in
            switch event {
            case .tabsChanged: events.append("tabs")
            case .activeTabChanged: events.append("active")
            case .visibilityChanged: events.append("visibility")
            default: break
            }
        }

        provider.registerTabs([tab("a")])

        #expect(events.contains("tabs"))
        #expect(events.contains("active"))
        #expect(events.contains("visibility"))
        handle.cancel()
    }

    @Test("重复注册相同样式 tabs 不重复发 tabsChanged")
    func noDuplicateTabsChangedEvent() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a")])
        var tabsChanged = 0
        let handle = provider.addObserver { event in
            if case .tabsChanged = event { tabsChanged += 1 }
        }

        provider.registerTabs([tab("a")])

        #expect(tabsChanged == 0)
        handle.cancel()
    }

    @Test("observe nil 不抛错且句柄安全")
    func observeNilIsSafe() {
        let provider = DefaultRailViewProviding()

        provider.registerTabs([tab("a")])

        #expect(provider.hasVisibleTabs)
    }

    @Test("hasVisibleSections 反映 sections 状态")
    func sectionsDriveVisibility() {
        let provider = DefaultRailViewProviding()

        #expect(provider.hasVisibleSections == false)

        provider.registerSections([
            RailSectionItem(id: "s1", order: 100) { AnyView(Text("s1")) },
        ])

        #expect(provider.hasVisibleSections)
    }

    @Test("railVisibilityPublisher 在 tab 或 section 可见时为 true")
    func railVisibilityCombinesTabsAndSections() {
        let provider = DefaultRailViewProviding()
        var visibility: [Bool] = []
        let cancellable = provider.railVisibilityPublisher.sink { visibility.append($0) }

        provider.registerSections([RailSectionItem(id: "s1", order: 100) { AnyView(Text("s1")) }])
        provider.registerSections([])

        #expect(visibility.contains(true))
        #expect(visibility.last == false)
        cancellable.cancel()
    }
}

/// `setVisibleTabID` 与分类过滤的互斥切换。
@Suite("Rail 可见性模式")
@MainActor
struct RailVisibilityModeTests {

    private func tab(
        _ id: String,
        category: RailViewCategory = .chat,
        order: Int = 200
    ) -> RailTabItem {
        RailTabItem(id: id, category: category, title: id, systemImage: "square", order: order) {
            Text(id)
        }
    }

    @Test("setVisibleTabID 限制到单个 tab")
    func restrictsToSingleTab() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a"), tab("b")])

        provider.setVisibleTabID("b")

        #expect(provider.visibleTabID == "b")
        #expect(provider.activeTabID == "b")
    }

    @Test("setVisibleTabID(nil) 恢复全部分类模式")
    func nilRestoresAllCategories() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a", category: .chat), tab("b", category: .project)])
        provider.setVisibleTabID("a")

        provider.setVisibleTabID(nil)

        #expect(provider.visibleTabID == nil)
        #expect(provider.activeTabID == "a")
    }

    @Test("切换到分类模式时清除遗留的 visibleTabID")
    func setVisibleCategoriesClearsStaleTabID() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a", category: .chat), tab("b", category: .project)])
        provider.setVisibleTabID("a")
        #expect(provider.visibleTabID == "a")

        provider.setVisibleCategories([.chat, .project])

        #expect(provider.visibleTabID == nil)
        #expect(provider.hasVisibleTabs)
    }

    @Test("setVisibleTabID 相同值不发事件")
    func sameTabIDEmitsNoEvent() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a")])
        provider.setVisibleTabID("a")
        var events = 0
        let handle = provider.addObserver { _ in events += 1 }

        provider.setVisibleTabID("a")

        #expect(events == 0)
        handle.cancel()
    }

    @Test("setVisibleCategories 相同值且无 visibleTabID 时不发事件")
    func sameCategoriesEmitNoEvent() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a")])
        provider.setVisibleCategories(Set(RailViewCategory.allCases))
        var events = 0
        let handle = provider.addObserver { _ in events += 1 }

        provider.setVisibleCategories(Set(RailViewCategory.allCases))

        #expect(events == 0)
        handle.cancel()
    }

    @Test("setVisibleCategories 变化时发 visibleCategoriesChanged")
    func emitsVisibleCategoriesChanged() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a", category: .chat)])
        var events: [RailViewProvidingEvent] = []
        let handle = provider.addObserver { events.append($0) }

        provider.setVisibleCategories([.project])

        #expect(events.contains { if case .visibleCategoriesChanged = $0 { true } else { false } })
        handle.cancel()
    }

    @Test("addTabs 追加并按 order 排序、同 id 去重")
    func addTabsMergesAndSorts() {
        let provider = DefaultRailViewProviding()
        provider.addTabs([tab("b", order: 200)])

        provider.addTabs([tab("a", order: 100), tab("b", order: 999)])

        #expect(provider.tabs.map(\.id) == ["a", "b"])
    }

    @Test("removeTabs 按 id 撤回")
    func removeTabsByID() {
        let provider = DefaultRailViewProviding()
        provider.addTabs([tab("a", order: 100), tab("b", order: 200)])

        provider.removeTabs(ids: ["a"])

        #expect(provider.tabs.map(\.id) == ["b"])
    }

    @Test("addSections 追加并排序、同 id 去重")
    func addSectionsMergesAndSorts() {
        let provider = DefaultRailViewProviding()
        provider.addSections([RailSectionItem(id: "b", order: 200) { AnyView(Text("b")) }])

        provider.addSections([
            RailSectionItem(id: "a", order: 100) { AnyView(Text("a")) },
            RailSectionItem(id: "b", order: 999) { AnyView(Text("b")) },
        ])

        #expect(provider.sections.map(\.id) == ["a", "b"])
    }

    @Test("removeSections 按 id 撤回")
    func removeSectionsByID() {
        let provider = DefaultRailViewProviding()
        provider.addSections([
            RailSectionItem(id: "a", order: 100) { AnyView(Text("a")) },
            RailSectionItem(id: "b", order: 200) { AnyView(Text("b")) },
        ])

        provider.removeSections(ids: ["a"])

        #expect(provider.sections.map(\.id) == ["b"])
    }
}

/// 观察者生命周期。
@Suite("Rail 观察者")
@MainActor
struct RailObserverTests {

    private func tab(_ id: String, order: Int = 200) -> RailTabItem {
        RailTabItem(id: id, category: .chat, title: id, systemImage: "square", order: order) {
            Text(id)
        }
    }

    @Test("多个观察者都收到事件")
    func multipleObserversReceive() {
        let provider = DefaultRailViewProviding()
        var first = 0
        var second = 0
        let a = provider.addObserver { _ in first += 1 }
        let b = provider.addObserver { _ in second += 1 }

        provider.registerTabs([tab("a")])

        #expect(first > 0)
        #expect(second > 0)
        a.cancel()
        b.cancel()
    }

    @Test("cancel 后不再收到事件")
    func cancelStopsEvents() {
        let provider = DefaultRailViewProviding()
        var count = 0
        let handle = provider.addObserver { _ in count += 1 }

        provider.registerTabs([tab("a")])
        let afterFirst = count
        handle.cancel()
        provider.registerTabs([tab("a"), tab("b")])

        #expect(count == afterFirst)
    }

    @Test("重复 cancel 幂等")
    func cancelIsIdempotent() {
        let provider = DefaultRailViewProviding()
        let handle = provider.addObserver { _ in }

        handle.cancel()
        handle.cancel()
    }

    @Test("句柄释放后不再收到事件（弱引用）")
    func deallocatedHandleStopsEvents() {
        let provider = DefaultRailViewProviding()
        var count = 0
        do {
            let _ = provider.addObserver { _ in count += 1 }
        }

        provider.registerTabs([tab("a")])

        #expect(count == 0)
    }

    @Test("makeRailView 返回 AnyView")
    func makesRailView() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([tab("a")])

        #expect(type(of: provider.makeRailView()) == AnyView.self)
    }
}

/// `RailViewProviding` 协议扩展的兜底实现。
@Suite("RailViewProviding 协议兜底")
@MainActor
struct RailViewProvidingFallbackTests {

    /// 只实现最小契约的自定义 provider。
    private final class MinimalProvider: RailViewProviding {
        private(set) var tabs: [RailTabItem] = []
        private(set) var registerCount = 0

        func registerTabs(_ tabs: [RailTabItem]) {
            self.tabs = tabs.sorted { $0.order < $1.order }
            registerCount += 1
        }

        func makeRailView() -> AnyView { AnyView(EmptyView()) }
    }

    private func tab(_ id: String, order: Int = 200) -> RailTabItem {
        RailTabItem(id: id, category: .chat, title: id, systemImage: "square", order: order) {
            Text(id)
        }
    }

    @Test("默认 visibleCategories 为全部分类")
    func defaultsToAllCategories() {
        #expect(MinimalProvider().visibleCategories == Set(RailViewCategory.allCases))
    }

    @Test("默认 visibleTabID / activeTabID 为 nil")
    func defaultsHaveNilIDs() {
        let provider = MinimalProvider()

        #expect(provider.visibleTabID == nil)
        #expect(provider.activeTabID == nil)
    }

    @Test("默认 hasVisibleTabs 依据 tabs 是否为空")
    func defaultHasVisibleTabs() {
        let provider = MinimalProvider()
        #expect(provider.hasVisibleTabs == false)

        provider.registerTabs([tab("a")])

        #expect(provider.hasVisibleTabs)
    }

    @Test("默认 sections 为空")
    func defaultsHaveNoSections() {
        let provider = MinimalProvider()

        #expect(provider.sections.isEmpty)
        #expect(provider.hasVisibleSections == false)
    }

    @Test("默认 railWidth 为 standard")
    func defaultsToStandardWidth() {
        #expect(MinimalProvider().railWidth == .standard)
    }

    @Test("默认 addTabs 合并并去重")
    func defaultAddTabsMerges() {
        let provider = MinimalProvider()
        provider.registerTabs([tab("b", order: 200)])

        provider.addTabs([tab("a", order: 100), tab("b", order: 999)])

        #expect(provider.tabs.map(\.id) == ["a", "b"])
    }

    @Test("默认 removeTabs 按 id 撤回")
    func defaultRemoveTabs() {
        let provider = MinimalProvider()
        provider.registerTabs([tab("a", order: 100), tab("b", order: 200)])

        provider.removeTabs(ids: ["a"])

        #expect(provider.tabs.map(\.id) == ["b"])
    }

    @Test("默认 addObserver 返回 Noop 句柄")
    func defaultObserverIsNoop() {
        let provider = MinimalProvider()

        let handle = provider.addObserver { _ in
            Issue.record("Noop 实现不应触发回调")
        }

        #expect(handle is NoopRailViewProvidingObserverHandle)
        handle.cancel()
    }

    @Test("默认 railVisibilityPublisher 按当前状态推送")
    func defaultVisibilityPublisher() {
        let provider = MinimalProvider()
        provider.registerTabs([tab("a")])
        var values: [Bool] = []
        let cancellable = provider.railVisibilityPublisher.sink { values.append($0) }

        #expect(values == [true])
        cancellable.cancel()
    }

    @Test("默认 railWidthPublisher 推送 standard")
    func defaultWidthPublisher() {
        let provider = MinimalProvider()
        var values: [RailViewWidth] = []
        let cancellable = provider.railWidthPublisher.sink { values.append($0) }

        #expect(values == [.standard])
        cancellable.cancel()
    }

    @Test("默认宽度与激活相关方法为空操作")
    func defaultWidthMethodsAreNoop() {
        let provider = MinimalProvider()

        provider.activateWidthProfile(
            ownerID: "plugin-a",
            recommended: RailViewWidth(minWidth: 100, idealWidth: 200, maxWidth: 300)
        )
        provider.deactivateWidthProfile(ownerID: "plugin-a")
        provider.saveCurrentWidth(250)
        provider.setVisibleCategories([.chat])
        provider.setVisibleTabID("a")
        provider.activateTab(id: "a")

        #expect(provider.railWidth == .standard)
    }

    @Test("默认 activateTabWhenAvailable 转发给 activateTab")
    func defaultActivateTabWhenAvailableForwards() {
        final class SpyProvider: RailViewProviding {
            private(set) var forwarded: [String?] = []
            let tabs: [RailTabItem] = []
            func registerTabs(_ tabs: [RailTabItem]) {}
            func makeRailView() -> AnyView { AnyView(EmptyView()) }
            func activateTab(id: String?) { forwarded.append(id) }
        }
        let spy = SpyProvider()

        spy.activateTabWhenAvailable(id: "a")
        spy.activateTabWhenAvailable(id: nil)

        #expect(spy.forwarded.count == 2)
        #expect(spy.forwarded.first == "a")
    }
}

/// `FileRailViewWidthStore` 的持久化往返。
@Suite("FileRailViewWidthStore")
@MainActor
struct FileRailViewWidthStoreTests {

    private func makeStore() -> (FileRailViewWidthStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rail-width-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("width.plist")
        return (FileRailViewWidthStore(fileURL: url), url)
    }

    @Test("保存后可重新读取")
    func roundTripsValue() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        store.saveWidth(280, ownerID: "plugin-a")

        let reloaded = FileRailViewWidthStore(fileURL: url)
        #expect(reloaded.loadWidth(ownerID: "plugin-a") == 280)
    }

    @Test("不同 owner 各自独立")
    func ownersAreIndependent() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        store.saveWidth(280, ownerID: "plugin-a")
        store.saveWidth(320, ownerID: "plugin-b")

        #expect(store.loadWidth(ownerID: "plugin-a") == 280)
        #expect(store.loadWidth(ownerID: "plugin-b") == 320)
    }

    @Test("未保存的 owner 返回 nil")
    func unknownOwnerReturnsNil() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(store.loadWidth(ownerID: "missing") == nil)
    }

    @Test("非法宽度被忽略")
    func rejectsInvalidWidths() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        store.saveWidth(0, ownerID: "plugin-a")
        store.saveWidth(-100, ownerID: "plugin-a")
        store.saveWidth(.nan, ownerID: "plugin-a")
        store.saveWidth(200, ownerID: "")

        #expect(store.loadWidth(ownerID: "plugin-a") == nil)
        #expect(store.loadWidth(ownerID: "") == nil)
    }

    @Test("removeWidth 清除已保存值")
    func removesSavedValue() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        store.saveWidth(280, ownerID: "plugin-a")

        store.removeWidth(ownerID: "plugin-a")

        #expect(store.loadWidth(ownerID: "plugin-a") == nil)
    }

    @Test("移除不存在的 owner 不崩")
    func removingUnknownOwnerIsSafe() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        store.removeWidth(ownerID: "missing")
        store.removeWidth(ownerID: "missing")
    }

    @Test("损坏的 plist 文件降级为空字典")
    func corruptedFileDegradesGracefully() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rail-width-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("width.plist")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data("not a plist".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileRailViewWidthStore(fileURL: url)

        #expect(store.loadWidth(ownerID: "plugin-a") == nil)
        // 仍可正常写入。
        store.saveWidth(280, ownerID: "plugin-a")
        #expect(store.loadWidth(ownerID: "plugin-a") == 280)
    }

    @Test("负值或零的磁盘值视为无效")
    func nonPositiveStoredValueIsInvalid() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rail-width-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("width.plist")
        let data = try? PropertyListSerialization.data(
            fromPropertyList: ["plugin-a": -5.0],
            format: .binary,
            options: 0
        )
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data?.write(to: url)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileRailViewWidthStore(fileURL: url)

        #expect(store.loadWidth(ownerID: "plugin-a") == nil)
    }
}
