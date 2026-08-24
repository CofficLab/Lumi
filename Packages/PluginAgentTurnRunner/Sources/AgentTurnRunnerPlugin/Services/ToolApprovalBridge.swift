import Foundation
import KernelLumi

/// AgentTurnRunner-owned bridge from its approval renderer back to the
/// suspended turn. AskUserPlugin is deliberately not involved.
@MainActor
final class ToolApprovalBridge: Sendable {
    static let shared = ToolApprovalBridge()

    private weak var messageSender: (any MessageSending)?

    private init() {}

    func start(kernel: KernelLumi) {
        messageSender = kernel.messageSender
    }

    func respond(to payload: ToolApprovalPayload, answer: String) {
        guard let conversationID = UUID(uuidString: payload.conversationId),
              let messageSender
        else { return }

        Task { @MainActor in
            _ = try? await messageSender.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(
                    suspensionID: payload.toolCallId,
                    answer: answer
                )
            )
        }
    }
}
