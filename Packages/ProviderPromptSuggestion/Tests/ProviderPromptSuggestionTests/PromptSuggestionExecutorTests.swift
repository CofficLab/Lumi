import Foundation
import KernelCore
import Testing
@testable import ProviderPromptSuggestion

@Suite("PromptSuggestionExecutor")
@MainActor
struct PromptSuggestionExecutorTests {
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
        let name = Notification.Name("lumi.openSettings")
        var didOpenSettings = false
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { _ in
            didOpenSettings = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let suggestion = PromptSuggestion(
            id: "open-settings",
            title: "打开设置",
            action: .openSettingsTab("settings")
        )
        await executor.execute(suggestion)

        #expect(didOpenSettings)
    }
}
