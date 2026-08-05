import SwiftUI
import LumiUI

/// 磁盘管理器主视图
///
/// 顶部保留磁盘使用情况卡（``DiskUsageInfoView``）；
/// 下方的具体清理类型由 ``DiskCleanupCategorySidebar``（RailView）控制，
/// 本视图只根据 ``DiskCleanupCategoryStore`` 当前选中的类别渲染对应内容。
struct DiskManagerView: View {
    @StateObject private var categoryStore = DiskCleanupCategoryStore()
    @StateObject private var viewModel = DiskManagerViewModel()
    @StateObject private var largeFilesViewModel = LargeFilesViewModel()
    @StateObject private var directoryTreeViewModel = DirectoryTreeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            DiskUsageInfoView()
                .padding()

            GlassDivider()

            // 内容区域 - 各模式自行负责显示状态和进度
            Group {
                switch categoryStore.selected {
                case .largeFiles:
                    LargeFilesListView(viewModel: largeFilesViewModel)
                case .directoryTree:
                    DirectoryTreeView(viewModel: directoryTreeViewModel)
                case .cacheCleaner:
                    CacheCleanerView()
                case .xcodeCleaner:
                    XcodeCleanerView()
                case .projectCleaner:
                    ProjectCleanerView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            viewModel.refreshDiskUsage()
        }
    }
}

// MARK: - 子组件

/// 磁盘使用情况信息视图
struct DiskUsageInfoView: View {
    @StateObject private var viewModel = DiskManagerViewModel()

    var body: some View {
        AppCard(padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {
            HStack(spacing: 40) {
                DiskUsageRingView()
                    .frame(width: 100, height: 100)

                if let usage = viewModel.diskUsage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(PluginDiskManagerLocalization.string("Macintosh HD"))
                            .font(.title2)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(PluginDiskManagerLocalization.string("总计："))\(formatBytes(usage.total))")
                            Text("\(PluginDiskManagerLocalization.string("已用："))\(formatBytes(usage.used))")
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            Text("\(PluginDiskManagerLocalization.string("可用："))\(formatBytes(usage.available))")
                                .foregroundColor(Color(hex: "30D158"))
                        }
                        .font(.subheadline)
                    }
                } else {
                    ProgressView()
                }

                Spacer()
            }
        }
        .onAppear {
            viewModel.refreshDiskUsage()
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        DiskManagerViewModel.byteFormatter.string(fromByteCount: bytes)
    }
}

// MARK: - 预览

#if DEBUG
#Preview("Disk Manager") {
    DiskManagerView()
        .frame(width: 800, height: 600)
}
#endif