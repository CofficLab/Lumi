import Combine
import SwiftUI
import LumiKernel
import os
import SuperLogKit

/// 文件树 V2 视图
///
/// 基于 NSCollectionView 的原生渲染实现，优化 LLM 流式响应期间的滚动性能。
/// 对外暴露与 TreeView 相同的接口，便于无缝切换。
///
/// 编辑器协同能力(打开/关闭/迁移 session、高亮、加入对话)通过 kernel 的
/// `FileTreeEditorCoordination` 协议消费,本视图不依赖具体编辑器服务实现。
public struct TreeViewV2: View, SuperLog {
    public nonisolated static let emoji = "🌲"
    public nonisolated static var verbose: Bool { ProjectFileTreePlugin.verbose }
    nonisolated static let logger = ProjectFileTreePlugin.logger

    /// 编辑器协同能力(从内核解析;若未注册则为 nil,相关操作安全降级为空操作)。
    private let coordination: (any FileTreeEditorCoordination)?
    /// 高亮 URL 变化流(init 时捕获一次,避免 body 每次重算重建 publisher 触发死循环)。
    private let highlightPublisher: AnyPublisher<URL?, Never>
    let kernel: LumiKernel

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

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        let coordination = kernel.resolveService(FileTreeEditorCoordination.self)
        self.coordination = coordination
        // 在 init 时捕获 publisher 一次;否则 body 里每次访问计算属性会创建新实例,
        // 导致 .onReceive 重新订阅并立即发送当前值 → 触发状态变化 → body 重算 → 死循环。
        self.highlightPublisher = coordination?.fileTreeHighlightPublisher ?? Empty().eraseToAnyPublisher()
    }

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
                        coordination?.closeSessions(forURLs: urls)
                    },
                    onRenameEditorTab: { oldURL, newURL in
                        coordination?.replaceSessionURL(from: oldURL, to: newURL)
                    },
                    onAddToConversation: { urls in
                        coordination?.addToConversation(fileURLs: urls, windowId: nil)
                    },
                    flashTrigger: flashTrigger,
                    onMiddleClick: { selectedURL in
                        openProjectFile(selectedURL)
                    },
                    gitStatusSnapshot: coordinator.gitStatusSnapshot,
                    packageDependencies: showPackageDependencies ? packageStore.dependencies : [],
                    targetedRefreshToken: coordinator.targetedRefreshToken,
                    changedDirectoryPaths: coordinator.changedDirectoryPaths
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environmentObject(selectionState)
        .frame(maxHeight: .infinity)
        .onReceive(highlightPublisher) { url in
            if let url {
                selectionState.syncFromEditorHighlight(url)
                // 触发闪烁效果，帮助用户定位文件
                if ProjectFileTreePlugin.flashHighlightEnabled {
                    selectionState.triggerFlash(for: url)
                }
            } else {
                selectionState.clearSelection()
            }
        }
        // 同步选中文件通知：外部触发时自动打开文件
        .onReceive(
            NotificationCenter.default.publisher(
                for: FileTreeEditorNotifications.syncSelectedFile
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
        kernel.project?.currentProject?.path ?? ""
    }

    private var showPackageDependencies: Bool {
        guard !currentProjectPath.isEmpty else { return false }
        return PackageDependencyResolver.shouldShowPackageDependencies(
            projectRootURL: URL(fileURLWithPath: currentProjectPath)
        )
    }

    // MARK: - Event Handlers

    private func openProjectFile(_ url: URL) {
        guard let coordination else { return }
        openFileTask?.cancel()
        coordination.setFileTreeHighlightedFileURL(url)

        let projectPath = currentProjectPath
        coordination.openFile(at: url)

        openFileTask = Task { @MainActor in
            await coordination.refreshProjectContext(for: projectPath)
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
