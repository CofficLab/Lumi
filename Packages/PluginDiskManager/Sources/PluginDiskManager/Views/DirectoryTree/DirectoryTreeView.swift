import LumiUI
import SwiftUI

/// 目录树视图
struct DirectoryTreeView: View {
    @ObservedObject var viewModel: DirectoryTreeViewModel

    var body: some View {
        VStack(spacing: 16) {
            // 扫描控制区域：扫描中保留 Stop 入口（#849）
            if viewModel.isScanControlBarVisible {
                DirectoryTreeScanControlBar(viewModel: viewModel)
            }

            // 错误消息
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(Color(hex: "FF453A"))
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

    // 图标按路径缓存，避免每次 body 求值重复同步 workspace 查询（#1223）。
    @MainActor private var icon: NSImage {
        WorkspaceIconCache.shared.icon(forPath: entry.path)
    }

    var body: some View {
        HStack {
            AppImageThumbnail(
                image: Image(nsImage: icon),
                size: CGSize(width: 16, height: 16),
                shape: .none
            )

            Text(entry.name)
                .lineLimit(1)

            Spacer()

            Text(viewModel.formatBytes(entry.size))
                .font(.monospacedDigit(.caption)())
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.vertical, 2)
    }
}

