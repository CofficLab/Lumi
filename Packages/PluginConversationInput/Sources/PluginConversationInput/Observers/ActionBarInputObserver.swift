import Foundation
import KitSuperLog
import os
import ProviderConversationInput
import ProviderMessageSender

/// 监听输入文本变化，并同步发送按钮的可发送状态。
@MainActor
final class ActionBarInputObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-input",
        category: "ActionBarInputObserver"
    )
    nonisolated static let emoji = "🔘"
    nonisolated static let verbose = false

    private weak var viewModel: SendActionBarViewModel?
    private var observer: (any TextInputObserverHandle)?
    private var senderObserver: (any MessageSenderObserverHandle)?

    init(
        capability: any ConversationInputCapability,
        viewModel: SendActionBarViewModel
    ) {
        self.viewModel = viewModel
        viewModel.updateInputText(capability.text)
        self.observer = capability.addTextObserver { [weak viewModel] text in
            viewModel?.updateInputText(text)
        }
        viewModel.updateAttachments()
        self.senderObserver = capability.addMessageSenderObserver { [weak viewModel] event in
            guard case .attachmentsChanged = event else { return }
            viewModel?.updateAttachments()
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
        senderObserver?.cancel()
        senderObserver = nil
    }
}
