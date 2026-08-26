import Foundation
import KitSuperLog
import os
import ProviderConversationInput

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

    init(input: any ConversationInputProviding, viewModel: SendActionBarViewModel) {
        self.viewModel = viewModel
        viewModel.updateInputText(input.text)
        self.observer = input.addTextObserver { [weak viewModel] text in
            viewModel?.updateInputText(text)
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }
}
