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
        let item = RailTabItem(id: "files", groupID: "editor", title: "Files", systemImage: "folder") {
            Text("files content")
        }

        #expect(item.id == "files")
        #expect(item.groupID == "editor")
        #expect(item.title == "Files")
        #expect(item.systemImage == "folder")
        #expect(item.order == 200)
    }

    @Test("DefaultRailViewProviding 注入 tabs 后排序但等待宿主激活分组")
    func defaultProviderStoresSortsAndWaitsForGroupActivation() {
        let provider = DefaultRailViewProviding()
        let tabs = [
            RailTabItem(id: "b", title: "B", systemImage: "b", order: 200) { Text("B") },
            RailTabItem(id: "a", title: "A", systemImage: "a", order: 100) { Text("A") },
        ]

        provider.registerTabs(tabs)

        #expect(provider.tabs.count == 2)
        #expect(provider.tabs.map(\.id) == ["a", "b"])
        #expect(provider.activeGroupID == nil)
        #expect(provider.activeTabID == nil)

        provider.activateGroup(id: "default")

        #expect(provider.activeTabID == "a")
    }

    @Test("activateTab 切换当前分组内的活跃 tab")
    func activateTabSwitchesActive() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "a", title: "A", systemImage: "a") { Text("A") },
            RailTabItem(id: "b", title: "B", systemImage: "b") { Text("B") },
        ])
        provider.activateGroup(id: "default")

        provider.activateTab(id: "b")

        #expect(provider.activeTabID == "b")
    }

    @Test("分组切换只展示对应标签并恢复各组选择")
    func groupSwitchingRestoresSelection() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "a1", groupID: "a", title: "A1", systemImage: "a") { Text("A1") },
            RailTabItem(id: "a2", groupID: "a", title: "A2", systemImage: "a") { Text("A2") },
            RailTabItem(id: "b1", groupID: "b", title: "B1", systemImage: "b") { Text("B1") },
        ])

        provider.activateGroup(id: "a")
        provider.activateTab(id: "a2")
        provider.activateGroup(id: "b")
        #expect(provider.activeTabID == "b1")

        provider.activateGroup(id: "a")
        #expect(provider.activeTabID == "a2")
    }

    @Test("激活无标签分组会折叠 Rail 状态")
    func emptyGroupClearsActiveTab() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "a", groupID: "with-rail", title: "A", systemImage: "a") { Text("A") },
        ])

        provider.activateGroup(id: "without-rail")

        #expect(provider.activeGroupID == "without-rail")
        #expect(provider.activeTabID == nil)
    }

    @Test("不能激活其他分组或未知标签")
    func rejectsTabsOutsideActiveGroup() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "a", groupID: "one", title: "A", systemImage: "a") { Text("A") },
            RailTabItem(id: "b", groupID: "two", title: "B", systemImage: "b") { Text("B") },
        ])
        provider.activateGroup(id: "one")

        provider.activateTab(id: "b")
        provider.activateTab(id: "missing")

        #expect(provider.activeTabID == "a")
    }

    @Test("追加与撤回贡献不覆盖其他插件")
    func addAndRemoveTabsAreContributionSafe() {
        let provider = DefaultRailViewProviding()
        provider.addTabs([
            RailTabItem(id: "a", groupID: "one", title: "A", systemImage: "a") { Text("A") },
        ])
        provider.addTabs([
            RailTabItem(id: "b", groupID: "two", title: "B", systemImage: "b") { Text("B") },
        ])

        provider.removeTabs(ids: ["a"])

        #expect(provider.tabs.map(\.id) == ["b"])
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
            RailTabItem(id: "y", title: "Y", systemImage: "ycircle") { Text("Y") },
        ])

        #expect(provider.tabs.count == 1)
        #expect(type(of: provider.makeRailView()) == AnyView.self)
    }
}
