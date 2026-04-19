import SwiftUI

/// Markdown 预览 Popover
/// 在面包屑导航右侧的预览按钮点击后弹出，展示当前 md 文件的渲染效果
struct MarkdownPreview: View {

    /// 编辑器状态（读取文件内容）
    @ObservedObject var state: EditorState

    /// Popover 内容高度
    @State private var contentHeight: CGFloat = 400

    /// Popover 内容宽度
    private let popoverWidth: CGFloat = 520

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let content = state.content?.string, !content.isEmpty {
                    MarkdownBlockRenderer(markdown: content)
                        .padding(20)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: popoverWidth, height: min(contentHeight, 600))
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
            Text("No content to preview")
                .font(.system(size: 12))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

#Preview {
    MarkdownPreview(state: EditorState())
}
