import MagicKit
import SwiftUI

/// 文件预览空白状态视图
struct FilePreviewEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "File Preview", table: "AgentFilePreview"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            Text(String(localized: "Select File to Preview", table: "AgentFilePreview"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
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
