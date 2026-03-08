import AppKit
import SwiftUI

/// 文件树节点
class FileNode: NSObject {
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [FileNode] = []
    var isLoaded = false
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        super.init()
    }
    
    func loadChildren() {
        guard isDirectory && !isLoaded else { return }
        isLoaded = true
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            children = contents
                .map { FileNode(url: $0) }
                .sorted { a, b in
                    if a.isDirectory == b.isDirectory {
                        return a.name.localizedStandardCompare(b.name) == .orderedAscending
                    }
                    return a.isDirectory
                }
        } catch {
            children = []
        }
    }
}

/// NSOutlineView 数据源和代理
class FileTreeDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var rootNodes: [FileNode] = []
    weak var outlineView: NSOutlineView?
    var onSelect: ((URL) -> Void)?
    
    func setRootURL(_ url: URL) {
        let node = FileNode(url: url)
        node.loadChildren()
        rootNodes = node.children
        outlineView?.reloadData()
    }
    
    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? FileNode {
            node.loadChildren()
            return node.children.count
        }
        return rootNodes.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? FileNode {
            return node.children[index]
        }
        return rootNodes[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? FileNode else { return false }
        return node.isDirectory
    }
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let node = item as? FileNode else { return nil }
        
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(node.url.path, forType: .string)
        pasteboardItem.setString(node.url.path, forType: .fileURL)
        return pasteboardItem
    }
    
    // MARK: - NSOutlineViewDelegate
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FileNode else { return nil }
        
        let cell = NSTableCellView()
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        
        // 图标
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: iconName(for: node), accessibilityDescription: nil)
        icon.contentTintColor = node.isDirectory ? .controlAccentColor : .secondaryLabelColor
        icon.frame = NSRect(x: 0, y: 0, width: 14, height: 14)
        stack.addArrangedSubview(icon)
        
        // 名称
        let label = NSTextField(labelWithString: node.name)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingMiddle
        stack.addArrangedSubview(label)
        
        cell.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        
        return cell
    }
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return FileTreeRowView()
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let node = item as? FileNode else { return false }
        
        if node.isDirectory {
            if outlineView.isItemExpanded(item) {
                outlineView.collapseItem(item)
            } else {
                outlineView.expandItem(item)
            }
            return false
        }
        return true
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView,
              let node = outlineView.item(atRow: outlineView.selectedRow) as? FileNode else { return }
        
        if !node.isDirectory {
            onSelect?(node.url)
        }
    }
    
    private func iconName(for node: FileNode) -> String {
        if node.isDirectory {
            return "folder"
        }
        let ext = node.url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "md", "txt", "json", "xml", "yaml", "yml": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }
}

/// 自定义行视图
class FileTreeRowView: NSTableRowView {
    private var isHovered: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var trackingArea: NSTrackingArea?
    
    override var wantsUpdateLayer: Bool { true }
    
    override func updateLayer() {
        layer?.backgroundColor = isHovered ? NSColor.controlBackgroundColor.cgColor : NSColor.clear.cgColor
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let selectionRect = bounds.insetBy(dx: 2, dy: 0)
            NSColor.controlAccentColor.withAlphaComponent(0.2).setFill()
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 4, yRadius: 4)
            path.fill()
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        
        if let area = trackingArea {
            addTrackingArea(area)
        }
        
        if let window = window, let area = trackingArea {
            let mouseLocation = window.mouseLocationOutsideOfEventStream
            let pointInBounds = convert(mouseLocation, from: nil)
            isHovered = bounds.contains(pointInBounds)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        isHovered = false
    }
}

/// NSOutlineView 的 SwiftUI 包装
struct FileTreeView: NSViewRepresentable {
    let rootURL: URL?
    let onSelect: (URL) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let outlineView = NSOutlineView()
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        
        // 先创建并添加列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        column.title = ""
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        outlineView.headerView = nil
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)
        outlineView.rowHeight = 22
        outlineView.indentationPerLevel = 16
        outlineView.floatsGroupRows = false
        
        scrollView.documentView = outlineView
        context.coordinator.outlineView = outlineView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let url = rootURL, context.coordinator.rootNodes.isEmpty {
            context.coordinator.setRootURL(url)
        }
    }
    
    func makeCoordinator() -> FileTreeDataSource {
        let coordinator = FileTreeDataSource()
        coordinator.onSelect = onSelect
        return coordinator
    }
}
