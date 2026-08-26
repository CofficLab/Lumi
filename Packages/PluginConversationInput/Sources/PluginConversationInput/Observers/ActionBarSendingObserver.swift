import Foundation
import KitSuperLog
import os
import ProviderMessageSender

/// 监听发送生命周期，并同步发送/停止按钮的显示状态。
@MainActor
final class ActionBarSendingObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-input",
        category: "ActionBarSendingObserver"
    )
    nonisolated static let emoji = "🔘"
    nonisolated static let verbose = false

    private weak var viewModel: SendActionBarViewModel?
    private var observer: (any SendingStateObserverHandle)?

    init(sender: any MessageSendingProviding, viewModel: SendActionBarViewModel) {
        self.viewModel = viewModel
        viewModel.updateSendingState(sender.isSending)
        self.observer = sender.addSendingStateObserver { [weak viewModel] isSending in
            viewModel?.updateSendingState(isSending)
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }
}
