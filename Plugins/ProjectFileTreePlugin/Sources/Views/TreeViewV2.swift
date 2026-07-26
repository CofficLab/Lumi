import SwiftUI
import LumiKernel
import os
import SuperLogKit

/// 文件树 V2 视图
///
/// 基于 NSCollectionView 的原生渲染实现，优化 LLM 流式响应期间的滚动性能。
/// 对外暴露与 TreeView 相同的接口，便于无缝切换。
///
/// 仅负责展示文件树;不承载任何 editor 协同行为。
public struct TreeViewV2: View, SuperLog {
    public nonisolated static let emoji = "🌲"
    public nonisolated static var verbose: Bool { ProjectFileTreePlugin.verbose }
    nonisolated static let logger = ProjectFileTreePlugin.logger

    let kernel: LumiKernel

    /// 文件树多选状态
    @StateObject private var selectionState = SelectionState()

    /// 刷新协调器
    @StateObject private var coordinator = RefreshCoordinator()

    /// Swift Package Dependencies 数据源
    @StateObject private var packageStore = PackageDependencyStore()

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        let projectPath = currentProjectPath

        VStack(spacing: 0) {
            if projectPath.isEmpty {
                NoProjectView()
            } else {
                FileTreeNSViewBridge(
                    projectRootPath: projectPath,
                    onExpansionChange: { relativePath, isExpanded in
                        handleExpansionChange(relativePath: relativePath, isExpanded: isExpanded)
                    },
                    onTreeMutation: {
                        refreshTreeAfterMutation()
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
        .onCurrentProjectDidChange { _ in
            onProjectPathChanged()
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
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
}
