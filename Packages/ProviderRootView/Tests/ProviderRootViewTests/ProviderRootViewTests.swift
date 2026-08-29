import Combine
import ProviderChatSection
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

    @Test("DefaultRootViewProvider 无工具栏时返回根视图")
    func defaultProviderReturnsRootViewWithoutToolbar() {
        let provider = DefaultRootViewProvider()

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("ChatSection 可见性同步到 trailing pane")
    func trailingPaneFollowsChatSectionVisibility() async {
        let chat = DefaultChatSectionProviding()
        let pane = RootTrailingPane(id: "chat", content: AnyView(Text("chat")))
        pane.bindVisibility(to: chat)

        #expect(pane.isVisible)
        chat.setVisible(false)
        await Task.yield()
        #expect(!pane.isVisible)
        chat.setVisible(true)
        await Task.yield()
        #expect(pane.isVisible)
    }

    @Test("Rail 可见性绑定到根布局")
    func railVisibilityFollowsPublisher() async {
        let provider = DefaultRootViewProvider()
        let visibility = CurrentValueSubject<Bool, Never>(true)

        provider.bindRailViewVisibility(to: visibility.eraseToAnyPublisher())
        #expect(provider.isRailViewVisible)

        visibility.send(false)
        await Task.yield()
        #expect(!provider.isRailViewVisible)

        visibility.send(true)
        await Task.yield()
        #expect(provider.isRailViewVisible)
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
            @Published var toolbarView: AnyView?
            @Published var activityBarView: AnyView?
            @Published var railView: AnyView?
            @Published var contentHeaderView: AnyView?
            @Published var contentView: AnyView?
            @Published var contentFooterView: AnyView?
            @Published var trailingPane: RootTrailingPane?

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

        provider.setContentFooterView(nil)
        #expect(!provider.hasActiveContent)
    }

    // MARK: - 注入守卫（值相同则跳过赋值，避免视图更新期间发布 objectWillChange）

    /// 订阅 objectWillChange 并返回发送次数计数。
    private func makeChangeCounter(for provider: DefaultRootViewProvider) -> (() -> Int, AnyCancellable) {
        var count = 0
        let cancellable = provider.objectWillChange.sink { _ in
            count += 1
        }
        return ({ count }, cancellable)
    }

    @Test("重复注入相同类型视图时跳过赋值（不发布 objectWillChange）")
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
        withExtendedLifetime(cancellable) {}
    }

    @Test("注入状态变化（nil ↔ 非 nil）时正常更新（发布 objectWillChange）")
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
        withExtendedLifetime(cancellable) {}
    }

    @Test("重复注入 nil 时跳过赋值（不发布 objectWillChange）")
    func repeatedNilInjectionSkipsPublish() {
        let provider = DefaultRootViewProvider()
        let (count, cancellable) = makeChangeCounter(for: provider)

        provider.setToolbarView(nil)
        let afterFirst = count()
        provider.setToolbarView(nil)
        let afterSecond = count()

        #expect(afterFirst == 0)
        #expect(afterSecond == afterFirst)
        withExtendedLifetime(cancellable) {}
    }

}
