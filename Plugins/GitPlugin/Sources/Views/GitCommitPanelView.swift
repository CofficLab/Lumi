import SwiftUI
import LumiUI
import LumiKernel

/// Git 提交面板视图：左侧历史列表 + 右侧详情
///
/// 使用 HSplitView 实现可拖拽的双栏布局，宽度比自动保存到 UserDefaults。
/// 左栏显示提交历史列表（含工作状态入口），
/// 右栏显示选中 commit 的详情、变更文件和 diff。
public struct GitCommitPanelView: View {
    let project: any ProjectProviding
    @ObservedObject var gitVM: AppGitVM

    public init(project: any ProjectProviding, gitVM: AppGitVM) {
        self.project = project
        self.gitVM = gitVM
    }

    public var body: some View {
        HSplitView {
            // 左栏：提交历史列表
            GitCommitHistorySidebarView(project: project, gitVM: gitVM)

            // 右栏：详情视图
            GitCommitDetailView(project: project, gitVM: gitVM)
        }
    }
}