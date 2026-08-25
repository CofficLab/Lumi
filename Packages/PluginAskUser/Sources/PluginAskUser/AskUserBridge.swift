import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderMessageSender

/// Ask User UI 与 AgentLoop 之间的恢复桥接。
@MainActor
final class AskUserBridge {
    static let shared = AskUserBridge()

    private weak var messageSender: (any MessageSendingProviding)?

    private init() {}

    func start(kernel: KernelCoreContainer) {
        messageSender = kernel.resolveProvider((any MessageSendingProviding).self)
    }

    func resume(conversationId: String, toolCallId: String, answer: String) {
        guard let conversationID = UUID(uuidString: conversationId),
              let messageSender else { return }

        Task { @MainActor in
            _ = try? await messageSender.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(
                    suspensionID: "userInput:\(toolCallId)",
                    answer: answer
                )
            )
        }
    }
}
