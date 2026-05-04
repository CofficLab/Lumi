import MagicKit
import SwiftUI

/// Git Commit 根视图覆盖层
///
/// 监听 commit 选中事件，自动激活当前面板。
struct GitCommitHistoryRootOverlay<Content: View>: View {
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

            if GitCommitHistoryPlugin.verbose {
                GitCommitHistoryPlugin.logger.info("Commit selected: \(newHash?.prefix(7) ?? "nil"), activating panel")
            }

            // 有 commit 被选中时，自动激活当前面板
            if layoutVM.selectedAgentSidebarTabId != GitCommitHistoryPlugin.id {
                layoutVM.selectAgentSidebarTab(GitCommitHistoryPlugin.id, reason: "RootOverlay: commit selected")
            }
        }
    }
}
