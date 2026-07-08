import AppKit
import SwiftUI
import os

/// NSViewRepresentable 桥接层
///
/// 将 FileTreeCollectionViewController 包装为 SwiftUI 视图。
struct FileTreeNSViewBridge: NSViewRepresentable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree-v2")

    let projectRootPath: String
    let onSelect: (URL) -> Void
    let onExpansionChange: ((String, Bool) -> Void)?
    let onTreeMutation: (() -> Void)?
    let onCloseEditorTabs: (([URL]) -> Void)?
    let onRenameEditorTab: ((URL, URL) -> Void)?
    let onAddToConversation: (([URL]) -> Void)?

    func makeNSView(context: Context) -> NSView {
        Self.logger.info("📝[FileTreeNSViewBridge] makeNSView 开始, projectRootPath: \(self.projectRootPath)")

        let viewController = FileTreeCollectionViewController()
        Self.logger.info("📝[FileTreeNSViewBridge] ViewController 创建完成")

        viewController.setProjectRoot(projectRootPath)
        viewController.onSelect = onSelect
        viewController.onExpansionChange = onExpansionChange
        viewController.onTreeMutation = onTreeMutation
        viewController.onCloseEditorTabs = onCloseEditorTabs
        viewController.onRenameEditorTab = onRenameEditorTab
        viewController.onAddToConversation = onAddToConversation

        // 强引用持有 viewController，防止被释放
        context.coordinator.viewController = viewController
        Self.logger.info("📝[FileTreeNSViewBridge] ViewController 已保存到 Coordinator")

        let view = viewController.view
        let w = view.frame.size.width, h = view.frame.size.height
        Self.logger.info("📝[FileTreeNSViewBridge] 返回 view, size: \(w)x\(h)")

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let w = nsView.frame.size.width, h = nsView.frame.size.height
        Self.logger.info("📝[FileTreeNSViewBridge] updateNSView 调用, view size: \(w)x\(h)")
        guard let viewController = context.coordinator.viewController else {
            Self.logger.warning("📝[FileTreeNSViewBridge] updateNSView: viewController 为 nil!")
            return
        }

        // 检查项目路径是否变化
        if viewController.getProjectRootPath() != projectRootPath {
            Self.logger.info("📝[FileTreeNSViewBridge] 项目路径变化, 重新设置: \(self.projectRootPath)")
            viewController.setProjectRoot(projectRootPath)
        }
    }

    func makeCoordinator() -> Coordinator {
        Self.logger.info("📝[FileTreeNSViewBridge] makeCoordinator 调用")
        return Coordinator()
    }

    class Coordinator {
        // 强引用持有 viewController，防止被释放
        var viewController: FileTreeCollectionViewController?
    }
}
