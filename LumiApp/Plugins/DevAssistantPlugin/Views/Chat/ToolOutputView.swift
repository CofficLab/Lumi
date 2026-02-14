import SwiftUI

/// 增强版工具输出视图 - 带有更多交互功能
struct ToolOutputView: View {
    let content: String
    let toolType: ToolType?
    @State private var isExpanded: Bool = false
    @State private var isCopied: Bool = false

    enum ToolType: String, CaseIterable {
        case shell = "Shell"
        case readFile = "Read File"
        case writeFile = "Write File"
        case listDirectory = "List Directory"
        case agent = "Agent"
        case unknown = "Tool"

        var icon: String {
            switch self {
            case .shell: return "terminal"
            case .readFile: return "doc.text"
            case .writeFile: return "doc.badge.plus"
            case .listDirectory: return "folder"
            case .agent: return "cpu"
            case .unknown: return "wrench.and.screwdriver"
            }
        }

        var color: Color {
            switch self {
            case .shell: return .green
            case .readFile: return .blue
            case .writeFile: return .orange
            case .listDirectory: return .purple
            case .agent: return .cyan
            case .unknown: return .gray
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 工具输出头部
            toolOutputHeader
                .padding(12)
                .background(DesignTokens.Color.semantic.textTertiary.opacity(0.03))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary.opacity(0.1)),
                    alignment: .bottom
                )

            // 可折叠内容
            if isExpanded {
                Divider()
                toolOutputContent
            }
        }
        .enhancedToolCardStyle()
    }

    // MARK: - Tool Output Header

    private var toolOutputHeader: some View {
        HStack(spacing: 8) {
            // 工具类型图标
            if let toolType = toolType {
                Image(systemName: toolType.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(toolType.color)
                    .frame(width: 20, height: 20)
                    .background(toolType.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }

            // 摘要文本
            Text(summaryText)
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .lineLimit(1)

            Spacer()

            // 行数指示器
            if lineCount > 1 {
                Text("\(lineCount) 行")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Color.semantic.textTertiary.opacity(0.1))
                    .cornerRadius(4)
            }

            // 复制按钮
            copyButton

            // 展开/折叠指示器
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Tool Output Content

    private var toolOutputContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                Text(content)
                    .font(DesignTokens.Typography.code)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 400)
        .background(DesignTokens.Color.semantic.textTertiary.opacity(0.02))
    }

    // MARK: - Copy Button

    private var copyButton: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                Text(isCopied ? "已复制" : "复制")
                    .font(DesignTokens.Typography.caption2)
            }
            .font(.system(size: 10))
            .foregroundColor(isCopied ? .green : DesignTokens.Color.semantic.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isCopied ? Color.green.opacity(0.1) : DesignTokens.Color.semantic.textTertiary.opacity(0.05))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Properties

    private var summaryText: String {
        if let firstLine = content.components(separatedBy: .newlines).first {
            return String(firstLine.prefix(70))
        }
        return String(content.prefix(70))
    }

    private var lineCount: Int {
        content.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
    }

    // MARK: - Actions

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)

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

// MARK: - View Modifiers

private extension View {
    /// 应用增强版工具卡片样式
    func enhancedToolCardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.12), lineWidth: 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    .opacity(0.3)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Convenience Initializers

extension ToolOutputView {
    /// 从消息创建工具输出视图
    init(message: ChatMessage, toolType: ToolType? = nil) {
        self.content = message.content
        self.toolType = toolType ?? .unknown
    }
}

// MARK: - Preview

#Preview("Simple Output") {
    VStack(alignment: .leading, spacing: 12) {
        ToolOutputView(
            content: "Successfully completed operation",
            toolType: .shell
        )
        ToolOutputView(
            content: "Error: File not found",
            toolType: .readFile
        )
    }
    .padding()
    .frame(width: 600)
    .background(Color.black)
}

#Preview("Multi Line Output") {
    VStack(alignment: .leading, spacing: 12) {
        ToolOutputView(
            content: """
            Project: Lumi
            Path: /Users/angel/Code/Coffic/Lumi
            Files: 142
            Size: 2.3 GB
            """,
            toolType: .listDirectory
        )

        ToolOutputView(
            content: """
            import SwiftUI

            struct ContentView: View {
                var body: some View {
                    Text("Hello, World!")
                }
            }
            """,
            toolType: .readFile
        )
    }
    .padding()
    .frame(width: 600)
    .background(Color.black)
}

#Preview("All Tool Types") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(ToolOutputView.ToolType.allCases, id: \.self) { type in
            ToolOutputView(
                content: "Example output for \(type.rawValue)",
                toolType: type
            )
        }
    }
    .padding()
    .frame(width: 600, height: 500)
    .background(Color.black)
}

#Preview("Long Output") {
    ToolOutputView(
        content: """
        # Project Structure
        ├── LumiApp/
        │   ├── Core/
        │   ├── UI/
        │   └── Plugins/
        ├── LumiFinder/
        └── NettoExtension/

        # Build Settings
        - SDK: macOS 15.0
        - Language: Swift
        - Architecture: arm64

        # Dependencies
        - SwiftUI
        - Combine
        - MagicKit

        # Plugin List
        1. DevAssistantPlugin
        2. NetworkManagerPlugin
        3. DiskManagerPlugin
        4. MemoryManagerPlugin
        5. DockerManagerPlugin
        6. HostsManagerPlugin
        7. RegistryManagerPlugin
        8. BrewManagerPlugin
        9. ClipboardManagerPlugin
        10. DatabaseManagerPlugin
        """,
        toolType: .listDirectory
    )
    .padding()
    .frame(width: 600)
    .background(Color.black)
}
