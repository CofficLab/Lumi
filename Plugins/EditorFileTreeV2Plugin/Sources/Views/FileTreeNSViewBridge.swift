import AppKit
import SwiftUI

/// NSViewRepresentable 桥接层
///
/// 将 FileTreeCollectionViewController 包装为 SwiftUI 视图。
struct FileTreeNSViewBridge: NSViewRepresentable {
    
    let projectRootPath: String
    let onSelect: (URL) -> Void
    let onExpansionChange: ((String, Bool) -> Void)?
    let onTreeMutation: (() -> Void)?
    
    func makeNSView(context: Context) -> NSView {
        let viewController = FileTreeCollectionViewController()
        viewController.setProjectRoot(projectRootPath)
        viewController.onSelect = onSelect
        viewController.onExpansionChange = onExpansionChange
        viewController.onTreeMutation = onTreeMutation
        
        // 保存引用以便后续更新
        context.coordinator.viewController = viewController
        
        return viewController.view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let viewController = context.coordinator.viewController else { return }
        
        // 检查项目路径是否变化
        if viewController.getProjectRootPath() != projectRootPath {
            viewController.setProjectRoot(projectRootPath)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        weak var viewController: FileTreeCollectionViewController?
    }
}
