import SwiftUI
import LumiUI

/// Git 分支状态栏视图
///
/// 监听以下时机自动刷新分支信息：
/// - 视图首次出现（`onAppear`）
/// - 项目路径变化（`onChange(of: currentProjectPath)`）
/// - 从其他应用切回（`applicationDidBecomeActive`）
struct GitPluginStatusBarView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @State private var branch: String?

    var body: some View {
        Group {
            if let branch {
                StatusBarHoverContainer(
                    detailView: GitPluginPopoverView(),
                    popoverWidth: 920,
                    id: "git-status"
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.appMicroEmphasized)

                        Text(branch)
                            .font(.appMicro)
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
            return
        }

        Task.detached { [path] in
            let result = GitBranchService.currentBranch(at: path)
            await MainActor.run {
                self.branch = result
            }
        }
    }
}

// MARK: - 预览

#Preview("Git Branch Status Bar") {
    GitPluginStatusBarView()
        .frame(height: 30)
        .inRootView()
}
