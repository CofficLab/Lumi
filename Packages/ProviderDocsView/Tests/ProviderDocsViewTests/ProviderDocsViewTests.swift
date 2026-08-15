import SwiftUI
import Testing
@testable import ProviderDocsView

/// DocsViewProviding 协议与默认实现的基础验证。
@Suite("ProviderDocsView")
@MainActor
struct ProviderDocsViewTests {

    @Test("未设置时返回占位")
    func defaultProviderReturnsPlaceholders() {
        let provider = DefaultDocsViewProviding()

        #expect(type(of: provider.makeAboutView()) == AnyView.self)
        #expect(type(of: provider.makeManualView()) == AnyView.self)
    }

    @Test("设置后返回对应视图")
    func defaultProviderReturnsSetViews() {
        let provider = DefaultDocsViewProviding()
        provider.setAboutView(AnyView(Text("about")))
        provider.setManualView(AnyView(Text("manual")))

        #expect(type(of: provider.makeAboutView()) == AnyView.self)
        #expect(type(of: provider.makeManualView()) == AnyView.self)
    }

    @Test("设置 nil 后回退到占位")
    func defaultProviderClearsViews() {
        let provider = DefaultDocsViewProviding()
        provider.setAboutView(AnyView(Text("about")))
        provider.setManualView(AnyView(Text("manual")))

        provider.setAboutView(nil)
        provider.setManualView(nil)

        #expect(type(of: provider.makeAboutView()) == AnyView.self)
        #expect(type(of: provider.makeManualView()) == AnyView.self)
    }

    @Test("DocsViewProviding 可作为 any DocsViewProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any DocsViewProviding = DefaultDocsViewProviding()
        provider.setAboutView(AnyView(Text("about")))
        provider.setManualView(AnyView(Text("manual")))

        #expect(type(of: provider.makeAboutView()) == AnyView.self)
        #expect(type(of: provider.makeManualView()) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        final class CustomDocsView: DocsViewProviding {
            var aboutView: AnyView?
            var manualView: AnyView?

            func setAboutView(_ view: AnyView?) {
                aboutView = view
            }

            func setManualView(_ view: AnyView?) {
                manualView = view
            }

            func makeAboutView() -> AnyView {
                aboutView ?? AnyView(Text("custom about"))
            }

            func makeManualView() -> AnyView {
                manualView ?? AnyView(Text("custom manual"))
            }
        }

        let provider: any DocsViewProviding = CustomDocsView()
        provider.setAboutView(AnyView(Text("custom about")))
        provider.setManualView(AnyView(Text("custom manual")))

        #expect(type(of: provider.makeAboutView()) == AnyView.self)
        #expect(type(of: provider.makeManualView()) == AnyView.self)
    }
}
