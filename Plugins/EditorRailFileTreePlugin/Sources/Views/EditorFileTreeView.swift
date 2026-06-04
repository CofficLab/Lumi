import os
import LumiCoreKit
import SuperLogKit
import SwiftUI
import LumiUI

/// Editor Rail 文件树根视图
public struct EditorFileTreeView: View, SuperLog {
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject var editorContext: EditorContext
    @EnvironmentObject var conversationVM: WindowConversationVM

    // MARK: - Logging Configuration

    /// 日志详细程度控制
    public nonisolated static let emoji = "🌳"
    public nonisolated static let verbose: Bool = true
    /// 使用插件的 logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree.view")

    /// 刷新协调器，管理文件系统监听和刷新令牌
    @StateObject private var coordinator = EditorFileTreeRefreshCoordinator()

    /// Swift Package Dependencies 数据源
    @StateObject private var packageStore = EditorPackageDependencyStore()

    /// 根节点刷新令牌（由协调器驱动 + 手动驱动）
    @State private var rootRefreshToken: Int = 0

    /// 点击文件后立即更新的本地选中态。
    ///
    /// `EditorContext.currentFileURL` 仍然是编辑器真实状态，但打开文件前会先刷新项目上下文。
    /// 用本地状态可以避免刷新期间文件树继续高亮上一个文件。
    @State private var selectedFileURL: URL?

    public var body: some View {
        VStack(spacing: 0) {
            if projectVM.currentProjectPath.isEmpty {
                EditorFileTreeNoProjectView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        EditorFileTreeNodeView(
                            url: URL(fileURLWithPath: projectVM.currentProjectPath),
                            depth: 0,  // depth == 0 表示根节点
                            selectedURL: selectedFileURL ?? editorContext.currentFileURL,
                            onSelect: { selectedURL in
                                openProjectFile(selectedURL)
                            },
                            windowId: conversationVM.windowId,
                            refreshToken: rootRefreshToken,
                            projectRootPath: projectVM.currentProjectPath,
                            onExpansionChange: { relativePath, isExpanded in
                                handleExpansionChange(relativePath: relativePath, isExpanded: isExpanded)
                            },
                            onTreeMutation: {
                                refreshTreeAfterMutation()
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
        .onChange(of: editorContext.currentFileURL, onSelectedFileChanged)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onReceive(
            NotificationCenter.default.publisher(
                for: EditorContext.syncSelectedFileNotificationName ?? Notification.Name("___unused___")
            )
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let path = userInfo["path"] as? String else { return }
            if let windowId = conversationVM.windowId {
                guard let senderWindowId = userInfo["windowId"] as? UUID,
                      senderWindowId == windowId else { return }
            }
            onSyncSelectedFile(path: path)
        }
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
        selectedFileURL = url.standardizedFileURL
        let projectPath = projectVM.currentProjectPath
        Task { @MainActor in
            await editorContext.refreshProjectContext(for: projectPath)
            editorContext.openFile(at: url)
        }
    }

    private func onProjectPathChanged() {
        // 项目路径变化时，更新协调器并递增刷新令牌
        coordinator.setProjectRootPath(projectVM.currentProjectPath)
        packageStore.setProjectRootPath(projectVM.currentProjectPath)
        selectedFileURL = editorContext.currentFileURL?.standardizedFileURL
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
            selectedFileURL = editorContext.currentFileURL?.standardizedFileURL
            rootRefreshToken += 1
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.info("\(Self.t)视图首次出现，初始化协调器，项目路径：\(projectVM.currentProjectPath)")
                }
            }
        }
    }

    private func onSelectedFileChanged() {
        selectedFileURL = editorContext.currentFileURL?.standardizedFileURL
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

    /// 文件树内创建、重命名或删除后立即刷新展开目录，避免 UI 等待文件系统监听回调。
    private func refreshTreeAfterMutation() {
        rootRefreshToken += 1
        packageStore.refresh()
        if Self.verbose {
            Self.logger.info("\(Self.t)文件树内容变化，立即刷新，令牌：\(rootRefreshToken)")
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
