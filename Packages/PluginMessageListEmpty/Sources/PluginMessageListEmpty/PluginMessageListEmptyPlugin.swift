import KernelCore
import LumiLoggingKit
import LumiUI
import os
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderProject
import ProviderPromptSuggestion
import ProviderToolbar
import SwiftUI

/// 独立的消息列表空态插件。
///
/// 它不依赖任何一个详细程度消息列表插件；通过 ChatSection 的互斥内容组，
/// 在未选中会话或当前会话没有消息时独立接管消息列表槽位。
@MainActor
public final class PluginMessageListEmptyPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.message-list.empty",
        category: "MessageListEmpty"
    )

    public let id = "com.coffic.lumi.plugin.message-list.empty"
    public let order = 81

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-list.empty",
        name: "消息列表（空态）",
        description: "无选中会话或无消息时的聊天空态",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var chat: (any ChatSectionProviding)?
    private var conversations: (any ConversationManaging)?
    private var messages: (any MessageManaging)?
    private var services: MessageListEmptyServices?
    private var guideState: MessageListGuideState?
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var messageChangeObserver: (any MessageChangeObserverHandle)?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    private var chatObserver: (any ChatSectionProvidingObserverHandle)?
    private var promptSuggestionsObserver: (any PromptSuggestionProvidingObserverHandle)?
    private var registrationEvaluationTask: Task<Void, Never>?
    private var isRegistered = false
    /// 「当前会话是否没有消息」这个判定的结果。
    ///
    /// 判定依赖异步 SwiftData 查询，因此必须显式建模「尚未得出结论」，
    /// 否则「还不知道」会被当成「答案是空」，让空态在判定窗口内抢占
    /// `message-list` 槽位，用户看到有消息却显示空态引导页。
    private enum RegistrationState {
        /// 判定任务在途，此刻**不应**参与槽位竞争。
        case evaluating
        /// 判定已完成，关联值即结论。
        case resolved(Bool)
    }
    private var registrationState: RegistrationState = .evaluating

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }

        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        let messages = kernel.resolveProvider((any MessageManaging).self)
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let promptSuggestions = kernel.resolveProvider((any PromptSuggestionProviding).self)
        let promptSuggestionExecutor = kernel.resolveProvider((any PromptSuggestionExecuting).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let services = MessageListEmptyServices(
            project: project,
            promptSuggestions: promptSuggestions,
            promptSuggestionExecutor: promptSuggestionExecutor
        )
        let toolbarCoordinator = NoConversationSelectedToolbarCoordinator(
            project: project,
            toolbar: toolbar
        )
        let guideState = MessageListGuideState(
            context: chat.activeContext,
            project: project,
            toolbarCoordinator: toolbarCoordinator
        )

        self.chat = chat
        self.conversations = conversations
        self.messages = messages
        self.services = services
        self.guideState = guideState

        selectedConversationObserver = conversations?.addSelectedConversationObserver { [weak self] conversationID in
            self?.updateSelection(conversationID)
            self?.scheduleRegistrationEvaluation()
        }
        messageChangeObserver = messages?.addMessageChangeObserver { [weak self] change in
            self?.handleMessageChange(change)
        }
        projectObserver = project?.addObserver { [weak guideState, project] _ in
            guideState?.handleProjectChange(project)
        }
        chatObserver = chat.addObserver { [weak guideState] event in
            guard case let .activeContextChanged(context) = event else { return }
            guideState?.handleContextChange(context)
        }
        promptSuggestionsObserver = promptSuggestions?.addObserver { [weak guideState] _ in
            guideState?.handlePromptSuggestionsChange()
        }

        updateSelection(conversations?.selectedConversationID)
        // 常驻注册：可见性随后续判定变化，注册本身不再变动。
        register()
        scheduleRegistrationEvaluation()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        registrationEvaluationTask?.cancel()
        registrationEvaluationTask = nil
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        messageChangeObserver?.cancel()
        messageChangeObserver = nil
        projectObserver?.cancel()
        projectObserver = nil
        chatObserver?.cancel()
        chatObserver = nil
        promptSuggestionsObserver?.cancel()
        promptSuggestionsObserver = nil

        if isRegistered {
            chat?.removeItem(id: id)
            isRegistered = false
        }
        guideState?.toolbarCoordinator.deactivate()
        guideState = nil
        services = nil
        messages = nil
        conversations = nil
        chat = nil
    }

    private func updateSelection(_ conversationID: UUID?) {
        guideState?.handleSelectionChange(conversationID)
    }

    private func handleMessageChange(_ change: MessageChange) {
        guard let selectedID = conversations?.selectedConversationID else {
            scheduleRegistrationEvaluation()
            return
        }
        let changedID: UUID?
        switch change {
        case let .inserted(_, conversationID), let .persisted(_, conversationID),
             let .updated(conversationID), let .deleted(_, conversationID),
             let .cleared(conversationID):
            changedID = conversationID
        }
        guard changedID == selectedID else { return }
        scheduleRegistrationEvaluation()
    }

    /// Schedule the database-backed empty-state check off the MainActor.
    ///
    /// Selection and message observers can fire in bursts while a conversation
    /// is loading or a turn is streaming. Canceling the previous task keeps
    /// only the latest state check and avoids synchronously entering SwiftData
    /// from the UI thread.
    private func scheduleRegistrationEvaluation() {
        registrationEvaluationTask?.cancel()
        let selectedID = conversations?.selectedConversationID
        updateSelection(selectedID)

        // 「判定中」：先退出槽位竞争，等结论出来再决定是否进入。
        //
        // - Important: 这是修复「有消息却显示空态」的关键。判定需要异步
        //   SwiftData 查询，在结论出来之前若保持已注册状态，消息列表插件
        //   会因 exclusiveGroup 排序而失去槽位；查询完成后撤销注册又需要
        //   一个异步窗口，用户会在窗口内看到空态引导页。这里让「尚未得知」
        //   明确表达为「暂不参与竞争」，而不是「答案是空」。
        registrationState = .evaluating

        guard let selectedID else {
            applyRegistration(shouldShow: true)
            return
        }

        guard let messages else {
            applyRegistration(shouldShow: true)
            return
        }

        registrationEvaluationTask = Task { @MainActor [weak self, messages] in
            guard let self else { return }

            let shouldShow = await messages.messagePageAsync(
                for: selectedID,
                limit: 1,
                beforeMessageID: nil,
                includesToolMessages: false
            ).isEmpty

            guard !Task.isCancelled,
                  self.conversations?.selectedConversationID == selectedID else { return }
            self.applyRegistration(shouldShow: shouldShow)
            self.registrationEvaluationTask = nil
        }
    }

    /// 空态当前是否应当渲染。
    ///
    /// 判定依赖异步 SwiftData 查询，因此必然存在一个「尚未得出结论」的
    /// 中间态。关键在于把它表达为 `false`（不渲染）而不是「答案是空」：
    ///
    /// `isActive` 在 `ChatSectionHostView.stackItems` 中先于 `exclusiveItems`
    /// 求值，因此它同时决定本插件能否赢得 `message-list` 槽位。判定在途时
    /// 返回 `false`，消息列表插件（常驻注册）即先渲染，用户不会看到「有消息
    /// 却显示空态」的中间画面。
    private var shouldRenderEmptyState: Bool {
        switch registrationState {
        case .evaluating:
            return false
        case .resolved(let value):
            return value
        }
    }

    /// 常驻注册槽位 item。注册是一次性的，可见性完全由 `isActive` 表达——
    /// 注册状态与可见状态刻意分离，避免二者脱节。
    ///
    /// 与 `VerbosityObservationBox` 采用同一范式：把状态收敛到单一数据源，
    /// 才不会出现在「已移除 item 却仍需重新注册」这类不变量被破坏的路径上。
    private func register() {
        guard !isRegistered else { return }
        let services = services
        chat?.addItems([
            ChatSectionItem(
                id: id,
                order: order,
                exclusiveGroup: "message-list",
                fillsRemainingHeight: true,
                isActive: { @MainActor [weak self] in
                    self?.shouldRenderEmptyState ?? false
                },
                content: { [weak guideState] in
                    guard let services, let guideState else { return AnyView(EmptyView()) }
                    return AnyView(MessageListEmptyContentView(services: services, guideState: guideState))
                }
            )
        ])
        isRegistered = true
    }

    private func applyRegistration(shouldShow: Bool) {
        registrationState = .resolved(shouldShow)
        chat?.refreshItems()
    }
}

@MainActor
private struct MessageListEmptyContentView: View {
    let services: MessageListEmptyServices
    @ObservedObject var guideState: MessageListGuideState

    var body: some View {
        if guideState.selectedConversationID == nil {
            return AnyView(NoConversationSelectedView(services: services, guideState: guideState))
        }
        return AnyView(MessageEmptyStateView(services: services, guideState: guideState))
    }
}
