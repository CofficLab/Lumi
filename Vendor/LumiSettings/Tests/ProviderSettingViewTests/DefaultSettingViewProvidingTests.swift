import SwiftUI
import Testing
@testable import ProviderSettingView

/// `DefaultSettingViewProviding` 的具体行为：分区管理、视图渲染、事件时序。
@Suite("默认设置 Provider")
@MainActor
struct DefaultSettingViewProvidingTests {

    // MARK: - 入口与选中

    @Test("注入入口后排序且默认选中第一个")
    func registersSortsAndSelectsFirst() {
        let provider = DefaultSettingViewProviding()

        provider.registerEntries([
            EntryFixture.entry("b", order: 200),
            EntryFixture.entry("a", order: 100),
        ])

        #expect(provider.entries.map(\.id) == ["a", "b"])
        #expect(provider.selectedEntryID == "a")
    }

    @Test("空 Provider 初始无入口无选中")
    func initialStateIsEmpty() {
        let provider = DefaultSettingViewProviding()

        #expect(provider.entries.isEmpty)
        #expect(provider.projectDetailSections.isEmpty)
        #expect(provider.selectedEntryID == nil)
    }

    @Test("通过协议引用时行为一致")
    func behavesIdenticallyThroughProtocol() {
        let provider: any SettingViewProviding = DefaultSettingViewProviding()

        provider.addEntries([
            EntryFixture.entry("general", order: 100),
            EntryFixture.entry("plugins", order: 200),
        ])
        provider.selectEntry(id: "plugins")

        #expect(provider.entries.map(\.id) == ["general", "plugins"])
        #expect(provider.selectedEntryID == "plugins")
        #expect(type(of: provider.makeSettingView()) == AnyView.self)
    }

    // MARK: - 项目详情分区

    @Test("追加分区后按 order 排序")
    func addSectionsSortsByOrder() {
        let provider = DefaultSettingViewProviding()

        provider.addProjectDetailSections([
            SectionFixture.section("late", order: 300),
            SectionFixture.section("early", order: 100),
        ])

        #expect(provider.projectDetailSections.map(\.id) == ["early", "late"])
    }

    @Test("重复追加同 id 分区时保留先注册者")
    func addSectionsDeduplicatesByID() {
        let provider = DefaultSettingViewProviding()
        provider.addProjectDetailSections([SectionFixture.section("stats", order: 100)])

        provider.addProjectDetailSections([
            SectionFixture.section("stats", order: 900),
            SectionFixture.section("other", order: 200),
        ])

        #expect(provider.projectDetailSections.map(\.id) == ["stats", "other"])
        #expect(provider.projectDetailSections.first?.order == 100, "同 id 应保留先注册者")
    }

    @Test("按 id 移除分区")
    func removeSectionsFiltersByID() {
        let provider = DefaultSettingViewProviding()
        provider.addProjectDetailSections([
            SectionFixture.section("a", order: 100),
            SectionFixture.section("b", order: 200),
            SectionFixture.section("c", order: 300),
        ])

        provider.removeProjectDetailSections(ids: ["a", "c"])

        #expect(provider.projectDetailSections.map(\.id) == ["b"])
    }

    @Test("移除未知分区 id 时保持不变")
    func removeSectionsIgnoresUnknownIDs() {
        let provider = DefaultSettingViewProviding()
        provider.addProjectDetailSections([SectionFixture.section("a")])

        provider.removeProjectDetailSections(ids: ["missing"])

        #expect(provider.projectDetailSections.map(\.id) == ["a"])
    }

    // MARK: - 事件时序

    @Test("注册入口先发 entriesChanged 再发选中变更")
    func registrationPublishesSelectionAfterEntries() {
        let provider = DefaultSettingViewProviding()
        let log = EventLog()
        let handle = log.observe(provider)

        provider.registerEntries([
            EntryFixture.entry("a", order: 100),
            EntryFixture.entry("b", order: 200),
        ])

        #expect(log.labels == ["entries", "selected:a"])
        handle.cancel()
    }

    @Test("重新注册保持选中项时只发 entriesChanged")
    func reRegistrationWithoutSelectionChangeSkipsSelectionEvent() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("a", order: 100), EntryFixture.entry("b", order: 200)])
        let log = EventLog()
        let handle = log.observe(provider)

        provider.registerEntries([EntryFixture.entry("a", order: 100), EntryFixture.entry("b", order: 200)])

        #expect(log.labels == ["entries"])
        handle.cancel()
    }

    @Test("选中项失效时重新发出选中事件")
    func registrationPublishesSelectionWhenSelectionInvalidated() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("a", order: 100), EntryFixture.entry("b", order: 200)])
        provider.selectEntry(id: "b")
        let log = EventLog()
        let handle = log.observe(provider)

        provider.removeEntries(ids: ["b"])

        #expect(log.labels == ["entries", "selected:a"])
        handle.cancel()
    }

    @Test("分区变化发布 projectDetailSectionsChanged")
    func sectionChangesPublishEvent() {
        let provider = DefaultSettingViewProviding()
        let log = EventLog()
        let handle = log.observe(provider)

        provider.addProjectDetailSections([SectionFixture.section("a")])
        provider.addProjectDetailSections([SectionFixture.section("a")])
        provider.removeProjectDetailSections(ids: ["a"])
        provider.removeProjectDetailSections(ids: ["a"])

        #expect(log.labels == ["sections", "sections", "sections", "sections"])
        handle.cancel()
    }

    @Test("取消后不再收到任何事件")
    func cancelledObserverStopsReceivingEvents() {
        let provider = DefaultSettingViewProviding()
        let log = EventLog()
        let handle = log.observe(provider)
        provider.registerEntries([EntryFixture.entry("a")])
        let baseline = log.labels

        handle.cancel()
        provider.selectEntry(id: "a")
        provider.addEntries([EntryFixture.entry("b")])
        provider.addProjectDetailSections([SectionFixture.section("s")])

        #expect(log.labels == baseline)
    }

    // MARK: - 视图渲染

    @Test("有入口时返回可渲染的设置视图")
    func rendersViewWithEntries() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("a", systemImage: "folder")])

        #expect(type(of: provider.makeSettingView()) == AnyView.self)
    }

    @Test("无入口时返回可渲染的设置视图")
    func rendersViewWithoutEntries() {
        let provider = DefaultSettingViewProviding()

        #expect(type(of: provider.makeSettingView()) == AnyView.self)
    }
}
