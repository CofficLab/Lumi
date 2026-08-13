import Foundation
import KernelLumi

/// AskUser 插件桥接器
///
/// 用户做出选择后，通过 MessageSending 恢复 Turn。
///
/// MessageSending 同时维护发送中的 UI 状态，因此恢复流程和普通消息发送
/// 使用同一套生命周期，消息列表会显示临时的“正在发送”状态。
///
/// 数据流：
/// ```
/// 渲染器用户点击 → AskUserBridge.resume(...)
///         ↓
/// MessageSending.resumeTurn(...)
/// ```
@MainActor
public final class AskUserBridge: Sendable {
    public static let shared = AskUserBridge()

    private weak var messageSender: (any MessageSending)?

    private init() {}

    public func start(kernel: KernelLumi) {
        messageSender = kernel.messageSender
    }

    /// 用户做出选择后调用，触发恢复并保持发送状态。
    public func resume(conversationId: String, toolCallId: String, answer: String) {
        guard let conversationID = UUID(uuidString: conversationId),
              let messageSender
        else { return }

        Task { @MainActor in
            _ = try? await messageSender.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(
                    suspensionID: toolCallId,
                    answer: answer
                )
            )
        }
    }
}
