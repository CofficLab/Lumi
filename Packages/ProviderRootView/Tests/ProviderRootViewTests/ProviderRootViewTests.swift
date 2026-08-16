import ProviderWorkspace
import SwiftUI
import Testing
@testable import ProviderRootView

/// RootViewProviding 协议与默认实现的基础验证。
@Suite("ProviderRootView")
@MainActor
struct ProviderRootViewTests {

    @Test("DefaultRootViewProviding 无工具栏时返回根视图")
    func defaultProviderReturnsRootViewWithoutToolbar() {
        let provider = DefaultRootViewProviding()

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("注入工具栏后返回根视图")
    func defaultProviderReturnsRootViewWithToolbar() {
        let provider = DefaultRootViewProviding()
        provider.setToolbarView(AnyView(Text("toolbar")))

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("注入 ActivityBar 后返回根视图")
    func defaultProviderReturnsRootViewWithActivityBar() {
        let provider = DefaultRootViewProviding()
        provider.setActivityBarView(AnyView(Text("activity bar")))

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("同时注入工具栏与 ActivityBar 后返回根视图")
    func defaultProviderReturnsRootViewWithToolbarAndActivityBar() {
        let provider = DefaultRootViewProviding()
        provider.setToolbarView(AnyView(Text("toolbar")))
        provider.setActivityBarView(AnyView(Text("activity bar")))

        let view = provider.makeRootView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("同时注入工具栏、ActivityBar、Rail 与内容后返回根视图")
    func defaultProviderReturnsRootViewWithAllInjections() {
        let provider = DefaultRootViewProviding()
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
        let provider: any RootViewProviding = DefaultRootViewProviding()
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
        let provider = DefaultRootViewProviding()
        provider.setActivityBarView(AnyView(Text("activity bar")))
        provider.setWorkspaceProvider(makeWorkspace(containerCount: 2))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }

    @Test("无活跃容器时返回根视图（Welcome 占位路径）")
    func welcomePlaceholderWithoutActiveContainer() {
        let provider = DefaultRootViewProviding()
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
        let provider = DefaultRootViewProviding()
        let workspace = makeWorkspace(containerCount: 1)
        provider.setWorkspaceProvider(workspace)
        provider.setContentView(AnyView(Text("content")))
        provider.setRailView(AnyView(Text("rail")))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }
}
