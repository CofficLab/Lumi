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
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    private var iconForFileURL: String {
        let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        return isDirectory ? "folder.fill" : "doc.fill"
    }
}
