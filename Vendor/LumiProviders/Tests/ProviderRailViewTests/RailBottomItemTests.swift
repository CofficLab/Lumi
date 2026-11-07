import Foundation
import SwiftUI
import Testing
@testable import ProviderRailView

/// Rail 底部固定项（`RailBottomItem`）的注入、排序与事件验证。
@Suite("ProviderRailView · 底部固定项")
@MainActor
struct RailBottomItemTests {

    @Test("RailBottomItem 可创建且默认不指定高度")
    func itemBasics() {
        let item = RailBottomItem(id: "user", order: 10) {
            Text("user info")
        }

        #expect(item.id == "user")
        #expect(item.order == 10)
        #expect(item.height == nil)
    }

    @Test("registerBottomItems 注入后按 order 排序")
    func registerSortsByOrder() {
        let provider = DefaultRailViewProviding()
        provider.registerBottomItems([
            RailBottomItem(id: "b", order: 200) { Text("B") },
            RailBottomItem(id: "a", order: 100) { Text("A") },
        ])

        #expect(provider.bottomItems.map(\.id) == ["a", "b"])
        #expect(provider.hasVisibleBottomItems)
    }

    @Test("addBottomItems 合并贡献且不覆盖同 id 的先注册者")
    func addMergesWithoutOverwriting() {
        let provider = DefaultRailViewProviding()
        provider.addBottomItems([RailBottomItem(id: "a", order: 100) { Text("first") }])
        provider.addBottomItems([RailBottomItem(id: "a", order: 999) { Text("second") }])
        provider.addBottomItems([RailBottomItem(id: "b", order: 200) { Text("B") }])

        #expect(provider.bottomItems.map(\.id) == ["a", "b"])
    }

    @Test("removeBottomItems 按 id 撤回")
    func removeByID() {
        let provider = DefaultRailViewProviding()
        provider.registerBottomItems([
            RailBottomItem(id: "a") { Text("A") },
            RailBottomItem(id: "b") { Text("B") },
        ])

        provider.removeBottomItems(ids: ["a"])

        #expect(provider.bottomItems.map(\.id) == ["b"])
        #expect(provider.hasVisibleBottomItems)
    }

    @Test("撤回全部底部固定项后 hasVisibleBottomItems 为 false")
    func removeAllClearsVisibility() {
        let provider = DefaultRailViewProviding()
        provider.registerBottomItems([RailBottomItem(id: "a") { Text("A") }])
        #expect(provider.hasVisibleBottomItems)

        provider.removeBottomItems(ids: ["a"])

        #expect(provider.hasVisibleBottomItems == false)
        #expect(provider.bottomItems.isEmpty)
    }

    @Test("底部固定项变化时发出 bottomItemsChanged 事件")
    func emitsEventOnChange() {
        let provider = DefaultRailViewProviding()
        var received: [[RailBottomItem]] = []
        let handle = provider.addObserver { event in
            guard case let .bottomItemsChanged(items) = event else { return }
            received.append(items)
        }
        defer { handle.cancel() }

        provider.registerBottomItems([RailBottomItem(id: "a") { Text("A") }])
        #expect(received.count == 1)
        #expect(received.first?.map(\.id) == ["a"])

        provider.removeBottomItems(ids: ["a"])
        #expect(received.count == 2)
        #expect(received.last?.isEmpty == true)
    }

    @Test("重复注册相同 id 集合不重复发出事件")
    func doesNotEmitForIdenticalIDs() {
        let provider = DefaultRailViewProviding()
        var received = 0
        let handle = provider.addObserver { event in
            guard case .bottomItemsChanged = event else { return }
            received += 1
        }
        defer { handle.cancel() }

        provider.registerBottomItems([RailBottomItem(id: "a") { Text("A") }])
        #expect(received == 1)

        provider.registerBottomItems([RailBottomItem(id: "a") { Text("A") }])
        #expect(received == 1)
    }

    @Test("底部固定项不影响 Rail 标签的激活状态")
    func bottomItemsDoNotAffectTabActivation() {
        let provider = DefaultRailViewProviding()
        provider.registerTabs([
            RailTabItem(id: "a", category: .general, title: "A", systemImage: "a") { Text("A") },
            RailTabItem(id: "b", category: .general, title: "B", systemImage: "b") { Text("B") },
        ])
        provider.registerBottomItems([RailBottomItem(id: "user") { Text("user") }])

        #expect(provider.activeTabID == "a")
        #expect(provider.hasVisibleTabs)
        #expect(provider.hasVisibleBottomItems)
    }
}
