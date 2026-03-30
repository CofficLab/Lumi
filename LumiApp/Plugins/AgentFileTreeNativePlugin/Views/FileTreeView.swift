import AppKit
import SwiftUI

/// 支持在列表层捕获 Enter 键触发行内重命名
@MainActor
final class FileTreeOutlineView: NSOutlineView {
    var onEnterKey: (() -> Void)?
    var onDirectoryClick: ((Any) -> Void)?

    override func keyDown(with event: NSEvent) {
        // Return(36) / Numpad Enter(76)
        if event.keyCode == 36 || event.keyCode == 76 {
            onEnterKey?()
            return
        }
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let row = row(at: location)
        
        if row >= 0,
           let item = item(atRow: row) as? FileNode,
           item.isDirectory {
            // 先调用父类处理选中
            super.mouseDown(with: event)
            
            // 然后调用目录点击回调处理展开/折叠
            // 注意：此时展开状态可能还没更新，需要延迟执行
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let node = item as? FileNode,
                      node.isDirectory else { return }
                
                // 检查当前展开状态并切换
                if self.isItemExpanded(node) {
                    self.collapseItem(node)
                } else {
                    self.expandItem(node)
                }
            }
        } else {
            super.mouseDown(with: event)
        }
    }
}

/// 文件树节点
@MainActor
class FileNode: NSObject {
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [FileNode] = []
    var isLoaded = false

    nonisolated fileprivate static func sortedContents(at url: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
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
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        super.init()
    }
    
    func loadChildren(onLoaded: (() -> Void)? = nil) {
        guard isDirectory && !isLoaded else { return }
        isLoaded = true

        let directoryURL = url
        Task {
            let urls = await Task.detached(priority: .userInitiated) {
                (try? FileNode.sortedContents(at: directoryURL)) ?? []
            }.value
            self.children = urls.map { FileNode(url: $0) }
            onLoaded?()
        }
    }
}

/// NSOutlineView 数据源和代理
@MainActor
class FileTreeDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate, NSTextFieldDelegate {
    var rootNodes: [FileNode] = []
    weak var outlineView: NSOutlineView?
    var onSelect: ((URL) -> Void)?
    var onDelete: ((URL, Bool) -> Void)?
    var onRename: ((URL, String) -> Void)?
    var currentRootURL: URL?
    var externalSelectedFileURL: URL?
    var onExpandedPathsChanged: ((Set<String>) -> Void)?
    private var expandedRelativePaths: Set<String> = []
    private var renamingNodeURL: URL?
    private var pendingSelectionTask: Task<Void, Never>?
    private var pendingSelectRetryTask: Task<Void, Never>?

    var currentOutlineSelectedFileURL: URL? {
        guard let outlineView else { return nil }
        let row = outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? FileNode else { return nil }
        return node.url
    }
    
    func setRootURL(_ url: URL) {
        pendingSelectionTask?.cancel()
        pendingSelectRetryTask?.cancel()
        currentRootURL = url
        Task.detached(priority: .userInitiated) {
            let urls = (try? FileNode.sortedContents(at: url)) ?? []
            await MainActor.run {
                self.rootNodes = urls.map { FileNode(url: $0) }
                self.outlineView?.reloadData()
                self.restoreExpandedNodes()
                self.selectExternalFileIfNeeded()
            }
        }
    }

    func setExpandedRelativePaths(_ paths: Set<String>) {
        expandedRelativePaths = paths
        restoreExpandedNodes()
    }
    
    func selectExternalFileIfNeeded() {
        guard let targetURL = externalSelectedFileURL else { return }
        
        if let node = findNode(for: targetURL) {
            expandParents(for: node)
            selectNodeInOutline(node)
            return
        }

        pendingSelectionTask?.cancel()
        pendingSelectionTask = Task { [weak self] in
            guard let self else { return }
            guard let node = await self.findOrLoadNode(for: targetURL) else { return }
            self.selectNodeInOutline(node)
        }
    }
    
    private func findNode(for url: URL) -> FileNode? {
        for rootNode in rootNodes {
            if rootNode.url == url { return rootNode }
            if let found = findNodeRecursive(parent: rootNode, targetURL: url) { return found }
        }
        return nil
    }
    
    private func findNodeRecursive(parent: FileNode, targetURL: URL) -> FileNode? {
        for child in parent.children {
            if child.url == targetURL { return child }
            if child.isDirectory, let found = findNodeRecursive(parent: child, targetURL: targetURL) { return found }
        }
        return nil
    }
    
    private func expandParents(for node: FileNode) {
        var current: FileNode? = node
        var parents: [FileNode] = []
        while let curr = current {
            if let parent = findParent(of: curr) {
                parents.insert(parent, at: 0)
                current = parent
            } else { break }
        }
        for parent in parents { outlineView?.expandItem(parent) }
    }
    
    private func findParent(of target: FileNode) -> FileNode? {
        for root in rootNodes { if let p = findParentRecursive(parent: root, target: target) { return p } }
        return nil
    }
    
    private func findParentRecursive(parent: FileNode, target: FileNode) -> FileNode? {
        for child in parent.children {
            if child === target { return parent }
            if let found = findParentRecursive(parent: child, target: target) { return found }
        }
        return nil
    }
    
    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? FileNode {
            node.loadChildren { [weak outlineView, weak self] in
                outlineView?.reloadItem(node, reloadChildren: true)
                self?.restoreExpandedNodes()
                self?.selectExternalFileIfNeeded()
            }
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
        
        // 名称（重命名时切为可编辑输入框）
        let textField: NSTextField
        if renamingNodeURL == node.url {
            let editor = NSTextField(string: node.name)
            editor.font = .systemFont(ofSize: 11)
            editor.isBordered = false
            editor.drawsBackground = false
            editor.focusRingType = .none
            editor.lineBreakMode = .byClipping
            editor.setContentHuggingPriority(.defaultLow, for: .horizontal)
            editor.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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
            label.font = .systemFont(ofSize: 11)
            label.textColor = .labelColor
            label.lineBreakMode = .byTruncatingMiddle
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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
        return FileTreeRowView()
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return item is FileNode
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView,
              let node = outlineView.item(atRow: outlineView.selectedRow) as? FileNode else { return }
        
        // 触发选中回调
        onSelect?(node.url)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FileNode else { return }
        guard node.isDirectory else { return }
        guard let relative = relativePath(for: node.url) else { return }

        expandedRelativePaths.insert(relative)
        onExpandedPathsChanged?(expandedRelativePaths)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FileNode else { return }
        guard node.isDirectory else { return }
        guard let relative = relativePath(for: node.url) else { return }

        expandedRelativePaths.remove(relative)
        let prefix = relative + "/"
        expandedRelativePaths = Set(expandedRelativePaths.filter { !$0.hasPrefix(prefix) })
        onExpandedPathsChanged?(expandedRelativePaths)
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
              let node = outlineView.item(atRow: row) as? FileNode else {
            return
        }
        
        // 选中当前行
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)

        let useMenuIcons = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26

        // 在 Finder 中显示
        let revealItem = NSMenuItem(
            title: String(localized: "Show in Finder", table: "AgentNativeFileTree"),
            action: #selector(handleRevealInFinder(_:)),
            keyEquivalent: ""
        )
        revealItem.target = self
        revealItem.representedObject = node
        if useMenuIcons { revealItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil) }
        menu.addItem(revealItem)

        // 在 VS Code 中打开
        let vscodeItem = NSMenuItem(
            title: String(localized: "Open in VS Code", table: "AgentNativeFileTree"),
            action: #selector(handleOpenInVSCode(_:)),
            keyEquivalent: ""
        )
        vscodeItem.target = self
        vscodeItem.representedObject = node
        if useMenuIcons { vscodeItem.image = NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right", accessibilityDescription: nil) }
        menu.addItem(vscodeItem)

        // 在终端中打开
        let terminalItem = NSMenuItem(
            title: String(localized: "Open in Terminal", table: "AgentNativeFileTree"),
            action: #selector(handleOpenInTerminal(_:)),
            keyEquivalent: ""
        )
        terminalItem.target = self
        terminalItem.representedObject = node
        if useMenuIcons { terminalItem.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil) }
        menu.addItem(terminalItem)

        menu.addItem(NSMenuItem.separator())

        // 复制路径
        let copyPathItem = NSMenuItem(
            title: String(localized: "Copy Path", table: "AgentNativeFileTree"),
            action: #selector(handleCopyPath(_:)),
            keyEquivalent: ""
        )
        copyPathItem.target = self
        copyPathItem.representedObject = node
        if useMenuIcons { copyPathItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil) }
        menu.addItem(copyPathItem)

        // 复制相对路径
        let copyRelativePathItem = NSMenuItem(
            title: String(localized: "Copy Relative Path", table: "AgentNativeFileTree"),
            action: #selector(handleCopyRelativePath(_:)),
            keyEquivalent: ""
        )
        copyRelativePathItem.target = self
        copyRelativePathItem.representedObject = node
        if useMenuIcons { copyRelativePathItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil) }
        menu.addItem(copyRelativePathItem)

        menu.addItem(NSMenuItem.separator())

        // 重命名菜单项
        let renameItem = NSMenuItem(
            title: String(localized: "Rename", table: "AgentNativeFileTree"),
            action: #selector(handleRename(_:)),
            keyEquivalent: ""
        )
        renameItem.target = self
        renameItem.representedObject = node
        if useMenuIcons { renameItem.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil) }
        menu.addItem(renameItem)

        menu.addItem(NSMenuItem.separator())

        // 删除菜单项
        let deleteItem = NSMenuItem(
            title: String(localized: "Delete", table: "AgentNativeFileTree"),
            action: #selector(handleDelete(_:)),
            keyEquivalent: ""
        )
        deleteItem.target = self
        deleteItem.representedObject = node
        if useMenuIcons { deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil) }
        menu.addItem(deleteItem)
    }
    
    @objc private func handleDelete(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        
        let alert = NSAlert()
        alert.messageText = String(localized: node.isDirectory ? "Confirm Delete Folder?" : "Confirm Delete File?", table: "AgentNativeFileTree")
        alert.informativeText = String(localized: "Will be deleted", table: "AgentNativeFileTree") + ": \(node.name)\n" + String(localized: "This action cannot be undone", table: "AgentNativeFileTree")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Delete", table: "AgentNativeFileTree"))
        alert.addButton(withTitle: String(localized: "Cancel", table: "AgentNativeFileTree"))
        
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
                        errorAlert.messageText = String(localized: "Delete Failed", table: "AgentNativeFileTree")
                        errorAlert.informativeText = error.localizedDescription
                        errorAlert.alertStyle = .critical
                        errorAlert.runModal()
                    }
                }
            }
        }
    }
    
    @objc private func handleRename(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
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
            let node = outlineView.item(atRow: outlineView.selectedRow) as? FileNode
        else {
            return
        }
        beginInlineRename(for: node)
    }

    private func beginInlineRename(for node: FileNode) {
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
                    errorAlert.messageText = String(localized: "Rename Failed", table: "AgentNativeFileTree")
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

    private func node(for url: URL) -> FileNode? {
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

    
    private func refreshNode(_ oldNode: FileNode, withNewURL newURL: URL) {
        let newNode = FileNode(url: newURL)
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
        guard let node = sender.representedObject as? FileNode else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(node.url.path, forType: .string)
    }
    
    @objc private func handleCopyRelativePath(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        
        // 获取项目根路径
        let rootPath = rootNodes.first?.url.deletingLastPathComponent().path ?? ""
        let fullPath = node.url.path
        
        // 计算相对路径
        let relativePath: String
        if fullPath.hasPrefix(rootPath) {
            let index = fullPath.index(fullPath.startIndex, offsetBy: rootPath.count)
            relativePath = String(fullPath[index...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            relativePath = fullPath
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(relativePath, forType: .string)
    }
    
    @objc private func handleRevealInFinder(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        NSWorkspace.shared.selectFile(node.url.path, inFileViewerRootedAtPath: "")
    }
    
    @objc private func handleOpenInTerminal(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        let targetURL: URL
        if node.isDirectory {
            targetURL = node.url
        } else {
            targetURL = node.url.deletingLastPathComponent()
        }
        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = ["open", "-a", "Terminal", targetURL.path]
        try? process.run()
    }

    @objc private func handleOpenInVSCode(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        let path = node.url.path

        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-b", "com.microsoft.VSCode", path]

        do {
            try task.run()
        } catch {
            // 如果 VS Code 未安装，尝试使用 code 命令
            let codeTask = Process()
            codeTask.launchPath = "/usr/local/bin/code"
            codeTask.arguments = [path]
            
            do {
                try codeTask.run()
            } catch {
                let alert = NSAlert()
                alert.messageText = String(localized: "Cannot Open VS Code", table: "AgentNativeFileTree")
                alert.informativeText = String(localized: "Please ensure VS Code is installed", table: "AgentNativeFileTree")
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
    
    private func findParentNode(of targetNode: FileNode) -> FileNode? {
        for rootNode in rootNodes {
            if let parent = findParentNodeRecursive(parent: rootNode, target: targetNode) {
                return parent
            }
        }
        return nil
    }
    
    private func findParentNodeRecursive(parent: FileNode, target: FileNode) -> FileNode? {
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

    private func restoreExpandedNodes() {
        guard let outlineView else { return }
        guard !expandedRelativePaths.isEmpty else { return }
        guard !rootNodes.isEmpty else { return }

        for node in rootNodes {
            restoreExpansionRecursively(node: node, outlineView: outlineView)
        }
    }

    private func restoreExpansionRecursively(node: FileNode, outlineView: NSOutlineView) {
        guard node.isDirectory else { return }
        guard let relative = relativePath(for: node.url) else { return }
        guard expandedRelativePaths.contains(relative) else { return }

        if !outlineView.isItemExpanded(node) {
            outlineView.expandItem(node)
        }

        node.loadChildren { [weak self, weak outlineView] in
            guard let self, let outlineView else { return }
            outlineView.reloadItem(node, reloadChildren: true)
            for child in node.children {
                self.restoreExpansionRecursively(node: child, outlineView: outlineView)
            }
            self.selectExternalFileIfNeeded()
        }

        if node.isLoaded {
            for child in node.children {
                restoreExpansionRecursively(node: child, outlineView: outlineView)
            }
        }
    }

    private func relativePath(for url: URL) -> String? {
        guard let root = currentRootURL?.standardizedFileURL else { return nil }
        let standardizedURL = url.standardizedFileURL

        let rootPath = root.path
        let targetPath = standardizedURL.path
        guard targetPath.hasPrefix(rootPath) else { return nil }

        let relative = String(targetPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relative.isEmpty ? "." : relative
    }

    private func selectNodeInOutline(_ node: FileNode) {
        guard let outlineView else { return }
        let row = outlineView.row(forItem: node)
        if row >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outlineView.scrollRowToVisible(row)
            return
        }

        pendingSelectRetryTask?.cancel()
        pendingSelectRetryTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                guard let outlineView = self.outlineView else { return }
                let retryRow = outlineView.row(forItem: node)
                if retryRow >= 0 {
                    outlineView.selectRowIndexes(IndexSet(integer: retryRow), byExtendingSelection: false)
                    outlineView.scrollRowToVisible(retryRow)
                    return
                }
                outlineView.reloadData()
            }
        }
    }

    private func findOrLoadNode(for targetURL: URL) async -> FileNode? {
        guard let rootURL = currentRootURL?.standardizedFileURL else { return nil }
        let standardizedTargetURL = targetURL.standardizedFileURL

        let rootPath = rootURL.path
        let targetPath = standardizedTargetURL.path
        guard targetPath == rootPath || targetPath.hasPrefix(rootPath + "/") else { return nil }

        let relative = String(targetPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relative.isEmpty else { return nil }

        let components = relative.split(separator: "/").map(String.init)
        var currentLevel = rootNodes
        var currentNode: FileNode?

        for (index, component) in components.enumerated() {
            guard let nextNode = currentLevel.first(where: { $0.name == component }) else { return nil }
            currentNode = nextNode

            let isLeaf = index == components.count - 1
            if isLeaf {
                return nextNode
            }

            guard nextNode.isDirectory else { return nil }
            await loadChildrenIfNeeded(nextNode)
            outlineView?.reloadItem(nextNode, reloadChildren: true)
            outlineView?.expandItem(nextNode)
            currentLevel = nextNode.children
        }

        return currentNode
    }

    private func loadChildrenIfNeeded(_ node: FileNode) async {
        if node.isLoaded { return }
        await withCheckedContinuation { continuation in
            node.loadChildren {
                continuation.resume()
            }
        }
    }
}

/// 自定义行视图
@MainActor
class FileTreeRowView: NSTableRowView {
    private var isHovered: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var trackingArea: NSTrackingArea?
    
    override var wantsUpdateLayer: Bool { true }
    
    override func updateLayer() {
        let baseColor = isHovered ? NSColor.controlBackgroundColor.withAlphaComponent(0.9) : .clear
        let insetRect = bounds.insetBy(dx: 4, dy: 0)
        let path = NSBezierPath(roundedRect: insetRect, xRadius: 4, yRadius: 4)

        // 手动绘制窄一些的 hover 背景，避免铺满整列
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        baseColor.setFill()
        path.fill()
        image.unlockFocus()

        layer?.contents = image
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let selectionRect = bounds.insetBy(dx: 4, dy: 1)
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

/// NSOutlineView 的 SwiftUI 包装
struct FileTreeView: NSViewRepresentable {
    let rootURL: URL?
    let selectedFileURL: URL?
    let expandedRelativePaths: Set<String>
    let onSelect: (URL) -> Void
    let onExpandedPathsChanged: (Set<String>) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let outlineView = FileTreeOutlineView()
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.onEnterKey = { [weak coordinator = context.coordinator] in
            coordinator?.beginInlineRenameForSelectedRow()
        }
        
        // 目录点击处理
        outlineView.onDirectoryClick = { [weak coordinator = context.coordinator] item in
            guard let coordinator,
                  let node = item as? FileNode,
                  node.isDirectory else { return }
            
            // 切换展开/折叠
            if coordinator.outlineView?.isItemExpanded(node) == true {
                coordinator.outlineView?.collapseItem(node)
            } else {
                coordinator.outlineView?.expandItem(node)
            }
        }
        
        // 启用右键菜单
        let menu = NSMenu()
        menu.delegate = context.coordinator
        outlineView.menu = menu
        
        // 先创建并添加列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        column.title = ""
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.autoresizesOutlineColumn = true
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outlineView.sizeLastColumnToFit()
        
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
        if let outlineView = nsView.documentView as? NSOutlineView {
            outlineView.sizeLastColumnToFit()
        }
        if let url = rootURL, context.coordinator.currentRootURL?.standardizedFileURL != url.standardizedFileURL {
            context.coordinator.setRootURL(url)
        }
        if let selectedURL = selectedFileURL {
            let currentSelected = context.coordinator.externalSelectedFileURL
            if currentSelected?.standardizedFileURL != selectedURL.standardizedFileURL {
                context.coordinator.externalSelectedFileURL = selectedURL
            }
            let outlineSelected = context.coordinator.currentOutlineSelectedFileURL
            if outlineSelected?.standardizedFileURL != selectedURL.standardizedFileURL {
                context.coordinator.selectExternalFileIfNeeded()
            }
        }
        context.coordinator.setExpandedRelativePaths(expandedRelativePaths)
    }
    
    func makeCoordinator() -> FileTreeDataSource {
        let coordinator = FileTreeDataSource()
        coordinator.onSelect = onSelect
        coordinator.onExpandedPathsChanged = onExpandedPathsChanged
        return coordinator
    }
}
