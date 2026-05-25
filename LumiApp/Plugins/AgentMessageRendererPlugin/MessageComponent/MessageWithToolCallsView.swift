import LumiUI
import AgentToolKit
import SwiftUI

/// 助手消息与工具调用视图
struct MessageWithToolCallsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let message: ChatMessage
    @EnvironmentObject var permissionRequestViewModel: WindowPermissionRequestVM
    @LumiMotionPreferenceReader private var motionPreference

    @State private var showRawMessage: Bool = false
    @State private var parameterPopoverToolCallID: String?
    @State private var resultPopoverToolCallID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !shouldHideMessageBody {
                MarkdownView(
                    message: message,
                    showRawMessage: showRawMessage
                )
                .messageBubbleStyle(role: message.role, isError: message.isError)
            }

            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(toolCalls.enumerated()), id: \.offset) { _, toolCall in
                        ToolCallRow(
                            toolCall: toolCall,
                            parameterPopoverToolCallID: $parameterPopoverToolCallID,
                            resultPopoverToolCallID: $resultPopoverToolCallID
                        )
                    }
                }
                .padding(.top, (message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || shouldHideMessageBody) ? 0 : 8)
            }
        }
    }

    private var trimmedContent: String {
        message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldHideMessageBody: Bool {
        guard message.toolCalls != nil else { return false }
        guard !trimmedContent.isEmpty else { return false }

        let lines = trimmedContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = lines.first else { return false }
        let isToolSummaryPrefix = first.hasPrefix("正在执行 ") || first.hasPrefix("Executing ")
        guard isToolSummaryPrefix else { return false }

        let toolCount = message.toolCalls?.count ?? 0
        return lines.count <= toolCount + 1
    }

}

// MARK: - Tool Call Row

/// 单条工具调用行，支持 hover 高亮效果
private struct ToolCallRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @LumiMotionPreferenceReader private var motionPreference

    let toolCall: ToolCall
    @Binding var parameterPopoverToolCallID: String?
    @Binding var resultPopoverToolCallID: String?

    @State private var isHovering = false

    private var isParametersPresented: Bool {
        parameterPopoverToolCallID == toolCall.id
    }

    private var isResultsPresented: Bool {
        resultPopoverToolCallID == toolCall.id
    }

    private var isLoadingResult: Bool {
        toolCall.result == nil && toolCall.authorizationState != .userRejected
    }

    private var shouldShowAuthState: Bool {
        toolCall.authorizationState != .noRisk
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textSecondary)

                Text(toolCall.displayName ?? toolCall.name)
                    .font(.appCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                if shouldShowAuthState {
                    Text("·")
                        .foregroundColor(theme.textSecondary)

                    Text(toolCall.authorizationState.displayName)
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let duration = toolCall.result?.duration {
                Text(formatDuration(duration))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }

            AppIconButton(
                systemImage: "slider.horizontal.3",
                tint: isParametersPresented
                    ? theme.textPrimary
                    : theme.textSecondary,
                size: .regular,
                isActive: isParametersPresented
            ) {
                toggleParameterPopover()
            }
            .help(String(localized: "调用参数", table: "CoreMessageRenderer"))
            .popover(isPresented: popoverBinding(selection: $parameterPopoverToolCallID), arrowEdge: .bottom) {
                ToolDetailPopoverView(
                    title: String(localized: "调用参数", table: "CoreMessageRenderer"),
                    systemImage: "slider.horizontal.3"
                ) {
                    ToolCallContentSectionView(toolCall: toolCall)
                }
            }

            AppIconButton(
                systemImage: isLoadingResult ? "hourglass" : "doc.text.magnifyingglass",
                tint: isResultsPresented
                    ? theme.textPrimary
                    : theme.textSecondary,
                size: .regular,
                isActive: isResultsPresented
            ) {
                toggleResultPopover()
            }
            .help(String(localized: "调用结果", table: "CoreMessageRenderer"))
            .popover(isPresented: popoverBinding(selection: $resultPopoverToolCallID), arrowEdge: .bottom) {
                ToolDetailPopoverView(
                    title: String(localized: "调用结果", table: "CoreMessageRenderer"),
                    systemImage: "doc.text.magnifyingglass"
                ) {
                    ToolResultSectionView(result: toolCall.result, isLoading: isLoadingResult)
                }
            }
        }
        .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
        .background(hoverBackground)
        .overlay(hoverBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isHovering && motionPreference.allowsMotion ? LumiMotion.rowHoverScale : 1.0)
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHovering)
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Hover Styles

    private var hoverBackground: some View {
        Group {
            if isHovering {
                Color.white.opacity(0.08)
            } else {
                theme.textSecondary.opacity(0.06)
            }
        }
    }

    private var hoverBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                isHovering ? Color.white.opacity(0.12) : theme.textTertiary.opacity(0.06),
                lineWidth: 1
            )
    }

    // MARK: - Actions

    private func toggleParameterPopover() {
        parameterPopoverToolCallID = parameterPopoverToolCallID == toolCall.id ? nil : toolCall.id
    }

    private func toggleResultPopover() {
        resultPopoverToolCallID = resultPopoverToolCallID == toolCall.id ? nil : toolCall.id
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

    /// 格式化耗时显示
    /// - 不到 1 秒显示毫秒，如 "320ms"
    /// - 1 秒以上显示秒（保留 1 位小数），如 "2.3s"
    /// - 超过 60 秒显示分秒，如 "1m 23s"
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1.0 {
            return "\(Int(duration * 1000))ms"
        } else if duration < 60.0 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Popover & Section Views

private struct ToolDetailPopoverView<Content: View>: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textSecondary)

                Text(title)
                    .font(.appCallout)
                    .foregroundColor(theme.textPrimary)
            }

            content
        }
        .padding(12)
        .frame(width: 520)
        .background(Material.regularMaterial)
    }
}

private struct ToolCallContentSectionView: View {
    let toolCall: ToolCall

    private var formattedArguments: String? {
        guard !toolCall.arguments.isEmpty,
              toolCall.arguments != "{}",
              let data = toolCall.arguments.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let prettyData = try? JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .sortedKeys]
        ),
        let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        return toolCall.arguments
    }

    var body: some View {
        if let formattedArguments {
            GenericToolSectionView(content: formattedArguments)
        } else {
            EmptyToolSectionView(
                systemImage: "info.circle",
                text: String(localized: "没有可显示的调用参数", table: "CoreMessageRenderer")
            )
        }
    }
}

private struct ToolResultSectionView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let result: ToolCallResult?
    let isLoading: Bool

    var body: some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(String(localized: "查询结果中…", table: "CoreMessageRenderer"))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(SubtleToolCardModifier())
        } else if let result, !result.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            GenericToolSectionView(content: result.content)
        } else {
            EmptyToolSectionView(
                systemImage: "info.circle",
                text: String(localized: "暂无工具输出", table: "CoreMessageRenderer")
            )
        }
    }
}

private struct GenericToolSectionView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let content: String

    var body: some View {
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        ) {
            ScrollView(.vertical, showsIndicators: true) {
                Text(content)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 360)
        }
    }
}

private struct EmptyToolSectionView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

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
        .modifier(SubtleToolCardModifier())
    }
}

private struct SubtleToolCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        ) {
            content
        }
    }
}
