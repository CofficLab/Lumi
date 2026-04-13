import MagicKit
import SwiftUI

/// Git Commit 详情根视图覆盖层
struct GitCommitDetailRootOverlay<Content: View>: View {
    @EnvironmentObject private var gitVM: GitVM
    @EnvironmentObject private var layoutVM: LayoutVM

    let content: Content

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: gitVM.selectedCommitHash) { _, newHash in
            guard newHash != nil else { return }
            
            GitCommitDetailPlugin.logger.info("Commit selected: \(newHash?.prefix(7) ?? "nil"), activating Detail and Sidebar tabs")
            
            // 有 commit 被选中时，自动切换到 GitCommitDetail 插件
            if layoutVM.selectedAgentDetailId != GitCommitDetailPlugin.id {
                GitCommitDetailPlugin.logger.info("Switching to GitCommitDetail plugin")
                layoutVM.selectAgentDetail(GitCommitDetailPlugin.id)
            }
            
            // 同时激活侧边栏的 Commit History 标签
            if layoutVM.selectedAgentSidebarTabId != GitCommitHistoryPlugin.id {
                GitCommitDetailPlugin.logger.info("Switching to GitCommitHistory plugin in sidebar")
                layoutVM.selectAgentSidebarTab(GitCommitHistoryPlugin.id, reason: "CommitDetailOverlay: commit selected")
            }
        }
    }
}
