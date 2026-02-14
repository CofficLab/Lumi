import SwiftUI

/// 工具输出视图 - 专门用于显示工具调用的结果
struct ToolOutputView: View {
    let content: String
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                ToolOutputContentView(content: content)
            },
            label: {
                ToolOutputSummaryView(content: content)
            }
        )
        .toolOutputCardStyle()
    }
}

// MARK: - Tool Output Content View

/// 工具输出内容区域
private struct ToolOutputContentView: View {
    let content: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                Text(content)
                    .font(DesignTokens.Typography.caption1.monospaced())
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 300)
        .padding(.top, 8)
    }
}

// MARK: - Tool Output Summary View

/// 工具输出摘要（折叠时显示）
private struct ToolOutputSummaryView: View {
    let content: String

    var body: some View {
        HStack(spacing: 8) {
            // 工具图标
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            // 摘要文本
            Text(summaryText)
                .font(DesignTokens.Typography.caption1.monospaced())
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .lineLimit(1)

            Spacer()

            // 行数指示器
            if lineCount > 1 {
                Text("×\(lineCount) 行")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Color.semantic.textTertiary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }

    private var summaryText: String {
        // 获取第一行作为摘要
        if let firstLine = content.components(separatedBy: .newlines).first {
            return String(firstLine.prefix(60))
        }
        return String(content.prefix(60))
    }

    private var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }
}

// MARK: - View Modifiers

private extension View {
    /// 应用工具输出卡片样式
    func toolOutputCardStyle() -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                DesignTokens.Color.semantic.textTertiary.opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
    }
}

// MARK: - Convenience Initializer

extension ToolOutputView {
    /// 从消息创建工具输出视图
    init(message: ChatMessage) {
        self.content = message.content
    }
}

// MARK: - Preview

#Preview("Single Line Output") {
    VStack(alignment: .leading, spacing: 12) {
        ToolOutputView(content: "Successfully completed operation")
        ToolOutputView(content: "Error: File not found")
    }
    .padding()
    .frame(width: 500)
    .background(Color.black)
}

#Preview("Multi Line Output") {
    VStack(alignment: .leading, spacing: 12) {
        ToolOutputView(content: """
        Project: Lumi
        Path: /Users/angel/Code/Coffic/Lumi
        Files: 142
        """)
        ToolOutputView(content: """
        import SwiftUI

        struct ContentView: View {
            var body: some View {
                Text("Hello, World!")
            }
        }
        """)
    }
    .padding()
    .frame(width: 500)
    .background(Color.black)
}

#Preview("Long Output") {
    ToolOutputView(content: """
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
    """)
    .padding()
    .frame(width: 500)
    .background(Color.black)
}
