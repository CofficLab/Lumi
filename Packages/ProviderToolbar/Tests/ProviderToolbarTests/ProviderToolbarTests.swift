import Combine
import SwiftUI
import Testing
@testable import ProviderToolbar

/// ToolbarProviding 协议、ToolbarItem 模型与默认实现的基础验证。
@Suite("ProviderToolbar")
@MainActor
struct ProviderToolbarTests {

    @Test("ToolbarItem 可创建且携带位置信息")
    func toolbarItemBasics() {
        let item = ProviderToolbar.ToolbarItem(id: "run", title: "Run", placement: .leading) {
            Image(systemName: "play.fill")
        }

        #expect(item.id == "run")
        #expect(item.title == "Run")
        #expect(item.placement == .leading)
        #expect(item.category == .global)
        #expect(item.order == 200)
    }

    @Test("DefaultToolbarProviding 注入 items 后可读取")
    func defaultProviderStoresInjectedItems() {
        let provider = DefaultToolbarProviding()
        let items = [
            ProviderToolbar.ToolbarItem(id: "a", title: "A", placement: .leading) { Text("A") },
            ProviderToolbar.ToolbarItem(id: "b", title: "B", placement: .trailing) { Text("B") },
        ]

        provider.registerToolbarItems(items)

        #expect(provider.toolbarItems.count == 2)
        #expect(provider.toolbarItems.map(\.id) == ["a", "b"])
    }

    @Test("追加工具栏项按 order 从小到大排列")
    func appendedItemsAreSortedByOrder() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([
            ProviderToolbar.ToolbarItem(id: "settings", title: "Settings", order: 300) { Text("Settings") },
        ])

        provider.addToolbarItems([
            ProviderToolbar.ToolbarItem(id: "conversation-list", title: "Chats", order: 200) { Text("Chats") },
            ProviderToolbar.ToolbarItem(id: "new-chat", title: "New Chat", order: 30) { Text("New Chat") },
        ])

        #expect(provider.toolbarItems.map(\.id) == ["new-chat", "conversation-list", "settings"])
    }

    @Test("注入 items 后返回可渲染的工具栏视图")
    func defaultProviderRendersInjectedItems() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([
            ProviderToolbar.ToolbarItem(id: "a", title: "A", placement: .leading) { Text("A") },
        ])

        let view = provider.makeToolbarView()

        #expect(type(of: view) == AnyView.self)
    }

    @Test("ToolbarProviding 可作为 any ToolbarProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any ToolbarProviding = DefaultToolbarProviding()
        provider.registerToolbarItems([
            ProviderToolbar.ToolbarItem(id: "x", title: "X") { Text("X") },
        ])

        #expect(provider.toolbarItems.count == 1)
        #expect(type(of: provider.makeToolbarView()) == AnyView.self)
    }

    @Test("自定义实现可被协议访问")
    func customProviderWorks() {
        @MainActor final class CustomToolbar: ToolbarProviding {
            @Published var toolbarItems: [ProviderToolbar.ToolbarItem] = []

            func registerToolbarItems(_ items: [ProviderToolbar.ToolbarItem]) {
                toolbarItems = items
            }

            func makeToolbarView() -> AnyView {
                AnyView(Text("custom toolbar"))
            }
        }

        let provider: any ToolbarProviding = CustomToolbar()
        provider.registerToolbarItems([
            ProviderToolbar.ToolbarItem(id: "y", title: "Y") { Text("Y") },
        ])

        #expect(provider.toolbarItems.count == 1)
        #expect(type(of: provider.makeToolbarView()) == AnyView.self)
    }

    @Test("ToolbarItem 默认属于 global 分类")
    func toolbarItemDefaultsToGlobalCategory() {
        let item = ProviderToolbar.ToolbarItem(id: "legacy", title: "Legacy") { Text("Legacy") }

        #expect(item.category == .global)
    }

    @Test("DefaultToolbarProviding 按可见分类过滤工具栏项")
    func filtersToolbarItemsByVisibleCategories() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([
            ProviderToolbar.ToolbarItem(id: "global", title: "Global", category: .global) { Text("Global") },
            ProviderToolbar.ToolbarItem(id: "project", title: "Project", category: .project) { Text("Project") },
            ProviderToolbar.ToolbarItem(id: "chat", title: "Chat", category: .chat) { Text("Chat") },
        ])

        provider.setVisibleCategories([.global, .project])

        #expect(provider.visibleCategories == [.global, .project])
        #expect(provider.visibleToolbarItems.map(\.id) == ["global", "project"])
        #expect(provider.toolbarItems.map(\.id) == ["global", "project", "chat"])
    }

    @Test("默认可见分类保持所有工具栏项可见")
    func allCategoriesAreVisibleByDefault() {
        let provider = DefaultToolbarProviding()
        provider.registerToolbarItems([
            ProviderToolbar.ToolbarItem(id: "global", title: "Global") { Text("Global") },
            ProviderToolbar.ToolbarItem(id: "project", title: "Project", category: .project) { Text("Project") },
        ])

        #expect(provider.visibleCategories == Set(ToolbarItemCategory.allCases))
        #expect(provider.visibleToolbarItems.map(\.id) == ["global", "project"])
    }

    @Test("临时隐藏分类不会覆盖 ActivityBar 的基础分类")
    func temporaryHiddenCategoriesOverlayBaseCategories() {
        let provider = DefaultToolbarProviding()
        provider.setVisibleCategories([.global, .chat, .project])

        provider.setHiddenCategories([.project], for: "message-list.empty-state")

        #expect(provider.visibleCategories == [.global, .chat])
        provider.setVisibleCategories([.global, .project])
        #expect(provider.visibleCategories == [.global])
    }

    @Test("清除指定来源后恢复被隐藏的分类")
    func clearingTemporaryHiddenCategoriesRestoresCategories() {
        let provider = DefaultToolbarProviding()
        provider.setVisibleCategories([.global, .chat, .project])
        provider.setHiddenCategories([.project], for: "message-list.empty-state")
        provider.setHiddenCategories([], for: "message-list.empty-state")

        #expect(provider.visibleCategories == [.global, .chat, .project])
    }

    @Test("多个隐藏来源取分类并集，清除一个来源不会影响其他来源")
    func hiddenCategoriesFromMultipleSourcesAreUnioned() {
        let provider = DefaultToolbarProviding()
        provider.setVisibleCategories([.global, .chat, .project, .system])
        provider.setHiddenCategories([.project], for: "message-list.empty-state")
        provider.setHiddenCategories([.system], for: "another-feature")

        #expect(provider.visibleCategories == [.global, .chat])
        provider.setHiddenCategories([], for: "message-list.empty-state")
        #expect(provider.visibleCategories == [.global, .chat, .project])
    }
}
