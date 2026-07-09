import AppKit
import SwiftUI
import os

/// NSViewRepresentable 桥接层
///
/// 将 FileTreeCollectionViewController 包装为 SwiftUI 视图。
struct FileTreeNSViewBridge: NSViewRepresentable {
    private static let emoji = "🌲"
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree-v2")
    private static let verbose = EditorFileTreeV2Plugin.verbose

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

    func makeNSView(context: Context) -> NSView {
        if Self.verbose {
            Self.logger.info("\(Self.emoji) makeNSView 开始, projectRootPath: \(self.projectRootPath)")
        }

        let viewController = FileTreeCollectionViewController()
        if Self.verbose {
            Self.logger.info("\(Self.emoji) ViewController 创建完成")
        }

        viewController.setProjectRoot(projectRootPath)
        viewController.onSelect = onSelect
        viewController.onExpansionChange = onExpansionChange
        viewController.onTreeMutation = onTreeMutation
        viewController.onCloseEditorTabs = onCloseEditorTabs
        viewController.onRenameEditorTab = onRenameEditorTab
        viewController.onAddToConversation = onAddToConversation
        viewController.onMiddleClick = onMiddleClick
        viewController.gitStatusSnapshot = gitStatusSnapshot

        // 强引用持有 viewController，防止被释放
        context.coordinator.viewController = viewController
        if Self.verbose {
            Self.logger.info("\(Self.emoji) ViewController 已保存到 Coordinator")
        }

        let view = viewController.view
        let w = view.frame.size.width, h = view.frame.size.height
        if Self.verbose {
            Self.logger.info("\(Self.emoji) 返回 view, size: \(w)x\(h)")
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let w = nsView.frame.size.width, h = nsView.frame.size.height
        if Self.verbose {
            Self.logger.info("\(Self.emoji) updateNSView 调用, view size: \(w)x\(h)")
        }
        guard let viewController = context.coordinator.viewController else {
            Self.logger.warning("\(Self.emoji) updateNSView: viewController 为 nil!")
            return
        }

        // 检查项目路径是否变化
        if viewController.getProjectRootPath() != projectRootPath {
            if Self.verbose {
                Self.logger.info("\(Self.emoji) 项目路径变化, 重新设置: \(self.projectRootPath)")
            }
            viewController.setProjectRoot(projectRootPath)
        }

        // 更新 Git 状态快照
        viewController.gitStatusSnapshot = gitStatusSnapshot

        // 更新闪烁触发
        if let flashTrigger {
            viewController.triggerFlash(path: flashTrigger.path)
        }
    }

    func makeCoordinator() -> Coordinator {
        if Self.verbose {
            Self.logger.info("\(Self.emoji) makeCoordinator 调用")
        }
        return Coordinator()
    }

    class Coordinator {
        // 强引用持有 viewController，防止被释放
        var viewController: FileTreeCollectionViewController?
    }
}
