import SwiftUI
import MagicKit

/// 文件预览空状态视图
struct FilePreviewEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            Text("文件预览")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Text("请在左侧文件树中选择一个文件\n查看其内容")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    FilePreviewEmptyStateView()
        .frame(width: 200, height: 300)
}
