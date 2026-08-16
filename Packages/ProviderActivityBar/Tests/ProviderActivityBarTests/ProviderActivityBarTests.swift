import SwiftUI
import Testing
@testable import ProviderActivityBar

/// ActivityBarProviding 协议、ActivityBarItem 模型与默认实现的基础验证。
@Suite("ProviderActivityBar")
@MainActor
struct ProviderActivityBarTests {

    @Test("ActivityBarItem 可创建且携带图标信息")
    func itemBasics() {
        let item = ActivityBarItem(id: "files", title: "Files", systemImage: "folder")

        #expect(item.id == "files")
        #expect(item.title == "Files")
        #expect(item.systemImage == "folder")
    }

    @Test("DefaultActivityBarProviding 注入 items 后可读取且按 order 排序")
    func defaultProviderStoresAndSortsItems() {
        let provider = DefaultActivityBarProviding()
        let items = [
            ActivityBarItem(id: "b", title: "B", systemImage: "b", order: 200),
            ActivityBarItem(id: "a", title: "A", systemImage: "a", order: 100),
        ]

        provider.registerItems(items)

        #expect(provider.items.count == 2)
        #expect(provider.items.map(\.id) == ["a", "b"])
    }

    @Test("注入 items 后返回可渲染的 ActivityBar 视图")
    func defaultProviderRendersItems() {
        let provider = DefaultActivityBarProviding()
        provider.registerItems([
            ActivityBarItem(id: "a", title: "A", systemImage: "folder"),
        ])

        #expect(type(of: provider.makeActivityBarView()) == AnyView.self)
    }

    @Test("ActivityBarProviding 可作为 any ActivityBarProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any ActivityBarProviding = DefaultActivityBarProviding()
        provider.registerItems([
            ActivityBarItem(id: "x", title: "X", systemImage: "xmark"),
        ])

        #expect(provider.items.count == 1)
        #expect(type(of: provider.makeActivityBarView()) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        final class CustomActivityBar: ActivityBarProviding {
            var items: [ActivityBarItem] = []

            func registerItems(_ items: [ActivityBarItem]) {
                self.items = items
            }

            func makeActivityBarView() -> AnyView {
                AnyView(Text("custom activity bar"))
            }
        }

        let provider: any ActivityBarProviding = CustomActivityBar()
        provider.registerItems([
            ActivityBarItem(id: "y", title: "Y", systemImage: "ycircle"),
        ])

        #expect(provider.items.count == 1)
        #expect(type(of: provider.makeActivityBarView()) == AnyView.self)
    }
}
