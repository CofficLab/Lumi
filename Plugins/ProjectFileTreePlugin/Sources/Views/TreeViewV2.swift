import SwiftUI
import LumiKernel
import os
import SuperLogKit

/// 文件树 V2 视图
///
/// 基于 NSCollectionView 的原生渲染实现，优化 LLM 流式响应期间的滚动性能。
/// 对外暴露与 TreeView 相同的接口，便于无缝切换。
///
/// 仅负责展示文件树;不承载其他协同行为。
public struct TreeViewV2: View, SuperLog {
    public nonisolated static let emoji = "🌲"
    public nonisolated static var verbose: Bool { ProjectFileTreePlugin.verbose }
    nonisolated static let logger = ProjectFileTreePlugin.logger

    let kernel: LumiKernel

    /// 当前项目路径缓存，用于驱动 SwiftUI 刷新。
    @State private var projectPath: String

    /// 文件树多选状态
    @StateObject private var selectionState = SelectionState()

    /// 刷新协调器
    @StateObject private var coordinator = RefreshCoordinator()

    /// Swift Package Dependencies 数据源
    @StateObject private var packageStore = PackageDependencyStore()

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        _projectPath = State(initialValue: kernel.project?.currentProject?.path ?? "")
    }

    public var body: some View {
        VStack(spacing: 0) {
            if projectPath.isEmpty {
                NoProjectView()
            } else {
                FileTreeNSViewBridge(
                    kernel: kernel,
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
        .onReceive(kernel.objectWillChange) { _ in
            syncProjectPathIfNeeded()
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
    }

    // MARK: - Private Computed Properties

    private var showPackageDependencies: Bool {
        guard !projectPath.isEmpty else { return false }
        return PackageDependencyResolver.shouldShowPackageDependencies(
            projectRootURL: URL(fileURLWithPath: projectPath)
        )
    }

    // MARK: - Event Handlers

    private func handleExpansionChange(relativePath: String, isExpanded: Bool) {
        let projectRoot = projectPath
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

    private func syncProjectPathIfNeeded() {
        let newProjectPath = kernel.project?.currentProject?.path ?? ""
        guard newProjectPath != projectPath else { return }

        projectPath = newProjectPath
        coordinator.stop()
        coordinator.setProjectRootPath(newProjectPath)
        packageStore.setProjectRootPath(newProjectPath)
    }

    private func onAppear() {
        syncProjectPathIfNeeded()
        coordinator.setProjectRootPath(projectPath)
        packageStore.setProjectRootPath(projectPath)
        if Self.verbose {
            Self.logger.info("\(Self.t)出现，项目路径: \(projectPath)")
        }
    }

    private func onDisappear() {
        coordinator.stop()
        if Self.verbose {
            Self.logger.info("\(Self.t)消失")
        }
    }
}
