import SwiftUI

// MARK: - Markdown Rendering Toggle Button

/// 全局 Markdown 渲染开关按钮
/// 控制所有消息的 Markdown 渲染开关
struct MarkdownRenderingToggleButton: View {
    @AppStorage("Agent_RenderMarkdownEnabled") private var renderMarkdownEnabled: Bool = false

    var body: some View {
        Button(action: { renderMarkdownEnabled.toggle() }) {
            Image(systemName: renderMarkdownEnabled ? "doc.richtext" : "doc.plaintext")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(renderMarkdownEnabled ? .green : DesignTokens.Color.semantic.textSecondary.opacity(0.6))
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.08))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(renderMarkdownEnabled ? "Markdown 渲染：已开启" : "Markdown 渲染：已关闭（纯文本模式）")
    }
}
