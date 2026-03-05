import SwiftUI

/// 工具调用视图 - 显示 AI 调用的工具及其参数
struct ToolCallView: View {
    let toolCall: ToolCall
    let index: Int
    
    @State private var isExpanded: Bool = false
    @State private var isCopied: Bool = false
    
    // MARK: - Tool Emoji & Color
    
    var emoji: String {
        toolEmojiMap[toolCall.name] ?? "🔧"
    }
    
    var color: Color {
        toolColorMap[toolCall.name] ?? .gray
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 工具调用头部
            toolCallHeader
                .padding(12)
                .background(color.opacity(0.08))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(color.opacity(0.2)),
                    alignment: .bottom
                )
            
            // 可折叠的参数内容
            if isExpanded {
                Divider()
                toolCallContent
            }
        }
        .toolCallCardStyle(color: color)
    }
    
    // MARK: - Tool Call Header
    
    private var toolCallHeader: some View {
        HStack(spacing: 8) {
            // 序号
            Text("\(index + 1)")
                .font(DesignTokens.Typography.caption2)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            
            // 工具 Emoji
            Text(emoji)
                .font(.system(size: 14))
                .frame(width: 20, height: 20)
            
            // 工具名称
            Text(toolCall.name)
                .font(DesignTokens.Typography.caption1)
                .fontWeight(.medium)
                .foregroundColor(color)
            
            Spacer()
            
            // 复制参数按钮
            copyButton
            
            // 展开/折叠指示器
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color.opacity(0.6))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
    }
    
    // MARK: - Tool Call Content
    
    private var toolCallContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                // 参数标签
                Text("参数")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.semibold)
                    .foregroundColor(color.opacity(0.8))
                
                // 格式化后的参数
                if let formattedParams = formattedParameters {
                    Text(formattedParams)
                        .font(DesignTokens.Typography.code)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else {
                    Text("无参数")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 300)
        .background(DesignTokens.Color.semantic.textTertiary.opacity(0.02))
    }
    
    // MARK: - Copy Button
    
    private var copyButton: some View {
        Button(action: copyParametersToClipboard) {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                Text(isCopied ? "已复制" : "复制")
                    .font(DesignTokens.Typography.caption2)
            }
            .font(.system(size: 10))
            .foregroundColor(isCopied ? .green : color.opacity(0.7))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isCopied ? Color.green.opacity(0.1) : color.opacity(0.08))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Formatted Parameters
    
    private var formattedParameters: String? {
        guard !toolCall.arguments.isEmpty,
              toolCall.arguments != "{}",
              let data = toolCall.arguments.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // 尝试生成格式化的 JSON
        if let prettyData = try? JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .sortedKeys]
        ),
        let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        
        return toolCall.arguments
    }
    
    // MARK: - Actions
    
    private func copyParametersToClipboard() {
        let contentToCopy = formattedParameters ?? toolCall.arguments
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(contentToCopy, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

// MARK: - Tool Emoji Map

private let toolEmojiMap: [String: String] = [
    "read_file": "📖",
    "write_file": "✍️",
    "run_command": "⚡",
    "list_directory": "📁",
    "create_directory": "📂",
    "move_file": "📦",
    "search_files": "🔍",
    "get_file_info": "ℹ️",
    "bash": "⚡",
    "glob": "🔎",
    "edit": "✏️",
    "str_replace_editor": "✏️",
    "lsp": "💻",
    "goto_definition": "➡️",
    "find_references": "🔗",
    "document": "📚",
    "grep": "🔍"
]

// MARK: - Tool Color Map

private let toolColorMap: [String: Color] = [
    "read_file": .blue,
    "write_file": .orange,
    "run_command": .green,
    "list_directory": .purple,
    "create_directory": .purple,
    "move_file": .cyan,
    "search_files": .pink,
    "get_file_info": .gray,
    "bash": .green,
    "glob": .pink,
    "edit": .orange,
    "str_replace_editor": .orange,
    "lsp": .indigo,
    "goto_definition": .blue,
    "find_references": .purple,
    "document": .teal,
    "grep": .pink
]

// MARK: - View Modifiers

private extension View {
    /// 应用工具调用卡片样式
    func toolCallCardStyle(color: Color) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: color.opacity(0.1), radius: 3, x: 0, y: 1)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview("Single Tool Call") {
    VStack(alignment: .leading, spacing: 12) {
        ToolCallView(
            toolCall: ToolCall(
                id: "tool_1",
                name: "read_file",
                arguments: "{\"path\": \"/Users/angel/Code/Coffic/Lumi/LumiApp/Core/App.swift\"}"
            ),
            index: 0
        )
        
        ToolCallView(
            toolCall: ToolCall(
                id: "tool_2",
                name: "run_command",
                arguments: "{\"command\": \"ls -la\"}"
            ),
            index: 1
        )
        
        ToolCallView(
            toolCall: ToolCall(
                id: "tool_3",
                name: "list_directory",
                arguments: "{\"path\": \"/Users/angel/Code/Coffic/Lumi\"}"
            ),
            index: 2
        )
    }
    .padding()
    .frame(width: 600)
    .background(Color.black)
}

#Preview("Tool with Complex Arguments") {
    VStack(alignment: .leading, spacing: 12) {
        ToolCallView(
            toolCall: ToolCall(
                id: "tool_4",
                name: "write_file",
                arguments: """
                {
                    "path": "/Users/angel/test.swift",
                    "content": "import SwiftUI\\n\\nstruct ContentView: View {\\n    var body: some View {\\n        Text(\\\"Hello\\\")\\n    }\\n}",
                    "overwrite": true
                }
                """
            ),
            index: 0
        )
    }
    .padding()
    .frame(width: 600)
    .background(Color.black)
}

#Preview("Tool with No Arguments") {
    VStack(alignment: .leading, spacing: 12) {
        ToolCallView(
            toolCall: ToolCall(
                id: "tool_5",
                name: "list_directory",
                arguments: "{}"
            ),
            index: 0
        )
    }
    .padding()
    .frame(width: 600)
    .background(Color.black)
}
