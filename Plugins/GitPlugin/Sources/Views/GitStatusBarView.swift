import SwiftUI
import LumiCoreKit
import LumiUI

/// Git 分支状态栏视图
///
/// 监听以下时机自动刷新分支信息：
/// - 视图首次出现（`onAppear`）
/// - 项目路径变化（`onChange(of: currentProjectPath)`）
/// - 从其他应用切回（`applicationDidBecomeActive`）
public struct GitPluginStatusBarView: View {
    let lumiCore: LumiCoreAccessing
    @State private var branch: String?

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    private var currentProjectPath: String {
        lumiCore.projectState?.currentProject?.path ?? ""
    }

    public var body: some View {
        Group {
            if let branch {
                StatusBarHoverContainer(
                    detailView: GitPluginPopoverView(lumiCore: lumiCore),
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
        .onChange(of: currentProjectPath) { _, _ in
            refreshBranch()
        }
        .onApplicationDidBecomeActive {
            refreshBranch()
        }
    }

    private func refreshBranch() {
        let path = currentProjectPath
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