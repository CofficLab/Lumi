import Foundation
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

    @Test("只展示指定分类并校正当前标签")
    func filtersTabsByVisibleCategories() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "chat", category: .chat, title: "Chat", systemImage: "message") { Text("Chat") },
            RailTabItem(id: "project", category: .project, title: "Project", systemImage: "folder") { Text("Project") },
            RailTabItem(id: "files", category: .fileTree, title: "Files", systemImage: "folder.fill") { Text("Files") },
        ])
        provider.activateTab(id: "project")

        provider.setVisibleCategories([.fileTree])

        #expect(provider.visibleCategories == [.fileTree])
        #expect(provider.activeTabID == "files")
        provider.activateTab(id: "project")
        #expect(provider.activeTabID == "files")
    }

    @Test("隐藏全部分类时不激活任何标签")
    func hidesAllCategories() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "chat", category: .chat, title: "Chat", systemImage: "message") { Text("Chat") },
        ])

        provider.setVisibleCategories([])

        #expect(provider.activeTabID == nil)
    }

    @Test("没有可见 tab 时 Rail 不占用内容")
    func visibleTabStateFollowsFiltering() {
        let provider = DefaultRailViewProviding()

        #expect(!provider.hasVisibleTabs)

        provider.registerTabs([
            RailTabItem(id: "chat", category: .chat, title: "Chat", systemImage: "message") { Text("Chat") },
        ])
        #expect(provider.hasVisibleTabs)

        provider.setVisibleCategories([])
        #expect(!provider.hasVisibleTabs)
    }

    @Test("只展示指定 id 的标签")
    func filtersTabsByVisibleID() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "chat", category: .chat, title: "Chat", systemImage: "message") { Text("Chat") },
            RailTabItem(id: "project", category: .project, title: "Project", systemImage: "folder") { Text("Project") },
        ])

        provider.setVisibleTabID("project")

        #expect(provider.visibleTabID == "project")
        #expect(provider.activeTabID == "project")
        provider.activateTab(id: "chat")
        #expect(provider.activeTabID == "project")

        provider.setVisibleTabID(nil)
        #expect(provider.visibleTabID == nil)
    }

    @Test("切换到分类过滤时清除指定 tab 过滤")
    func categoryFilterClearsVisibleID() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "chat", category: .chat, title: "Chat", systemImage: "message") { Text("Chat") },
            RailTabItem(id: "project", category: .project, title: "Project", systemImage: "folder") { Text("Project") },
        ])

        provider.setVisibleTabID("project")
        provider.setVisibleCategories([.chat])

        #expect(provider.visibleTabID == nil)
        #expect(provider.activeTabID == "chat")
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

    @Test("首次激活使用推荐宽度，拖拽后按插件 ID 恢复")
    func widthProfileRestoresSavedWidth() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderRailViewTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("rail-view-widths.plist")
        defer { try? FileManager.default.removeItem(at: directory) }

        let recommended = RailViewWidth(minWidth: 240, idealWidth: 320, maxWidth: 480)
        let firstProvider = DefaultRailViewProviding(
            widthStore: FileRailViewWidthStore(fileURL: fileURL)
        )

        firstProvider.activateWidthProfile(ownerID: "plugin.resume", recommended: recommended)
        #expect(firstProvider.railWidth.idealWidth == 320)

        firstProvider.saveCurrentWidth(400)
        #expect(firstProvider.railWidth.idealWidth == 400)

        let secondProvider = DefaultRailViewProviding(
            widthStore: FileRailViewWidthStore(fileURL: fileURL)
        )
        secondProvider.activateWidthProfile(ownerID: "plugin.resume", recommended: recommended)

        #expect(secondProvider.railWidth.idealWidth == 400)
    }

    @Test("没有磁盘值时使用推荐宽度，保存值超出新范围时被限制")
    func widthProfileUsesRecommendationAndClampsRestoredValue() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderRailViewTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("rail-view-widths.plist")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileRailViewWidthStore(fileURL: fileURL)
        let provider = DefaultRailViewProviding(widthStore: store)
        let recommended = RailViewWidth(minWidth: 240, idealWidth: 340, maxWidth: 480)

        provider.activateWidthProfile(ownerID: "plugin.new", recommended: recommended)
        #expect(provider.railWidth.idealWidth == 340)

        provider.saveCurrentWidth(470)
        let reloaded = DefaultRailViewProviding(
            widthStore: FileRailViewWidthStore(fileURL: fileURL)
        )
        reloaded.activateWidthProfile(
            ownerID: "plugin.new",
            recommended: RailViewWidth(minWidth: 260, idealWidth: 300, maxWidth: 360)
        )

        #expect(reloaded.railWidth.idealWidth == 360)
    }

    @Test("旧插件释放宽度时不会覆盖新插件")
    func staleDeactivationDoesNotResetCurrentProfile() {
        let provider = DefaultRailViewProviding()
        provider.activateWidthProfile(
            ownerID: "plugin.first",
            recommended: RailViewWidth(minWidth: 200, idealWidth: 300, maxWidth: 400)
        )
        provider.activateWidthProfile(
            ownerID: "plugin.second",
            recommended: RailViewWidth(minWidth: 240, idealWidth: 360, maxWidth: 500)
        )

        provider.deactivateWidthProfile(ownerID: "plugin.first")

        #expect(provider.railWidth.idealWidth == 360)
    }
}
