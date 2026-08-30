import Foundation
import KitSuperLog
import os
import SwiftUI

/// 文件树视图
///
/// 基于 NSCollectionView 的原生渲染实现，优化 LLM 流式响应期间的滚动性能。
///
/// 仅负责展示文件树;不承载其他协同行为。
public struct TreeView: View, SuperLog {
    public nonisolated static let emoji = "🌲"
    public nonisolated static var verbose: Bool { ProjectFileTreePlugin.verbose }
    nonisolated static let logger = ProjectFileTreePlugin.logger

    let context: FileTreeContext
    @ObservedObject var viewModel: ProjectFileTreeViewModel

    /// 当前项目是否需要展示 Swift Package 依赖区域（随项目路径变化时重新计算）。
    /// 缓存为 @State 而非 computed：避免每次 body 重算都触发一次
    /// `shouldShowPackageDependencies`（内部含 `contentsOfDirectory`）的同步磁盘扫描。
    @State private var showPackageDependencies: Bool = false

    /// 文件树多选状态
    @StateObject private var selectionState = SelectionState()

    /// 刷新协调器
    @StateObject private var coordinator = RefreshCoordinator()

    /// Swift Package Dependencies 数据源
    @StateObject private var packageStore = PackageDependencyStore()

    init(context: FileTreeContext, viewModel: ProjectFileTreeViewModel) {
        self.context = context
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.currentProjectPath.isEmpty {
                EmptyView()
            } else {
                FileTreeNSViewBridge(
                    context: context,
                    projectRootPath: viewModel.currentProjectPath,
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
        .onChange(of: viewModel.currentProjectPath) { _, newPath in
            projectPathDidChange(to: newPath)
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
    }

    // MARK: - Event Handlers

    private func handleExpansionChange(relativePath: String, isExpanded: Bool) {
        let projectRoot = viewModel.currentProjectPath
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

    private func projectPathDidChange(to newProjectPath: String) {
        recomputeShowPackageDependencies()
        coordinator.stop()
        coordinator.setProjectRootPath(newProjectPath)
        packageStore.setProjectRootPath(newProjectPath)
    }

    private func onAppear() {
        projectPathDidChange(to: viewModel.currentProjectPath)
        if Self.verbose {
            Self.logger.info("\(Self.t)出现，项目路径: \(viewModel.currentProjectPath)")
        }
    }

    /// 重新计算当前项目是否需要展示 Swift Package 依赖区域。
    /// 仅在项目路径变化/视图出现时调用一次，避免在 body 中反复同步扫描磁盘。
    private func recomputeShowPackageDependencies() {
        // 软件包依赖功能暂时隐藏，待后续完善后再启用。
        showPackageDependencies = false
    }

    private func onDisappear() {
        coordinator.stop()
        if Self.verbose {
            Self.logger.info("\(Self.t)消失")
        }
    }
}
