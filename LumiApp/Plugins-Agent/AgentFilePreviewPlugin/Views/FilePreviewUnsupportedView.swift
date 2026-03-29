import SwiftUI
import MagicKit

/// 文件预览暂不支持视图
struct FilePreviewUnsupportedView: View {
    let fileName: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 32))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "Preview Not Supported", table: "AgentFilePreview"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            Text(String(localized: "Preview Not Supported Type", table: "AgentFilePreview") + "\n" + fileName)
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    FilePreviewUnsupportedView(fileName: "example.bin")
        .frame(width: 200, height: 300)
}