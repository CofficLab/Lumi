import Testing
@testable import PluginSettingView
import ProviderSettingView
import SwiftUI

@MainActor
@Suite("SettingViewManager Tests")
struct SettingViewManagerTests {

    private func makeEntry(id: String, order: Int = 200) -> SettingEntryItem {
        SettingEntryItem(id: id, title: id, systemImage: "gear", order: order) {}
    }

    @Test("registerEntries 按 order 升序排列")
    func registerAndSort() {
        let manager = SettingViewManager()

        manager.registerEntries([
            makeEntry(id: "c", order: 300),
            makeEntry(id: "a", order: 100),
            makeEntry(id: "b", order: 200),
        ])

        #expect(manager.entries.map(\.id) == ["a", "b", "c"])
    }

    @Test("registerEntries 自动选中第一项")
    func autoSelectFirst() {
        let manager = SettingViewManager()

        manager.registerEntries([makeEntry(id: "first", order: 100)])

        #expect(manager.selectedEntryID == "first")
    }

    @Test("addEntries 追加并去重")
    func addEntriesDedupe() {
        let manager = SettingViewManager()

        manager.registerEntries([makeEntry(id: "a", order: 100)])
        manager.addEntries([
            makeEntry(id: "a", order: 999),  // 重复，应忽略
            makeEntry(id: "b", order: 200),
        ])

        #expect(manager.entries.count == 2)
        #expect(manager.entries.map(\.id) == ["a", "b"])
        #expect(manager.entries.first(where: { $0.id == "a" })?.order == 100) // 保留先注册者
    }

    @Test("removeEntries 按 id 移除")
    func removeEntries() {
        let manager = SettingViewManager()

        manager.registerEntries([
            makeEntry(id: "a", order: 100),
            makeEntry(id: "b", order: 200),
        ])
        manager.removeEntries(ids: ["a"])

        #expect(manager.entries.count == 1)
        #expect(manager.entries.first?.id == "b")
    }

    @Test("选中入口切换")
    func selectEntry() {
        let manager = SettingViewManager()

        manager.registerEntries([
            makeEntry(id: "a", order: 100),
            makeEntry(id: "b", order: 200),
        ])
        #expect(manager.selectedEntryID == "a")

        manager.selectEntry(id: "b")
        #expect(manager.selectedEntryID == "b")
    }
}
