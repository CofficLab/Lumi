import Foundation
import LumiLocalizationKit
import KernelCore
import ProviderActivityBar
import ProviderAgentLoop
import ProviderMessage
import ProviderMessageSender
import ProviderPromptSuggestion
import ProviderPromptSuggestionExecutor
import ProviderRailView
import ProviderSettingView
import ProviderToast
import SwiftUI
import Testing

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
                bundle: ProviderPromptSuggestionExecutorResources.bundle,
                locale: Locale(identifier: "zh-Hans")
            ) == "插件已启用"
        )
        #expect(
            LumiLocalization.string(
                "is now enabled.",
                bundle: ProviderPromptSuggestionExecutorResources.bundle,
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

    // MARK: - 发送失败反馈（#493）

    @Test("发送失败时必须展示错误 Toast（#493）")
    func sendFailureShowsErrorToast() async throws {
        let kernel = KernelCoreContainer()
        let sender = StubMessageSender(errorToSend: MessageSendError.persistence)
        let toasts = CapturingToastProviding()
        try kernel.registerProvider((any MessageSendingProviding).self, sender)
        try kernel.registerProvider((any ToastProviding).self, toasts)
        let executor = DefaultPromptSuggestionExecutor(kernel: kernel)
        let suggestion = PromptSuggestion(id: "send.fail", title: "发送", prompt: "hello")

        await executor.execute(suggestion)

        #expect(sender.recordedPrompts == ["hello"], "失败也应恰好尝试发送一次，不得静默跳过")
        let errorToast = toasts.shown.first { $0.style == .error }
        let toast = try #require(errorToast, "发送失败必须展示错误 Toast（#493）")
        #expect(toast.title == LumiLocalization.string("Failed to Send Message", bundle: ProviderPromptSuggestionExecutorResources.bundle))
        #expect(!(toast.detail ?? "").isEmpty, "错误详情不得为空")
    }

    @Test("发送成功不得展示错误 Toast（#493 护栏）")
    func sendSuccessShowsNoErrorToast() async throws {
        let kernel = KernelCoreContainer()
        let sender = StubMessageSender(errorToSend: nil)
        let toasts = CapturingToastProviding()
        try kernel.registerProvider((any MessageSendingProviding).self, sender)
        try kernel.registerProvider((any ToastProviding).self, toasts)
        let executor = DefaultPromptSuggestionExecutor(kernel: kernel)
        let suggestion = PromptSuggestion(id: "send.ok", title: "发送", prompt: "hello")

        await executor.execute(suggestion)

        #expect(sender.recordedPrompts == ["hello"])
        #expect(toasts.shown.isEmpty)
    }
}

/// 发送结果可编程的桩发送器。
@MainActor
private final class StubMessageSender: MessageSendingProviding {
    let errorToSend: MessageSendError?
    private(set) var recordedPrompts: [String] = []

    init(errorToSend: MessageSendError?) {
        self.errorToSend = errorToSend
    }

    var isSending: Bool { false }
    var pendingImageAttachments: [UserImageAttachment] { [] }
    var pendingFileAttachments: [UserFileAttachment] { [] }
    func addImageAttachment(_ attachment: UserImageAttachment) {}
    func removeImageAttachment(id: UUID) {}
    func clearImageAttachments() {}
    func addFileAttachment(_ attachment: UserFileAttachment) {}
    func removeFileAttachment(id: UUID) {}
    func clearFileAttachments() {}
    func addSendingStateObserver(_ callback: @escaping (Bool) -> Void) -> any SendingStateObserverHandle {
        NoopSendingStateHandle()
    }
    func pendingMessages(for conversationID: UUID) -> [PendingChatMessage] { [] }
    func cancelPendingMessage(id: UUID, in conversationID: UUID) {}
    func commitUserMessage(_ content: String, conversationID: UUID?) throws -> MessageSendCommit? { nil }
    func commitUserMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) throws -> MessageSendCommit? { nil }
    func commitUserMessageInBackground(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws -> MessageSendCommit? { nil }
    func startTurn(for commit: MessageSendCommit) async {}
    func cancelCurrentRequest() {}
    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome { .completed }

    func sendMessage(_ content: String, conversationID: UUID?) async throws {
        recordedPrompts.append(content)
        if let errorToSend { throw errorToSend }
    }

    func sendMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws {
        recordedPrompts.append(content)
        if let errorToSend { throw errorToSend }
    }
}

private enum MessageSendError: Error, CustomStringConvertible {
    case persistence

    var description: String { "persistence failed" }
}

@MainActor
private final class NoopSendingStateHandle: SendingStateObserverHandle {
    func cancel() {}
}

/// 捕获 Toast 的桩实现。
@MainActor
private final class CapturingToastProviding: ToastProviding {
    private(set) var shown: [LumiToast] = []
    private(set) var presentedErrors: [(title: String, message: String)] = []

    var currentToast: LumiToast? { shown.last }

    func show(_ toast: LumiToast) {
        shown.append(toast)
    }

    func presentError(title: String, message: String, sourceWindowID: String?) {
        presentedErrors.append((title, message))
    }

    func dismissError() {}

    func addObserver(
        _ callback: @escaping (ToastProvidingEvent) -> Void
    ) -> any ToastProvidingObserverHandle {
        NoopToastProvidingObserverHandle()
    }
}
