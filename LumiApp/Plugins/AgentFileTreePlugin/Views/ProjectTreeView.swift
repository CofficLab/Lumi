import MagicKit
import os
import SwiftUI

/// 项目文件树视图
struct ProjectTreeView: View {
    @EnvironmentObject var projectVM: ProjectVM

    /// 根节点刷新令牌，每次项目路径变化时递增
    @State private var rootRefreshToken: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            if projectVM.currentProjectPath.isEmpty {
                FileTreeNoProjectView()
            } else {
                FileNodeView(
                    url: URL(fileURLWithPath: projectVM.currentProjectPath),
                    depth: 0,  // depth == 0 表示根节点
                    selectedURL: projectVM.selectedFileURL,
                    onSelect: { selectedURL in
                        projectVM.selectFile(at: selectedURL)
                    },
                    refreshToken: rootRefreshToken
                )
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: projectVM.currentProjectPath, onProjectPathChanged)
        .onChange(of: projectVM.selectedFileURL, onSelectedFileChanged)
        .onDisappear(perform: onDisappear)
        .onSyncSelectedFile(perform: onSyncSelectedFile)
    }
}

// MARK: - Event Handler

extension ProjectTreeView {
    private func onSyncSelectedFile(path: String) {
        let url = URL(fileURLWithPath: path)
        projectVM.selectFile(at: url)
    }

    private func onProjectPathChanged() {
        // 项目路径变化时，递增刷新令牌触发根节点重新加载
        rootRefreshToken += 1
    }

    private func onDisappear() {
        // 清理工作由 FileNodeView 内部处理
    }

    private func onSelectedFileChanged() {
        // 自动展开到选中文件的逻辑需要在 FileNodeView 中处理
        // 目前先保持简单，如果需要可以后续添加
    }
}

// MARK: - Preview

#Preview {
    ProjectTreeView()
        .inRootView()
        .frame(width: 250, height: 400)
}
