import SwiftUI
import MagicKit

/// Git 分支状态栏视图
///
/// 监听以下时机自动刷新分支信息：
/// - 视图首次出现（`onAppear`）
/// - 项目路径变化（`onChange(of: currentProjectPath)`）
/// - 从其他应用切回（`applicationDidBecomeActive`）
struct GitBranchStatusBarView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @State private var branch: String?
    @State private var gitInfo: GitInfo?

    var body: some View {
        Group {
            if let branch {
                StatusBarHoverContainer(
                    detailView: GitBranchPickerPanel(),
                    id: "git-branch-status"
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))

                        Text(branch)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            refreshBranch()
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            refreshBranch()
        }
        .onApplicationDidBecomeActive {
            refreshBranch()
        }
    }

    private func refreshBranch() {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else {
            branch = nil
            gitInfo = nil
            return
        }

        Task.detached { [path] in
            let result = GitBranchService.currentBranch(at: path)
            let info = GitBranchService.getGitInfo(at: path)
            await MainActor.run {
                self.branch = result
                self.gitInfo = info
            }
        }
    }
}

// MARK: - 预览

#Preview("Git Branch Status Bar") {
    GitBranchStatusBarView()
        .frame(height: 30)
        .inRootView()
}
