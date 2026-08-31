import Foundation
import KitLocalization
import KernelCore
import ProviderActivityBar
import ProviderRailView
import ProviderSettingView
import SwiftUI
import Testing
@testable import ProviderPromptSuggestion

@Suite("PromptSuggestionExecutor")
@MainActor
struct PromptSuggestionExecutorTests {
    private final class NotificationCapture: @unchecked Sendable {
        var didOpenSettings = false
        var receivedEntryID: String?
    }

    @Test("插件启用 Toast 支持中文本地化")
    func localizesPluginEnabledToastStrings() {
        #expect(
            LumiLocalization.string(
                "Plugin Enabled",
                bundle: .module,
                locale: Locale(identifier: "zh-Hans")
            ) == "插件已启用"
        )
        #expect(
            LumiLocalization.string(
                "is now enabled.",
                bundle: .module,
                locale: Locale(identifier: "zh-Hans")
            ) == "已启用。"
        )
    }

    @Test("文件夹选择动作委托给 UI 回调")
    func forwardsProjectFolderSelection() async {
        let kernel = KernelCoreContainer()
        let executor = DefaultPromptSuggestionExecutor(kernel: kernel)
        var didPickFolder = false
        let suggestion = PromptSuggestion(
            id: "pick-folder",
            title: "选择项目",
            action: .pickProjectFolder
        )

        await executor.execute(suggestion) { didPickFolder = true }

        #expect(didPickFolder)
    }

    @Test("打开设置动作发布设置通知")
    func publishesOpenSettingsNotification() async {
        let kernel = KernelCoreContainer()
        let executor = DefaultPromptSuggestionExecutor(kernel: kernel)
        let capture = NotificationCapture()
        let observer = NotificationCenter.default.addObserver(
            forName: SettingViewNavigation.openSettingsNotification,
            object: nil,
            queue: .main
        ) { notification in
            capture.didOpenSettings = true
            capture.receivedEntryID = notification.userInfo?[SettingViewNavigation.entryIDUserInfoKey] as? String
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let suggestion = PromptSuggestion(
            id: "open-settings",
            title: "打开设置",
            action: .openSettingsTab("settings")
        )
        await executor.execute(suggestion)

        #expect(capture.didOpenSettings)
        #expect(capture.receivedEntryID == "settings")
    }

    @Test("插件入口动作同时激活 ActivityBar 和 Rail tab")
    func activatesPluginEntryAndRailTab() async throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let railView = DefaultRailViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any RailViewProviding).self, railView)

        let activityBarItemID = "plugin.entry"
        let railTabID = "plugin.documents"
        activityBar.registerItems([
            ActivityBarItem(
                id: activityBarItemID,
                title: "Plugin",
                systemImage: "square"
            ),
        ])
        railView.registerTabs([
            RailTabItem(
                id: railTabID,
                category: .project,
                title: "Documents",
                systemImage: "doc"
            ) {
                EmptyView()
            },
        ])

        let executor = DefaultPromptSuggestionExecutor(kernel: kernel)
        let suggestion = PromptSuggestion(
            id: "plugin.open",
            title: "打开插件",
            action: .activatePluginEntry(
                activityBarItemID: activityBarItemID,
                railTabID: railTabID
            )
        )

        await executor.execute(suggestion)

        #expect(activityBar.activeItemID == activityBarItemID)
        #expect(railView.activeTabID == railTabID)
    }
}
