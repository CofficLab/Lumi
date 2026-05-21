import LumiUI
import SwiftUI

/// 助手消息与工具调用视图
struct MessageWithToolCallsView: View {
    let message: ChatMessage
    let toolOutputMessages: [ChatMessage]

    @EnvironmentObject var permissionRequestViewModel: WindowPermissionRequestVM
    @EnvironmentObject var timelineViewModel: WindowChatTimelineViewModel
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
                        toolCallRow(for: toolCall)
                    }
                }
                .padding(.top, (message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || shouldHideMessageBody) ? 0 : 8)
            }
        }
    }

    @ViewBuilder
    private func toolCallRow(for toolCall: ToolCall) -> some View {
        let isParametersPresented = parameterPopoverToolCallID == toolCall.id
        let isResultsPresented = resultPopoverToolCallID == toolCall.id
        let isLoadingResult = timelineViewModel.isLoadingToolOutput(for: toolCall.id)
        let resultMessages = timelineViewModel.toolOutputs(for: toolCall.id)
        let effectiveResults = resultMessages.isEmpty
            ? toolOutputMessages.filter { $0.toolCallID == toolCall.id }
            : resultMessages
        let shouldShowAuthState = toolCall.authorizationState != .noRisk

        VStack(alignment: .leading, spacing: 8) {
            AppCard(
                style: .subtle,
                padding: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
            ) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                        Text(toolCall.name)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                            .lineLimit(1)

                        if shouldShowAuthState {
                            Text("·")
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                            Text(toolCall.authorizationState.displayName)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    AppIconButton(
                        systemImage: "slider.horizontal.3",
                        tint: isParametersPresented
                            ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
                            : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"),
                        size: .regular,
                        isActive: isParametersPresented
                    ) {
                        toggleParameterPopover(for: toolCall.id)
                    }
                    .help(String(localized: "调用参数", table: "CoreMessageRenderer"))
                    .popover(isPresented: popoverBinding(for: toolCall.id, selection: $parameterPopoverToolCallID), arrowEdge: .bottom) {
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
                            ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
                            : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"),
                        size: .regular,
                        isActive: isResultsPresented
                    ) {
                        toggleResultPopover(for: toolCall.id)
                    }
                    .help(String(localized: "调用结果", table: "CoreMessageRenderer"))
                    .popover(isPresented: popoverBinding(for: toolCall.id, selection: $resultPopoverToolCallID), arrowEdge: .bottom) {
                        ToolDetailPopoverView(
                            title: String(localized: "调用结果", table: "CoreMessageRenderer"),
                            systemImage: "doc.text.magnifyingglass"
                        ) {
                            ToolResultSectionView(outputs: effectiveResults, isLoading: isLoadingResult)
                        }
                    }
                }
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

    private func toggleParameterPopover(for toolCallID: String) {
        parameterPopoverToolCallID = parameterPopoverToolCallID == toolCallID ? nil : toolCallID
    }

    private func toggleResultPopover(for toolCallID: String) {
        let shouldShow = resultPopoverToolCallID != toolCallID

        if shouldShow && !timelineViewModel.hasLoadedToolOutput(for: toolCallID) {
            timelineViewModel.loadToolOutput(for: message, toolCallID: toolCallID)
        }

        resultPopoverToolCallID = shouldShow ? toolCallID : nil
    }

    private func popoverBinding(for toolCallID: String, selection: Binding<String?>) -> Binding<Bool> {
        Binding {
            selection.wrappedValue == toolCallID
        } set: { isPresented in
            if !isPresented, selection.wrappedValue == toolCallID {
                selection.wrappedValue = nil
            }
        }
    }

}

private struct ToolDetailPopoverView<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
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
    let outputs: [ChatMessage]
    let isLoading: Bool

    private var combinedContent: String {
        outputs
            .map(\.content)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(String(localized: "查询结果中…", table: "CoreMessageRenderer"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(SubtleToolCardModifier())
        } else if !combinedContent.isEmpty {
            GenericToolSectionView(content: combinedContent)
        } else {
            EmptyToolSectionView(
                systemImage: "info.circle",
                text: String(localized: "暂无工具输出", table: "CoreMessageRenderer")
            )
        }
    }
}

private struct GenericToolSectionView: View {
    let content: String

    var body: some View {
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        ) {
            ScrollView(.vertical, showsIndicators: true) {
                Text(content)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 360)
        }
    }
}

private struct EmptyToolSectionView: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
