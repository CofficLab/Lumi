import SwiftUI

/// 大文件行视图
struct LargeFileRow: View {
    let item: LargeFileEntry
    @ObservedObject var viewModel: DiskManagerViewModel
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text(item.path)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(viewModel.formatBytes(item.size))
                    .font(.monospacedDigit(.body)())
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                Text(item.fileType.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .padding(.horizontal, 4)
                    .background(DesignTokens.Color.semantic.textTertiary.opacity(0.1))
                    .cornerRadius(4)
            }

            HStack(spacing: 12) {
                Button(action: {
                    viewModel.revealInFinder(item)
                }) {
                    Image(systemName: "folder")
                        .foregroundColor(DesignTokens.Color.semantic.info)
                }
                .buttonStyle(.plain)
                .help("在访达中显示")

                Button(action: {
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(DesignTokens.Color.semantic.error)
                }
                .buttonStyle(.plain)
                .help("删除文件")
                .confirmationDialog("确定要删除此文件吗？", isPresented: $showDeleteConfirm) {
                    Button("删除", role: .destructive) {
                        viewModel.deleteFile(item)
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("文件 \"\(item.name)\" 将被永久删除。")
                }
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
    }
}
