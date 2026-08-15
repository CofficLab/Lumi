import SwiftUI
import Testing
@testable import ProviderSettingView

/// SettingViewProviding 协议与默认实现的基础验证。
@Suite("ProviderSettingView")
@MainActor
struct ProviderSettingViewTests {

    @Test("DefaultSettingViewProviding 返回可渲染的设置视图")
    func defaultProviderReturnsSettingView() {
        let provider = DefaultSettingViewProviding()

        let view = provider.makeSettingView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("SettingViewProviding 可作为 any SettingViewProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any SettingViewProviding = DefaultSettingViewProviding()

        let view = provider.makeSettingView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        final class CustomSettingView: SettingViewProviding {
            func makeSettingView() -> AnyView {
                AnyView(Text("custom settings"))
            }
        }

        let provider: any SettingViewProviding = CustomSettingView()
        let view = provider.makeSettingView()

        #expect(type(of: view) == AnyView.self)
    }
}
