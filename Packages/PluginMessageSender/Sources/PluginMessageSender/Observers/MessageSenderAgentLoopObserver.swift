import Foundation
import ProviderAgentLoop

/// Forwards AgentLoop lifecycle events to the message sender.
@MainActor
final class MessageSenderAgentLoopObserver {
    private var handle: (any AgentLoopObserverHandle)?

    init(agentLoop: any AgentLoopProviding, sender: MessageSender) {
        handle = agentLoop.addAgentLoopObserver { [weak sender] event in
            sender?.handleAgentLoopEvent(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
