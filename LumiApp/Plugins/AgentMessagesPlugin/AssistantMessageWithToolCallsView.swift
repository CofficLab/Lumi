import SwiftUI

/// 助手消息与工具调用视图 - 显示助手回复及工具调用列表
struct AssistantMessageWithToolCallsView: View {
    let message: ChatMessage
    @State private var showRawMessage: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 显示助手的文本内容（如果有）
            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MarkdownMessageView(message: message, showRawMessage: showRawMessage)
                    .messageBubbleStyle(role: message.role, isError: message.isError)
                    .overlay(alignment: .topTrailing) {
                        RawMessageToggleButton(showRawMessage: $showRawMessage)
                    }
            }

            // 显示工具调用列表
            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    // 工具调用标题
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("正在调用工具")
                            .font(DesignTokens.Typography.caption1)
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                    .padding(.bottom, 2)

                    // 工具调用列表
                    ForEach(Array(toolCalls.enumerated()), id: \.element.id) { index, toolCall in
                        ToolCallView(toolCall: toolCall, index: index)
                    }
                }
                .padding(.top, message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 8)
            }
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

    return AssistantMessageWithToolCallsView(message: message)
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

    return AssistantMessageWithToolCallsView(message: message)
        .padding()
        .frame(width: 600)
        .background(Color.black)
}
