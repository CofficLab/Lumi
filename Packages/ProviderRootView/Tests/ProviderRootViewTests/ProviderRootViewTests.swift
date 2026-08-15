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

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }
}
