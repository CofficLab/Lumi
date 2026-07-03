import AppKit
import SwiftUI
import EditorFileTreePlugin
import LumiUI

/// 文件树节点单元格
///
/// NSCollectionViewItem 宿主，使用 NSHostingView 承载 NodeRowView。
final class FileTreeNodeCell: NSCollectionViewItem {
    
    private var hostingView: NSHostingView<NodeRowView>?
    private var isHovered = false
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        
        hostingView = NSHostingView(rootView: NodeRowView.placeholder)
        hostingView?.translatesAutoresizingMaskIntoConstraints = false
        
        if let hostingView = hostingView {
            view.addSubview(hostingView)
            
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: view.topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }
    
    func configure(
        with item: FileTreeNodeItem,
        isSelected: Bool,
        isHovered: Bool,
        gitStatus: GitStatus?,
        theme: any LumiAppChromeTheme
    ) {
        self.isHovered = isHovered
        
        let rowView = NodeRowView(
            item: item,
            isSelected: isSelected,
            isHovered: isHovered,
            gitStatus: gitStatus,
            theme: theme
        )
        
        hostingView?.rootView = rowView
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        hostingView?.rootView = NodeRowView.placeholder
        isHovered = false
    }
}
