import SwiftUI

/// 大文件行视图
struct LargeFileRow: View {
    let item: LargeFileEntry
    @ObservedObject var viewModel: LargeFilesViewModel
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack {
            AppImageThumbnail(
                image: Image(nsImage: item.icon),
                size: CGSize(width: 32, height: 32),
                shape: .none
            )

            VStack(alignment: .leading) {
                Text(item.name)
                    .font(AppUI.Typography.bodyEmphasized)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                Text(item.path)
                    .font(.caption)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(viewModel.formatBytes(item.size))
                    .font(.monospacedDigit(.body)())
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

                AppTag(item.fileType.rawValue.capitalized, style: .subtle)
            }

            HStack(spacing: 12) {
                Button(action: {
                    viewModel.revealInFinder(item)
                }) {
                    Image(systemName: "folder")
                        .foregroundColor(AppUI.Color.semantic.info)
                }
                .buttonStyle(.plain)
                .help("在访达中显示")

                Button(action: {
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(AppUI.Color.semantic.error)
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
