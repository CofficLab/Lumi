import SwiftUI
import Testing
@testable import ProviderChatSection

@Suite("ProviderChatSection")
@MainActor
struct ProviderChatSectionTests {
    @Test("贡献按 order 排序并支持替换")
    func itemsAreSortedAndReplaced() {
        let provider = DefaultChatSectionProviding()
        provider.addItems([
            ChatSectionItem(id: "b", order: 20) { Text("B") },
            ChatSectionItem(id: "a", order: 10) { Text("A") },
        ])
        #expect(provider.items.map(\.id) == ["a", "b"])

        provider.addItems([ChatSectionItem(id: "a", order: 30) { Text("A2") }])
        #expect(provider.items.map(\.id) == ["b", "a"])
    }

    @Test("Bar contribution 按 order 排序")
    func barItemsAreSorted() {
        let provider = DefaultChatSectionProviding()
        provider.addBarItems([
            ChatSectionBarItem(id: "b", order: 2, placement: .actionTrailing) { Text("B") },
            ChatSectionBarItem(id: "a", order: 1, placement: .header) { Text("A") },
        ])
        #expect(provider.barItems.map(\.id) == ["a", "b"])
    }

    @Test("显隐和会话上下文状态可独立切换")
    func visibilityAndContextState() {
        let provider = DefaultChatSectionProviding()
        provider.setVisible(false)
        provider.setContextActive(true)
        #expect(provider.isVisible == false)
        #expect(provider.isContextActive == true)
        #expect(type(of: provider.makeChatSectionView()) == AnyView.self)
    }
}
