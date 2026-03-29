import SwiftUI

/// 目录树视图
struct DirectoryTreeView: View {
    @ObservedObject var viewModel: DirectoryTreeViewModel

    var body: some View {
        VStack(spacing: 16) {
            // 扫描控制区域
            if viewModel.isScanning == false && viewModel.rootEntries.isNotEmpty {
                DirectoryTreeScanControlBar(viewModel: viewModel)
            }

            // 错误消息
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(DesignTokens.Color.semantic.error)
                    .padding()
            }

            // 内容区域（扫描/空态/列表互斥显示，避免高度被多个 .infinity 分走）
            ZStack {
                if viewModel.isScanning {
                    DirectoryTreeScanProgressView(viewModel: viewModel)
                } else if viewModel.rootEntries.isEmpty {
                    EmptyDirectoryTreeView(viewModel: viewModel)
                } else {
                    List(viewModel.rootEntries, children: \.children) { entry in
                        DirectoryTreeRow(entry: entry, viewModel: viewModel)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
}

/// 目录树行视图
struct DirectoryTreeRow: View {
    let entry: DirectoryEntry
    @ObservedObject var viewModel: DirectoryTreeViewModel

    var body: some View {
        HStack {
            AppImageThumbnail(
                image: Image(nsImage: entry.icon),
                size: CGSize(width: 16, height: 16),
                shape: .none
            )

            Text(entry.name)
                .lineLimit(1)

            Spacer()

            Text(viewModel.formatBytes(entry.size))
                .font(.monospacedDigit(.caption)())
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
