import Foundation
import KitSuperLog
import os
import ProviderConversation

/// 监听对话切换事件，切换时清空输入框和未提交附件状态。
///
/// `DefaultConversationInputProvider` 是全局单例，输入文本跨对话持久存在。
/// 当用户切换对话时，需要主动调用 `clear()` 清空残留内容，
/// 否则新对话的输入框会显示上一个对话未发送的文本。清空逻辑通过
/// ViewModel 意图执行，View 不直接接触输入/发送 Provider。
@MainActor
final class ActionBarConversationObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-input",
        category: "ActionBarConversationObserver"
    )
    nonisolated static let emoji = "🔘"
    nonisolated static let verbose = false

    private weak var viewModel: ConversationInputViewModel?
    private var observer: (any SelectedConversationObserverHandle)?

    init(
        capability: any ConversationInputCapability,
        viewModel: ConversationInputViewModel
    ) {
        self.viewModel = viewModel
        self.observer = capability.addSelectedConversationObserver { [weak viewModel] _ in
            if Self.verbose {
                Self.logger.debug("conversation switched, clearing input")
            }
            viewModel?.handleConversationSwitched()
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }
}
