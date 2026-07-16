import AppKit
import SwiftUI
import os
import SuperLogKit

/// NSViewRepresentable 桥接层
///
/// 将 FileTreeCollectionViewController 包装为 SwiftUI 视图。
struct FileTreeNSViewBridge: NSViewRepresentable, SuperLog {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree-v2")
    private static let verbose = EditorFileTreeV2Plugin.verbose
    public nonisolated static let emoji: String = ""

    let projectRootPath: String
    let onSelect: (URL) -> Void
    let onExpansionChange: ((String, Bool) -> Void)?
    let onTreeMutation: (() -> Void)?
    let onCloseEditorTabs: (([URL]) -> Void)?
    let onRenameEditorTab: ((URL, URL) -> Void)?
    let onAddToConversation: (([URL]) -> Void)?
    let flashTrigger: (path: String, id: UUID)?
    let onMiddleClick: ((URL) -> Void)?
    let gitStatusSnapshot: GitStatusSnapshot
    let packageDependencies: [PackageDependency]

    /// 精准刷新令牌：watcher 检测到外部文件系统变化时由 RefreshCoordinator 递增。
    /// 变化时在 updateNSView 中据此驱动对应目录的 reloadDirectory。
    let targetedRefreshToken: Int

    /// 最近一次精准刷新命中的目录绝对路径集合（标准化后）。
    /// 由 RefreshCoordinator 下发，逐个 reload 这些目录以反映外部增删改。
    let changedDirectoryPaths: Set<String>

    func makeNSView(context: Context) -> NSView {
        if Self.verbose {
            Self.logger.info("\(Self.t)🏗️ makeNSView 开始, projectRootPath: \(self.projectRootPath)")
        }

        let viewController = FileTreeCollectionViewController()
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ ViewController 创建完成")
        }

        viewController.setProjectRoot(projectRootPath)
        viewController.setPackageDependencies(packageDependencies)
        viewController.onSelect = onSelect
        viewController.onExpansionChange = onExpansionChange
        viewController.onTreeMutation = onTreeMutation
        viewController.onCloseEditorTabs = onCloseEditorTabs
        viewController.onRenameEditorTab = onRenameEditorTab
        viewController.onAddToConversation = onAddToConversation
        viewController.onMiddleClick = onMiddleClick
        viewController.gitStatusSnapshot = gitStatusSnapshot

        context.coordinator.viewController = viewController
        if Self.verbose {
            Self.logger.info("\(Self.t)💾 ViewController 已保存到 Coordinator")
        }

        let view = viewController.view
        let w = view.frame.size.width, h = view.frame.size.height
        if Self.verbose {
            Self.logger.info("\(Self.t)📐 返回 view, size: \(w)x\(h)")
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let w = nsView.frame.size.width, h = nsView.frame.size.height
        if Self.verbose {
            Self.logger.info("\(Self.t)🔄 updateNSView 调用, view size: \(w)×\(h)")
        }
        guard let viewController = context.coordinator.viewController else {
            Self.logger.warning("\(Self.t)❌ updateNSView: viewController 为 nil!")
            return
        }

        if viewController.getProjectRootPath() != projectRootPath {
            if Self.verbose {
                Self.logger.info("\(Self.t)📂 项目路径变化, 重新设置: \(self.projectRootPath)")
            }
            viewController.setProjectRoot(projectRootPath)
        }

        viewController.setPackageDependencies(packageDependencies)

        viewController.gitStatusSnapshot = gitStatusSnapshot

        if let flashTrigger, !flashTrigger.path.isEmpty {
            viewController.triggerFlash(path: flashTrigger.path)
        }

        // 精准刷新：watcher 检测到外部文件系统变化时，RefreshCoordinator 递增
        // targetedRefreshToken 并下发 changedDirectoryPaths。此处据此驱动 reloadDirectory，
        // 避免整树重载。用 lastTargetedRefreshToken 去重，防止 updateNSView 因其它属性
        // 变化（如 Git 快照更新）重入时造成多余刷新。
        if context.coordinator.lastTargetedRefreshToken != targetedRefreshToken {
            context.coordinator.lastTargetedRefreshToken = targetedRefreshToken
            if changedDirectoryPaths.isEmpty {
                // 无具体目标（兜底）：全量刷新
                viewController.fullRefresh()
            } else {
                // 精准刷新：逐个 reload 变化的目录
                for path in changedDirectoryPaths {
                    // 跳过项目根目录：根节点始终由 setProjectRoot / fullRefresh 维护，
                    // reloadDirectory 依赖节点已存在于 items 中，对根目录单独 reload 不适用。
                    if path == projectRootPath { continue }
                    viewController.reloadDirectory(at: URL(fileURLWithPath: path))
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var viewController: FileTreeCollectionViewController?
        /// 已处理过的精准刷新令牌，用于在 updateNSView 中去重。
        var lastTargetedRefreshToken: Int = -1
    }
}
