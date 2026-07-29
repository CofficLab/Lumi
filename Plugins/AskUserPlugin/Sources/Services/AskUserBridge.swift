import Foundation
import LumiKernel

/// AskUser 插件桥接器
///
/// 用户做出选择后，直接委托给内核的 AgentTurnManager 恢复 Turn。
///
/// 数据流：
/// ```
/// 渲染器用户点击 → AskUserBridge.resume(...)
///         ↓
/// AgentTurnManager.resumeTurn(...)
/// ```
@MainActor
public final class AskUserBridge: Sendable {
    public static let shared = AskUserBridge()

    private weak var manager: (any AgentTurnManaging)?

    private init() {}

    public func start(kernel: LumiKernel) {
        manager = kernel.agentTurnManager
    }

    /// 用户做出选择后调用，直接触发内核恢复。
    public func resume(conversationId: String, toolCallId: String, answer: String) {
        guard let conversationID = UUID(uuidString: conversationId),
              let manager
        else { return }

        Task { @MainActor in
            _ = try? await manager.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(
                    suspensionID: toolCallId,
                    answer: answer
                )
            )
        }
    }
}
