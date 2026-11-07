import SwiftUI
import Testing
@testable import ProviderSettingView

/// `SettingViewProviding` 协议契约：注册、选择、观察者、深链导航常量。
@Suite("设置协议契约")
@MainActor
struct SettingViewProvidingTests {

    // MARK: - 入口注册

    @Test("registerEntries 按 order 升序排序")
    func registerEntriesSortsByOrder() {
        let provider = DefaultSettingViewProviding()

        provider.registerEntries([
            EntryFixture.entry("c", order: 300),
            EntryFixture.entry("a", order: 100),
            EntryFixture.entry("b", order: 200),
        ])

        #expect(provider.entries.map(\.id) == ["a", "b", "c"])
    }

    @Test("registerEntries 会替换现有入口而非追加")
    func registerEntriesReplacesPrevious() {
        let provider = DefaultSettingViewProviding()

        provider.registerEntries([EntryFixture.entry("old")])
        provider.registerEntries([EntryFixture.entry("new")])

        #expect(provider.entries.map(\.id) == ["new"])
    }

    @Test("registerEntries 传入空数组时清空入口")
    func registerEntriesAcceptsEmpty() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("a")])
        provider.registerEntries([])

        #expect(provider.entries.isEmpty)
    }

    @Test("addEntries 合并同 id 去重并保留先注册者")
    func addEntriesMergesAndDeduplicates() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("a", title: "先注册", order: 100)])

        provider.addEntries([
            EntryFixture.entry("a", title: "后注册", order: 500),
            EntryFixture.entry("b", order: 200),
        ])

        #expect(provider.entries.map(\.id) == ["a", "b"])
        #expect(provider.entries.first?.title == "先注册", "同 id 应保留先注册者")
    }

    @Test("addEntries 在空注册表上等价于首次注册")
    func addEntriesOnEmptyProvider() {
        let provider = DefaultSettingViewProviding()

        provider.addEntries([EntryFixture.entry("b", order: 200), EntryFixture.entry("a", order: 100)])

        #expect(provider.entries.map(\.id) == ["a", "b"])
    }

    @Test("removeEntries 按 id 撤回入口并保留其余排序")
    func removeEntriesFiltersByID() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([
            EntryFixture.entry("a", order: 100),
            EntryFixture.entry("b", order: 200),
            EntryFixture.entry("c", order: 300),
        ])

        provider.removeEntries(ids: ["a", "c"])

        #expect(provider.entries.map(\.id) == ["b"])
    }

    @Test("removeEntries 传入未知 id 时保持不变")
    func removeEntriesIgnoresUnknownIDs() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("a", order: 100)])

        provider.removeEntries(ids: ["missing"])

        #expect(provider.entries.map(\.id) == ["a"])
    }

    // MARK: - 选中状态

    @Test("首次注册自动选中 order 最小的入口")
    func firstRegistrationSelectsLowestOrder() {
        let provider = DefaultSettingViewProviding()

        provider.registerEntries([
            EntryFixture.entry("second", order: 200),
            EntryFixture.entry("first", order: 100),
        ])

        #expect(provider.selectedEntryID == "first")
    }

    @Test("重新注册后保持原有选中项")
    func reRegistrationKeepsSelection() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([
            EntryFixture.entry("a", order: 100),
            EntryFixture.entry("b", order: 200),
        ])
        provider.selectEntry(id: "b")

        provider.registerEntries([
            EntryFixture.entry("a", order: 100),
            EntryFixture.entry("b", order: 200),
            EntryFixture.entry("c", order: 300),
        ])

        #expect(provider.selectedEntryID == "b", "选中项仍存在时不应被重置")
    }

    @Test("选中项被移除后回落到首个入口")
    func selectionFallsBackWhenEntryRemoved() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([
            EntryFixture.entry("a", order: 100),
            EntryFixture.entry("b", order: 200),
        ])
        provider.selectEntry(id: "b")

        provider.removeEntries(ids: ["b"])

        #expect(provider.entries.map(\.id) == ["a"])
        #expect(provider.selectedEntryID == "a")
    }

    @Test("入口全部清空后选中项变为 nil")
    func selectionClearsWhenNoEntries() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("a")])
        #expect(provider.selectedEntryID == "a")

        provider.registerEntries([])

        #expect(provider.selectedEntryID == nil)
    }

    @Test("selectEntry 重复选择同一项不重复发事件")
    func selectEntryIgnoresDuplicateSelection() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("a")])
        let log = EventLog()
        let handle = log.observe(provider)

        provider.selectEntry(id: "a")
        provider.selectEntry(id: "a")

        #expect(log.labels == [])
        handle.cancel()
    }

    @Test("selectEntry 允许切换到 nil")
    func selectEntryAcceptsNil() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("a"), EntryFixture.entry("b", order: 300)])

        provider.selectEntry(id: nil)

        #expect(provider.selectedEntryID == nil)
    }

    @Test("selectEntry 可选中尚未注册的 id 并保持该状态")
    func selectEntryCanTargetUnregisteredID() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("a")])

        provider.selectEntry(id: "not-registered")

        #expect(provider.selectedEntryID == "not-registered")
    }

    // MARK: - 观察者

    @Test("多次注册按各自状态变化发布事件")
    func multipleRegistrationsPublishEvents() {
        let provider = DefaultSettingViewProviding()
        let log = EventLog()
        let handle = log.observe(provider)

        provider.registerEntries([EntryFixture.entry("a")])
        provider.registerEntries([EntryFixture.entry("b")])

        // 每次注册都会发 entriesChanged；选中项失效时额外发一次 selectedEntryChanged
        #expect(log.labels == ["entries", "selected:a", "entries", "selected:b"])
        handle.cancel()
    }

    @Test("多个观察者同时收到事件")
    func multipleObserversReceiveEvents() {
        let provider = DefaultSettingViewProviding()
        var first = 0, second = 0
        let firstHandle = provider.addSettingViewObserver { _ in first += 1 }
        let secondHandle = provider.addSettingViewObserver { _ in second += 1 }

        provider.registerEntries([EntryFixture.entry("a")])

        // 首次注册产生 entriesChanged 与自动选中的 selectedEntryChanged
        #expect(first == 2)
        #expect(second == 2)
        firstHandle.cancel()
        secondHandle.cancel()
    }

    @Test("cancel 幂等且不会影响其他观察者")
    func cancelIsIdempotentAndScoped() {
        let provider = DefaultSettingViewProviding()
        var cancelledCount = 0
        var activeCount = 0
        let cancelledHandle = provider.addSettingViewObserver { _ in cancelledCount += 1 }
        let activeHandle = provider.addSettingViewObserver { _ in activeCount += 1 }

        provider.registerEntries([EntryFixture.entry("a")])
        cancelledHandle.cancel()
        cancelledHandle.cancel()

        provider.registerEntries([EntryFixture.entry("b")])

        #expect(cancelledCount == 2, "取消后的观察者不再收到事件")
        #expect(activeCount == 4, "其他观察者不受影响")
        activeHandle.cancel()
    }

    @Test("仅实现最小成员的 Provider 可用协议扩展工作")
    func protocolExtensionsWorkOnMinimalProvider() {
        let provider = MinimalSettingViewProvider()

        provider.addEntries([EntryFixture.entry("a", order: 100)])
        provider.addEntries([EntryFixture.entry("b", order: 200)])
        #expect(provider.entries.map(\.id) == ["a", "b"])
        #expect(provider.registerCallCount == 2, "每次 addEntries 应委托给 registerEntries 一次")

        provider.addProjectDetailSections([SectionFixture.section("stats")])
        provider.removeProjectDetailSections(ids: ["stats"])
        #expect(provider.projectDetailSections.isEmpty, "默认实现应为 no-op")
    }

    @Test("未实现的观察者方法回退为 no-op 句柄")
    func observerFallsBackToNoopHandle() {
        let provider = MinimalSettingViewProvider()

        let handle = provider.addSettingViewObserver { _ in
            Issue.record("no-op 句柄不应触发回调")
        }
        provider.registerEntries([EntryFixture.entry("a")])

        handle.cancel()
        handle.cancel()
    }

    // MARK: - 深链导航常量

    @Test("设置窗口导航常量值稳定")
    func navigationConstantsAreStable() {
        #expect(SettingViewNavigation.openSettingsNotification == Notification.Name("lumi.openSettings"))
        #expect(SettingViewNavigation.entryIDUserInfoKey == "lumi.settings.entryID")
    }

    @Test("只读 Provider 也能读取选中入口")
    func readonlyProviderReadsSelection() {
        let provider: any SettingViewProviding = DefaultSettingViewProviding()

        #expect(provider.selectedEntryID == nil)
        #expect(provider.entries.isEmpty)
        #expect(provider.projectDetailSections.isEmpty)
    }
}
