import MagicKit
import SwiftUI

/// Git Commit 详情根视图覆盖层
///
/// 始终存在于视图树中（通过 addRootView 包裹），监听 GitVM 中
/// selectedCommitHash 的变化，当有新 commit 被选中时自动操作 LayoutVM
/// 将 GitCommitDetail 插件切换为当前活跃的 Detail 视图。
///
/// 为什么不放在 GitCommitDetailView 中？
/// 因为 Detail 视图只有在中间栏选中了对应 Tab 时才会出现在视图树中，
/// 如果用户当前看的是 FilePreview 等其他 Detail，GitCommitDetailView
/// 不会收到 onChange 回调，监听就失效了。
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
            // 有 commit 被选中时，自动切换到 GitCommitDetail 插件
            layoutVM.selectAgentDetail(GitCommitDetailPlugin.id)
        }
    }
}
