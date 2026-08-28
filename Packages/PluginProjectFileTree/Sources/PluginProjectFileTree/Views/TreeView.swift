import Combine
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

    // 本视图已是窄播：context 用 let（非 @ObservedObject），body 不订阅项目总线，
    // 只通过下方 .onReceive + guard 把关心的 projectPath 缓存进 @State，
    // 故项目能力上其他属性的变更不会触发 body 重算。
    // 未采用 ObservableProjectBox 是因为本视图刷新链路较复杂（NSCollectionView 桥接），
    // 当前手写去重已足够；如需统一风格可后续迁移。
    let context: FileTreeContext

    /// 空 Publisher：未打开项目（无 ProjectProviding）时兜底，避免 onReceive 需要可选。
    private let emptyProjectPublisher = ObservableObjectPublisher()

    /// 当前项目路径缓存，用于驱动 SwiftUI 刷新。
    @State private var projectPath: String

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

    public init(context: FileTreeContext) {
        self.context = context
        _projectPath = State(initialValue: context.currentProjectPath ?? "")
    }

    /// 项目能力的变化发布器（未打开项目时用空发布器兜底）。
    private var projectWillChange: ObservableObjectPublisher {
        context.project?.objectWillChange ?? emptyProjectPublisher
    }

    public var body: some View {
        VStack(spacing: 0) {
            if projectPath.isEmpty {
                NoProjectView()
            } else {
                FileTreeNSViewBridge(
                    context: context,
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
        .onReceive(projectWillChange) { _ in
            syncProjectPathIfNeeded()
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
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
        let newProjectPath = context.currentProjectPath ?? ""
        guard newProjectPath != projectPath else { return }

        projectPath = newProjectPath
        recomputeShowPackageDependencies()
        coordinator.stop()
        coordinator.setProjectRootPath(newProjectPath)
        packageStore.setProjectRootPath(newProjectPath)
    }

    private func onAppear() {
        syncProjectPathIfNeeded()
        recomputeShowPackageDependencies()
        coordinator.setProjectRootPath(projectPath)
        packageStore.setProjectRootPath(projectPath)
        if Self.verbose {
            Self.logger.info("\(Self.t)出现，项目路径: \(projectPath)")
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
