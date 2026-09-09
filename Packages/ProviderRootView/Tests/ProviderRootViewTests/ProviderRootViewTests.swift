import ProviderChatSection
import ProviderRailView
import SwiftUI
import Testing
@testable import ProviderRootView

/// RootViewProviding 协议与默认实现的基础验证。
@Suite("ProviderRootView")
@MainActor
struct ProviderRootViewTests {

    @Test("根叠层按顺序注册且可独立撤回")
    func rootOverlaysRegisterAndRemoveByID() {
        let provider = DefaultRootViewProvider()
        provider.addOverlays([
            RootOverlayItem(id: "later", order: 20) { $0 },
            RootOverlayItem(id: "first", order: 10) { $0 },
            RootOverlayItem(id: "first", order: 0) { $0 },
        ])

        #expect(provider.overlays.map(\.id) == ["first", "later"])
        #expect(type(of: provider.makeRootView()) == AnyView.self)

        provider.removeOverlays(ids: ["first"])
        #expect(provider.overlays.map(\.id) == ["later"])
    }

    @Test("根视图状态变化会发布类型化观察事件")
    func rootViewChangesAreObservable() {
        let provider = DefaultRootViewProvider()
        var events: [String] = []
        let handle = provider.addRootViewObserver { event in
            switch event {
            case .overlaysChanged:
                events.append("overlays")
            case .toolbarViewChanged:
                events.append("toolbar")
            case let .railViewVisibilityChanged(visible):
                events.append("rail:\(visible)")
            case let .contentViewVisibilityChanged(hidden):
                events.append("content-hidden:\(hidden)")
            default:
                break
            }
        }

        provider.addOverlays([RootOverlayItem(id: "search") { $0 }])
        provider.setToolbarView(AnyView(Text("toolbar")))
        provider.setRailViewVisible(false)
        provider.setContentViewHidden(true)

        #expect(events == ["overlays", "toolbar", "rail:false", "content-hidden:true"])

        handle.cancel()
        provider.setContentViewHidden(false)
        #expect(events == ["overlays", "toolbar", "rail:false", "content-hidden:true"])
    }

    @Test("DefaultRootViewProvider 无工具栏时返回根视图")
    func defaultProviderReturnsRootViewWithoutToolbar() {
        let provider = DefaultRootViewProvider()

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("ChatSection 可见性同步到 trailing pane")
    func trailingPaneFollowsChatSectionVisibility() {
        let chat = DefaultChatSectionProviding()
        let pane = RootTrailingPane(id: "chat", content: AnyView(Text("chat")))
        pane.bindVisibility(to: chat)

        #expect(pane.isVisible)
        chat.setVisible(false)
        #expect(!pane.isVisible)
        chat.setVisible(true)
        #expect(pane.isVisible)
    }

    @Test("Trailing pane 状态变化会发布类型化观察事件")
    func trailingPaneChangesAreObservable() {
        let pane = RootTrailingPane(id: "chat", content: AnyView(Text("chat")))
        var events: [String] = []
        let handle = pane.addObserver { event in
            if case let .visibilityChanged(visible) = event {
                events.append("visible:\(visible)")
            }
        }

        pane.isVisible = false
        #expect(events == ["visible:false"])

        handle.cancel()
        pane.isVisible = true
        #expect(events == ["visible:false"])
    }

    @Test("重新绑定 ChatSection 显隐时取消旧观察者")
    func rebindingTrailingPaneVisibilityCancelsPreviousObserver() {
        let firstChat = DefaultChatSectionProviding()
        let secondChat = DefaultChatSectionProviding()
        let pane = RootTrailingPane(id: "chat", content: AnyView(Text("chat")))

        firstChat.setVisible(false)
        pane.bindVisibility(to: firstChat)
        #expect(!pane.isVisible)

        secondChat.setVisible(true)
        pane.bindVisibility(to: secondChat)
        #expect(pane.isVisible)

        firstChat.setVisible(true)
        #expect(pane.isVisible)

        secondChat.setVisible(false)
        #expect(!pane.isVisible)
    }

    @Test("ChatSection 宽度绑定到 trailing pane 并转发用户拖拽")
    func trailingPaneFollowsChatSectionWidthAndForwardsResize() {
        let chat = DefaultChatSectionProviding()
        let pane = RootTrailingPane(
            id: "chat",
            width: chat.chatSectionWidth,
            content: AnyView(Text("chat"))
        )
        var resizedWidth: CGFloat?
        pane.bindWidth(
            to: chat,
            onResize: { resizedWidth = $0 }
        )

        let customWidth = ChatSectionWidth(minWidth: 280, idealWidth: 400, maxWidth: 560)
        chat.activateWidthProfile(ownerID: "plugin.chat", recommended: customWidth)
        #expect(pane.width == customWidth)

        pane.saveWidth(460)
        #expect(resizedWidth == 460)
    }

    @Test("重新绑定 ChatSection 宽度时取消旧观察者")
    func rebindingTrailingPaneWidthCancelsPreviousObserver() {
        let firstChat = DefaultChatSectionProviding()
        let secondChat = DefaultChatSectionProviding()
        let pane = RootTrailingPane(id: "chat", content: AnyView(Text("chat")))

        let firstWidth = ChatSectionWidth(minWidth: 280, idealWidth: 380, maxWidth: 520)
        firstChat.activateWidthProfile(ownerID: "plugin.first", recommended: firstWidth)
        pane.bindWidth(to: firstChat, onResize: { _ in })
        #expect(pane.width == firstWidth)

        let secondWidth = ChatSectionWidth(minWidth: 280, idealWidth: 420, maxWidth: 560)
        secondChat.activateWidthProfile(ownerID: "plugin.second", recommended: secondWidth)
        pane.bindWidth(to: secondChat, onResize: { _ in })
        #expect(pane.width == secondWidth)

        firstChat.saveCurrentWidth(500)
        #expect(pane.width == secondWidth)

        secondChat.saveCurrentWidth(460)
        #expect(pane.width == secondWidth.withIdealWidth(460))
    }

    @Test("Rail 可见性绑定到根布局")
    func railVisibilityFollowsProvider() {
        let provider = DefaultRootViewProvider()
        let rail = DefaultRailViewProviding()

        provider.bindRailViewVisibility(to: rail)
        #expect(!provider.isRailViewVisible)

        rail.registerTabs([
            RailTabItem(id: "rail", category: .general, title: "Rail", systemImage: "sidebar") { Text("Rail") },
        ])
        #expect(provider.isRailViewVisible)

        rail.removeTabs(ids: ["rail"])
        #expect(!provider.isRailViewVisible)
    }

    @Test("重新绑定 Rail 显隐时取消旧观察者")
    func rebindingRailVisibilityCancelsPreviousObserver() {
        let provider = DefaultRootViewProvider()
        let firstRail = DefaultRailViewProviding()
        let secondRail = DefaultRailViewProviding()

        firstRail.registerTabs([
            RailTabItem(id: "first", category: .general, title: "First", systemImage: "1.circle") { Text("First") },
        ])
        provider.bindRailViewVisibility(to: firstRail)
        #expect(provider.isRailViewVisible)

        provider.bindRailViewVisibility(to: secondRail)
        #expect(!provider.isRailViewVisible)

        firstRail.removeTabs(ids: ["first"])
        #expect(!provider.isRailViewVisible)

        secondRail.registerTabs([
            RailTabItem(id: "second", category: .general, title: "Second", systemImage: "2.circle") { Text("Second") },
        ])
        #expect(provider.isRailViewVisible)
    }

    @Test("Rail 宽度绑定并转发用户拖拽回调")
    func railWidthFollowsProviderAndForwardsResize() async {
        let provider = DefaultRootViewProvider()
        let rail = DefaultRailViewProviding()
        var resizedWidth: CGFloat?

        provider.bindRailViewWidth(
            to: rail,
            onResize: { resizedWidth = $0 }
        )
        #expect(provider.railWidth == .standard)

        let customWidth = RailViewWidth(minWidth: 240, idealWidth: 360, maxWidth: 480)
        rail.activateWidthProfile(ownerID: "plugin.rail", recommended: customWidth)
        await Task.yield()
        #expect(provider.railWidth == customWidth)

        provider.saveRailViewWidth(420)
        #expect(resizedWidth == 420)
    }

    @Test("Content Footer 高度 profile 支持恢复约束并保存拖拽结果")
    func contentFooterHeightProfileRestoresAndSaves() {
        let provider = DefaultRootViewProvider()
        let recommended = ContentFooterHeight(minHeight: 120, idealHeight: 280, maxHeight: 520)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderRootViewTests-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        provider.activateContentFooterHeightProfile(
            ownerID: "plugin.editor-preview",
            recommended: recommended,
            store: FileContentFooterHeightStore(fileURL: fileURL)
        )
        #expect(provider.contentFooterHeight == recommended)

        provider.saveCurrentContentFooterHeight(460)
        #expect(provider.contentFooterHeight.idealHeight == 460)

        let reloadedProvider = DefaultRootViewProvider()
        reloadedProvider.activateContentFooterHeightProfile(
            ownerID: "plugin.editor-preview",
            recommended: recommended,
            store: FileContentFooterHeightStore(fileURL: fileURL)
        )
        #expect(reloadedProvider.contentFooterHeight.idealHeight == 460)

        provider.saveCurrentContentFooterHeight(80)
        #expect(provider.contentFooterHeight.idealHeight == 120)
    }

    @Test("没有容器时可通过 trailing pane 渲染")
    func visibleTrailingPaneCountsAsActiveContentWithoutContainer() {
        let provider = DefaultRootViewProvider()
        let pane = RootTrailingPane(id: "chat", content: AnyView(Text("chat")))
        provider.setTrailingPane(pane)

        #expect(provider.hasActiveContent)
        pane.isVisible = false
        #expect(!provider.hasActiveContent)
    }

    @Test("注入工具栏后返回根视图")
    func defaultProviderReturnsRootViewWithToolbar() {
        let provider = DefaultRootViewProvider()
        provider.setToolbarView(AnyView(Text("toolbar")))

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("注入 ActivityBar 后返回根视图")
    func defaultProviderReturnsRootViewWithActivityBar() {
        let provider = DefaultRootViewProvider()
        provider.setActivityBarView(AnyView(Text("activity bar")))

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("同时注入工具栏与 ActivityBar 后返回根视图")
    func defaultProviderReturnsRootViewWithToolbarAndActivityBar() {
        let provider = DefaultRootViewProvider()
        provider.setToolbarView(AnyView(Text("toolbar")))
        provider.setActivityBarView(AnyView(Text("activity bar")))

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("同时注入工具栏、ActivityBar、Rail 与内容后返回根视图")
    func defaultProviderReturnsRootViewWithAllInjections() {
        let provider = DefaultRootViewProvider()
        provider.setToolbarView(AnyView(Text("toolbar")))
        provider.setActivityBarView(AnyView(Text("activity bar")))
        provider.setRailView(AnyView(Text("rail")))
        provider.setContentHeaderView(AnyView(Text("content header")))
        provider.setContentView(AnyView(Text("content")))
        provider.setContentFooterView(AnyView(Text("content footer")))
        provider.setTrailingPane(RootTrailingPane(id: "chat", content: AnyView(Text("chat"))))

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("RootViewProviding 可作为 any RootViewProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any RootViewProviding = DefaultRootViewProvider()
        provider.setToolbarView(AnyView(Text("toolbar")))
        provider.setActivityBarView(AnyView(Text("activity bar")))
        provider.setRailView(AnyView(Text("rail")))
        provider.setContentView(AnyView(Text("content")))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        @MainActor final class CustomRootView: RootViewProviding {
            var toolbarView: AnyView?
            var activityBarView: AnyView?
            var railView: AnyView?
            var contentHeaderView: AnyView?
            var contentView: AnyView?
            var contentFooterView: AnyView?
            var trailingPane: RootTrailingPane?

            func setToolbarView(_ view: AnyView?) {
                toolbarView = view
            }

            func setActivityBarView(_ view: AnyView?) {
                activityBarView = view
            }

            func setRailView(_ view: AnyView?) {
                railView = view
            }

            func setContentHeaderView(_ view: AnyView?) {
                contentHeaderView = view
            }

            func setContentView(_ view: AnyView?) {
                contentView = view
            }

            func setContentFooterView(_ view: AnyView?) {
                contentFooterView = view
            }

            func setTrailingPane(_ pane: RootTrailingPane?) {
                trailingPane = pane
            }

            func makeRootView() -> AnyView {
                AnyView(VStack {
                    if let toolbarView { toolbarView }
                    HStack {
                        if let activityBarView { activityBarView }
                        if let railView { railView }
                        VStack {
                            if let contentHeaderView { contentHeaderView }
                            if let contentView { contentView }
                            if let contentFooterView { contentFooterView }
                        }
                        Text("custom root")
                    }
                })
            }
        }

        let provider: any RootViewProviding = CustomRootView()
        provider.setToolbarView(AnyView(Text("custom toolbar")))
        provider.setActivityBarView(AnyView(Text("custom activity bar")))
        provider.setRailView(AnyView(Text("custom rail")))
        provider.setContentHeaderView(AnyView(Text("custom content header")))
        provider.setContentView(AnyView(Text("custom content")))
        provider.setContentFooterView(AnyView(Text("custom content footer")))
        provider.setTrailingPane(RootTrailingPane(id: "custom", content: AnyView(Text("custom trailing"))))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }

    @Test("Footer 注入后被视为主内容并返回根视图")
    func contentFooterCountsAsActiveContent() {
        let provider = DefaultRootViewProvider()
        provider.setContentFooterView(AnyView(Text("content footer")))

        #expect(provider.hasActiveContent)
        #expect(type(of: provider.makeRootView()) == AnyView.self)

        provider.setContentFooterViewHidden(true)
        #expect(provider.isContentFooterViewHidden)
        #expect(!provider.hasActiveContent)

        provider.setContentFooterViewHidden(false)
        #expect(!provider.isContentFooterViewHidden)
        #expect(provider.hasActiveContent)

        provider.setContentFooterView(nil)
        #expect(!provider.hasActiveContent)
    }

    // MARK: - 注入守卫（值相同则跳过赋值，避免无意义事件）

    /// 订阅工具栏视图事件并返回发送次数计数。
    private func makeChangeCounter(for provider: DefaultRootViewProvider) -> (() -> Int, any RootViewObserverHandle) {
        var count = 0
        let handle = provider.addRootViewObserver { event in
            if case .toolbarViewChanged = event {
                count += 1
            }
        }
        return ({ count }, handle)
    }

    @Test("重复注入相同类型视图时跳过赋值（不发布类型化事件）")
    func repeatedSameTypeInjectionSkipsPublish() {
        let provider = DefaultRootViewProvider()
        let (count, cancellable) = makeChangeCounter(for: provider)

        provider.setToolbarView(AnyView(Text("toolbar")))
        let afterFirst = count()
        // 同类型视图重复注入 → 守卫跳过，不再发布。
        provider.setToolbarView(AnyView(Text("toolbar")))
        let afterSecond = count()

        #expect(afterFirst == 1)
        #expect(afterSecond == afterFirst)
        cancellable.cancel()
    }

    @Test("注入状态变化（nil ↔ 非 nil）时正常更新（发布类型化事件）")
    func valueTransitionStillPublishes() {
        let provider = DefaultRootViewProvider()
        let (count, cancellable) = makeChangeCounter(for: provider)

        provider.setToolbarView(nil)
        let afterNil = count()
        // nil → 非 nil：状态变化，正常替换。
        provider.setToolbarView(AnyView(Text("toolbar")))
        let afterInjected = count()
        // 非 nil → nil：状态变化，正常清空。
        provider.setToolbarView(nil)
        let afterCleared = count()

        #expect(afterNil == 0)
        #expect(afterInjected == 1)
        #expect(afterCleared == 2)
        cancellable.cancel()
    }

    @Test("重复注入 nil 时跳过赋值（不发布类型化事件）")
    func repeatedNilInjectionSkipsPublish() {
        let provider = DefaultRootViewProvider()
        let (count, cancellable) = makeChangeCounter(for: provider)

        provider.setToolbarView(nil)
        let afterFirst = count()
        provider.setToolbarView(nil)
        let afterSecond = count()

        #expect(afterFirst == 0)
        #expect(afterSecond == afterFirst)
        cancellable.cancel()
    }

}
