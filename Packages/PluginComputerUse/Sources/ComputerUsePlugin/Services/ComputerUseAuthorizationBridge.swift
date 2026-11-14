import Foundation
import KernelCore
import KitAgentTool
import ProviderAgentLoop
import ProviderMessageSender

/// 把卡片上的决定送回等待中的 agent。
///
/// 与 `ToolApprovalBridge` 的分工一致：UI 只负责采集决定，
/// 由本桥接层落地授权并驱动回合恢复。
@MainActor
final class ComputerUseAuthorizationBridge {
    static let shared = ComputerUseAuthorizationBridge()

    private weak var messageSender: (any MessageSendingProviding)?
    private weak var agentLoop: (any AgentLoopProviding)?
    private let coordinator: ComputerUseAuthorizationCoordinator

    init(coordinator: ComputerUseAuthorizationCoordinator = .shared) {
        self.coordinator = coordinator
    }

    func start(kernel: KernelCoreContainer) {
        messageSender = kernel.resolveProvider((any MessageSendingProviding).self)
        agentLoop = kernel.resolveProvider((any AgentLoopProviding).self)
    }

    func stop() {
        messageSender = nil
        agentLoop = nil
    }

    /// 落地决策并恢复回合。
    func resolve(
        conversationID: UUID,
        toolCall: ToolCall,
        request: ComputerUseAuthorizationRequest,
        decision: ComputerUseAuthorizationDecision
    ) {
        // 先落授权再恢复：恢复后工具会被重新执行，届时授权必须已经生效。
        let message = coordinator.apply(
            decision: decision,
            request: request,
            conversationID: conversationID
        )
        let answer = "\(ComputerUseAuthorizationResolver.token(for: decision))\n\(message)"

        guard let messageSender else {
            ComputerUseAuthorizationCoordinator.logger.error(
                "\(ComputerUseAuthorizationCoordinator.t)MessageSender 不可用，无法恢复回合"
            )
            return
        }
        ComputerUseAuthorizationCoordinator.logger.info(
            "\(ComputerUseAuthorizationCoordinator.t)用户决策已落地 decision=\(decision.rawValue, privacy: .public) app=\(request.bundleIdentifier, privacy: .public)"
        )
        Task { @MainActor in
            _ = try? await messageSender.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(
                    suspensionID: "userInput:\(toolCall.id)",
                    answer: answer
                )
            )
        }
    }
}
