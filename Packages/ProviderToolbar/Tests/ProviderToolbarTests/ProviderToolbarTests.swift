import SwiftUI
import Testing
@testable import ProviderToolbar

/// ToolbarProviding 协议与默认实现的基础验证。
@Suite("ProviderToolbar")
@MainActor
struct ProviderToolbarTests {

    @Test("DefaultToolbarProviding 返回可渲染的工具栏视图")
    func defaultProviderReturnsToolbarView() {
        let provider = DefaultToolbarProviding()

        let view = provider.makeToolbarView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("ToolbarProviding 可作为 any ToolbarProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any ToolbarProviding = DefaultToolbarProviding()

        let view = provider.makeToolbarView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        final class CustomToolbar: ToolbarProviding {
            func makeToolbarView() -> AnyView {
                AnyView(Text("custom toolbar"))
            }
        }

        let provider: any ToolbarProviding = CustomToolbar()
        let view = provider.makeToolbarView()

        #expect(type(of: view) == AnyView.self)
    }
}
