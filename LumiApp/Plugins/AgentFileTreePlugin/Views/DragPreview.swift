import SwiftUI

/// 文件拖拽预览视图
struct DragPreview: View {
    let fileURL: URL

    var body: some View {
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
