import Combine
import SwiftUI
import Testing
@testable import ProviderRailView

/// RailViewProviding 协议、RailTabItem 模型与默认实现的基础验证。
@Suite("ProviderRailView")
@MainActor
struct ProviderRailViewTests {

    @Test("RailTabItem 可创建且携带信息")
    func itemBasics() {
        let item = RailTabItem(id: "files", category: .project, title: "Files", systemImage: "folder") {
            Text("files content")
        }

        #expect(item.id == "files")
        #expect(item.category == .project)
        #expect(item.title == "Files")
        #expect(item.systemImage == "folder")
        #expect(item.order == 200)
    }

    @Test("DefaultRailViewProviding 注入 tabs 后排序并自动激活首个标签")
    func defaultProviderStoresSortsAndActivatesFirstTab() {
        let provider = DefaultRailViewProviding()
        let tabs = [
            RailTabItem(id: "b", category: .general, title: "B", systemImage: "b", order: 200) { Text("B") },
            RailTabItem(id: "a", category: .general, title: "A", systemImage: "a", order: 100) { Text("A") },
        ]

        provider.registerTabs(tabs)

        #expect(provider.tabs.count == 2)
        #expect(provider.tabs.map(\.id) == ["a", "b"])
        #expect(provider.activeTabID == "a")
    }

    @Test("activateTab 切换活跃 tab")
    func activateTabSwitchesActive() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "a", category: .general, title: "A", systemImage: "a") { Text("A") },
            RailTabItem(id: "b", category: .general, title: "B", systemImage: "b") { Text("B") },
        ])
        provider.activateTab(id: "b")

        #expect(provider.activeTabID == "b")
    }

    @Test("不能激活未知标签")
    func rejectsUnknownTabs() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "a", category: .general, title: "A", systemImage: "a") { Text("A") },
            RailTabItem(id: "b", category: .general, title: "B", systemImage: "b") { Text("B") },
        ])

        provider.activateTab(id: "missing")

        #expect(provider.activeTabID == "a")
    }

    @Test("追加与撤回贡献不覆盖其他插件")
    func addAndRemoveTabsAreContributionSafe() {
        let provider = DefaultRailViewProviding()
        provider.addTabs([
            RailTabItem(id: "a", category: .general, title: "A", systemImage: "a") { Text("A") },
        ])
        provider.addTabs([
            RailTabItem(id: "b", category: .general, title: "B", systemImage: "b") { Text("B") },
        ])

        provider.removeTabs(ids: ["a"])

        #expect(provider.tabs.map(\.id) == ["b"])
    }

    @Test("注入 tabs 后返回可渲染的 Rail 视图")
    func defaultProviderRendersView() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "a", category: .general, title: "A", systemImage: "folder") { Text("A") },
        ])

        #expect(type(of: provider.makeRailView()) == AnyView.self)
    }

    @Test("RailViewProviding 可作为 any RailViewProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any RailViewProviding = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "x", category: .general, title: "X", systemImage: "xmark") { Text("X") },
        ])

        #expect(provider.tabs.count == 1)
        #expect(type(of: provider.makeRailView()) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        @MainActor final class CustomRailView: RailViewProviding {
            @Published var tabs: [RailTabItem] = []

            func registerTabs(_ tabs: [RailTabItem]) {
                self.tabs = tabs
            }

            func makeRailView() -> AnyView {
                AnyView(Text("custom rail view"))
            }
        }

        let provider: any RailViewProviding = CustomRailView()
        provider.registerTabs([
            RailTabItem(id: "y", category: .general, title: "Y", systemImage: "ycircle") { Text("Y") },
        ])

        #expect(provider.tabs.count == 1)
        #expect(type(of: provider.makeRailView()) == AnyView.self)
    }
}
