import Foundation
import ProviderAgentLoop
import ProviderConversationState
import ProviderMessageSender

/// 将消息发送器的生命周期转换为会话 activity。
@MainActor
final class MessageSenderStateObserver {
    private let provider: ConversationStateProvider
    private var handle: (any MessageSenderObserverHandle)?

    init(sender: any MessageSendingProviding, provider: ConversationStateProvider) {
        self.provider = provider
        handle = sender.addMessageSenderObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .started(let id):
                self.provider.update(conversationID: id, activity: .sending)
            case .turnCompleted(let id, let outcome):
                // suspended 代表回合仍在等待用户处理，不能按完成回合清除 activity。
                guard case .suspended = outcome else {
                    self.provider.update(conversationID: id, clearActivity: true)
                    break
                }
            case .turnFailed(let id, _):
                self.provider.update(conversationID: id, clearActivity: true)
            case .attachmentsChanged, .pendingMessagesChanged:
                break
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
