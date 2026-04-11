import MagicKit
import os
import SwiftUI

/// 项目文件树视图
struct ProjectTreeView: View {
    @EnvironmentObject var projectVM: ProjectVM

    /// 刷新协调器，管理文件系统监听和刷新令牌
    @StateObject private var coordinator = ProjectTreeRefreshCoordinator()

    /// 根节点刷新令牌（由协调器驱动 + 手动驱动）
    @State private var rootRefreshToken: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            if projectVM.currentProjectPath.isEmpty {
                FileTreeNoProjectView()
            } else {
                ScrollView {
                    FileNodeView(
                        url: URL(fileURLWithPath: projectVM.currentProjectPath),
                        depth: 0,  // depth == 0 表示根节点
                        selectedURL: projectVM.selectedFileURL,
                        onSelect: { selectedURL in
                            projectVM.selectFile(at: selectedURL)
                        },
                        refreshToken: rootRefreshToken,
                        projectRootPath: projectVM.currentProjectPath,
                        onExpansionChange: { relativePath, isExpanded in
                            handleExpansionChange(relativePath: relativePath, isExpanded: isExpanded)
                        }
                    )
                }
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: projectVM.currentProjectPath, onProjectPathChanged)
        .onChange(of: projectVM.selectedFileURL, onSelectedFileChanged)
        .onDisappear(perform: onDisappear)
        .onSyncSelectedFile(perform: onSyncSelectedFile)
        .onReceive(coordinator.$refreshToken) { newToken in
            onCoordinatorRefresh(newToken)
        }
    }

    // MARK: - Event Handler

    private func onSyncSelectedFile(path: String) {
        let url = URL(fileURLWithPath: path)
        projectVM.selectFile(at: url)
    }

    private func onProjectPathChanged() {
        // 项目路径变化时，更新协调器并递增刷新令牌
        coordinator.setProjectRootPath(projectVM.currentProjectPath)
        rootRefreshToken += 1
    }

    private func onSelectedFileChanged() {
        // 自动展开到选中文件的逻辑需要在 FileNodeView 中处理
    }

    private func onDisappear() {
        coordinator.stop()
    }

    /// 协调器检测到文件系统变化时，递增根刷新令牌驱动整棵树刷新
    private func onCoordinatorRefresh(_ newToken: Int) {
        guard newToken > 0 else { return }
        rootRefreshToken += 1
        ProjectTreeRefreshCoordinator.logger.info("🌳 协调器驱动刷新，令牌：\(rootRefreshToken)")
    }

    /// 子节点展开/折叠时通知协调器更新监听列表
    private func handleExpansionChange(relativePath: String, isExpanded: Bool) {
        if isExpanded {
            coordinator.addExpandedPath(relativePath)
        } else {
            coordinator.removeExpandedPath(relativePath)
        }
    }
}

// MARK: - Preview

#Preview {
    ProjectTreeView()
        .inRootView()
        .frame(width: 250, height: 400)
}
