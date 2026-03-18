import SwiftUI

/// 助手消息与工具调用视图 - 显示助手回复及工具调用列表
struct MessageWithToolCallsView: View {
    let message: ChatMessage
    let toolOutputMessages: [ChatMessage]
    @EnvironmentObject var permissionRequestViewModel: PermissionRequestVM
    @EnvironmentObject var timelineViewModel: ChatTimelineViewModel
    @ObservedObject private var expansionState = MessageExpansionState.shared
    @State private var showRawMessage: Bool = false
    @State private var isToolDetailsExpanded: Bool = false
    private var renderMetadata: MessageRenderMetadata {
        MessageRenderCache.shared.metadata(for: message)
    }

    // 判断是否是长消息
    private var isLongMessage: Bool {
        renderMetadata.isLongMessage
    }
    
    // 当前消息的展开状态
    private var isExpanded: Bool {
        expansionState.isExpanded(id: message.id, defaultExpanded: !renderMetadata.shouldDefaultCollapse)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 显示助手的文本内容（如果有且不是工具摘要占位）
            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !shouldHideMessageBody {
                MarkdownMessageView(
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

            // 显示工具执行分组（默认折叠）
            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            Text(executionSummaryTitle(for: toolCalls))
                                .font(DesignTokens.Typography.caption1)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if message.hasToolCalls {
                            Button {
                                timelineViewModel.loadToolOutputs(for: message, forceReload: timelineViewModel.hasLoadedToolOutputs(for: message))
                                if !isToolDetailsExpanded {
                                    DispatchQueue.main.async {
                                        isToolDetailsExpanded = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if timelineViewModel.isLoadingToolOutputs(for: message) {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: timelineViewModel.hasLoadedToolOutputs(for: message) ? "arrow.clockwise" : "tray.and.arrow.down")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    Text(toolOutputActionText)
                                        .font(DesignTokens.Typography.caption1)
                                }
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Text(toolExecutionStatusText(for: toolCalls))
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                        Image(systemName: isToolDetailsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
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
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                    .onTapGesture {
                        toggleToolDetailsExpanded()
                    }

                    if isToolDetailsExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            ToolExecutionTimelineView(
                                toolCalls: toolCalls,
                                toolOutputs: toolOutputMessages,
                                waitingPermissionToolCallId: permissionRequestViewModel.pendingPermissionRequest?.toolCallID
                            )

                            // SwiftUI 要求 ForEach 的 id 在同一集合内唯一；toolCall.id 在某些提供方下可能重复，
                            // 这里用 message.id + index + toolCall.id 组合出稳定且必唯一的 key，避免展开/折叠时出现未定义行为甚至卡死。
                            ForEach(Array(toolCalls.enumerated()), id: \.offset) { index, toolCall in
                                ToolCallView(toolCall: toolCall, index: index)
                            }

                            if !toolOutputMessages.isEmpty {
                                // toolOutputMessages.id 理论上应唯一，但在历史合并/重建时可能出现重复，导致 SwiftUI 未定义行为（展开/折叠卡死）。
                                ForEach(Array(toolOutputMessages.enumerated()), id: \.offset) { _, output in
                                    ToolOutputView(message: output)
                                }
                            }
                        }
                        .padding(.top, 2)
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

    private func executionSummaryTitle(for toolCalls: [ToolCall]) -> String {
        if shouldHideMessageBody {
            let firstLine = trimmedContent.components(separatedBy: .newlines).first ?? trimmedContent
            return firstLine
        }
        return "正在执行 \(toolCalls.count) 个工具："
    }

    private func toolExecutionStatusText(for toolCalls: [ToolCall]) -> String {
        let callIds = Set(toolCalls.map(\.id))
        let outputs = toolOutputMessages.filter { output in
            guard let id = output.toolCallID else { return false }
            return callIds.contains(id)
        }

        if let waitingId = permissionRequestViewModel.pendingPermissionRequest?.toolCallID,
           callIds.contains(waitingId) {
            return "待授权"
        }

        if timelineViewModel.isLoadingToolOutputs(for: message) {
            return "查询中"
        }

        if !timelineViewModel.hasLoadedToolOutputs(for: message) {
            return "未查询"
        }

        if outputs.count < toolCalls.count {
            return "执行中"
        }

        let hasFailure = outputs.contains { msg in
            msg.isError || msg.content.localizedCaseInsensitiveContains("error") || msg.content.localizedCaseInsensitiveContains("aborted")
        }
        return hasFailure ? "部分失败" : "已完成"
    }

    private var toolOutputActionText: String {
        if timelineViewModel.isLoadingToolOutputs(for: message) {
            return "查询中"
        }
        return timelineViewModel.hasLoadedToolOutputs(for: message) ? "刷新输出" : "查看输出"
    }

    private func toggleToolDetailsExpanded() {
        let target = !isToolDetailsExpanded
        if target {
            DispatchQueue.main.async {
                isToolDetailsExpanded = true
            }
        } else {
            isToolDetailsExpanded = false
        }
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
