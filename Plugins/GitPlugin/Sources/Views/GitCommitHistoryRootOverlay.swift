import SwiftUI
import SuperLogKit
import LumiKernel

/// Git Commit 根视图覆盖层
///
/// 监听 commit 选中事件，**不再自行激活当前面板** —
/// 激活宿主布局的行为由挂载本视图的宿主侧在合适的时机主动发起。
public struct GitCommitHistoryRootOverlay<Content: View>: View {
    @ObservedObject var gitVM: AppGitVM
    let project: any ProjectProviding

    public let content: Content

    public init(gitVM: AppGitVM, project: any ProjectProviding, @ViewBuilder content: () -> Content) {
        self.gitVM = gitVM
        self.project = project
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: gitVM.selectedCommitHash) { _, newHash in
            guard newHash != nil else { return }

            if GitPlugin.verbose {
                GitPlugin.logger.info("\(GitPlugin.t)Commit selected: \(newHash?.prefix(7) ?? "nil")")
            }
            // 原来的 `layoutState.activateViewContainer(id: GitPlugin.info.id)` 已删除
            // (进一步清理:`GitPlugin.info` 在新插件体系中也不再存在,改为
            // `GitPlugin.id`;此处只保留注释,实际不再引用该 ID)。
            // 激活面板属于宿主布局行为,不应由 GitPlugin 越权操作。
        }
    }
}
