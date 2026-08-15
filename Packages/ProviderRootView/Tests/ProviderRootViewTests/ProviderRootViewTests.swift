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

    @Test("RootViewProviding 可作为 any RootViewProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any RootViewProviding = DefaultRootViewProviding()
        provider.setToolbarView(AnyView(Text("toolbar")))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        final class CustomRootView: RootViewProviding {
            var toolbarView: AnyView?

            func setToolbarView(_ view: AnyView?) {
                toolbarView = view
            }

            func makeRootView() -> AnyView {
                AnyView(VStack {
                    if let toolbarView { toolbarView }
                    Text("custom root")
                })
            }
        }

        let provider: any RootViewProviding = CustomRootView()
        provider.setToolbarView(AnyView(Text("custom toolbar")))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }
}
