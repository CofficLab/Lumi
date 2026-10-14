import LumiUI
import ProviderMessage
import SwiftUI

/// 失败消息 header 上的「重试」按钮。
///
/// 与用户消息上的 `ResendMessageButton`（重新发送消息内容）不同：这里重跑的是
/// 失败的那一轮 LLM 回合（`turnID`），由 AgentLoop 校验回合仍然有效。
struct RetryTurnButton: View {
    @LumiTheme private var theme

    let capability: (any MessageRendererCapability)?
    let message: Message

    private var retryableTurnID: UUID? {
        Self.retryableTurnID(message: message, capability: capability)
    }

    /// 该错误消息的回合当前是否真的可重试。
    ///
    /// 抽成纯函数以便单元测试直接覆盖判定：消息必须带 `turnID`，且
    /// AgentLoop 仍停留在该失败回合上（`canRetryTurn`）。回合已被新回合取代时
    /// 必须返回 `nil`，否则点击会触发一次注定失败的 `retryTurn`。
    static func retryableTurnID(
        message: Message,
        capability: (any MessageRendererCapability)?
    ) -> UUID? {
        guard let turnID = message.turnID,
              capability?.canRetryTurn(turnID: turnID, conversationID: message.conversationID) == true
        else { return nil }
        return turnID
    }

    var body: some View {
        AppIconButton(
            systemImage: "arrow.clockwise",
            label: pluginLocalization.string("重试"),
            tint: theme.textSecondary.opacity(0.8),
            size: .compact,
            action: retry
        )
        .help(pluginLocalization.string("重试该回合"))
    }

    private func retry() {
        guard let turnID = retryableTurnID else { return }
        Task {
            await capability?.retryTurn(turnID: turnID, conversationID: message.conversationID)
        }
    }
}
