import Combine
import SwiftUI
import Testing
@testable import ProviderMenuBar

/// MenuBarProviding 协议与默认实现的基础验证。
@Suite("ProviderMenuBar")
@MainActor
struct ProviderMenuBarTests {

    @Test("初始条目为空")
    func defaultProviderStartsEmpty() {
        let provider = DefaultMenuBarProviding()

        #expect(provider.contentItems.isEmpty)
        #expect(provider.popupItems.isEmpty)
    }

    @Test("追加内容与弹窗条目后可读取")
    func defaultProviderStoresItems() {
        let provider = DefaultMenuBarProviding()
        provider.addContent(MenuBarContentItem(id: "cpu", title: "CPU") { Text("cpu") })
        provider.addPopup(MenuBarPopupItem(id: "cpu", title: "CPU") { Text("cpu detail") })

        #expect(provider.contentItems.count == 1)
        #expect(provider.contentItems[0].id == "cpu")
        #expect(provider.popupItems.count == 1)
        #expect(provider.popupItems[0].id == "cpu")
        #expect(type(of: provider.contentItems[0].makeView()) == AnyView.self)
        #expect(type(of: provider.popupItems[0].makeView()) == AnyView.self)
    }

    @Test("同 id 追加去重")
    func defaultProviderDeduplicatesItems() {
        let provider = DefaultMenuBarProviding()
        provider.addContent(MenuBarContentItem(id: "cpu", title: "CPU") { Text("a") })
        provider.addContent(MenuBarContentItem(id: "cpu", title: "CPU") { Text("b") })
        provider.addPopup(MenuBarPopupItem(id: "mem", title: "Mem") { Text("a") })
        provider.addPopup(MenuBarPopupItem(id: "mem", title: "Mem") { Text("b") })

        #expect(provider.contentItems.count == 1)
        #expect(provider.popupItems.count == 1)
    }

    @Test("makeContentView 与 makePopupView 可渲染")
    func defaultProviderRendersViews() {
        let provider = DefaultMenuBarProviding()
        provider.addContent(MenuBarContentItem(id: "cpu", title: "CPU") { Text("cpu") })
        provider.addPopup(MenuBarPopupItem(id: "cpu", title: "CPU") { Text("cpu detail") })

        #expect(type(of: provider.makeContentView()) == AnyView.self)
        #expect(type(of: provider.makePopupView()) == AnyView.self)
    }

    @Test("MenuBarProviding 可作为 any MenuBarProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any MenuBarProviding = DefaultMenuBarProviding()
        provider.addContent(MenuBarContentItem(id: "cpu", title: "CPU") { Text("cpu") })
        provider.addPopup(MenuBarPopupItem(id: "cpu", title: "CPU") { Text("cpu detail") })

        #expect(provider.contentItems.count == 1)
        #expect(provider.popupItems.count == 1)
        #expect(type(of: provider.makeContentView()) == AnyView.self)
        #expect(type(of: provider.makePopupView()) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        final class CustomMenuBar: @preconcurrency MenuBarProviding {
            let objectWillChange = ObservableObjectPublisher()
            var contentItems: [MenuBarContentItem] = []
            var popupItems: [MenuBarPopupItem] = []

            func replaceContentItems(_ items: [MenuBarContentItem]) {
                contentItems = items
            }

            func replacePopupItems(_ items: [MenuBarPopupItem]) {
                popupItems = items
            }
        }

        let provider: any MenuBarProviding = CustomMenuBar()
        provider.addContent(MenuBarContentItem(id: "cpu", title: "CPU") { Text("cpu") })
        provider.addPopup(MenuBarPopupItem(id: "cpu", title: "CPU") { Text("cpu detail") })

        #expect(provider.contentItems.count == 1)
        #expect(provider.popupItems.count == 1)
    }
}
