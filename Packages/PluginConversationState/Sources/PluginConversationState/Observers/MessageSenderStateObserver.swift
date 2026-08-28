import Foundation
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
            case .turnCompleted(let id, _), .turnFailed(let id, _):
                self.provider.update(conversationID: id, clearActivity: true)
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
