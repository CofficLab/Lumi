import Combine
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
        #expect(!item.preservesContentFooter)

        let editorItem = ActivityBarItem(
            id: "editor",
            title: "Editor",
            systemImage: "chevron.left.forwardslash.chevron.right",
            preservesContentFooter: true
        )
        #expect(editorItem.preservesContentFooter)
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
        #expect(provider.activeItemID == "a")
    }

    @Test("仅一个入口时不显示 ActivityBar")
    func hidesActivityBarWhenThereIsAtMostOneItem() {
        let provider = DefaultActivityBarProviding()

        #expect(provider.shouldDisplayActivityBar == false)

        provider.registerItems([
            ActivityBarItem(id: "a", title: "A", systemImage: "a")
        ])
        #expect(provider.shouldDisplayActivityBar == false)

        provider.addItems([
            ActivityBarItem(id: "b", title: "B", systemImage: "b")
        ])
        #expect(provider.shouldDisplayActivityBar == true)
    }

    @Test("激活项变化只通知旧入口和新入口")
    func activationNotifiesOnlyChangedItems() {
        let provider = DefaultActivityBarProviding()
        var received: [String] = []
        provider.registerItems([
            ActivityBarItem(id: "a", title: "A", systemImage: "a") { state in
                received.append("a:\(state == .activated ? "on" : "off")")
            },
            ActivityBarItem(id: "b", title: "B", systemImage: "b") { state in
                received.append("b:\(state == .activated ? "on" : "off")")
            },
        ])

        #expect(received == ["a:on"])

        provider.activateItem(id: "b")

        #expect(provider.activeItemID == "b")
        #expect(received.suffix(2) == ["a:off", "b:on"])
    }

    @Test("移除当前激活入口会回退并通知剩余入口")
    func removingActiveItemActivatesFallback() {
        let provider = DefaultActivityBarProviding()
        var bActivations: [ActivityBarItem.ActivationState] = []
        provider.registerItems([
            ActivityBarItem(id: "a", title: "A", systemImage: "a"),
            ActivityBarItem(id: "b", title: "B", systemImage: "b") { state in
                bActivations.append(state)
            },
        ])
        provider.activateItem(id: "b")

        provider.removeItems(ids: ["b"])

        #expect(provider.activeItemID == "a")
        #expect(provider.items.map(\.id) == ["a"])
        #expect(bActivations.last == .deactivated)
    }

    @Test("未知入口不会改变当前激活项")
    func unknownActivationIsIgnored() {
        let provider = DefaultActivityBarProviding()
        provider.registerItems([
            ActivityBarItem(id: "a", title: "A", systemImage: "a"),
        ])

        provider.activateItem(id: "missing")

        #expect(provider.activeItemID == "a")
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
        @MainActor final class CustomActivityBar: ActivityBarProviding {
            @Published var items: [ActivityBarItem] = []

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
