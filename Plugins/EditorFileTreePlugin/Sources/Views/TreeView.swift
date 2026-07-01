import EditorService
import os
import LumiCoreKit
import SuperLogKit
import SwiftUI
import LumiUI

/// Editor Rail 文件树根视图
public struct TreeView: View, SuperLog {
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject var editorContext: EditorContext
    @EnvironmentObject var conversationVM: WindowConversationVM

    public nonisolated static let emoji = "🌳"
    public nonisolated static var verbose: Bool { EditorFileTreePanelPlugin.verbose }
    public nonisolated static let logger = EditorFileTreePanelPlugin.logger

    /// 刷新协调器，管理文件系统监听和刷新令牌
    @StateObject private var coordinator = RefreshCoordinator()

    /// 文件树多选状态
    @StateObject private var selectionState = SelectionState()

    /// Swift Package Dependencies 数据源
    @StateObject private var packageStore = PackageDependencyStore()

    /// 根节点刷新令牌（由协调器驱动 + 手动驱动）
    @State private var rootRefreshToken: Int = 0

    /// 闪烁高亮触发器：当此值变化时，匹配路径的节点会闪烁
    @State private var flashTrigger: (path: String, id: UUID)?

    public init() {}

    /// 打开文件任务，连续点击时取消较早的请求，避免乱序完成。
    @State private var openFileTask: Task<Void, Never>?

    private var showPackageDependencies: Bool {
        guard !projectVM.currentProjectPath.isEmpty else { return false }
        guard EditorFileTreePanelPlugin.packageDependenciesEnabled else { return false }
        return PackageDependencyResolver.shouldShowPackageDependencies(
            projectRootURL: URL(fileURLWithPath: projectVM.currentProjectPath)
        )
    }

    public var body: some View {
        let showsPackageDependencies = showPackageDependencies
        let _ = FileTreePerformanceLog.recordTreeBody(
            projectPath: projectVM.currentProjectPath,
            rootRefreshToken: rootRefreshToken,
            showsPackageDependencies: showsPackageDependencies
        )

        VStack(spacing: 0) {
            if projectVM.currentProjectPath.isEmpty {
                NoProjectView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        NodeView(
                            url: URL(fileURLWithPath: projectVM.currentProjectPath),
                            depth: 0,  // depth == 0 表示根节点
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
                            gitStatusSnapshot: coordinator.gitStatusSnapshot,
                            targetedRefreshToken: coordinator.targetedRefreshToken,
                            changedDirectoryPathsToken: coordinator.changedDirectoryPathsToken,
                            changedDirectoryPaths: coordinator.changedDirectoryPaths,
                            gitStatusToken: coordinator.gitStatusToken
                        )

                        if showPackageDependencies {
                            Divider()
                                .opacity(0.35)

                            PackageDependencySection(
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
        }
        .environmentObject(selectionState)
        .frame(maxHeight: .infinity)
        .onChange(of: editorContext.fileTreeHighlightedFileURL) { _, url in
            if let url {
                selectionState.syncFromEditorHighlight(url)
                // 触发闪烁效果，帮助用户定位文件
                if EditorFileTreePanelPlugin.flashHighlightEnabled {
                    selectionState.triggerFlash(for: url)
                }
            } else {
                selectionState.clearSelection()
            }
        }
        .onChange(of: rootRefreshToken) { _, _ in
            selectionState.resetVisibleOrder()
        }
        .onChange(of: projectVM.currentProjectPath, onProjectPathChanged)
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
        openFileTask?.cancel()
        editorContext.setFileTreeHighlightedFileURL(url)

        let projectPath = projectVM.currentProjectPath
        editorContext.openFile(at: url)

        openFileTask = Task { @MainActor in
            await editorContext.refreshProjectContext(for: projectPath)
        }
    }

    private func onProjectPathChanged() {
        coordinator.setProjectRootPath(projectVM.currentProjectPath)
        packageStore.setProjectRootPath(projectVM.currentProjectPath)
        openFileTask?.cancel()
        openFileTask = nil
        selectionState.clearSelection()
        selectionState.resetVisibleOrder()
        editorContext.syncFileTreeHighlightFromEditor()
        rootRefreshToken += 1
        if Self.verbose {
            Self.logger.info("\(Self.t)项目路径变化，更新协调器并递增刷新令牌")
        }
    }

    private func onAppear() {
        if !projectVM.currentProjectPath.isEmpty {
            coordinator.setProjectRootPath(projectVM.currentProjectPath)
            packageStore.setProjectRootPath(projectVM.currentProjectPath)
            if editorContext.fileTreeHighlightedFileURL == nil {
                editorContext.syncFileTreeHighlightFromEditor()
            } else if let highlighted = editorContext.fileTreeHighlightedFileURL {
                selectionState.syncFromEditorHighlight(highlighted)
            }
            if rootRefreshToken == 0 {
                rootRefreshToken = 1
            }
            if Self.verbose {
                Self.logger.info("\(Self.t)视图首次出现，初始化协调器，项目路径：\(projectVM.currentProjectPath)")
            }
        }
    }

    private func onDisappear() {
        openFileTask?.cancel()
        openFileTask = nil
        coordinator.stop()
        if Self.verbose {
            Self.logger.info("\(Self.t)视图消失，停止协调器监听")
        }
    }

    /// 协调器检测到文件系统变化时，递增根刷新令牌驱动整棵树刷新
    private func onCoordinatorRefresh(_ newToken: Int) {
        guard newToken > 0 else { return }
        rootRefreshToken += 1
        packageStore.refresh()
        if Self.verbose {
            Self.logger.info("\(Self.t)协调器驱动刷新，令牌：\(rootRefreshToken)")
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
                Self.logger.info("\(Self.t)节点展开：\(relativePath)")
            }
        } else {
            coordinator.removeExpandedPath(relativePath)
            if Self.verbose {
                Self.logger.info("\(Self.t)节点折叠：\(relativePath)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TreeView()
        .inRootView()
        .frame(width: 250, height: 400)
}
