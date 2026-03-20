import Foundation

/// 把“流式/轮次处理中间件产生的 UI 状态变化”从 `AgentRuntime` 中抽离出来。
///
/// - `AgentRuntime` 只负责 agent 领域逻辑与 runtimeStore 更新。
/// - UI 状态投影由 `DefaultAgentUIHandler`（或等价实现）直接写入各 UI VM。
@MainActor
protocol AgentUIHandler: AnyObject {
    // MARK: Message sending lifecycle
    func onMessageSendProcessingStarted(conversationId: UUID)
    func onMessageSendProcessingFinished(conversationId: UUID)

    // MARK: Stream lifecycle
    func onStreamStartedUI(messageId: UUID, conversationId: UUID)
    func onStreamFirstTokenUI(conversationId: UUID, ttftMs: Double?)
    func onStreamFinishedUI(conversationId: UUID)
    func onThinkingStartedUI(conversationId: UUID)

    // MARK: Turn lifecycle
    func onTurnFinishedUI(conversationId: UUID)
    func onTurnFailedUI(conversationId: UUID, errorMessage: String)

    // MARK: UI state projections
    func setPendingPermissionRequest(_ request: PermissionRequest?, conversationId: UUID)
    func setDepthWarning(_ warning: DepthWarning?, conversationId: UUID)
    func setLastHeartbeatTime(_ date: Date?)
    func setIsThinking(_ thinking: Bool, for conversationId: UUID)
    func appendThinkingText(_ text: String, for conversationId: UUID)
    func setThinkingText(_ text: String, for conversationId: UUID)

    // MARK: Imperative resets
    func setIsProcessing(_ processing: Bool)
    func dismissDepthWarning()

    /// 同步思考状态的“当前激活会话”，用于驱动全局 `isThinking/thinkingText` 展示。
    func setActiveConversation(_ conversationId: UUID?)
}

/// 默认实现：直接操作各个 UI ViewModel（用于共享的 `RootViewContainer` 场景）。
@MainActor
final class DefaultAgentUIHandler: AgentUIHandler {
    private let conversationVM: ConversationVM
    private let processingStateViewModel: ProcessingStateVM
    private let permissionRequestViewModel: PermissionRequestVM
    private let thinkingStateViewModel: ThinkingStateVM
    private let depthWarningViewModel: DepthWarningVM

    init(
        conversationVM: ConversationVM,
        processingStateViewModel: ProcessingStateVM,
        permissionRequestViewModel: PermissionRequestVM,
        thinkingStateViewModel: ThinkingStateVM,
        depthWarningViewModel: DepthWarningVM
    ) {
        self.conversationVM = conversationVM
        self.processingStateViewModel = processingStateViewModel
        self.permissionRequestViewModel = permissionRequestViewModel
        self.thinkingStateViewModel = thinkingStateViewModel
        self.depthWarningViewModel = depthWarningViewModel
    }

    func onMessageSendProcessingStarted(conversationId: UUID) {
        guard conversationVM.selectedConversationId == conversationId else { return }
        depthWarningViewModel.dismissDepthWarning()
        processingStateViewModel.beginSending()
    }

    func onMessageSendProcessingFinished(conversationId: UUID) {
        guard conversationVM.selectedConversationId == conversationId else { return }
        processingStateViewModel.finish()
    }

    func onStreamStartedUI(messageId: UUID, conversationId: UUID) {
        processingStateViewModel.markStreamStarted()
    }

    func onStreamFirstTokenUI(conversationId: UUID, ttftMs: Double?) {
        if let ttftMs {
            processingStateViewModel.markFirstToken(ttftMs: ttftMs)
        } else {
            processingStateViewModel.markGenerating()
        }
    }

    func onStreamFinishedUI(conversationId: UUID) {
        processingStateViewModel.finish()
    }

    func onThinkingStartedUI(conversationId: UUID) {
        setIsThinking(true, for: conversationId)
    }

    func onTurnFinishedUI(conversationId: UUID) {
        processingStateViewModel.finish()
    }

    func onTurnFailedUI(conversationId: UUID, errorMessage: String) {
        processingStateViewModel.finish()
    }

    func setPendingPermissionRequest(_ request: PermissionRequest?, conversationId: UUID) {
        permissionRequestViewModel.setPendingPermissionRequest(request)
    }

    func setDepthWarning(_ warning: DepthWarning?, conversationId: UUID) {
        depthWarningViewModel.setDepthWarning(warning)
    }

    func setLastHeartbeatTime(_ date: Date?) {
        processingStateViewModel.setLastHeartbeatTime(date)
    }

    func setIsThinking(_ thinking: Bool, for conversationId: UUID) {
        thinkingStateViewModel.setIsThinking(thinking, for: conversationId)
    }

    func appendThinkingText(_ text: String, for conversationId: UUID) {
        thinkingStateViewModel.appendThinkingText(text, for: conversationId)
    }

    func setThinkingText(_ text: String, for conversationId: UUID) {
        thinkingStateViewModel.setThinkingText(text, for: conversationId)
    }

    func setIsProcessing(_ processing: Bool) {
        processingStateViewModel.setIsProcessing(processing)
    }

    func dismissDepthWarning() {
        depthWarningViewModel.dismissDepthWarning()
    }

    func setActiveConversation(_ conversationId: UUID?) {
        thinkingStateViewModel.setActiveConversation(conversationId)
    }
}
