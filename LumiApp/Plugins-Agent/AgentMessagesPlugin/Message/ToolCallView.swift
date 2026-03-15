import SwiftUI

/// 工具调用视图 - 显示 AI 调用的工具及其参数
struct ToolCallView: View {
    let toolCall: ToolCall
    let index: Int
    
    @State private var isExpanded: Bool = false
    @State private var isCopied: Bool = false
    @State private var formattedParametersCache: String?
    @State private var isFormatting: Bool = false
    @State private var displayedParameters: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 工具调用头部
            toolCallHeader
                .padding(12)
                .background(Color.accentColor.opacity(0.08))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.accentColor.opacity(0.2)),
                    alignment: .bottom
                )
            
            // 可折叠的参数内容
            if isExpanded {
                Divider()
                toolCallContent
            }
        }
        .toolCallCardStyle()
    }
    
    // MARK: - Tool Call Header
    
    private var toolCallHeader: some View {
        HStack(spacing: 8) {
            // 序号
            Text("\(index + 1)")
                .font(DesignTokens.Typography.caption2)
                .fontWeight(.semibold)
                .foregroundColor(Color.accentColor)
                .frame(width: 18, height: 18)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
            
            // 工具名称
            Text(toolCall.name)
                .font(DesignTokens.Typography.caption1)
                .fontWeight(.medium)
                .foregroundColor(Color.accentColor)
            
            Spacer()
            
            // 复制参数按钮
            copyButton
            
            // 展开/折叠指示器
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.accentColor.opacity(0.6))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let willExpand = !isExpanded
            if willExpand {
                DispatchQueue.main.async {
                    isExpanded = true
                    stageRenderParameters()
                    startFormattingIfNeeded()
                }
            } else {
                isExpanded = false
                displayedParameters = ""
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
                    .foregroundColor(Color.accentColor.opacity(0.8))
                
                // 格式化后的参数
                if let formattedParams = formattedParametersCache {
                    Text(formattedParams)
                        .font(DesignTokens.Typography.code)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else if isFormatting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在格式化参数…")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if toolCall.arguments.isEmpty || toolCall.arguments == "{}" {
                    Text("无参数")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                } else {
                    // 兜底：直接展示原始参数，避免同步 JSON pretty print 卡死主线程
                    Text(displayedParameters)
                        .font(DesignTokens.Typography.code)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 300)
        .background(DesignTokens.Color.semantic.textTertiary.opacity(0.02))
        .onAppear {
            stageRenderParameters()
            startFormattingIfNeeded()
        }
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
            .foregroundColor(isCopied ? .green : Color.accentColor.opacity(0.7))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isCopied ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.08))
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
        let contentToCopy = formattedParametersCache ?? toolCall.arguments
        
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

    private func startFormattingIfNeeded() {
        guard isExpanded else { return }
        guard formattedParametersCache == nil else { return }
        guard !toolCall.arguments.isEmpty, toolCall.arguments != "{}" else { return }
        guard !isFormatting else { return }

        isFormatting = true

        let raw = toolCall.arguments
        Task.detached(priority: .userInitiated) {
            let formatted: String? = {
                guard let data = raw.data(using: .utf8),
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
                return nil
            }()

            await MainActor.run {
                self.formattedParametersCache = formatted
                self.isFormatting = false
                // 如果格式化成功，用格式化结果替换显示（避免用户一直看到截断的原始参数）
                if let formatted, !formatted.isEmpty {
                    self.displayedParameters = formatted
                } else {
                    self.stageRenderParameters()
                }
            }
        }
    }

    private func stageRenderParameters() {
        guard isExpanded else { return }
        guard formattedParametersCache == nil else { return }
        guard !toolCall.arguments.isEmpty, toolCall.arguments != "{}" else { return }

        let raw = toolCall.arguments
        let prefixLimit = 6_000
        if raw.count <= prefixLimit {
            displayedParameters = raw
            return
        }
        displayedParameters = String(raw.prefix(prefixLimit)) + "\n…"
        DispatchQueue.main.async {
            guard isExpanded else { return }
            // 如果这期间已经拿到了格式化内容，就不再覆盖
            guard formattedParametersCache == nil else { return }
            displayedParameters = raw
        }
    }
}

// MARK: - View Modifiers

private extension View {
    /// 应用工具调用卡片样式
    func toolCallCardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: Color.accentColor.opacity(0.1), radius: 3, x: 0, y: 1)
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
