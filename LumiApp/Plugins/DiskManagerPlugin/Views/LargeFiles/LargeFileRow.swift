import SwiftUI
import DiskManagerKit

/// 大文件行视图
struct LargeFileRow: View {
    let item: LargeFileEntry
    @ObservedObject var viewModel: LargeFilesViewModel
    @State private var showDeleteConfirm = false

    // 在 UI 层计算图标（避免在 Sendable 模型中存储 NSImage）
    private var icon: NSImage {
        NSWorkspace.shared.icon(forFile: item.path)
    }

    var body: some View {
        HStack {
            AppImageThumbnail(
                image: Image(nsImage: icon),
                size: CGSize(width: 32, height: 32),
                shape: .none
            )

            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                Text(item.path)
                    .font(.caption)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(viewModel.formatBytes(item.size))
                    .font(.monospacedDigit(.body)())
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                AppTag(item.fileType.rawValue.capitalized, style: .subtle)
            }

            HStack(spacing: 12) {
                Button(action: {
                    viewModel.revealInFinder(item)
                }) {
                    Image(systemName: "folder")
                        .foregroundColor(Color(hex: "0A84FF"))
                }
                .buttonStyle(.plain)
                .help(String(localized: "在访达中显示", table: "DiskManager"))

                Button(action: {
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(Color(hex: "FF453A"))
                }
                .buttonStyle(.plain)
                .help(String(localized: "删除文件", table: "DiskManager"))
                .confirmationDialog("确定要删除此文件吗？", isPresented: $showDeleteConfirm) {
                    Button(String(localized: "删除", table: "DiskManager"), role: .destructive) {
                        viewModel.deleteFile(item)
                    }
                    Button(String(localized: "取消", table: "DiskManager"), role: .cancel) {}
                } message: {
                    Text("文件 \"\(item.name)\" 将被永久删除。")
                }
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
    }
}
