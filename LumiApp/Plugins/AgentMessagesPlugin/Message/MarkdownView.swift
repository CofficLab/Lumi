import SwiftUI
import MarkdownUI

/// Markdown 消息视图，负责渲染聊天消息内容
/// 使用 MarkdownUI 库渲染（支持 GitHub Flavored Markdown）
struct MarkdownMessageView: View {
    let message: ChatMessage
    let showRawMessage: Bool
    let isCollapsible: Bool
    @Binding var isExpanded: Bool
    
    /// 最大高度（超过后折叠）
    private let maxHeight: CGFloat = 400
    
    var body: some View {
        Group {
            if showRawMessage {
                TextEditor(text: .constant(message.content))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .scrollContentBackground(.hidden)
                    .applyCollapsible(isCollapsible: isCollapsible, isExpanded: isExpanded, maxHeight: maxHeight)
            } else {
                Markdown(message.content)
                    .textSelection(.enabled)
                    .applyCollapsible(isCollapsible: isCollapsible, isExpanded: isExpanded, maxHeight: maxHeight)
            }
        }
        .overlay(alignment: .bottom) {
            // 折叠时显示渐变遮罩和展开按钮
            if isCollapsible && !isExpanded && contentNeedsCollapse {
                VStack {
                    Spacer()
                    ExpandButton(isExpanded: $isExpanded)
                        .padding(.top, 60)
                        .padding(.bottom, 8)
                }
            }
        }
    }
    
    /// 判断内容是否需要折叠（通过测量内容高度）
    private var contentNeedsCollapse: Bool {
        // 简单判断：通过字符数估算
        // 更精确的方式需要使用 GeometryReader 测量实际高度
        let estimatedLines = message.content.components(separatedBy: "\n").count
        let estimatedHeight = CGFloat(estimatedLines * 20) // 每行约 20pt
        return estimatedHeight > maxHeight
    }
}

// MARK: - Expand Button

/// 展开按钮
struct ExpandButton: View {
    @Binding var isExpanded: Bool
    
    var body: some View {
        Button(action: { isExpanded = true }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                Text("展开")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapse Button

/// 折叠按钮（在 Header 中显示）
struct CollapseButton: View {
    @Binding var isExpanded: Bool
    
    var body: some View {
        Button(action: { isExpanded = false }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                Text("折叠")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.8))
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .help("折叠消息")
    }
}

// MARK: - View Modifier

extension View {
    /// 应用折叠逻辑
    func applyCollapsible(isCollapsible: Bool, isExpanded: Bool, maxHeight: CGFloat) -> some View {
        self
            .lineLimit(isCollapsible && !isExpanded ? 20 : nil)
            .frame(maxHeight: isCollapsible && !isExpanded ? maxHeight : nil)
            .clipped()
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        MarkdownMessageView(
            message: ChatMessage(role: .assistant, content: """
                ## Try MarkdownUI
                
                **MarkdownUI** is a native Markdown renderer for SwiftUI
                compatible with the [GitHub Flavored Markdown Spec](https://github.github.com/gfm/).
                
                ### Code Example
                
                ```swift
                let hello = "world"
                print(hello)
                ```
                
                - List item 1
                - List item 2
                """),
            showRawMessage: false,
            isCollapsible: true,
            isExpanded: .constant(true)
        )

        MarkdownMessageView(
            message: ChatMessage(role: .assistant, content: "# Hello\nThis is a *markdown* message."),
            showRawMessage: true,
            isCollapsible: false,
            isExpanded: .constant(true)
        )
    }
    .padding()
}

#Preview("Long Message") {
    let longContent = """
        # 这是一个很长的消息示例
        
        ## 第一章：介绍
        
        Swift 是一种强大的编程语言，由 Apple 开发用于构建 iOS、macOS、watchOS 和 tvOS 应用。
        
        ### 主要特性
        
        - 类型安全
        - 推断类型
        - 字符串插值
        - 可选类型
        - 错误处理
        
        ## 第二章：代码示例
        
        ```swift
        import Foundation
        import SwiftUI
        
        struct ContentView: View {
            var body: some View {
                VStack {
                    Text("Hello, World!")
                        .padding()
                    
                    Button("Click Me") {
                        print("Button clicked!")
                    }
                }
            }
        }
        
        @main
        struct MyApp: App {
            var body: some Scene {
                WindowGroup {
                    ContentView()
                }
            }
        }
        ```
        
        ## 第三章：更多内容
        
        这里有很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多很多文字。
        
        ### 列表
        
        1. 第一项
        2. 第二项
        3. 第三项
        4. 第四项
        5. 第五项
        
        > 这是一段引用文字，用于测试折叠功能。
        
        ### 表格
        
        | 列 1 | 列 2 | 列 3 |
        |-----|-----|-----|
        | A   | B   | C   |
        | D   | E   | F   |
        | G   | H   | I   |
        
        ## 结论
        
        这是一个非常长的消息，用于测试折叠和展开功能。当消息内容超过一定高度时，应该自动折叠，并显示"展开"按钮。
        """
    
    return MarkdownMessageView(
        message: ChatMessage(role: .assistant, content: longContent),
        showRawMessage: false,
        isCollapsible: true,
        isExpanded: .constant(false)
    )
    .padding()
    .frame(width: 600)
}
