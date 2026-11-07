import SwiftUI
import Testing
@testable import ProviderSettingView

/// iOS 根页的入口分组归拢规则。
@MainActor
struct SettingEntryGroupingTests {

    private func entry(
        id: String,
        title: String,
        order: Int = 200,
        group: SettingEntryGroup? = nil
    ) -> SettingEntryItem {
        SettingEntryItem(id: id, title: title, systemImage: "gearshape", order: order, group: group) {
            EmptyView()
        }
    }

    private let appearance = SettingEntryGroup(id: "appearance", title: "外观", order: 10)
    private let general = SettingEntryGroup(id: "general", title: "通用", order: 20)

    @Test("按分组归拢，并按 group.order 排序")
    func groupsEntriesByDeclaredGroup() {
        let entries = [
            entry(id: "plugin-manager", title: "插件管理", order: 90, group: SettingEntryGroup(id: "extensions", title: "扩展", order: 30)),
            entry(id: "general", title: "应用信息", order: 1, group: general),
            entry(id: "appearance", title: "主题", order: 2, group: appearance),
        ]

        let sections = SettingEntryGrouping.sections(from: entries)

        #expect(sections.count == 3)
        #expect(sections.map(\.id) == ["appearance", "general", "extensions"])
        #expect(sections.map(\.title) == ["外观", "通用", "扩展"])
        #expect(sections[0].entries.map(\.id) == ["appearance"])
    }

    @Test("分组标题与组内唯一条目标题相同时不显示标题")
    func hidesTitleDuplicatingItsOnlyEntry() {
        let entries = [
            entry(id: "appearance", title: "外观", group: appearance),
            entry(id: "general", title: "通用", group: general),
        ]

        let sections = SettingEntryGrouping.sections(from: entries)

        #expect(sections.count == 2)
        // 「外观」分组里只有「外观」一行，标题只是复述行标题。
        #expect(sections[0].title == nil)
        #expect(sections[1].title == nil)
        // 分组本身仍然保留，只是不再画标题。
        #expect(sections.map(\.id) == ["appearance", "general"])
        #expect(sections[0].entries.map(\.id) == ["appearance"])
    }

    @Test("分组内有多项时保留标题")
    func keepsTitleWhenGroupHasMultipleEntries() {
        let entries = [
            entry(id: "theme", title: "主题", order: 10, group: appearance),
            entry(id: "mode", title: "外观模式", order: 20, group: appearance),
        ]

        let sections = SettingEntryGrouping.sections(from: entries)

        #expect(sections.count == 1)
        #expect(sections[0].title == "外观")
    }

    @Test("未声明分组的入口归入末尾的无标题分组")
    func ungroupedEntriesGoLastWithoutTitle() {
        let entries = [
            entry(id: "loose", title: "其他"),
            entry(id: "appearance", title: "外观", group: appearance),
        ]

        let sections = SettingEntryGrouping.sections(from: entries)

        #expect(sections.count == 2)
        #expect(sections[0].id == "appearance")
        #expect(sections[1].id == SettingEntryFallbackGroup.id)
        #expect(sections[1].title == nil)
        #expect(sections[1].entries.map(\.id) == ["loose"])
    }

    @Test("同组内保持 entry.order 的既有排序")
    func keepsEntryOrderWithinGroup() {
        let entries = [
            entry(id: "b", title: "B", order: 20, group: appearance),
            entry(id: "a", title: "A", order: 10, group: appearance),
        ]

        let sections = SettingEntryGrouping.sections(from: entries)

        #expect(sections.count == 1)
        #expect(sections[0].entries.map(\.id) == ["b", "a"])
    }

    @Test("关键词过滤命中标题，空关键词不过滤")
    func filtersByKeyword() {
        let entries = [
            entry(id: "appearance", title: "外观", group: appearance),
            entry(id: "general", title: "通用", group: general),
        ]

        #expect(SettingEntryGrouping.filter(entries, keyword: "").count == 2)
        #expect(SettingEntryGrouping.filter(entries, keyword: "  ").count == 2)
        #expect(SettingEntryGrouping.filter(entries, keyword: "外").map(\.id) == ["appearance"])
        #expect(SettingEntryGrouping.filter(entries, keyword: "zzz").isEmpty)
    }

    @Test("过滤与归拢可以组合调用")
    func combinesFilterAndGrouping() {
        let entries = [
            entry(id: "appearance", title: "外观", group: appearance),
            entry(id: "general", title: "通用", group: general),
        ]

        let sections = SettingEntryGrouping.sections(from: entries, keyword: "外")

        #expect(sections.count == 1)
        #expect(sections[0].id == "appearance")
    }

    @Test("连续的无标题分组合并成一张卡片")
    func mergesUntitledSectionsIntoOneCard() {
        let entries = [
            entry(id: "appearance", title: "外观", group: appearance),
            entry(id: "general", title: "通用", group: general),
        ]

        let cards = SettingEntryGrouping.cards(from: entries, keyword: "")

        #expect(cards.count == 1)
        #expect(cards[0].title == nil)
        #expect(cards[0].entries.map(\.id) == ["appearance", "general"])
    }

    @Test("有标题的分组自成一卡，不与相邻无标题分组合并")
    func titledSectionStaysSeparate() {
        let entries = [
            entry(id: "theme", title: "主题", order: 10, group: appearance),
            entry(id: "mode", title: "外观模式", order: 20, group: appearance),
            entry(id: "loose", title: "其他"),
        ]

        let cards = SettingEntryGrouping.cards(from: entries, keyword: "")

        #expect(cards.count == 2)
        #expect(cards[0].title == "外观")
        #expect(cards[0].entries.map(\.id) == ["theme", "mode"])
        #expect(cards[1].title == nil)
        #expect(cards[1].entries.map(\.id) == ["loose"])
    }
}
