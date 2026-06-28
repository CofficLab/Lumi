import SwiftUI

/// 文件树节点拖拽预览视图
public struct FileTreeDragPreview: View {
    public let fileURL: URL
    public let isDirectory: Bool

    public init(fileURL: URL, isDirectory: Bool) {
        self.fileURL = fileURL
        self.isDirectory = isDirectory
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isDirectory ? "folder.fill" : "doc.fill")
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
}
