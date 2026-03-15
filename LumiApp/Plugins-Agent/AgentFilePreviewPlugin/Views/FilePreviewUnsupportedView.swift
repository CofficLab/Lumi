import SwiftUI
import MagicKit

/// 文件预览暂不支持视图
struct FilePreviewUnsupportedView: View {
    let fileName: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            Text("暂不支持预览")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Text("暂不支持预览该类型的文件\n\(fileName)")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
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
