import SwiftUI

/// 助手消息与工具调用视图
struct MessageWithToolCallsView: View {
    let message: ChatMessage
    let toolOutputMessages: [ChatMessage]

    @EnvironmentObject var permissionRequestViewModel: PermissionRequestVM
    @EnvironmentObject var timelineViewModel: ChatTimelineViewModel

    @ObservedObject private var expansionState = MessageExpansionState.shared
    @State private var showRawMessage: Bool = false
    @State private var expandedParameterToolCallIDs = Set<String>()
    @State private var expandedResultToolCallIDs = Set<String>()

    private var renderMetadata: MessageRenderMetadata {
        MessageRenderCache.shared.metadata(for: message)
    }

    private var isLongMessage: Bool {
        renderMetadata.isLongMessage
    }

    private var isExpanded: Bool {
        expansionState.isExpanded(id: message.id, defaultExpanded: !renderMetadata.shouldDefaultCollapse)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !shouldHideMessageBody {
                MarkdownView(
                    message: message,
                    showRawMessage: showRawMessage,
                    isCollapsible: isLongMessage,
                    isExpanded: isExpanded,
                    onToggleExpand: {
                        Task { @MainActor in
                            expansionState.toggleExpansion(id: message.id)
                        }
                    }
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
        let isParametersExpanded = expandedParameterToolCallIDs.contains(toolCall.id)
        let isResultsExpanded = expandedResultToolCallIDs.contains(toolCall.id)
        let isLoadingResult = timelineViewModel.isLoadingToolOutput(for: toolCall.id)
        let resultMessages = timelineViewModel.toolOutputs(for: toolCall.id)
        let effectiveResults = resultMessages.isEmpty
            ? toolOutputMessages.filter { $0.toolCallID == toolCall.id }
            : resultMessages

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Text(toolCall.name)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    toggleParameterSection(for: toolCall.id)
                } label: {
                    compactActionChip(
                        title: "参数",
                        systemImage: "slider.horizontal.3",
                        isActive: isParametersExpanded
                    )
                }
                .buttonStyle(.plain)

                Button {
                    toggleResultSection(for: toolCall.id)
                } label: {
                    if isLoadingResult {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text("结果")
                                .font(DesignTokens.Typography.caption1)
                        }
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.08))
                        )
                    } else {
                        compactActionChip(
                            title: "结果",
                            systemImage: "doc.text.magnifyingglass",
                            isActive: isResultsExpanded
                        )
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.22), lineWidth: 1)
                    )
            )

            if isParametersExpanded {
                ToolCallContentSectionView(toolCall: toolCall, title: "参数")
            }

            if isResultsExpanded {
                ToolResultSectionView(outputs: effectiveResults, isLoading: isLoadingResult)
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

    private func toggleParameterSection(for toolCallID: String) {
        if expandedParameterToolCallIDs.contains(toolCallID) {
            expandedParameterToolCallIDs.remove(toolCallID)
        } else {
            expandedParameterToolCallIDs.insert(toolCallID)
        }
    }

    private func toggleResultSection(for toolCallID: String) {
        if expandedResultToolCallIDs.contains(toolCallID) {
            expandedResultToolCallIDs.remove(toolCallID)
            return
        }

        if !timelineViewModel.hasLoadedToolOutput(for: toolCallID) {
            timelineViewModel.loadToolOutput(for: message, toolCallID: toolCallID)
        }
        expandedResultToolCallIDs.insert(toolCallID)
    }

    @ViewBuilder
    private func compactActionChip(title: String, systemImage: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(DesignTokens.Typography.caption1)
        }
        .foregroundColor(isActive ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(DesignTokens.Color.semantic.textTertiary.opacity(isActive ? 0.14 : 0.08))
        )
    }
}

private struct ToolCallContentSectionView: View {
    let toolCall: ToolCall
    let title: String

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
            GenericToolSectionView(title: title, content: formattedArguments)
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
                Text("查询结果中…")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.05))
            )
        } else if !combinedContent.isEmpty {
            GenericToolSectionView(title: "结果", content: combinedContent)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                Text("点击结果后会在这里显示工具输出")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.05))
            )
        }
    }
}

private struct GenericToolSectionView: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Text(content)
                .font(DesignTokens.Typography.code)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

#Preview("Assistant with Tool Calls") {
    let toolCalls = [
        ToolCall(id: "tool_1", name: "read_file", arguments: "{\"path\": \"/Users/angel/Code/Lumi/App.swift\"}"),
        ToolCall(id: "tool_2", name: "run_command", arguments: "{\"command\": \"ls -la\"}")
    ]
    let message = ChatMessage(
        role: .assistant,
        content: "让我帮你查看项目结构和文件内容。",
        toolCalls: toolCalls
    )

    return MessageWithToolCallsView(message: message, toolOutputMessages: [])
        .padding()
        .frame(width: 600)
        .background(Color.black)
}

#Preview("Assistant with Tool Calls (No Text)") {
    let toolCalls = [
        ToolCall(id: "tool_1", name: "list_directory", arguments: "{\"path\": \"/Users/angel/Code/Lumi\"}")
    ]
    let message = ChatMessage(
        role: .assistant,
        content: "",
        toolCalls: toolCalls
    )

    return MessageWithToolCallsView(message: message, toolOutputMessages: [])
        .padding()
        .frame(width: 600)
        .background(Color.black)
}
