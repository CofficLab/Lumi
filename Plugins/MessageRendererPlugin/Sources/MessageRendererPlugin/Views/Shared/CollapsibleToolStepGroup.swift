import LumiKernel
import AgentToolKit
import LumiUI
import SwiftUI

/// V1 (brief) 模式下的「可折叠工具步骤组」(ChatGPT/Codex 风格)。
///
/// 把一条助手消息内联的若干工具调用包成一个可折叠的整体:
/// - **turn 进行中**(本组 id 在 `lumiActiveToolGroupIDs` 中)→ 默认**展开**,
///   逐个工具实时显示 loading → 完成(含耗时、参数/结果按钮)。
/// - **turn 结束** → 默认**收起**成一行摘要(`数量 + 总耗时`),点击可重新展开。
///
/// 用户随时可点击表头手动展开/收起任意步骤组;手动操作存于本地 `@State`,
/// 当本组从"进行中"变为"已完成"(`isActive` 由 true→false)时清空覆盖,回归默认收起态。
///
/// 展开态复用既有 `ToolCallRowView`(经 `ToolCallRowRendererRegistry` 优先走自定义渲染器),
/// 但**强制显示详情**(耗时、参数/结果按钮)——这是 V1 步骤组与旧 V1 纯文本行的关键区别。
struct CollapsibleToolStepGroup: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let toolCalls: [LumiToolCall]
    let verbosity: LumiResponseVerbosity

    @Environment(\.lumiActiveToolGroupIDs) private var activeIDs

    @State private var parameterPopoverToolCallID: String?
    @State private var resultPopoverToolCallID: String?

    /// 用户的手动展开/收起覆盖;`nil` 表示沿用默认(由 `isActive` 决定)。
    @State private var userOverride: Bool?

    /// 本组是否属于"当前正在进行的 turn" → 默认展开。
    private var isActive: Bool {
        activeIDs.contains(message.id)
    }

    /// 有效折叠态:用户覆盖优先,否则进行中展开、结束后收起。
    private var isCollapsed: Bool {
        userOverride ?? !isActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryHeader

            if !isCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(toolCalls) { toolCall in
                        toolCallRow(for: toolCall)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isCollapsed)
        // turn 结束(isActive true→false):清空手动覆盖,自动收起。
        // 注意:用户在结束后仍可再次手动点开(此时 isActive 已为 false,userOverride 重新赋值)。
        .onChange(of: isActive) { _, active in
            if !active, userOverride != nil {
                userOverride = nil
            }
        }
    }

    // MARK: - Header (折叠态/展开态共用的一行摘要)

    private var summaryHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                userOverride = !isCollapsed
            }
        } label: {
            HStack(spacing: 6) {
                statusIcon

                Text(summaryText)
                    .font(.appCaption)
                    .foregroundColor(summaryColor)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // chevron 指示展开/收起方向。
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusIcon: some View {
        Group {
            if aggregateState == .loading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: aggregateState.systemImage)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(aggregateState.isFailure ? theme.error : theme.textSecondary)
            }
        }
        .frame(width: 14, height: 14)
    }

    private var summaryColor: Color {
        aggregateState.isFailure ? theme.error : theme.textSecondary
    }

    /// 组内任一调用仍在执行 → loading;否则任一失败 → failed;否则 completed。
    private var aggregateState: ToolCallResultVisualState {
        ToolStepGroupSummary.aggregateState(for: toolCalls)
    }

    /// 折叠态摘要文案(用户选定的"数量 + 总耗时"样式)。
    /// - 进行中:`执行中 · 已完成 k/N`
    /// - 全部完成:`执行了 N 个步骤 · <总耗时>`(有失败则追加 `· X 失败`)
    private var summaryText: String {
        ToolStepGroupSummary.summaryText(for: toolCalls)
    }

    // MARK: - Expanded rows

    @ViewBuilder
    private func toolCallRow(for toolCall: LumiToolCall) -> some View {
        if let customRenderer = ToolCallRowRendererRegistry.shared.findRenderer(for: toolCall.agentToolCall) {
            customRenderer.render(
                toolCall: toolCall.agentToolCall,
                message: ToolCallRowMessageContext(
                    conversationId: message.conversationID,
                    assistantMessageId: message.id,
                    verbosityRawValue: verbosity.rawValue
                )
            )
        } else {
            ToolCallRowView(
                message: message,
                toolCall: toolCall,
                verbosity: verbosity,
                showsDetails: true,
                parameterPopoverToolCallID: $parameterPopoverToolCallID,
                resultPopoverToolCallID: $resultPopoverToolCallID
            )
        }
    }
}
