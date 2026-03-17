import SwiftUI

/// 大文件列表视图
struct LargeFilesListView: View {
    @ObservedObject var viewModel: DiskManagerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // 扫描控制区域
            HStack {
                Button(action: {
                    if viewModel.isScanning {
                        viewModel.stopScan()
                    } else {
                        viewModel.startScan()
                    }
                }) {
                    Label {
                        Text(viewModel.isScanning ? "停止扫描" : "扫描大文件")
                    } icon: {
                        Image(systemName: viewModel.isScanning ? "stop.circle" : "magnifyingglass.circle")
                    }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isScanning ? DesignTokens.Color.semantic.error : DesignTokens.Color.semantic.info)

                Spacer()

                Text("扫描目录：用户主目录")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .padding(.horizontal)

            // 文件列表
            if viewModel.largeFiles.isEmpty && !viewModel.isScanning {
                ContentUnavailableView {
                    Text("暂无大文件")
                } description: {
                    Text("点击扫描按钮开始查找大文件")
                }
            } else {
                List {
                    ForEach(viewModel.largeFiles) { file in
                        LargeFileRow(item: file, viewModel: viewModel)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

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

// MARK: - 预览

#Preview {
    LargeFilesListView(viewModel: DiskManagerViewModel())
}
