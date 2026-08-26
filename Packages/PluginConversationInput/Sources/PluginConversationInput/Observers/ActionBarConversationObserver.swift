import Foundation
import KitSuperLog
import os
import ProviderConversation
import ProviderConversationInput

/// 监听对话切换事件，切换时清空输入框状态。
///
/// `DefaultConversationInputProvider` 是全局单例，输入文本跨对话持久存在。
/// 当用户切换对话时，需要主动调用 `clear()` 清空残留内容，
/// 否则新对话的输入框会显示上一个对话未发送的文本。
@MainActor
final class ActionBarConversationObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-input",
        category: "ActionBarConversationObserver"
    )
    nonisolated static let emoji = "🔘"
    nonisolated static let verbose = false

    private weak var input: (any ConversationInputProviding)?
    private var observer: (any SelectedConversationObserverHandle)?

    init(conversations: any ConversationManaging, input: any ConversationInputProviding) {
        self.input = input
        self.observer = conversations.addSelectedConversationObserver { [weak self] _ in
            if Self.verbose {
                Self.logger.debug("\(self?.t ?? "")conversation switched, clearing input")
            }
            self?.input?.clear()
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }
}
