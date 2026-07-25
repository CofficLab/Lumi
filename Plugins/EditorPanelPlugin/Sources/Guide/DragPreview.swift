import SwiftUI

/// 文件拖拽预览视图。
///
/// 负责在拖拽编辑器文件或目录时提供轻量的视觉预览，帮助用户确认当前拖拽
/// 的目标对象。
public struct DragPreview: View {
    public let fileURL: URL

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForFileURL)
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(fileURL.lastPathComponent)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.95))
        )
    }

    private var iconForFileURL: String {
        let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        return isDirectory ? "folder.fill" : "doc.fill"
    }
}
