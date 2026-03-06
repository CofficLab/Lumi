import SwiftUI
import MarkdownUI

/// Markdown 消息视图，负责渲染聊天消息内容
/// 使用 MarkdownUI 库渲染（支持 GitHub Flavored Markdown）
struct MarkdownMessageView: View {
    let message: ChatMessage
    let showRawMessage: Bool
    let isCollapsible: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    
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
                    // 展开按钮区域 - 横跨整个消息宽度
                    ExpandButtonBar(action: onToggleExpand)
                        .padding(.top, 60)
                        .padding(.horizontal, -10)  // 抵消父视图的 padding
                        .padding(.bottom, -10)
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

// MARK: - Expand Button Bar

/// 展开按钮条 - 横跨整个消息底部的背景条
struct ExpandButtonBar: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                    Text("展开")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                Spacer()
            }
            .background(
                DesignTokens.Color.semantic.info.opacity(0.8)
                    .overlay(
                        Rectangle()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        DesignTokens.Color.semantic.info.opacity(0.8)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DesignTokens.Color.semantic.info.opacity(0.8))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expand Button

/// 展开按钮（独立按钮，不使用条状背景）
struct ExpandButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                Text("展开")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.Color.semantic.info.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.Color.semantic.info.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
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
            isExpanded: true,
            onToggleExpand: {}
        )

        MarkdownMessageView(
            message: ChatMessage(role: .assistant, content: "# Hello\nThis is a *markdown* message."),
            showRawMessage: true,
            isCollapsible: false,
            isExpanded: true,
            onToggleExpand: {}
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
        isExpanded: false,
        onToggleExpand: {}
    )
    .padding()
    .frame(width: 600)
}
