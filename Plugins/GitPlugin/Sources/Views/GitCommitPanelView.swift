import SwiftUI
import LumiUI
import LumiCoreKit

/// Git 提交面板视图：左侧历史列表 + 右侧详情
///
/// 使用 HSplitView 实现可拖拽的双栏布局，宽度比自动保存到 UserDefaults。
/// 左栏显示提交历史列表（含工作状态入口），
/// 右栏显示选中 commit 的详情、变更文件和 diff。
public struct GitCommitPanelView: View {
    let lumiCore: LumiCoreAccessing
    @ObservedObject var gitVM: AppGitVM

    public init(lumiCore: LumiCoreAccessing, gitVM: AppGitVM) {
        self.lumiCore = lumiCore
        self.gitVM = gitVM
    }

    public var body: some View {
        HSplitView {
            // 左栏：提交历史列表
            GitCommitHistorySidebarView(lumiCore: lumiCore, gitVM: gitVM)

            // 右栏：详情视图
            GitCommitDetailView(lumiCore: lumiCore, gitVM: gitVM)
        }
    }
}