import os
import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import KitAgentTool
import LumiUI
import SwiftUI

/// V1 (brief) 模式下的「可折叠工具步骤组」(ChatGPT/Codex 风格)。
///
/// 把一条助手消息内联的若干工具调用包成一个可折叠的整体:
/// - 所有状态下都默认**收起**成一行摘要(`数量 + 总耗时`),点击可重新展开。
///
/// 用户随时可点击表头手动展开/收起任意步骤组;手动操作存于本地 `@State`,
/// 当本组从"进行中"变为"已完成"(`isActive` 由 true→false)时清空覆盖,回归默认收起态。
///
/// 展开态复用既有 `ToolCallRowView`(经 `ToolCallRowRendererRegistry` 优先走自定义渲染器),
/// 传入 `showsDetails: false` 以隐藏耗时与参数/结果按钮,保持 V1 的 inline 极简风格。
struct CollapsibleToolStepGroup: View {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-renderer", category: "CollapsibleToolStepGroup")

    let kernel: KernelCoreContainer
    @LumiTheme private var theme

    let message: Message
    let toolCalls: [MessageToolCall]
    let verbosity: LumiResponseVerbosity

    @State private var parameterPopoverToolCallID: String?
    @State private var resultPopoverToolCallID: String?

    /// 用户的手动展开/收起覆盖;`nil` 表示沿用默认(由 `isActive` 决定)。
    @State private var userOverride: Bool?

    /// 表头悬停态;仅用于显隐 chevron。
    @State private var isHovering = false
    @State private var resolvedToolCalls: [MessageToolCall]?
    @State private var isLoadingResults = false

    private var displayedToolCalls: [MessageToolCall] {
        resolvedToolCalls ?? toolCalls
    }

    private var resolutionTaskID: String {
        toolCalls
            .map { "\($0.id):\($0.result != nil)" }
            .joined(separator: "|")
    }

    /// 组内是否存在「正在等待用户作答」的交互式工具调用(如 ask_user)。
    /// 新版 `MessageToolResult` 不携带 `AgentTurnControl`，此判断降级为 false
    /// （等待态由 `ToolCallResult.awaitingUserResponse` 经自定义行渲染器呈现）。
    private var hasAwaitingInteraction: Bool {
        false
    }

    /// 有效折叠态:用户覆盖优先;否则进行中展开、结束后收起。
    /// 例外:存在等待用户作答的交互式调用时,强制展开(不可收起),保证交互入口可见。
    private var isCollapsed: Bool {
        if hasAwaitingInteraction { return false }
        return userOverride ?? true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryHeader

            if !isCollapsed {
                VStack(alignment: .leading, spacing: 10) {
                    if isLoadingResults {
                        ToolResultsLoadingView()
                    }
                    ForEach(displayedToolCalls) { toolCall in
                        toolCallRow(for: toolCall)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isCollapsed)
        .task(id: resolutionTaskID) {
            // Suspended interactive tools force the group open; load their result
            // even though there is no header click to trigger the lazy lookup.
            if !isCollapsed {
                await resolveResults()
            }
        }
    }

    // MARK: - Header (折叠态/展开态共用的一行摘要)

    private var summaryHeader: some View {
        Button {
            let willExpand = isCollapsed
            withAnimation(.easeInOut(duration: 0.2)) {
                userOverride = !isCollapsed
            }
            if willExpand {
                Task { await resolveResults() }
            }
        } label: {
            HStack(spacing: 6) {
                statusIcon

                Text(summaryText)
                    .font(.appCaption)
                    .foregroundColor(summaryColor)
                    .lineLimit(1)

                // chevron 紧贴摘要文字右侧(不再用 Spacer 推到行尾);默认隐藏,悬停时显现。
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
                    .opacity(isHovering ? 1 : 0)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
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
        if isLoadingResults { return .loading }
        return ToolStepGroupSummary.aggregateState(for: displayedToolCalls)
    }

    /// 折叠态摘要文案(用户选定的"数量 + 总耗时"样式)。
    /// - 进行中:`执行中 · 已完成 k/N`
    /// - 全部完成:`执行了 N 个步骤 · <总耗时>`(有失败则追加 `· X 失败`)
    private var summaryText: String {
        ToolStepGroupSummary.summaryText(for: displayedToolCalls)
    }

    @MainActor
    private func resolveResults() async {
        guard resolvedToolCalls == nil, let manager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("Failed to resolve ToolManagerProviding from kernel")
            return
        }

        // 命中"完全解析"缓存时跳过逐个 kernel 查询与 loading 态闪烁
        if let cached = ToolCallResolutionCache.shared.resolvedCalls(
            messageID: message.id,
            toolCalls: toolCalls
        ) {
            resolvedToolCalls = cached
            return
        }

        isLoadingResults = true
        defer { isLoadingResults = false }

        var resolved = toolCalls
        var didResolveAnyResult = false
        for index in resolved.indices where resolved[index].result == nil {
            if let raw = await manager.toolCallResult(for: resolved[index].id),
               let converted = MessageToolResult(toolCallResult: raw) {
                resolved[index].result = converted
                didResolveAnyResult = true
            }
        }
        ToolCallResolutionCache.shared.storeIfFullyResolved(
            messageID: message.id,
            toolCalls: resolved
        )
        if didResolveAnyResult || resolved.allSatisfy({ $0.result != nil }) {
            resolvedToolCalls = resolved
        }
    }

    // MARK: - Expanded rows

    @ViewBuilder
    private func toolCallRow(for toolCall: MessageToolCall) -> some View {
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
                kernel: kernel,
                message: message,
                toolCall: toolCall,
                verbosity: verbosity,
                // V1 展开态只显示工具名(+ loading/失败颜色),不带耗时与参数/结果按钮,
                // 以完全融入正文列。
                showsDetails: false,
                parameterPopoverToolCallID: $parameterPopoverToolCallID,
                resultPopoverToolCallID: $resultPopoverToolCallID
            )
        }
    }
}

private struct ToolResultsLoadingView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("正在加载工具结果…")
                .font(.appCaption)
                .foregroundColor(.secondary)
        }
    }
}
