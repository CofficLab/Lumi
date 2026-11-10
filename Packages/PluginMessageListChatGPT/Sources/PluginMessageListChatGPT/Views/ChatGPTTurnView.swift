import CoreGraphics
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// V5（ChatGPT）一轮对话的视图外壳。
///
/// 一轮包含若干行（用户气泡、助手正文、工作历史、状态行）。
/// 本视图负责：
/// - 响应式内容列宽与 turn 间距；
/// - 把轮次上下文（`MessageTurnPresentationContext`）注入每一行；
/// - 维护**两个独立的 hover 域**：用户段与助手段。
///
/// - Important: 助手正文**没有气泡、没有卡片背景、没有头像、没有名称**，
///   占满阅读列。轮尾操作由核心 Assistant renderer 依据
///   `isTailAssistantText && !isRunning && messageTurnIsHovered` 自行决定。
struct ChatGPTTurnView: View {
    let services: MessageListServices
    let turn: ChatGPTTurn
    let verbosity: ResponseVerbosity
    /// 聊天容器宽度（用于响应式列宽与间距）。
    let containerWidth: CGFloat

    /// 当前 turn 的**助手段**是否处于 hover 状态。
    ///
    /// - Important: 只覆盖助手正文、工作历史等**非用户**的段。
    ///   用户气泡有自己的 hover 域。
    @State private var isAssistantHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: ChatGPTConversationLayout.turnSpacing) {
            ForEach(segments) { segment in
                segmentView(segment)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, ChatGPTConversationLayout.turnSpacing)
        .padding(.bottom, ChatGPTConversationLayout.turnSpacing)
    }

    // MARK: - 分段

    /// 一轮内的**行段**：连续的同角色行归为一段。
    ///
    /// - Important: hover 域挂在**段**上，不是挂在单行上。
    ///
    ///   若每行各挂一个 `onHover`，鼠标从助手正文移到工作历史时，
    ///   「旧行离开」会把「新行进入」刚排好的防抖任务取消掉，
    ///   助手操作栏就永远亮不起来。段级 hover 只有一个进入 / 离开事件对。
    struct TurnSegment: Identifiable {
        /// 段身份。
        let id: String
        /// 段内的行。
        var rows: [ChatGPTTurnRow]
        /// 该段是否属于**用户**内容。
        let isUserSegment: Bool
    }

    /// 把本轮的行按角色分段。
    private var segments: [TurnSegment] {
        var result: [TurnSegment] = []
        for row in turn.rows {
            let isUserRow = row.message.role == .user
            if var last = result.last, last.isUserSegment == isUserRow {
                last.rows.append(row)
                result[result.count - 1] = last
            } else {
                result.append(
                    TurnSegment(
                        id: "\(isUserRow ? "user" : "assistant")-\(row.id)",
                        rows: [row],
                        isUserSegment: isUserRow
                    )
                )
            }
        }
        return result
    }

    @ViewBuilder
    private func segmentView(_ segment: TurnSegment) -> some View {
        VStack(alignment: .leading, spacing: ChatGPTConversationLayout.userAssistantSpacing) {
            ForEach(segment.rows) { row in
                MessageRowView(
                    services: services,
                    message: row.message,
                    verbosity: verbosity,
                    turnContext: context(for: row)
                )
                .environment(\.messageTurnIsHovered, isAssistantHovered)
            }
        }
        .modifier(
            TurnSegmentHoverDomainModifier(
                isUserSegment: segment.isUserSegment,
                isHovered: $isAssistantHovered
            )
        )
    }

    // MARK: - 私有

    private var horizontalPadding: CGFloat {
        ChatGPTConversationLayout.horizontalPadding(for: containerWidth)
    }

    /// 为某一行构造轮次呈现上下文。
    ///
    /// - Important: 只有**轮尾助手正文**才带 `isTailAssistantText = true`，
    ///   这样操作栏只挂在轮尾，不会每条正文都出现一次。
    private func context(for row: ChatGPTTurnRow) -> MessageTurnPresentationContext {
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

/// 把一段内容挂进 hover 域。
///
/// - Important: 用户段**必须**排除在助手段 hover 域之外。
///   否则悬停用户气泡就会点亮助手轮尾操作栏。
///
/// - Note: `.contentShape(Rectangle())` 让段的**空白区域**也算命中 ——
///   助手正文是占满阅读列的，没有气泡包裹，空白也是「正文的一部分」。
private struct TurnSegmentHoverDomainModifier: ViewModifier {
    let isUserSegment: Bool
    @Binding var isHovered: Bool

    func body(content: Content) -> some View {
        if isUserSegment {
            content
        } else {
            content
                .contentShape(Rectangle())
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}
