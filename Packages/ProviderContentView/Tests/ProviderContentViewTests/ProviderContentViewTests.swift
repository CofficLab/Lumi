import Combine
import SwiftUI
import Testing
@testable import ProviderContentView

/// ContentViewProviding 协议与默认实现的基础验证。
@Suite("ProviderContentView")
@MainActor
struct ProviderContentViewTests {

    @Test("未设置内容时返回占位视图")
    func defaultProviderReturnsPlaceholder() {
        let provider = DefaultContentViewProviding()

        let view = provider.makeContentView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("设置内容后返回该视图")
    func defaultProviderReturnsSetContent() {
        let provider = DefaultContentViewProviding()
        provider.setContentView(AnyView(Text("device content")))

        let view = provider.makeContentView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("切换内容会发布视图刷新事件")
    func settingContentPublishesChange() {
        let provider = DefaultContentViewProviding()
        var changeCount = 0
        let cancellable = provider.objectWillChange.sink { changeCount += 1 }

        provider.setContentView(AnyView(Text("next")))

        #expect(changeCount == 1)
        cancellable.cancel()
    }

    @Test("设置 nil 后回退到占位")
    func defaultProviderClearsContent() {
        let provider = DefaultContentViewProviding()
        provider.setContentView(AnyView(Text("content")))
        provider.setContentView(nil)

        let view = provider.makeContentView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("ContentViewProviding 可作为 any ContentViewProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any ContentViewProviding = DefaultContentViewProviding()
        provider.setContentView(AnyView(Text("content")))

        #expect(type(of: provider.makeContentView()) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        final class CustomContentView: ContentViewProviding {
            var content: AnyView?

            func setContentView(_ view: AnyView?) {
                content = view
            }

            func makeContentView() -> AnyView {
                content ?? AnyView(Text("custom content"))
            }
        }

        let provider: any ContentViewProviding = CustomContentView()
        provider.setContentView(AnyView(Text("custom")))

        #expect(type(of: provider.makeContentView()) == AnyView.self)
    }
}
