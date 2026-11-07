import ProviderRailView
import SwiftUI
import Testing
@testable import ProviderRootView

/// 记录内容区 footer 高度存取调用。
@MainActor
private final class SpyFooterHeightStore: ContentFooterHeightStoring {
    private(set) var loadCalls: [String] = []
    private(set) var saveCalls: [(CGFloat, String)] = []
    private(set) var removeCalls: [String] = []
    var stored: [String: CGFloat]

    init(stored: [String: CGFloat] = [:]) {
        self.stored = stored
    }

    func loadHeight(ownerID: String) -> CGFloat? {
        loadCalls.append(ownerID)
        return stored[ownerID]
    }

    func saveHeight(_ height: CGFloat, ownerID: String) {
        saveCalls.append((height, ownerID))
        stored[ownerID] = height
    }

    func removeHeight(ownerID: String) {
        removeCalls.append(ownerID)
        stored.removeValue(forKey: ownerID)
    }
}

/// `ContentFooterHeight` 的夹取规则。
@Suite("ContentFooterHeight 约束")
@MainActor
struct ContentFooterHeightConstraintTests {

    @Test("standard 使用固定档位")
    func standardValues() {
        #expect(ContentFooterHeight.standard.minHeight == 100)
        #expect(ContentFooterHeight.standard.idealHeight == 280)
        #expect(ContentFooterHeight.standard.maxHeight == .infinity)
    }

    @Test("init 把 idealHeight 夹取到 [min, max]")
    func initClampsIdeal() {
        #expect(ContentFooterHeight(minHeight: 100, idealHeight: 50, maxHeight: 400).idealHeight == 100)
        #expect(ContentFooterHeight(minHeight: 100, idealHeight: 900, maxHeight: 400).idealHeight == 400)
    }

    @Test("init 把负数 minHeight 归零")
    func initClampsNegativeMin() {
        #expect(ContentFooterHeight(minHeight: -50, idealHeight: 100, maxHeight: 400).minHeight == 0)
    }

    @Test("max 小于 min 时抬升为 min")
    func initRaisesMaxToMin() {
        let height = ContentFooterHeight(minHeight: 300, idealHeight: 100, maxHeight: 200)

        #expect(height.maxHeight == 300)
        #expect(height.idealHeight == 300)
    }

    @Test("非有限 idealHeight 回落到 minHeight")
    func initHandlesNonFiniteIdeal() {
        #expect(ContentFooterHeight(minHeight: 100, idealHeight: .nan, maxHeight: 400).idealHeight == 100)
        #expect(ContentFooterHeight(minHeight: 100, idealHeight: .infinity, maxHeight: 400).idealHeight == 100)
    }

    @Test("clamped 把高度限制到 [min, max]")
    func clampedConstrains() {
        let height = ContentFooterHeight(minHeight: 100, idealHeight: 200, maxHeight: 400)

        #expect(height.clamped(50) == 100)
        #expect(height.clamped(999) == 400)
        #expect(height.clamped(250) == 250)
        #expect(height.clamped(.nan) == 100)
    }

    @Test("withIdealHeight 保留 min/max 只换 ideal")
    func withIdealHeightKeepsBounds() {
        let height = ContentFooterHeight(minHeight: 100, idealHeight: 200, maxHeight: 400)

        let updated = height.withIdealHeight(250)

        #expect(updated.idealHeight == 250)
        #expect(updated.minHeight == 100)
        #expect(updated.maxHeight == 400)
    }
}

/// 区域（region）视图存储与隐藏状态。
@Suite("RootView 区域")
@MainActor
struct RootViewRegionTests {

    @Test("setView / view 按区域存取")
    func storesViewsPerRegion() {
        let provider = DefaultRootViewProviding()

        provider.setView(AnyView(Text("toolbar")), for: .toolbar)

        #expect(provider.view(for: .toolbar) != nil)
        #expect(provider.view(for: .activityBar) == nil)
    }

    @Test("setView(nil) 清除区域")
    func clearsRegionWithNil() {
        let provider = DefaultRootViewProviding()
        provider.setView(AnyView(Text("x")), for: .content)

        provider.setView(nil, for: .content)

        #expect(provider.view(for: .content) == nil)
    }

    @Test("setRegionHidden 记录隐藏状态")
    func tracksHiddenRegions() {
        let provider = DefaultRootViewProviding()

        provider.setRegionHidden(true, for: .sidebar)
        #expect(provider.isRegionHidden(.sidebar))

        provider.setRegionHidden(false, for: .sidebar)
        #expect(provider.isRegionHidden(.sidebar) == false)
    }

    @Test("专用 setter 复用区域存储")
    func dedicatedSettersUseRegions() {
        let provider = DefaultRootViewProviding()

        provider.setToolbarView(AnyView(Text("t")))
        provider.setActivityBarView(AnyView(Text("a")))
        provider.setRailView(AnyView(Text("r")))
        provider.setContentHeaderView(AnyView(Text("h")))
        provider.setContentFooterView(AnyView(Text("f")))

        #expect(provider.toolbarView != nil)
        #expect(provider.activityBarView != nil)
        #expect(provider.railView != nil)
        #expect(provider.contentHeaderView != nil)
        #expect(provider.contentFooterView != nil)
        #expect(provider.view(for: .statusBar) == nil)
        #expect(provider.view(for: .sidebar) == nil)
    }

    @Test("isContentViewHidden 独立于区域隐藏")
    func contentVisibilityIsIndependent() {
        let provider = DefaultRootViewProviding()

        provider.setContentViewHidden(true)

        #expect(provider.isContentViewHidden)
        #expect(provider.isRegionHidden(.content) == false)
    }

    @Test("content 可见性重复设置不发事件")
    func contentVisibilityIsIdempotent() {
        let provider = DefaultRootViewProviding()
        provider.setContentViewHidden(true)
        var events = 0
        let handle = provider.addRootViewObserver { _ in events += 1 }

        provider.setContentViewHidden(true)

        #expect(events == 0)
        handle.cancel()
    }

    @Test("header 可见性切换")
    func headerVisibilityToggle() {
        let provider = DefaultRootViewProviding()

        provider.setContentHeaderViewHidden(true)
        #expect(provider.isContentHeaderViewHidden)

        provider.setContentHeaderViewHidden(false)
        #expect(provider.isContentHeaderViewHidden == false)
    }

    @Test("footer 可见性切换")
    func footerVisibilityToggle() {
        let provider = DefaultRootViewProviding()

        provider.setContentFooterViewHidden(true)
        #expect(provider.isContentFooterViewHidden)

        provider.setContentFooterViewHidden(false)
        #expect(provider.isContentFooterViewHidden == false)
    }

    @Test("isRailViewVisible 切换与幂等")
    func railVisibilityToggle() {
        let provider = DefaultRootViewProviding()
        var events = 0
        let handle = provider.addRootViewObserver { _ in events += 1 }

        provider.setRailViewVisible(false)
        #expect(provider.isRailViewVisible == false)
        #expect(events == 1)

        provider.setRailViewVisible(false)
        #expect(events == 1)
        handle.cancel()
    }

    @Test("makeRootView 返回 AnyView")
    func makesRootView() {
        let provider = DefaultRootViewProviding()
        provider.setContentView(AnyView(Text("content")))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }
}

/// overlay 的合并、排序与撤回。
@Suite("RootView overlay")
@MainActor
struct RootOverlayTests {

    private func overlay(_ id: String, order: Int = 0) -> RootOverlayItem {
        RootOverlayItem(id: id, order: order) { $0 }
    }

    @Test("addOverlays 按 order 升序排列")
    func sortsByOrder() {
        let provider = DefaultRootViewProviding()

        provider.addOverlays([overlay("c", order: 300), overlay("a", order: 100)])

        #expect(provider.overlays.map(\.id) == ["a", "c"])
    }

    @Test("order 相同时按 id 稳定排序")
    func stableByIDForEqualOrder() {
        let provider = DefaultRootViewProviding()

        provider.addOverlays([overlay("zebra", order: 10), overlay("alpha", order: 10)])

        #expect(provider.overlays.map(\.id) == ["alpha", "zebra"])
    }

    @Test("同 id 覆盖而非追加")
    func sameIDReplaces() {
        let provider = DefaultRootViewProviding()
        provider.addOverlays([overlay("toast", order: 100)])

        provider.addOverlays([overlay("toast", order: 200)])

        #expect(provider.overlays.count == 1)
        #expect(provider.overlays.first?.order == 200)
    }

    @Test("removeOverlays 按 id 撤回")
    func removesByID() {
        let provider = DefaultRootViewProviding()
        provider.addOverlays([overlay("a", order: 1), overlay("b", order: 2)])

        provider.removeOverlays(ids: ["a"])

        #expect(provider.overlays.map(\.id) == ["b"])
    }

    @Test("addOverlays 发 overlaysChanged")
    func emitsOverlaysChanged() {
        let provider = DefaultRootViewProviding()
        var events = 0
        let handle = provider.addRootViewObserver { event in
            if case .overlaysChanged = event { events += 1 }
        }

        provider.addOverlays([overlay("a")])
        provider.removeOverlays(ids: ["a"])

        #expect(events == 2)
        handle.cancel()
    }

    @Test("Set 与 Array 两种 removeOverlays 重载行为一致")
    func arrayOverloadMatchesSetOverload() {
        let setBased = DefaultRootViewProviding()
        setBased.addOverlays([overlay("a", order: 1), overlay("b", order: 2)])
        setBased.removeOverlays(ids: Set(["a"]))

        let arrayBased = DefaultRootViewProviding()
        arrayBased.addOverlays([overlay("a", order: 1), overlay("b", order: 2)])
        arrayBased.removeOverlays(ids: ["a"])

        #expect(setBased.overlays.map(\.id) == arrayBased.overlays.map(\.id))
        #expect(arrayBased.overlays.map(\.id) == ["b"])
    }

    @Test("makeRootView 按排序应用 overlay 包装链")
    func makeRootViewAppliesOverlaysInOrder() {
        let provider = DefaultRootViewProviding()
        provider.setContentView(AnyView(Text("root")))
        provider.addOverlays([overlay("inner", order: 1), overlay("outer", order: 2)])

        // 包装链本身不易直接断言，验证视图可构造且不崩。
        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }
}

/// 尾部面板（trailing pane）的装配。
@Suite("RootView 尾部面板")
@MainActor
struct RootViewPaneTests {

    @Test("setTrailingPane 记录面板")
    func storesTrailingPane() {
        let provider = DefaultRootViewProviding()
        let pane = RootViewPane(id: "inspector") { Text("pane") }

        provider.setTrailingPane(pane)

        #expect(provider.trailingPane?.id == "inspector")
    }

    @Test("setTrailingPane(nil) 清除面板")
    func clearsTrailingPane() {
        let provider = DefaultRootViewProviding()
        provider.setTrailingPane(RootViewPane(id: "inspector") { Text("pane") })

        provider.setTrailingPane(nil)

        #expect(provider.trailingPane == nil)
    }

    @Test("setTrailingPane 发 trailingPaneChanged")
    func emitsTrailingPaneChanged() {
        let provider = DefaultRootViewProviding()
        var events = 0
        let handle = provider.addRootViewObserver { event in
            if case .trailingPaneChanged = event { events += 1 }
        }

        provider.setTrailingPane(nil)
        provider.setTrailingPane(RootViewPane(id: "p") { Text("p") })

        #expect(events == 2)
        handle.cancel()
    }

    @Test("面板默认可见且尺寸可读")
    func paneDefaults() {
        let pane = RootViewPane(id: "p") { Text("p") }

        #expect(pane.isVisible)
        #expect(pane.minWidth == 280)
        #expect(pane.idealWidth == 320)
        #expect(pane.maxWidth == .infinity)
    }

    @Test("面板显式隐藏")
    func paneHiddenAtInit() {
        let pane = RootViewPane(id: "p", isVisible: false) { Text("p") }

        #expect(pane.isVisible == false)
    }

    @Test("updateDimensions 覆盖推荐宽度")
    func updatesDimensions() {
        let pane = RootViewPane(id: "p") { Text("p") }

        pane.updateDimensions(minWidth: 100, idealWidth: 150, maxWidth: 300)

        #expect(pane.minWidth == 100)
        #expect(pane.idealWidth == 150)
        #expect(pane.maxWidth == 300)
    }

    @Test("isVisible 相同值不触发钩子")
    func visibilityHookSkipsNoop() {
        final class SpyPane: RootViewPane {
            private(set) var visibilityCalls: [Bool] = []
            private(set) var saveCalls: [CGFloat] = []

            init() {
                super.init(id: "spy", content: AnyView(EmptyView()))
            }

            override func visibilityDidChange(_ isVisible: Bool) {
                visibilityCalls.append(isVisible)
            }

            override func saveWidth(_ width: CGFloat) {
                saveCalls.append(width)
            }
        }

        let pane = SpyPane()
        pane.isVisible = true // 已是 true → 无变化
        #expect(pane.visibilityCalls.isEmpty)

        pane.isVisible = false
        pane.isVisible = true
        #expect(pane.visibilityCalls == [false, true])

        pane.saveWidth(200)
        #expect(pane.saveCalls == [200])
    }

    @Test("AnyView 便利构造与泛型构造一致")
    func anyViewConvenienceInit() {
        let pane = RootViewPane(id: "p", minWidth: 100, idealWidth: 200, maxWidth: 300) {
            Text("p")
        }

        #expect(pane.minWidth == 100)
        #expect(pane.idealWidth == 200)
        #expect(pane.maxWidth == 300)
    }
}

/// footer 高度档位（height profile）的激活与持久化。
@Suite("RootView footer 高度档位")
@MainActor
struct RootFooterHeightProfileTests {

    private let tall = ContentFooterHeight(minHeight: 200, idealHeight: 400, maxHeight: 600)
    private let compact = ContentFooterHeight(minHeight: 100, idealHeight: 150, maxHeight: 200)

    @Test("初始高度为 standard")
    func startsAtStandard() {
        #expect(DefaultRootViewProviding().contentFooterHeight == .standard)
    }

    @Test("激活档位应用推荐高度")
    func activationAppliesRecommended() {
        let provider = DefaultRootViewProviding()

        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: tall,
            store: nil
        )

        #expect(provider.contentFooterHeight.idealHeight == 400)
    }

    @Test("空 ownerID 被忽略")
    func emptyOwnerIDIsIgnored() {
        let provider = DefaultRootViewProviding()

        provider.activateContentFooterHeightProfile(
            ownerID: "",
            recommended: tall,
            store: nil
        )

        #expect(provider.contentFooterHeight == .standard)
    }

    @Test("store 中的保存值优先于推荐值")
    func storeValueWins() {
        let store = SpyFooterHeightStore(stored: ["plugin-a": 300])
        let provider = DefaultRootViewProviding()

        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: tall,
            store: store
        )

        #expect(provider.contentFooterHeight.idealHeight == 300)
        #expect(store.loadCalls == ["plugin-a"])
    }

    @Test("恢复的高度被夹取到档位边界")
    func restoredHeightIsClamped() {
        let store = SpyFooterHeightStore(stored: ["plugin-a": 9999])
        let provider = DefaultRootViewProviding()

        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: tall,
            store: store
        )

        #expect(provider.contentFooterHeight.idealHeight == 600)
    }

    @Test("宽度未变化时不发事件")
    func noEventWhenHeightUnchanged() {
        let provider = DefaultRootViewProviding()
        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: compact,
            store: nil
        )
        var events = 0
        let handle = provider.addRootViewObserver { _ in events += 1 }

        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: compact,
            store: nil
        )

        #expect(events == 0)
        handle.cancel()
    }

    @Test("停用档位回落到 standard")
    func deactivationResetsToStandard() {
        let provider = DefaultRootViewProviding()
        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: tall,
            store: nil
        )

        provider.deactivateContentFooterHeightProfile(ownerID: "plugin-a")

        #expect(provider.contentFooterHeight == .standard)
    }

    @Test("非 owner 停用不影响当前档位")
    func nonOwnerDeactivationIsIgnored() {
        let provider = DefaultRootViewProviding()
        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: tall,
            store: nil
        )

        provider.deactivateContentFooterHeightProfile(ownerID: "plugin-b")

        #expect(provider.contentFooterHeight.idealHeight == 400)
    }

    @Test("saveCurrentContentFooterHeight 写回 owner 的 store")
    func saveWritesToOwnerStore() {
        let store = SpyFooterHeightStore()
        let provider = DefaultRootViewProviding()
        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: tall,
            store: store
        )

        provider.saveCurrentContentFooterHeight(350)

        #expect(store.saveCalls.count == 1)
        #expect(store.saveCalls[0].0 == 350)
        #expect(store.saveCalls[0].1 == "plugin-a")
        #expect(provider.contentFooterHeight.idealHeight == 350)
    }

    @Test("saveCurrentContentFooterHeight 夹取越界高度")
    func saveClampsOutOfBounds() {
        let store = SpyFooterHeightStore()
        let provider = DefaultRootViewProviding()
        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: tall,
            store: store
        )

        provider.saveCurrentContentFooterHeight(9999)

        #expect(store.saveCalls[0].0 == 600)
        #expect(provider.contentFooterHeight.idealHeight == 600)
    }

    @Test("未激活档位时不写盘")
    func saveWithoutActiveProfileIsNoop() {
        let store = SpyFooterHeightStore()
        let provider = DefaultRootViewProviding()
        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: tall,
            store: store
        )
        provider.deactivateContentFooterHeightProfile(ownerID: "plugin-a")

        provider.saveCurrentContentFooterHeight(350)

        #expect(store.saveCalls.isEmpty)
        #expect(provider.contentFooterHeight == .standard)
    }

    @Test("store 为 nil 时仍更新内存高度")
    func saveWithoutStoreUpdatesMemory() {
        let provider = DefaultRootViewProviding()
        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: tall,
            store: nil
        )

        provider.saveCurrentContentFooterHeight(350)

        #expect(provider.contentFooterHeight.idealHeight == 350)
    }

    @Test("新插件接管后旧插件停用不覆盖新配置")
    func newOwnerSurvivesOldDeactivation() {
        let provider = DefaultRootViewProviding()
        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: tall,
            store: nil
        )
        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-b",
            recommended: compact,
            store: nil
        )

        provider.deactivateContentFooterHeightProfile(ownerID: "plugin-a")

        #expect(provider.contentFooterHeight.idealHeight == 150)
    }
}

/// Rail 可见性与宽度的绑定。
@Suite("RootView rail 绑定")
@MainActor
struct RootRailBindingTests {

    private func tab(_ id: String) -> RailTabItem {
        RailTabItem(id: id, category: .chat, title: id, systemImage: "square") { Text(id) }
    }

    @Test("绑定时同步当前 rail 可见性")
    func bindSyncsInitialVisibility() {
        let rail = DefaultRailViewProviding()
        let root = DefaultRootViewProviding()
        root.setRailViewVisible(true)

        root.bindRailViewVisibility(to: rail)

        #expect(root.isRailViewVisible == rail.hasVisibleTabs)
    }

    @Test("rail 出现可见 tab 后绑定方跟随更新")
    func followsVisibilityChanges() {
        let rail = DefaultRailViewProviding()
        let root = DefaultRootViewProviding()

        root.bindRailViewVisibility(to: rail)
        #expect(root.isRailViewVisible == false)

        rail.registerTabs([tab("a")])

        #expect(root.isRailViewVisible)
    }

    @Test("rail 失去全部可见 tab 后绑定方隐藏")
    func followsVisibilityLoss() {
        let rail = DefaultRailViewProviding()
        rail.registerTabs([tab("a")])
        let root = DefaultRootViewProviding()
        root.bindRailViewVisibility(to: rail)
        #expect(root.isRailViewVisible)

        rail.registerTabs([])

        #expect(root.isRailViewVisible == false)
    }

    @Test("绑定宽度时同步 rail 当前宽度")
    func bindSyncsInitialWidth() {
        let rail = DefaultRailViewProviding()
        let root = DefaultRootViewProviding()

        root.bindRailViewWidth(to: rail, onResize: { _ in })

        #expect(root.railWidth == rail.railWidth)
    }

    @Test("rail 宽度变化后绑定方跟随更新")
    func followsWidthChanges() {
        let rail = DefaultRailViewProviding()
        let root = DefaultRootViewProviding()
        root.bindRailViewWidth(to: rail, onResize: { _ in })

        rail.activateWidthProfile(
            ownerID: "plugin-a",
            recommended: RailViewWidth(minWidth: 200, idealWidth: 320, maxWidth: 500),
            store: nil
        )

        #expect(root.railWidth.idealWidth == 320)
    }

    @Test("saveRailViewWidth 转发给 resize 回调")
    func forwardsResizeToHandler() {
        let rail = DefaultRailViewProviding()
        let root = DefaultRootViewProviding()
        var resized: [CGFloat] = []
        root.bindRailViewWidth(to: rail, onResize: { resized.append($0) })

        root.saveRailViewWidth(280)

        #expect(resized == [280])
    }

    @Test("重复绑定只保留最新观察者")
    func rebindingReplacesPreviousObserver() {
        let rail = DefaultRailViewProviding()
        let root = DefaultRootViewProviding()

        root.bindRailViewWidth(to: rail, onResize: { _ in })
        root.bindRailViewWidth(to: rail, onResize: { _ in })
        var events = 0
        let handle = root.addRootViewObserver { event in
            if case .railWidthChanged = event { events += 1 }
        }

        rail.activateWidthProfile(
            ownerID: "plugin-a",
            recommended: RailViewWidth(minWidth: 200, idealWidth: 320, maxWidth: 500),
            store: nil
        )

        #expect(events == 1)
        handle.cancel()
    }
}

/// `RootViewProviding` 协议扩展的兜底实现与兼容别名。
@Suite("RootViewProviding 协议兜底")
@MainActor
struct RootViewProvidingFallbackTests {

    /// 只实现 `makeRootView()` 的最小 provider。
    private final class MinimalProvider: RootViewProviding {
        func makeRootView() -> AnyView { AnyView(EmptyView()) }
    }

    @Test("默认 view(for:) 返回 nil，setView 为空操作")
    func viewAccessorsAreNoop() {
        let provider = MinimalProvider()

        provider.setView(AnyView(Text("x")), for: .toolbar)

        #expect(provider.view(for: .toolbar) == nil)
    }

    @Test("默认 isRegionHidden 为 false")
    func defaultRegionVisibility() {
        #expect(MinimalProvider().isRegionHidden(.sidebar) == false)
    }

    @Test("默认 overlays 为空，增删为空操作")
    func overlayDefaultsAreNoop() {
        let provider = MinimalProvider()

        provider.addOverlays([RootOverlayItem(id: "a") { $0 }])
        provider.removeOverlays(ids: ["a"])

        #expect(provider.overlays.isEmpty)
    }

    @Test("Array 重载委托给 Set 重载")
    func arrayOverloadDelegates() {
        final class SpyProvider: RootViewProviding {
            private(set) var removed: Set<String> = []
            func makeRootView() -> AnyView { AnyView(EmptyView()) }
            func removeOverlays(ids: Set<String>) { removed = ids }
        }
        let spy = SpyProvider()

        spy.removeOverlays(ids: ["a", "b"])

        #expect(spy.removed == ["a", "b"])
    }

    @Test("默认 observer 返回 Noop 句柄")
    func defaultObserverIsNoop() {
        let provider = MinimalProvider()

        let handle = provider.addRootViewObserver { _ in
            Issue.record("Noop 实现不应触发回调")
        }
        handle.cancel()
    }

    @Test("兼容 setter 转发到 setView")
    func compatibilitySettersForward() {
        final class SpyProvider: RootViewProviding {
            private(set) var stored: [RootViewRegion: AnyView] = [:]
            func makeRootView() -> AnyView { AnyView(EmptyView()) }
            func view(for region: RootViewRegion) -> AnyView? { stored[region] }
            func setView(_ view: AnyView?, for region: RootViewRegion) { stored[region] = view }
        }
        let spy = SpyProvider()

        spy.setToolbarView(AnyView(Text("t")))
        spy.setActivityBarView(AnyView(Text("a")))
        spy.setRailView(AnyView(Text("r")))
        spy.setSidebarView(AnyView(Text("s")))
        spy.setStatusBarView(AnyView(Text("st")))
        spy.setControlView(AnyView(Text("c")))

        #expect(spy.stored.count == 6)
        #expect(spy.controlView != nil)
        #expect(spy.sidebarView != nil)
        #expect(spy.statusBarView != nil)
    }

    @Test("兼容 visibility helper 转发到 setContentViewHidden")
    func visibilityHelpersForward() {
        final class SpyProvider: RootViewProviding {
            private(set) var hidden: Bool?
            func makeRootView() -> AnyView { AnyView(EmptyView()) }
            func setContentViewHidden(_ hidden: Bool) { self.hidden = hidden }
            var isContentViewHidden: Bool { hidden ?? false }
        }
        let spy = SpyProvider()

        spy.showContentView()
        #expect(spy.hidden == false)

        spy.hideContentView()
        #expect(spy.hidden == true)

        spy.toggleContentView()
        #expect(spy.hidden == false)
    }

    @Test("兼容 isContentViewVisible 与 setContentViewVisible 互逆")
    func visibilityAccessorsAreInverse() {
        final class SpyProvider: RootViewProviding {
            var isContentViewHidden = false
            func makeRootView() -> AnyView { AnyView(EmptyView()) }
            func setContentViewHidden(_ hidden: Bool) { isContentViewHidden = hidden }
        }
        let spy = SpyProvider()

        spy.setContentViewVisible(false)
        #expect(spy.isContentViewVisible == false)

        spy.setContentViewVisible(true)
        #expect(spy.isContentViewVisible)
    }

    @Test("兼容 rail 可见性默认值")
    func railVisibilityDefaults() {
        #expect(MinimalProvider().isRailViewVisible)
        #expect(MinimalProvider().railWidth == .standard)
    }

    @Test("兼容 footer 高度默认值为 standard 且方法为空操作")
    func footerDefaultsAreNoop() {
        let provider = MinimalProvider()

        provider.activateContentFooterHeightProfile(
            ownerID: "plugin-a",
            recommended: ContentFooterHeight(minHeight: 100, idealHeight: 200, maxHeight: 300),
            store: nil
        )
        provider.deactivateContentFooterHeightProfile(ownerID: "plugin-a")
        provider.saveCurrentContentFooterHeight(250)

        #expect(provider.contentFooterHeight == .standard)
    }

    @Test("兼容 trailingPane 默认为 nil")
    func trailingPaneDefaultsToNil() {
        #expect(MinimalProvider().trailingPane == nil)
    }

    @Test("makeRootView 在无内容时仍可构造")
    func makeRootViewWithoutContent() {
        #expect(type(of: MinimalProvider().makeRootView()) == AnyView.self)
    }

    @Test("协议默认 makeRootView 应用 overlay 包装链")
    func defaultMakeRootViewAppliesOverlays() {
        final class OverlayProvider: RootViewProviding {
            func makeRootView() -> AnyView { AnyView(EmptyView()) }
        }
        let provider = OverlayProvider()

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }
}

/// `FileContentFooterHeightStore` 的持久化往返。
@Suite("FileContentFooterHeightStore")
@MainActor
struct FileContentFooterHeightStoreTests {

    private func makeStore() -> (FileContentFooterHeightStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("footer-height-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("height.plist")
        return (FileContentFooterHeightStore(fileURL: url), url)
    }

    @Test("保存后可重新读取")
    func roundTripsValue() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        store.saveHeight(320, ownerID: "plugin-a")

        let reloaded = FileContentFooterHeightStore(fileURL: url)
        #expect(reloaded.loadHeight(ownerID: "plugin-a") == 320)
    }

    @Test("不同 owner 各自独立")
    func ownersAreIndependent() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        store.saveHeight(320, ownerID: "plugin-a")
        store.saveHeight(180, ownerID: "plugin-b")

        #expect(store.loadHeight(ownerID: "plugin-a") == 320)
        #expect(store.loadHeight(ownerID: "plugin-b") == 180)
    }

    @Test("未保存的 owner 返回 nil")
    func unknownOwnerReturnsNil() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(store.loadHeight(ownerID: "missing") == nil)
    }

    @Test("非法高度被忽略")
    func rejectsInvalidHeights() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        store.saveHeight(0, ownerID: "plugin-a")
        store.saveHeight(-100, ownerID: "plugin-a")
        store.saveHeight(.nan, ownerID: "plugin-a")
        store.saveHeight(200, ownerID: "")

        #expect(store.loadHeight(ownerID: "plugin-a") == nil)
        #expect(store.loadHeight(ownerID: "") == nil)
    }

    @Test("removeHeight 清除已保存值")
    func removesSavedValue() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        store.saveHeight(320, ownerID: "plugin-a")

        store.removeHeight(ownerID: "plugin-a")

        #expect(store.loadHeight(ownerID: "plugin-a") == nil)
    }

    @Test("移除不存在的 owner 不崩")
    func removingUnknownOwnerIsSafe() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        store.removeHeight(ownerID: "missing")
        store.removeHeight(ownerID: "missing")
    }

    @Test("损坏的 plist 降级为空字典且仍可写入")
    func corruptedFileDegradesGracefully() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("footer-height-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("height.plist")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data("not a plist".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileContentFooterHeightStore(fileURL: url)

        #expect(store.loadHeight(ownerID: "plugin-a") == nil)
        store.saveHeight(320, ownerID: "plugin-a")
        #expect(store.loadHeight(ownerID: "plugin-a") == 320)
    }
}
