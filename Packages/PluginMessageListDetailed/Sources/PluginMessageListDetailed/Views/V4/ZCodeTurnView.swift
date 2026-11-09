import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// V4（ZCode）一轮对话的视图外壳。
///
/// 一轮包含若干行（用户气泡、助手正文、工作历史、状态行）。
/// 本视图负责：
/// - 响应式内容列宽与 turn 间距；
/// - 把轮次上下文（`MessageTurnPresentationContext`）注入每一行；
/// - hover 状态属于**整个 turn**，通过 Environment 传给轮尾正文。
///
/// - Important: 助手正文**没有气泡、没有卡片背景、没有头像、没有名称**，
///   占满内容列。轮尾操作栏由核心 Assistant renderer 依据
///   `isTailAssistantText && !isRunning && messageTurnIsHovered` 自行决定。
struct ZCodeTurnView: View {
    let services: MessageListServices
    let developerModeState: DeveloperModeStateViewModel
    let turn: ZCodeTurn
    let verbosity: ResponseVerbosity
    /// 聊天容器宽度（用于响应式列宽与间距）。
    let containerWidth: CGFloat

    /// 当前 turn 是否处于 hover 状态。
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: ZCodeConversationLayout.primarySpacing) {
            ForEach(turn.rows) { row in
                MessageRowView(
                    services: services,
                    developerModeState: developerModeState,
                    message: row.message,
                    verbosity: verbosity,
                    turnContext: context(for: row)
                )
                .environment(\.messageTurnIsHovered, isHovered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, spacing.top)
        .padding(.bottom, spacing.bottom)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    // MARK: - 私有

    /// 该轮是否含有可见的用户气泡。
    ///
    /// 没有可见用户气泡的工作/通知型 turn 顶部间距为 0，
    /// 避免与上一 turn 的 20 叠加成 76 的空白。
    private var hasVisibleUserBubble: Bool {
        turn.rows.contains { row in
            row.message.role == .user
                && (!row.message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || row.message.toolCalls?.isEmpty == false)
        }
    }

    private var spacing: ZCodeConversationLayout.TurnSpacing {
        ZCodeConversationLayout.turnSpacing(hasVisibleUserBubble: hasVisibleUserBubble)
    }

    private var horizontalPadding: CGFloat {
        ZCodeConversationLayout.turnHorizontalPadding(for: containerWidth)
    }

    /// 为某一行构造轮次呈现上下文。
    ///
    /// - Important: 只有**轮尾助手正文**才带 `isTailAssistantText = true`，
    ///   这样操作栏只挂在轮尾，不会每条正文都出现一次。
    private func context(for row: ZCodeTurnRow) -> MessageTurnPresentationContext {
        MessageTurnPresentationContext(
            turnKey: turn.id,
            agentTurnID: turn.agentTurnID,
            isTailAssistantText: turn.tailAssistantRowID == row.id,
            isRunning: turn.isRunning,
            assistantCopyText: turn.assistantCopyText,
            completedAt: turn.completedAt
        )
    }
}
