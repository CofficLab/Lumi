import SwiftUI

/// 增强版工具输出视图 - 带有更多交互功能
struct ToolOutputView: View {
    let content: String
    private let timestamp: Date?
    private let summaryTextCached: String
    private let lineCountCached: Int
    @State private var isExpanded: Bool = false
    @State private var displayedContent: String = ""
    @State private var isHeaderHovered: Bool = false

    init(content: String, timestamp: Date? = nil) {
        self.content = content
        self.timestamp = timestamp
        self.summaryTextCached = ToolOutputView.makeSummaryText(from: content)
        self.lineCountCached = ToolOutputView.makeLineCount(from: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 工具输出头部（与用户消息 header 同风格）
            toolOutputHeader

            // 可折叠内容
            if isExpanded {
                toolOutputContent
            }
        }
    }

    // MARK: - Tool Output Header（与 Assistant / User / System 消息一致的 header 样式）

    private var toolOutputHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            // 左侧：工具输出标识 · 行数（与 Assistant 的 Lumi · provider · model 结构一致）
            HStack(alignment: .center, spacing: 4) {
                Text("工具输出")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                if lineCountCached > 1 {
                    Text("·")
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text("\(lineCountCached) 行")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }

            Spacer()

            HStack(alignment: .center, spacing: 12) {
                // 复制按钮（与 User / Assistant 一致）
                CopyMessageButton(
                    content: content,
                    showFeedback: .constant(false)
                )

                // 折叠/展开（与 Assistant 一致：展开时显示折叠按钮，折叠时显示「已折叠」文案）
                if isExpanded {
                    CollapseButton(action: toggleExpanded)
                } else {
                    Text("已折叠")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.6))
                }

                // 时间戳
                if let timestamp = timestamp {
                    Text(formatTimestamp(timestamp))
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHeaderHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHeaderHovered = hovering
            }
        }
        .onTapGesture {
            toggleExpanded()
        }
    }

    private func toggleExpanded() {
        let willExpand = !isExpanded
        if willExpand {
            DispatchQueue.main.async {
                isExpanded = true
                stageRenderContent()
            }
        } else {
            isExpanded = false
            displayedContent = ""
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }

    // MARK: - Tool Output Content

    private var toolOutputContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                Text(displayedContent)
                    .font(DesignTokens.Typography.code)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 400)
        .background(DesignTokens.Color.semantic.textTertiary.opacity(0.02))
    }

    private func stageRenderContent() {
        guard isExpanded else { return }
        // 先渲染前一小段，下一帧再补全，降低点击瞬间的主线程压力
        let prefixLimit = 8_000
        if content.count <= prefixLimit {
            displayedContent = content
            return
        }
        displayedContent = String(content.prefix(prefixLimit)) + "\n…"
        DispatchQueue.main.async {
            // 如果用户立刻折叠，则不再补全
            guard isExpanded else { return }
            displayedContent = content
        }
    }

    // MARK: - Helper Properties
    private static func makeSummaryText(from content: String) -> String {
        if let firstLine = content.components(separatedBy: .newlines).first {
            return String(firstLine.prefix(70))
        }
        return String(content.prefix(70))
    }

    private static func makeLineCount(from content: String) -> Int {
        // 避免 split 成大量数组；只做轻量统计
        var count = 0
        var hasNonNewline = false
        for ch in content {
            if ch == "\n" {
                if hasNonNewline { count += 1 }
                hasNonNewline = false
            } else {
                hasNonNewline = true
            }
        }
        if hasNonNewline { count += 1 }
        return count
    }

}

// MARK: - Convenience Initializers

extension ToolOutputView {
    /// 从消息创建工具输出视图
    init(message: ChatMessage) {
        self.init(content: message.content, timestamp: message.timestamp)
    }
}

// MARK: - Preview

#Preview("Simple Output") {
    VStack(alignment: .leading, spacing: 12) {
        ToolOutputView(content: "Successfully completed operation")
        ToolOutputView(content: "Error: File not found")
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
            """
        )

        ToolOutputView(
            content: """
            import SwiftUI

            struct ContentView: View {
                var body: some View {
                    Text("Hello, World!")
                }
            }
            """
        )
    }
    .padding()
    .frame(width: 600)
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
        """
    )
    .padding()
    .frame(width: 600)
    .background(Color.black)
}
