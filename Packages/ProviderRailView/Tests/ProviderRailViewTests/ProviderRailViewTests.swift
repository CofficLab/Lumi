import SwiftUI
import Testing
@testable import ProviderRailView

/// RailViewProviding 协议、RailTabItem 模型与默认实现的基础验证。
@Suite("ProviderRailView")
@MainActor
struct ProviderRailViewTests {

    @Test("RailTabItem 可创建且携带信息")
    func itemBasics() {
        let item = RailTabItem(id: "files", title: "Files", systemImage: "folder") {
            Text("files content")
        }

        #expect(item.id == "files")
        #expect(item.title == "Files")
        #expect(item.systemImage == "folder")
        #expect(item.order == 200)
    }

    @Test("DefaultRailViewProviding 注入 tabs 后排序且默认选中第一个")
    func defaultProviderStoresSortsAndSelectsFirst() {
        let provider = DefaultRailViewProviding()
        let tabs = [
            RailTabItem(id: "b", title: "B", systemImage: "b", order: 200) { Text("B") },
            RailTabItem(id: "a", title: "A", systemImage: "a", order: 100) { Text("A") },
        ]

        provider.registerTabs(tabs)

        #expect(provider.tabs.count == 2)
        #expect(provider.tabs.map(\.id) == ["a", "b"])
        #expect(provider.activeTabID == "a")
    }

    @Test("selectTab 切换活跃 tab")
    func selectTabSwitchesActive() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "a", title: "A", systemImage: "a") { Text("A") },
            RailTabItem(id: "b", title: "B", systemImage: "b") { Text("B") },
        ])

        provider.selectTab(id: "b")

        #expect(provider.activeTabID == "b")
    }

    @Test("注入 tabs 后返回可渲染的 Rail 视图")
    func defaultProviderRendersView() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "a", title: "A", systemImage: "folder") { Text("A") },
        ])

        #expect(type(of: provider.makeRailView()) == AnyView.self)
    }

    @Test("RailViewProviding 可作为 any RailViewProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any RailViewProviding = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "x", title: "X", systemImage: "xmark") { Text("X") },
        ])

        #expect(provider.tabs.count == 1)
        #expect(type(of: provider.makeRailView()) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        final class CustomRailView: RailViewProviding {
            var tabs: [RailTabItem] = []

            func registerTabs(_ tabs: [RailTabItem]) {
                self.tabs = tabs
            }

            func makeRailView() -> AnyView {
                AnyView(Text("custom rail view"))
            }
        }

        let provider: any RailViewProviding = CustomRailView()
        provider.registerTabs([
            RailTabItem(id: "y", title: "Y", systemImage: "ycircle") { Text("Y") },
        ])

        #expect(provider.tabs.count == 1)
        #expect(type(of: provider.makeRailView()) == AnyView.self)
    }
}
