import Combine
import ProviderWorkspace
import SwiftUI
import Testing
@testable import ProviderRootView

/// RootViewProviding 协议与默认实现的基础验证。
@Suite("ProviderRootView")
@MainActor
struct ProviderRootViewTests {

    @Test("DefaultRootViewProvider 无工具栏时返回根视图")
    func defaultProviderReturnsRootViewWithoutToolbar() {
        let provider = DefaultRootViewProvider()

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
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
        provider.setContentView(AnyView(Text("content")))
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
        final class CustomRootView: RootViewProviding {
            var toolbarView: AnyView?
            var activityBarView: AnyView?
            var railView: AnyView?
            var contentView: AnyView?
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

            func setContentView(_ view: AnyView?) {
                contentView = view
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
                        if let contentView { contentView }
                        Text("custom root")
                    }
                })
            }
        }

        let provider: any RootViewProviding = CustomRootView()
        provider.setToolbarView(AnyView(Text("custom toolbar")))
        provider.setActivityBarView(AnyView(Text("custom activity bar")))
        provider.setRailView(AnyView(Text("custom rail")))
        provider.setContentView(AnyView(Text("custom content")))
        provider.setTrailingPane(RootTrailingPane(id: "custom", content: AnyView(Text("custom trailing"))))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }

    // MARK: - 显示条件（复刻旧版 AppLayoutView）

    /// 构造一个含 N 个容器的 workspace。
    private func makeWorkspace(containerCount: Int) -> DefaultWorkspaceProviding {
        let workspace = DefaultWorkspaceProviding(
            pluginDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("ProviderRootViewTests-\(UUID().uuidString)", isDirectory: true)
        )
        for index in 0..<containerCount {
            workspace.registerContainer(
                WorkspaceContainer(
                    id: "container.\(index)",
                    title: "Container \(index)",
                    systemImage: "square",
                    order: index
                ),
                ownerPluginID: "test"
            )
        }
        return workspace
    }

    @Test("ActivityBar 注入后仍返回根视图（容器数 > 1 时显示）")
    func activityBarVisibleWithMultipleContainers() {
        let provider = DefaultRootViewProvider()
        provider.setActivityBarView(AnyView(Text("activity bar")))
        provider.setWorkspaceProvider(makeWorkspace(containerCount: 2))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }

    @Test("无活跃容器时返回根视图（Welcome 占位路径）")
    func welcomePlaceholderWithoutActiveContainer() {
        let provider = DefaultRootViewProvider()
        // 有 workspace 但无活跃容器（未注册任何容器）。
        let workspace = DefaultWorkspaceProviding(
            pluginDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("ProviderRootViewTests-\(UUID().uuidString)", isDirectory: true)
        )
        provider.setWorkspaceProvider(workspace)
        provider.setContentView(AnyView(Text("content")))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }

    @Test("存在活跃容器时返回带内容区的根视图")
    func contentShownWithActiveContainer() {
        let provider = DefaultRootViewProvider()
        let workspace = makeWorkspace(containerCount: 1)
        provider.setWorkspaceProvider(workspace)
        provider.setContentView(AnyView(Text("content")))
        provider.setRailView(AnyView(Text("rail")))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
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

    @Test("重复注入相同 workspace 实例时跳过（不重复订阅/发布）")
    func repeatedWorkspaceInjectionSkipsPublish() {
        let provider = DefaultRootViewProvider()
        let workspace = makeWorkspace(containerCount: 1)
        let (count, cancellable) = makeChangeCounter(for: provider)

        provider.setWorkspaceProvider(workspace)
        let afterFirst = count()
        provider.setWorkspaceProvider(workspace)
        let afterSecond = count()

        #expect(afterFirst == 1)
        #expect(afterSecond == afterFirst)
        withExtendedLifetime(cancellable) {}
    }
}
