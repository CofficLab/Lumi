import SwiftUI
import SuperLogKit
import LumiCoreKit

/// Git Commit 根视图覆盖层
///
/// 监听 commit 选中事件，自动激活当前面板。
public struct GitCommitHistoryRootOverlay<Content: View>: View {
    @EnvironmentObject private var gitVM: AppGitVM
    @ObservedObject private var layoutState = LumiLayoutStateStore.shared

    public let content: Content

    public var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: gitVM.selectedCommitHash) { _, newHash in
            guard newHash != nil else { return }

            if GitPlugin.verbose {
                if GitPlugin.verbose {
                                    GitPlugin.logger.info("\(GitPlugin.t)Commit selected: \(newHash?.prefix(7) ?? "nil"), activating panel")
                }
            }

            // 有 commit 被选中时，自动激活当前面板
            if layoutState.activeViewContainerID != GitPlugin.info.id {
                layoutState.activateViewContainer(id: GitPlugin.info.id)
            }
        }
    }
}
