import SwiftUI
import Testing
@testable import ProviderSettingView

/// 设置外壳视图的冒烟测试：确认各平台分支都能构造并驱动 Provider。
@Suite("设置视图外壳")
@MainActor
struct SettingViewTests {

    @Test("makeSettingView 可为任意 Provider 生成视图")
    func makeSettingViewSupportsGenericProvider() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("general", order: 100)])

        #expect(type(of: makeSettingView(provider: provider)) == AnyView.self)
    }

    @Test("设置视图可由持有默认 Provider 构造")
    func settingViewConstructsForDefaultProvider() {
        let provider = DefaultSettingViewProviding()

        let view = SettingView(provider: provider)

        #expect(view.provider.selectedEntryID == nil)
    }

    @Test("设置视图在 Provider 已有入口与选中项时可构造")
    func settingViewConstructsWithSelectedEntry() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([
            EntryFixture.entry("first", order: 100),
            EntryFixture.entry("second", order: 200),
        ])
        provider.selectEntry(id: "second")

        let view = SettingView(provider: provider)

        #expect(view.provider.selectedEntryID == "second")
        #expect(view.provider.entries.count == 2)
    }

#if os(iOS)
    @Test("iOS 导航视图可构造并持有 Provider")
    func iosNavigationViewConstructs() {
        let provider = DefaultSettingViewProviding()
        provider.registerEntries([EntryFixture.entry("general")])

        let view = IOSSettingsNavigationView(provider: provider)

        #expect(view.provider.selectedEntryID == "general")
    }

    @Test("iOS 导航视图在无入口时保持空态")
    func iosNavigationViewHandlesEmptyProvider() {
        let provider = DefaultSettingViewProviding()

        let view = IOSSettingsNavigationView(provider: provider)

        #expect(view.provider.entries.isEmpty)
        #expect(view.provider.selectedEntryID == nil)
    }
#endif

    @Test("外壳观察者在消失后释放，不再接收事件")
    func shellObserverStopsReceivingEventsAfterCancel() {
        let provider = DefaultSettingViewProviding()
        let log = EventLog()
        let handle = log.observe(provider)
        provider.registerEntries([EntryFixture.entry("a")])
        let baseline = log.labels

        // 对应 `onDisappear` 时对句柄的 cancel
        handle.cancel()
        provider.addEntries([EntryFixture.entry("b")])
        provider.addProjectDetailSections([SectionFixture.section("s")])

        #expect(log.labels == baseline)
    }
}
