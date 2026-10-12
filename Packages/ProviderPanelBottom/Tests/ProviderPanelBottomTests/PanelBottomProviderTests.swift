import SwiftUI
import Testing
@testable import ProviderPanelBottom

/// PanelBottomProvider 单元测试。
///
/// 覆盖点：
/// - 入口按 order 排序、同 id 覆盖更新；
/// - 按 ownerPluginID 批量撤回且不影响其他插件；
/// - 激活入口的回退（持久化历史选择 → 首个入口）与切换持久化；
/// - 类型化观察者在状态更新完成后收到事件。
@Suite("ProviderPanelBottom")
@MainActor
struct PanelBottomProviderTests {

    private func item(
        id: String,
        order: Int = 0,
        owner: String = "owner.a"
    ) -> PanelBottomItem {
        PanelBottomItem(
            id: id,
            title: id,
            order: order,
            ownerPluginID: owner
        ) { AnyView(EmptyView()) }
    }

    @Test("addItems 按 order 排序，同 id 覆盖更新")
    func addItemsSortsAndUpserts() {
        let provider = PanelBottomProvider()
        provider.addItems([item(id: "b", order: 200), item(id: "a", order: 100)])
        #expect(provider.items.map(\.id) == ["a", "b"])

        provider.addItems([PanelBottomItem(id: "a", title: "Updated", order: 100, ownerPluginID: "owner.a") {
            AnyView(EmptyView())
        }])
        #expect(provider.items.count == 2)
        #expect(provider.items.first?.title == "Updated")
    }

    @Test("无入口时 hasVisibleItems 为 false，注册后为 true")
    func hasVisibleItemsReflectsContents() {
        let provider = PanelBottomProvider()
        #expect(provider.hasVisibleItems == false)

        provider.addItems([item(id: "a")])
        #expect(provider.hasVisibleItems == true)
    }

    @Test("首个入口注册时激活它；removeItems 只撤回指定插件并回退激活入口")
    func removeItemsByOwnerFallsBackActiveItem() {
        let provider = PanelBottomProvider()
        provider.addItems([
            item(id: "preview.a", owner: "owner.a"),
            item(id: "terminal.b", order: 10, owner: "owner.b"),
        ])
        #expect(provider.activeItemID == "preview.a")

        provider.removeItems(ownerPluginID: "owner.a")
        #expect(provider.items.map(\.id) == ["terminal.b"])
        #expect(provider.activeItemID == "terminal.b")

        provider.removeItems(ownerPluginID: "owner.a")
        provider.removeItems(ownerPluginID: "owner.b")
        #expect(provider.hasVisibleItems == false)
        #expect(provider.activeItemID == nil)
    }

    @Test("激活入口优先回退到持久化的历史选择")
    func activeItemFallsBackToPersistedChoice() {
        let provider = PanelBottomProvider(loadActiveItemID: { "terminal.b" })
        provider.addItems([
            item(id: "preview.a", owner: "owner.a"),
            item(id: "terminal.b", order: 10, owner: "owner.b"),
        ])

        #expect(provider.activeItemID == "terminal.b")
    }

    @Test("selectItem 切换并持久化，未知 id 忽略")
    func selectItemPersistsChoice() {
        var persisted: String? = nil
        let provider = PanelBottomProvider(saveActiveItemID: { persisted = $0 })
        provider.addItems([
            item(id: "preview.a", owner: "owner.a"),
            item(id: "terminal.b", order: 10, owner: "owner.b"),
        ])

        provider.selectItem(id: "terminal.b")
        #expect(provider.activeItemID == "terminal.b")
        #expect(persisted == "terminal.b")

        provider.selectItem(id: "unknown.c")
        #expect(provider.activeItemID == "terminal.b")
        #expect(persisted == "terminal.b")
    }

    @Test("观察者在状态更新完成后收到 itemsChanged 与 activeItemChanged")
    func observersReceiveEventsAfterMutation() {
        let provider = PanelBottomProvider()
        var events: [PanelBottomEvent] = []
        let handle = provider.addPanelBottomObserver { event in
            // 事件触发时状态已更新。
            if case .itemsChanged = event {
                #expect(provider.hasVisibleItems == true)
            }
            events.append(event)
        }

        provider.addItems([item(id: "preview.a", owner: "owner.a")])
        provider.addItems([item(id: "terminal.b", order: 10, owner: "owner.b")])
        provider.selectItem(id: "terminal.b")

        // add#1: itemsChanged + activeItemChanged(preview.a)
        // add#2: itemsChanged（激活项未变）
        // select: activeItemChanged(terminal.b)
        #expect(events.count == 4)
        if case .itemsChanged? = events.first {
            // 期望命中
        } else {
            Issue.record("首个事件应为 itemsChanged")
        }
        if case let .activeItemChanged(activeID)? = events.last {
            #expect(activeID == "terminal.b")
        } else {
            Issue.record("末个事件应为 activeItemChanged")
        }

        handle.cancel()
        provider.addItems([item(id: "other.c", order: 200, owner: "owner.c")])
        #expect(events.count == 4)
    }
}
