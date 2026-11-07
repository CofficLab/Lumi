import SwiftUI
import Testing
@testable import ProviderSettingView

/// `SettingEntryItem` 的字段与详情视图构造行为。
@Suite("设置入口模型")
@MainActor
struct SettingEntryItemTests {

    @Test("默认 order 为 200，字段按构造参数赋值")
    func entryItemCarriesFields() {
        let entry = EntryFixture.entry("general", title: "通用", systemImage: "gearshape")

        #expect(entry.id == "general")
        #expect(entry.title == "通用")
        #expect(entry.systemImage == "gearshape")
        #expect(entry.order == 200)
    }

    @Test("可显式指定 order")
    func entryItemAcceptsCustomOrder() {
        #expect(EntryFixture.entry("a", order: 42).order == 42)
    }

    @Test("入口详情闭包按需构造视图")
    func entryItemBuildsDetailViewLazily() {
        var buildCount = 0
        let entry = SettingEntryItem(id: "counted", title: "Counted", systemImage: "folder") {
            buildCount += 1
            return Text("detail")
        }

        #expect(buildCount == 0, "详情视图应延迟到 makeDetailView 才构造")
        #expect(type(of: entry.makeDetailView()) == AnyView.self)
        #expect(buildCount == 1)

        _ = entry.makeDetailView()
        #expect(buildCount == 2, "每次调用都应重新构造视图")
    }

    @Test("入口是 Identifiable 且 id 可用于集合去重")
    func entryItemIsIdentifiable() {
        let entries = [EntryFixture.entry("b"), EntryFixture.entry("a")]

        #expect(entries.map(\.id) == ["b", "a"])
        #expect(Set(entries.map(\.id)).count == entries.count)
    }
}
