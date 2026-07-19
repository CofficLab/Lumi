import AgentToolKit
import LumiKernel
import LumiUI
import SwiftUI

struct BorderedUtilityContent<Content: View>: View {
    let tint: Color
    let role: LumiChatMessageRole
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                tint.opacity(role == .system ? 0.07 : 0.1),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            )
    }
}

// MARK: - ToolCallRowsView
/// V1 (brief) 模式：纯文本 inline 样式，完全融入消息正文；
/// V2/V3 模式：带图标/背景/边框/按钮的卡片行。

struct ToolCallRowsView: View {
    let message: LumiChatMessage
    let verbosity: LumiResponseVerbosity

    @State private var parameterPopoverToolCallID: String?
    @State private var resultPopoverToolCallID: String?

    private var toolCalls: [LumiToolCall] {
        message.toolCalls ?? []
    }

    var body: some View {
        if verbosity == .brief {
            LumiInlineToolCallListView(toolCalls: toolCalls)
        } else {
            lumiCardRows
        }
    }

    private var lumiCardRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(toolCalls) { toolCall in
                ToolCallRowView(
                    message: message,
                    toolCall: toolCall,
                    verbosity: verbosity,
                    parameterPopoverToolCallID: $parameterPopoverToolCallID,
                    resultPopoverToolCallID: $resultPopoverToolCallID
                )
            }
        }
    }
}

// MARK: - V1 inline tool call view (brief mode)

/// V1 模式下的工具调用展示：纯文本 inline，完全融入消息正文样式。
/// 与 AssistantMessageBody 的正文保持一致的字体与颜色，
/// 不带图标、背景、边框、按钮，保持简洁的 inline 风格。
private struct LumiInlineToolCallListView: View {
    @LumiTheme private var theme
    let toolCalls: [LumiToolCall]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(toolCalls) { toolCall in
                Text(lineText(for: toolCall))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .allowsHitTesting(true)
            }
        }
    }

    private func lineText(for toolCall: LumiToolCall) -> String {
        let title = (toolCall.displayName?.isEmpty == false ? toolCall.displayName : nil) ?? toolCall.name
        return "\u{00b7} \(title)"
    }
}

// MARK: - ToolCallRowView

private struct ToolCallRowView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let toolCall: LumiToolCall
    let verbosity: LumiResponseVerbosity
    @Binding var parameterPopoverToolCallID: String?
    @Binding var resultPopoverToolCallID: String?

    @State private var isHovering = false

    /// V1 (brief) 只显示描述，V2/V3 显示更多详情
    private var showsDetails: Bool {
        verbosity != .brief
    }

    private var isParametersPresented: Bool {
        parameterPopoverToolCallID == toolCall.id
    }

    private var isResultsPresented: Bool {
        resultPopoverToolCallID == toolCall.id
    }

    private var isLoadingResult: Bool {
        toolCall.result == nil
    }

    /// 动作行展示文案：优先用工具生成的语义化描述，并根据执行状态加上
    /// 「正在…/已完成」前缀，读起来更接近自然语言。
    /// 仅当存在语义化描述时加前缀，避免给原始工具名（如 run_command）生硬拼接。
    private var actionTitle: String {
        if let displayName = toolCall.displayName {
            return isLoadingResult ? "正在\(displayName)…" : displayName
        }
        return toolCall.name
    }

    private var visualState: ToolCallResultVisualState {
        ToolCallResultVisualState(result: toolCall.result, isLoading: isLoadingResult)
    }

    var body: some View {
        Group {
            if let customRenderer = ToolCallRowRendererRegistry.shared.findRenderer(for: toolCall.agentToolCall) {
                customRenderer.render(
                    toolCall: toolCall.agentToolCall,
                    message: ToolCallRowMessageContext(
                        conversationId: message.conversationID,
                        assistantMessageId: message.id
                    )
                )
            } else {
                defaultToolCallRow
            }
        }
    }

    private var defaultToolCallRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.appCaptionEmphasized)
                    .foregroundColor(visualState.isFailure ? theme.error : theme.textSecondary)

                Text(actionTitle)
                    .font(.appCaption)
                    .foregroundColor(visualState.isFailure ? theme.error : theme.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            // V2/V3 显示执行时长
            if showsDetails, let duration = toolCall.result?.duration {
                Text(MessageViewHelpers.formatDuration(duration))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }

            // V2/V3 显示参数和结果按钮
            if showsDetails {
                parameterButton

                resultButton
            }
        }
        .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
        .background(rowBackground)
        .overlay(rowBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isHovering ? 1.01 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private var parameterButton: some View {
        AppIconButton(
            systemImage: "slider.horizontal.3",
            tint: isParametersPresented ? theme.textPrimary : theme.textSecondary,
            size: .regular,
            isActive: isParametersPresented
        ) {
            toggleParameterPopover()
        }
        .help(LumiPluginLocalization.string("调用参数", bundle: .module))
        .popover(isPresented: popoverBinding(selection: $parameterPopoverToolCallID), arrowEdge: .bottom) {
            ToolDetailPopoverView(
                title: "\(toolCall.name) · 调用参数",
                systemImage: "slider.horizontal.3"
            ) {
                ToolCallArgumentsView(toolCall: toolCall)
            }
        }
    }

    @ViewBuilder
    private var resultButton: some View {
        AppIconButton(
            systemImage: visualState.systemImage,
            tint: isResultsPresented
                ? theme.textPrimary
                : visualState.isFailure ? theme.error : theme.textSecondary,
            size: .regular,
            isActive: isResultsPresented
        ) {
            toggleResultPopover()
        }
        .help(LumiPluginLocalization.string("调用结果", bundle: .module))
        .popover(isPresented: popoverBinding(selection: $resultPopoverToolCallID), arrowEdge: .bottom) {
            ToolDetailPopoverView(
                title: "调用结果",
                systemImage: visualState.systemImage,
                isError: visualState.isFailure
            ) {
                ToolCallResultView(
                    result: toolCall.result,
                    isLoading: isLoadingResult,
                    visualState: visualState
                )
            }
        }
    }

    private var rowBackground: some View {
        Group {
            if isHovering {
                visualState.isFailure ? theme.error.opacity(0.12) : Color.white.opacity(0.08)
            } else {
                visualState.isFailure ? theme.error.opacity(0.08) : theme.textSecondary.opacity(0.06)
            }
        }
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                visualState.isFailure
                    ? theme.error.opacity(isHovering ? 0.45 : 0.28)
                    : isHovering ? Color.white.opacity(0.12) : theme.textTertiary.opacity(0.06),
                lineWidth: 1
            )
    }

    private func toggleParameterPopover() {
        parameterPopoverToolCallID = isParametersPresented ? nil : toolCall.id
    }

    private func toggleResultPopover() {
        resultPopoverToolCallID = isResultsPresented ? nil : toolCall.id
    }

    private func popoverBinding(selection: Binding<String?>) -> Binding<Bool> {
        Binding {
            selection.wrappedValue == toolCall.id
        } set: { isPresented in
            if !isPresented, selection.wrappedValue == toolCall.id {
                selection.wrappedValue = nil
            }
        }
    }
}

// MARK: - ToolDetailPopoverView

private struct ToolDetailPopoverView<Content: View>: View {
    @LumiTheme private var theme

    let title: String
    let systemImage: String
    var isError = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(isError ? theme.error : theme.textSecondary)

                Text(title)
                    .font(.appCallout)
                    .foregroundColor(isError ? theme.error : theme.textPrimary)
            }

            content
        }
        .padding(12)
        .frame(width: 520)
        .background(Material.regularMaterial)
    }
}

// MARK: - ToolCallArgumentsView

private struct ToolCallArgumentsView: View {
    let toolCall: LumiToolCall

    var body: some View {
        if let formattedArguments {
            ToolTextSectionView(content: formattedArguments)
        } else {
            EmptyToolSectionView(systemImage: "info.circle", text: "没有可显示的调用参数")
        }
    }

    private var formattedArguments: String? {
        MessageViewHelpers.formatToolCallArguments(toolCall.arguments)
    }
}

// MARK: - ToolCallResultView

private struct ToolCallResultView: View {
    let result: LumiToolResult?
    let isLoading: Bool
    let visualState: ToolCallResultVisualState

    var body: some View {
        if isLoading {
            LoadingToolSectionView()
        } else if let result {
            VStack(alignment: .leading, spacing: 8) {
                if visualState.isFailure {
                    ToolFailureNoticeView()
                }

                if result.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptyToolSectionView(
                        systemImage: "info.circle",
                        text: visualState.isFailure ? "没有错误详情" : "暂无工具输出"
                    )
                } else {
                    ToolTextSectionView(content: result.content, isError: visualState.isFailure)
                }
            }
        } else {
            EmptyToolSectionView(systemImage: "info.circle", text: "暂无工具输出")
        }
    }
}

// MARK: - LoadingToolSectionView

private struct LoadingToolSectionView: View {
    @LumiTheme private var theme

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text(verbatim: LumiPluginLocalization.string("查询结果中...", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolSubtleCard()
    }
}

// MARK: - ToolFailureNoticeView

private struct ToolFailureNoticeView: View {
    @LumiTheme private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.error)

            Text(verbatim: LumiPluginLocalization.string("工具执行失败", bundle: .module))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.error)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolSubtleCard()
    }
}

// MARK: - ToolTextSectionView

private struct ToolTextSectionView: View {
    @LumiTheme private var theme

    let content: String
    var isError = false

    var body: some View {
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        ) {
            ScrollView(.vertical, showsIndicators: true) {
                Text(content)
                    .font(.appMonoCaption)
                    .foregroundColor(isError ? theme.error : theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 360)
        }
    }
}

// MARK: - EmptyToolSectionView

private struct EmptyToolSectionView: View {
    @LumiTheme private var theme

    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(theme.textSecondary)

            Text(text)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolSubtleCard()
    }
}

// MARK: - ToolSubtleCardModifier

private struct ToolSubtleCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        ) {
            content
        }
    }
}

private extension View {
    func toolSubtleCard() -> some View {
        modifier(ToolSubtleCardModifier())
    }
}

// MARK: - ToolCallResultVisualState

enum ToolCallResultVisualState: Equatable {
    case loading
    case failed
    case completed

    init(result: LumiToolResult?, isLoading: Bool) {
        if isLoading {
            self = .loading
        } else if result?.isError == true {
            self = .failed
        } else {
            self = .completed
        }
    }

    var systemImage: String {
        switch self {
        case .loading: "hourglass"
        case .failed: "exclamationmark.triangle.fill"
        case .completed: "doc.text.magnifyingglass"
        }
    }

    var isFailure: Bool {
        self == .failed
    }
}
