import SwiftUI
import LumiUI

/// 磁盘管理器主视图
///
/// 磁盘使用情况卡已迁移到 rail 视图（``DiskCleanupCategorySidebar``）下方，
/// 本视图只根据 ``DiskCleanupCategoryStore`` 当前选中的类别渲染对应清理内容。
///
/// 各清理类型的 ViewModel 由外部 ``DiskCleanupWorkspace`` 提供，保证：
/// - 切换清理类型时 ViewModel 不被销毁，已启动的扫描任务继续跑、结果不丢；
/// - 多个类型可以同时工作（互不抢资源）。
struct DiskManagerView: View {
    @ObservedObject var categoryStore: DiskCleanupCategoryStore
    @ObservedObject var workspace: DiskCleanupWorkspace

    init(categoryStore: DiskCleanupCategoryStore, workspace: DiskCleanupWorkspace) {
        self.categoryStore = categoryStore
        self.workspace = workspace
    }

    var body: some View {
        Group {
            switch categoryStore.selected {
            case .largeFiles:
                LargeFilesListView(viewModel: workspace.largeFiles)
            case .directoryTree:
                DirectoryTreeView(viewModel: workspace.directoryTree)
            case .cacheCleaner:
                CacheCleanerView(viewModel: workspace.cacheCleaner)
            case .xcodeCleaner:
                XcodeCleanerView(viewModel: workspace.xcodeCleaner)
            case .projectCleaner:
                ProjectCleanerView(viewModel: workspace.projectCleaner)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Disk Manager") {
    DiskManagerView(
        categoryStore: DiskCleanupCategoryStore(),
        workspace: DiskCleanupWorkspace()
    )
    .frame(width: 800, height: 600)
}
#endif