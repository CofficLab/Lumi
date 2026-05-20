import os
import SwiftUI

/// Editor Rail 文件树根视图
struct EditorFileTreeView: View, SuperLog {
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject var editorVM: WindowEditorVM

    // MARK: - Logging Configuration

    /// 日志详细程度控制
    nonisolated static let emoji = "🌳"
    nonisolated static let verbose: Bool = false
    /// 使用插件的 logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree.view")

    /// 刷新协调器，管理文件系统监听和刷新令牌
    @StateObject private var coordinator = EditorFileTreeRefreshCoordinator()

    /// Swift Package Dependencies 数据源
    @StateObject private var packageStore = EditorPackageDependencyStore()

    /// 根节点刷新令牌（由协调器驱动 + 手动驱动）
    @State private var rootRefreshToken: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            if projectVM.currentProjectPath.isEmpty {
                EditorFileTreeNoProjectView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        EditorFileTreeNodeView(
                            url: URL(fileURLWithPath: projectVM.currentProjectPath),
                            depth: 0,  // depth == 0 表示根节点
                            selectedURL: editorVM.service.currentFileURL,
                            onSelect: { selectedURL in
                                openProjectFile(selectedURL)
                            },
                            refreshToken: rootRefreshToken,
                            projectRootPath: projectVM.currentProjectPath,
                            onExpansionChange: { relativePath, isExpanded in
                                handleExpansionChange(relativePath: relativePath, isExpanded: isExpanded)
                            },
                            gitStatusSnapshot: coordinator.gitStatusSnapshot
                        )

                        Divider()
                            .opacity(0.35)

                        EditorPackageDependencySection(
                            projectRootPath: projectVM.currentProjectPath,
                            dependencies: packageStore.dependencies,
                            isLoading: packageStore.isLoading,
                            diagnostic: packageStore.diagnostic,
                            onRetry: { packageStore.refresh() }
                        )
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: projectVM.currentProjectPath, onProjectPathChanged)
        .onChange(of: editorVM.service.currentFileURL, onSelectedFileChanged)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onSyncSelectedFile(perform: onSyncSelectedFile)
        .onReceive(coordinator.$refreshToken) { newToken in
            onCoordinatorRefresh(newToken)
        }
    }

    // MARK: - Event Handler

    private func onSyncSelectedFile(path: String) {
        let url = URL(fileURLWithPath: path)
        openProjectFile(url)
    }

    private func openProjectFile(_ url: URL) {
        let projectPath = projectVM.currentProjectPath
        Task { @MainActor in
            await editorVM.service.refreshProjectContext(for: projectPath)
            editorVM.service.open(at: url)
        }
    }

    private func onProjectPathChanged() {
        // 项目路径变化时，更新协调器并递增刷新令牌
        coordinator.setProjectRootPath(projectVM.currentProjectPath)
        packageStore.setProjectRootPath(projectVM.currentProjectPath)
        rootRefreshToken += 1
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)项目路径变化，更新协调器并递增刷新令牌")
            }
        }
    }

    private func onAppear() {
        // 首次渲染时初始化协调器（解决应用启动恢复上次项目时 onChange 不触发的问题）
        if !projectVM.currentProjectPath.isEmpty {
            coordinator.setProjectRootPath(projectVM.currentProjectPath)
            packageStore.setProjectRootPath(projectVM.currentProjectPath)
            rootRefreshToken += 1
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.info("\(Self.t)视图首次出现，初始化协调器，项目路径：\(projectVM.currentProjectPath)")
                }
            }
        }
    }

    private func onSelectedFileChanged() {
        // 自动展开到选中文件的逻辑需要在 EditorFileTreeNodeView 中处理
    }

    private func onDisappear() {
        coordinator.stop()
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)视图消失，停止协调器监听")
            }
        }
    }

    /// 协调器检测到文件系统变化时，递增根刷新令牌驱动整棵树刷新
    private func onCoordinatorRefresh(_ newToken: Int) {
        guard newToken > 0 else { return }
        rootRefreshToken += 1
        packageStore.refresh()
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)协调器驱动刷新，令牌：\(rootRefreshToken)")
            }
        }
    }

    /// 子节点展开/折叠时通知协调器更新监听列表
    private func handleExpansionChange(relativePath: String, isExpanded: Bool) {
        if isExpanded {
            coordinator.addExpandedPath(relativePath)
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.info("\(Self.t)节点展开：\(relativePath)")
                }
            }
        } else {
            coordinator.removeExpandedPath(relativePath)
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.info("\(Self.t)节点折叠：\(relativePath)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EditorFileTreeView()
        .inRootView()
        .frame(width: 250, height: 400)
}
