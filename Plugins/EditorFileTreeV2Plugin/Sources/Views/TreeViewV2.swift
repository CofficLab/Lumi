import SwiftUI
import EditorService
import LumiCoreKit
import EditorFileTreePlugin
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

    /// 根节点刷新令牌
    @State private var rootRefreshToken: Int = 0

    /// 闪烁高亮触发器
    @State private var flashTrigger: (path: String, id: UUID)?

    /// 打开文件任务
    @State private var openFileTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        let projectPath = currentProjectPath
        let _ = Self.logger.info("\(Self.t)📝[body] projectPath: \(projectPath)")

        VStack(spacing: 0) {
            if projectPath.isEmpty {
                let _ = Self.logger.warning("\(Self.t)📝[body] → NoProjectView (projectPath is empty)")
                NoProjectView()
            } else {
                let _ = Self.logger.info("\(Self.t)📝[body] → FileTreeNSViewBridge (projectPath is not empty)")
                FileTreeNSViewBridge(
                    projectRootPath: projectPath,
                    onSelect: { selectedURL in
                        Self.logger.info("\(Self.t)📝[onSelect] url: \(selectedURL.path)")
                        openProjectFile(selectedURL)
                    },
                    onExpansionChange: { relativePath, isExpanded in
                        Self.logger.info("\(Self.t)📝[onExpansionChange] path: \(relativePath), isExpanded: \(isExpanded)")
                        handleExpansionChange(relativePath: relativePath, isExpanded: isExpanded)
                    },
                    onTreeMutation: {
                        Self.logger.info("\(Self.t)📝[onTreeMutation] triggered")
                        refreshTreeAfterMutation()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environmentObject(selectionState)
        .frame(maxHeight: .infinity)
        .onChange(of: editorContext.fileTreeHighlightedFileURL) { url in
            if let url {
                selectionState.syncFromEditorHighlight(url)
            } else {
                selectionState.clearSelection()
            }
        }
        .onCurrentProjectDidChange { _ in
            onProjectPathChanged()
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onReceive(coordinator.$refreshToken) { newToken in
            onCoordinatorRefresh(newToken)
        }
    }

    // MARK: - Private Computed Properties

    private var currentProjectPath: String {
        LumiCore.projectState?.currentProject?.path ?? ""
    }

    // MARK: - Event Handlers

    private func openProjectFile(_ url: URL) {
        openFileTask?.cancel()
        editorContext.setFileTreeHighlightedFileURL(url)
        editorContext.openFile(at: url)
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
    }

    private func onProjectPathChanged() {
        coordinator.stop()
        rootRefreshToken += 1
    }

    private func onAppear() {
        coordinator.setProjectRootPath(currentProjectPath)
        Self.logger.info("FileTreeV2 出现，项目路径: \(currentProjectPath)")
    }

    private func onDisappear() {
        coordinator.stop()
        Self.logger.info("FileTreeV2 消失")
    }

    private func onCoordinatorRefresh(_ newToken: Int) {
        rootRefreshToken = newToken
    }
}
