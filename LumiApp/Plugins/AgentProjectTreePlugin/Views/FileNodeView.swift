import AppKit
import SwiftUI

/// 自定义行视图（仅用于 ProjectTree 插件）
@MainActor
final class ProjectFileTreeRowView: NSTableRowView {
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

        if let window = window {
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

/// 支持在列表层捕获 Enter 键触发行内重命名
@MainActor
final class ProjectFileTreeOutlineView: NSOutlineView {
    var onEnterKey: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // Return(36) / Numpad Enter(76)
        if event.keyCode == 36 || event.keyCode == 76 {
            onEnterKey?()
            return
        }
        super.keyDown(with: event)
    }
}

/// 项目文件树中的单个节点模型
/// 包含文件/文件夹的基本信息以及懒加载的子节点
@MainActor
final class ProjectFileNode: NSObject {
    /// 节点对应的文件或文件夹 URL
    let url: URL

    /// 展示名称（文件名或文件夹名）
    let name: String

    /// 是否为目录
    let isDirectory: Bool

    /// 子节点集合，仅在需要时加载
    var children: [ProjectFileNode] = []

    /// 是否已经完成子节点加载
    var isLoaded = false

    /// 获取指定目录下的内容，并按「文件夹在前，名称升序」排序
    nonisolated static func sortedContents(at url: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return contents.sorted { a, b in
            let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if aIsDir == bIsDir {
                return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
            }
            return aIsDir
        }
    }

    /// 使用文件 URL 初始化节点
    /// - Parameter url: 节点对应的文件或目录 URL
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        super.init()
    }

    /// 懒加载子节点，仅在目录首次展开时触发
    /// - Parameter onLoaded: 加载完成后的回调，用于刷新 UI
    func loadChildren(onLoaded: (() -> Void)? = nil) {
        guard isDirectory && !isLoaded else { return }
        isLoaded = true

        let directoryURL = url
        Task {
            let urls = await Task.detached(priority: .userInitiated) {
                (try? ProjectFileNode.sortedContents(at: directoryURL)) ?? []
            }.value
            self.children = urls.map { ProjectFileNode(url: $0) }
            onLoaded?()
        }
    }
}

/// NSOutlineView 数据源和代理
@MainActor
final class ProjectFileTreeDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate, NSTextFieldDelegate {
    var rootNodes: [ProjectFileNode] = []
    weak var outlineView: NSOutlineView?
    var onSelect: ((URL) -> Void)?
    var onDelete: ((URL, Bool) -> Void)?
    var onRename: ((URL, String) -> Void)?
    var currentRootURL: URL?
    private var renamingNodeURL: URL?

    func setRootURL(_ url: URL) {
        currentRootURL = url
        Task.detached(priority: .userInitiated) {
            let urls = (try? ProjectFileNode.sortedContents(at: url)) ?? []
            await MainActor.run {
                self.rootNodes = urls.map { ProjectFileNode(url: $0) }
                self.outlineView?.reloadData()
            }
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? ProjectFileNode {
            node.loadChildren { [weak outlineView] in
                outlineView?.reloadItem(node, reloadChildren: true)
            }
            return node.children.count
        }
        return rootNodes.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? ProjectFileNode {
            return node.children[index]
        }
        return rootNodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? ProjectFileNode else { return false }
        return node.isDirectory
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let node = item as? ProjectFileNode else { return nil }

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(node.url.path, forType: .string)
        pasteboardItem.setString(node.url.path, forType: .fileURL)
        return pasteboardItem
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? ProjectFileNode else { return nil }

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

        // 名称（重命名时切为可编辑输入框）
        let textField: NSTextField
        if renamingNodeURL == node.url {
            let editor = NSTextField(string: node.name)
            editor.font = NSFont.systemFont(ofSize: 11)
            editor.isBordered = false
            editor.drawsBackground = false
            editor.focusRingType = .none
            editor.lineBreakMode = .byClipping
            editor.setContentHuggingPriority(NSLayoutConstraint.Priority.defaultLow, for: .horizontal)
            editor.setContentCompressionResistancePriority(NSLayoutConstraint.Priority.defaultLow, for: .horizontal)
            editor.delegate = self
            editor.target = self
            editor.action = #selector(handleRenameTextFieldAction(_:))
            textField = editor
            cell.textField = editor

            DispatchQueue.main.async { [weak self, weak outlineView, weak editor] in
                guard
                    let self,
                    let outlineView,
                    let editor,
                    self.renamingNodeURL == node.url
                else { return }

                outlineView.window?.makeFirstResponder(editor)
                if let fieldEditor = editor.currentEditor() {
                    fieldEditor.selectedRange = NSRange(location: 0, length: (editor.stringValue as NSString).length)
                }
            }
        } else {
            let label = NSTextField(labelWithString: node.name)
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = NSColor.labelColor
            label.lineBreakMode = .byTruncatingMiddle
            label.setContentHuggingPriority(NSLayoutConstraint.Priority.defaultLow, for: .horizontal)
            label.setContentCompressionResistancePriority(NSLayoutConstraint.Priority.defaultLow, for: .horizontal)
            textField = label
            cell.textField = label
        }
        stack.addArrangedSubview(textField)

        cell.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return ProjectFileTreeRowView()
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        item is ProjectFileNode
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView,
              let node = outlineView.item(atRow: outlineView.selectedRow) as? ProjectFileNode else { return }

        if !node.isDirectory {
            onSelect?(node.url)
        }
    }

    // MARK: - 右键菜单

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        guard let outlineView = outlineView,
              let event = NSApp.currentEvent,
              event.type == .rightMouseDown || event.type == .rightMouseUp || event.type == .leftMouseDown else {
            return
        }

        // 转换坐标到 outlineView
        let point = outlineView.convert(event.locationInWindow, from: nil)
        let row = outlineView.row(at: point)

        guard row >= 0,
              let node = outlineView.item(atRow: row) as? ProjectFileNode else {
            return
        }

        // 选中当前行
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)

        // 在 Finder 中显示
        let revealItem = NSMenuItem(
            title: "在 Finder 中显示",
            action: #selector(handleRevealInFinder(_:)),
            keyEquivalent: ""
        )
        revealItem.target = self
        revealItem.representedObject = node
        revealItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        menu.addItem(revealItem)

        // 复制路径
        let copyPathItem = NSMenuItem(
            title: "复制路径",
            action: #selector(handleCopyPath(_:)),
            keyEquivalent: ""
        )
        copyPathItem.target = self
        copyPathItem.representedObject = node
        menu.addItem(copyPathItem)

        menu.addItem(NSMenuItem.separator())

        // 重命名菜单项
        let renameItem = NSMenuItem(
            title: "重命名",
            action: #selector(handleRename(_:)),
            keyEquivalent: ""
        )
        renameItem.target = self
        renameItem.representedObject = node
        renameItem.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        menu.addItem(renameItem)
    }

    @objc private func handleDelete(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? ProjectFileNode else { return }

        let alert = NSAlert()
        alert.messageText = node.isDirectory ? "确认删除文件夹？" : "确认删除文件？"
        alert.informativeText = "即将删除: \(node.name)\n此操作不可撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Task.detached(priority: .userInitiated) {
                do {
                    try FileManager.default.removeItem(at: node.url)
                    await MainActor.run {
                        self.onDelete?(node.url, node.isDirectory)

                        // 刷新数据
                        if let parent = self.findParentNode(of: node) {
                            parent.children.removeAll { $0 === node }
                            self.outlineView?.reloadItem(parent, reloadChildren: true)
                        } else {
                            self.rootNodes.removeAll { $0 === node }
                            self.outlineView?.reloadData()
                        }
                    }
                } catch {
                    await MainActor.run {
                        let errorAlert = NSAlert()
                        errorAlert.messageText = "删除失败"
                        errorAlert.informativeText = error.localizedDescription
                        errorAlert.alertStyle = .critical
                        errorAlert.runModal()
                    }
                }
            }
        }
    }

    @objc private func handleRename(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? ProjectFileNode else { return }
        beginInlineRename(for: node)
    }

    @objc private func handleRenameTextFieldAction(_ sender: NSTextField) {
        commitInlineRename(newName: sender.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelInlineRename()
            return true
        }
        return false
    }

    func beginInlineRenameForSelectedRow() {
        guard
            let outlineView,
            outlineView.selectedRow >= 0,
            let node = outlineView.item(atRow: outlineView.selectedRow) as? ProjectFileNode
        else {
            return
        }
        beginInlineRename(for: node)
    }

    private func beginInlineRename(for node: ProjectFileNode) {
        renamingNodeURL = node.url
        guard let outlineView else { return }

        let row = outlineView.row(forItem: node)
        if row >= 0 {
            outlineView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
        } else {
            outlineView.reloadData()
        }
    }

    private func cancelInlineRename() {
        guard let currentURL = renamingNodeURL else { return }
        renamingNodeURL = nil
        reloadRow(for: currentURL)
    }

    private func commitInlineRename(newName rawName: String) {
        guard let currentURL = renamingNodeURL else { return }
        let newName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        renamingNodeURL = nil

        guard let node = node(for: currentURL) else {
            outlineView?.reloadData()
            return
        }

        guard !newName.isEmpty, newName != node.name else {
            reloadRow(for: currentURL)
            return
        }

        let newURL = node.url.deletingLastPathComponent().appendingPathComponent(newName)
        Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.moveItem(at: node.url, to: newURL)
                await MainActor.run {
                    self.onRename?(newURL, newName)
                    self.refreshNode(node, withNewURL: newURL)
                }
            } catch {
                await MainActor.run {
                    self.reloadRow(for: currentURL)
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "重命名失败"
                    errorAlert.informativeText = error.localizedDescription
                    errorAlert.alertStyle = .critical
                    errorAlert.runModal()
                }
            }
        }
    }

    private func reloadRow(for nodeURL: URL) {
        guard let outlineView, let node = node(for: nodeURL) else {
            outlineView?.reloadData()
            return
        }
        let row = outlineView.row(forItem: node)
        if row >= 0 {
            outlineView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
        } else {
            outlineView.reloadData()
        }
    }

    private func node(for url: URL) -> ProjectFileNode? {
        for rootNode in rootNodes {
            if rootNode.url == url {
                return rootNode
            }
            if let found = findNodeRecursive(parent: rootNode, targetURL: url) {
                return found
            }
        }
        return nil
    }

    private func findNodeRecursive(parent: ProjectFileNode, targetURL: URL) -> ProjectFileNode? {
        for child in parent.children {
            if child.url == targetURL {
                return child
            }
            if let found = findNodeRecursive(parent: child, targetURL: targetURL) {
                return found
            }
        }
        return nil
    }

    private func refreshNode(_ oldNode: ProjectFileNode, withNewURL newURL: URL) {
        let newNode = ProjectFileNode(url: newURL)
        newNode.isLoaded = oldNode.isLoaded
        newNode.children = oldNode.children

        if let parent = findParentNode(of: oldNode) {
            if let index = parent.children.firstIndex(where: { $0 === oldNode }) {
                parent.children[index] = newNode
            }
            outlineView?.reloadItem(parent, reloadChildren: true)
        } else {
            if let index = rootNodes.firstIndex(where: { $0 === oldNode }) {
                rootNodes[index] = newNode
            }
            outlineView?.reloadData()
        }

        // 重命名后保持选中项
        if let outlineView {
            let row = outlineView.row(forItem: newNode)
            guard row >= 0 else { return }
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }

    // MARK: - 菜单动作

    @objc private func handleCopyPath(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? ProjectFileNode else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(node.url.path, forType: .string)
    }

    @objc private func handleRevealInFinder(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? ProjectFileNode else { return }
        NSWorkspace.shared.selectFile(node.url.path, inFileViewerRootedAtPath: "")
    }

    private func findParentNode(of targetNode: ProjectFileNode) -> ProjectFileNode? {
        for rootNode in rootNodes {
            if let parent = findParentNodeRecursive(parent: rootNode, target: targetNode) {
                return parent
            }
        }
        return nil
    }

    private func findParentNodeRecursive(parent: ProjectFileNode, target: ProjectFileNode) -> ProjectFileNode? {
        for child in parent.children {
            if child === target {
                return parent
            }
            if let found = findParentNodeRecursive(parent: child, target: target) {
                return found
            }
        }
        return nil
    }

    private func iconName(for node: ProjectFileNode) -> String {
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


/// NSOutlineView 的 SwiftUI 包装（项目文件树）
struct ProjectFileTreeView: NSViewRepresentable {
    let rootURL: URL?
    let onSelect: (URL) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let outlineView = ProjectFileTreeOutlineView()
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.onEnterKey = { [weak coordinator = context.coordinator] in
            coordinator?.beginInlineRenameForSelectedRow()
        }

        // 启用右键菜单
        let menu = NSMenu()
        menu.delegate = context.coordinator
        outlineView.menu = menu

        // 列配置
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        column.title = ""
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        outlineView.headerView = nil
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)
        outlineView.rowHeight = 22
        outlineView.indentationPerLevel = 16
        outlineView.floatsGroupRows = false
        outlineView.allowsEmptySelection = true

        scrollView.documentView = outlineView
        context.coordinator.outlineView = outlineView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let url = rootURL, context.coordinator.currentRootURL?.standardizedFileURL != url.standardizedFileURL {
            context.coordinator.setRootURL(url)
        }
    }

    func makeCoordinator() -> ProjectFileTreeDataSource {
        let coordinator = ProjectFileTreeDataSource()
        coordinator.onSelect = onSelect
        return coordinator
    }
}

