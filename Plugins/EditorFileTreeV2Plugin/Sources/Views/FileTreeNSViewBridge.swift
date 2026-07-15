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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var viewController: FileTreeCollectionViewController?
    }
}
