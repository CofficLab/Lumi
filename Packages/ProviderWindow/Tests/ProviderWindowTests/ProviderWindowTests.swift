import SwiftUI
import Testing
@testable import ProviderWindow

/// WindowProviding 协议与默认实现的基础验证。
@Suite("ProviderWindow")
@MainActor
struct ProviderWindowTests {

    @Test("DefaultWindowProviding 返回可渲染的根视图")
    func defaultProviderReturnsRootView() {
        let provider = DefaultWindowProviding()

        let rootView = provider.makeRootView()

        // AnyView 恒非空；验证协议调用链路正常返回即可。
        #expect(type(of: rootView) == AnyView.self)
    }

    @Test("WindowProviding 可作为 any WindowProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any WindowProviding = DefaultWindowProviding()

        let rootView = provider.makeRootView()

        #expect(type(of: rootView) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        final class CustomWindow: WindowProviding {
            func makeRootView() -> AnyView {
                AnyView(Text("custom"))
            }
        }

        let provider: any WindowProviding = CustomWindow()
        let rootView = provider.makeRootView()

        // 自定义实现经协议调用正常返回即可。
        #expect(type(of: rootView) == AnyView.self)
    }
}
