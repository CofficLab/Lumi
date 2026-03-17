import SwiftUI

/// 目录树视图
struct DirectoryTreeView: View {
    @ObservedObject var viewModel: DirectoryTreeViewModel

    var body: some View {
        VStack(spacing: 16) {
            // 扫描控制区域
            DirectoryTreeScanControlBar(viewModel: viewModel)

            // 扫描进度
            if viewModel.isScanning {
                DirectoryTreeScanProgressView(viewModel: viewModel)
            }

            // 错误消息
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(DesignTokens.Color.semantic.error)
                    .padding()
            }

            // 目录列表
            VStack {
                if viewModel.rootEntries.isEmpty && !viewModel.isScanning {
                    EmptyDirectoryTreeView(viewModel: viewModel)
                } else if !viewModel.isScanning {
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
            Image(nsImage: entry.icon)
                .resizable()
                .frame(width: 16, height: 16)

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
