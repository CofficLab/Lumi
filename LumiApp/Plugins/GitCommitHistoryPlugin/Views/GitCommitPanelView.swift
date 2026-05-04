import SwiftUI

/// Git 提交面板视图：左侧历史列表 + 右侧详情
///
/// 使用 HSplitView 实现可拖拽的双栏布局，宽度比自动保存到 UserDefaults。
/// 左栏显示提交历史列表（含工作状态入口），
/// 右栏显示选中 commit 的详情、变更文件和 diff。
struct GitCommitPanelView: View {
    /// 插件专属的 storage key，用于持久化内部分割比例
    private let storageKey = "Split.Panel.GitCommitHistory"

    var body: some View {
        HSplitView {
            // 左栏：提交历史列表
            GitCommitHistorySidebarView()
                .background(SplitViewWidthPersistence(storageKey: storageKey))

            // 右栏：详情视图
            GitCommitDetailView()
        }
        .background(SplitViewAutosaveConfigurator(autosaveName: storageKey))
    }
}

#Preview {
    GitCommitPanelView()
        .inRootView()
        .frame(width: 900, height: 600)
}
