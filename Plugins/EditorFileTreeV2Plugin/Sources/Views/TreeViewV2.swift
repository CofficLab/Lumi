import SwiftUI
import EditorService
import LumiCoreKit
import os
import SuperLogKit

/// 文件树 V2 视图
///
/// 基于 NSCollectionView 的原生渲染实现，优化 LLM 流式响应期间的滚动性能。
/// 对外暴露与 TreeView 相同的接口，便于无缝切换。
public struct TreeViewV2: View, SuperLog {
    public nonisolated static let emoji = "🌲"
    public nonisolated static var verbose: Bool { EditorFileTreeV2Plugin.verbose }
    nonisolated static let logger = EditorFileTreeV2Plugin.logger

    @EnvironmentObject var editorContext: EditorContext

    /// 文件树多选状态
    @StateObject private var selectionState = SelectionState()

    /// 刷新协调器
    @StateObject private var coordinator = RefreshCoordinator()

    /// Swift Package Dependencies 数据源
    @StateObject private var packageStore = PackageDependencyStore()

    /// 根节点刷新令牌
    @State private var rootRefreshToken: Int = 0

    /// 闪烁高亮触发器
    @State private var flashTrigger: (path: String, id: UUID)?

    /// 打开文件任务
    @State private var openFileTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        let projectPath = currentProjectPath

        VStack(spacing: 0) {
            if projectPath.isEmpty {
                NoProjectView()
            } else {
                FileTreeNSViewBridge(
                    projectRootPath: projectPath,
                    onSelect: { selectedURL in
                        openProjectFile(selectedURL)
                    },
                    onExpansionChange: { relativePath, isExpanded in
                        handleExpansionChange(relativePath: relativePath, isExpanded: isExpanded)
                    },
                    onTreeMutation: {
                        refreshTreeAfterMutation()
                    },
                    onCloseEditorTabs: { urls in
                        editorContext.closeSessions(forURLs: urls)
                    },
                    onRenameEditorTab: { oldURL, newURL in
                        editorContext.replaceSessionURL(from: oldURL, to: newURL)
                    },
                    onAddToConversation: { urls in
                        editorContext.addToConversation(fileURLs: urls, windowId: nil)
                    },
                    flashTrigger: flashTrigger,
                    onMiddleClick: { selectedURL in
                        openProjectFile(selectedURL)
                    },
                    gitStatusSnapshot: coordinator.gitStatusSnapshot,
                    packageDependencies: showPackageDependencies ? packageStore.dependencies : []
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environmentObject(selectionState)
        .frame(maxHeight: .infinity)
        .onChange(of: editorContext.fileTreeHighlightedFileURL) { url in
            if let url {
                selectionState.syncFromEditorHighlight(url)
                // 触发闪烁效果，帮助用户定位文件
                if EditorFileTreeV2Plugin.flashHighlightEnabled {
                    selectionState.triggerFlash(for: url)
                }
            } else {
                selectionState.clearSelection()
            }
        }
        // 同步选中文件通知：外部触发时自动打开文件
        .onReceive(
            NotificationCenter.default.publisher(
                for: EditorContext.syncSelectedFileNotificationName ?? Notification.Name("___unused___")
            )
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let path = userInfo["path"] as? String else { return }
            let url = URL(fileURLWithPath: path)
            openProjectFile(url)
        }
        .onCurrentProjectDidChange { _ in
            onProjectPathChanged()
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onReceive(coordinator.$refreshToken) { newToken in
            onCoordinatorRefresh(newToken)
        }
        // 监听闪烁路径变化，转换为 flashTrigger 传递给 AppKit 层
        .onReceive(selectionState.$flashPath) { path in
            if let path = path {
                flashTrigger = (path, UUID())
            }
        }
    }

    // MARK: - Private Computed Properties

    private var currentProjectPath: String {
        LumiCore.projectState?.currentProject?.path ?? ""
    }

    private var showPackageDependencies: Bool {
        guard !currentProjectPath.isEmpty else { return false }
        return PackageDependencyResolver.shouldShowPackageDependencies(
            projectRootURL: URL(fileURLWithPath: currentProjectPath)
        )
    }

    // MARK: - Event Handlers

    private func openProjectFile(_ url: URL) {
        openFileTask?.cancel()
        editorContext.setFileTreeHighlightedFileURL(url)

        let projectPath = currentProjectPath
        editorContext.openFile(at: url)

        openFileTask = Task { @MainActor in
            await editorContext.refreshProjectContext(for: projectPath)
        }
    }

    private func handleExpansionChange(relativePath: String, isExpanded: Bool) {
        let projectRoot = currentProjectPath
        if isExpanded {
            FileTreeSettings.shared.addExpandedPath(relativePath, for: projectRoot)
        } else {
            FileTreeSettings.shared.removeExpandedPath(relativePath, for: projectRoot)
        }
    }

    private func refreshTreeAfterMutation() {
        coordinator.refresh()
        packageStore.refresh()
    }

    private func onProjectPathChanged() {
        coordinator.stop()
        packageStore.setProjectRootPath(currentProjectPath)
        rootRefreshToken += 1
    }

    private func onAppear() {
        coordinator.setProjectRootPath(currentProjectPath)
        packageStore.setProjectRootPath(currentProjectPath)
        if Self.verbose {
            Self.logger.info("\(Self.t)出现，项目路径: \(currentProjectPath)")
        }
    }

    private func onDisappear() {
        coordinator.stop()
        if Self.verbose {
            Self.logger.info("\(Self.t)消失")
        }
    }

    private func onCoordinatorRefresh(_ newToken: Int) {
        rootRefreshToken = newToken
        packageStore.refresh()
    }
}
