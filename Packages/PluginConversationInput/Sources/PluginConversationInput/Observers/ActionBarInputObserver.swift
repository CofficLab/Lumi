import Combine
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
    private var senderObserver: AnyCancellable?

    init(
        input: any ConversationInputProviding,
        sender: any MessageSendingProviding,
        viewModel: SendActionBarViewModel
    ) {
        self.viewModel = viewModel
        viewModel.updateInputText(input.text)
        self.observer = input.addTextObserver { [weak viewModel] text in
            viewModel?.updateInputText(text)
        }
        viewModel.updateAttachments()
        self.senderObserver = sender.objectWillChange.sink { [weak viewModel] _ in
            DispatchQueue.main.async {
                viewModel?.updateAttachments()
            }
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
        senderObserver?.cancel()
        senderObserver = nil
    }
}
