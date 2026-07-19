import AppKit
import SwiftUI
import LumiKernel
import LumiUI
import MagicAlert
import SuperLogKit

/// 文件树集合视图控制器
///
/// 使用 NSCollectionView 实现高性能文件树渲染。
@MainActor
final class FileTreeCollectionViewController: NSViewController, SuperLog {
    nonisolated static let emoji = "📂"
    nonisolated static var verbose: Bool { EditorFileTreeV2Plugin.verbose }
    nonisolated static let logger = EditorFileTreeV2Plugin.logger

    private let collectionView: NSCollectionView = {
        let cv = NSCollectionView()
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.isSelectable = true
        cv.allowsMultipleSelection = false
        cv.backgroundColors = [.clear]
        return cv
    }()

    private var dataSource: FileTreeDiffableDataSource!
    private let fileTreeDataSource = FileTreeDataSource()
    private var selectionState = SelectionState()
    private var hoveredItemURL: URL?
    private var trackingArea: NSTrackingArea?
    private let theme: any LumiAppChromeTheme = LumiFallbackChromeTheme()

    /// 文件选择回调
    var onSelect: ((URL) -> Void)?

    /// 展开状态变化回调
    var onExpansionChange: ((String, Bool) -> Void)?

    /// 树结构变化回调
    var onTreeMutation: (() -> Void)?

    /// 删除文件后关闭对应编辑器 tab 的回调
    var onCloseEditorTabs: (([URL]) -> Void)?

    /// 重命名文件后迁移编辑器 tab 的回调（旧 URL → 新 URL）
    var onRenameEditorTab: ((URL, URL) -> Void)?

    /// 将文件加入对话的回调
    var onAddToConversation: (([URL]) -> Void)?

    /// 中键点击预览回调
    var onMiddleClick: ((URL) -> Void)?

    /// Git 状态快照
    var gitStatusSnapshot: GitStatusSnapshot = .empty

    /// 闪烁高亮不透明度（由外部通过 triggerFlash 设置）
    private var flashItemURL: URL?
    private var flashOpacity: Double = 0

    private static let cellIdentifier = NSUserInterfaceItemIdentifier("FileTreeNodeCellView")
    private static let packageCellIdentifier = NSUserInterfaceItemIdentifier("PackageDependencyNodeCellView")

    /// viewDidLoad 之前预存的根路径
    private var pendingProjectRoot: String?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupDataSource()
        setupBindings()
        setupTrackingArea()
        if Self.verbose {
            Self.logger.info("\(Self.t)视图加载完成")
        }

        // bindings 就绪后再加载数据
        if let path = pendingProjectRoot, !path.isEmpty {
            if Self.verbose {
                Self.logger.info("\(Self.t)延迟加载项目：\(path)")
            }
            fileTreeDataSource.setProjectRoot(path)
            pendingProjectRoot = nil
        }
    }

    private func setupCollectionView() {
        let layout = Self.makeLayout()
        collectionView.collectionViewLayout = layout

        // 注册 cell 类以启用复用池
        collectionView.register(FileTreeNodeCell.self, forItemWithIdentifier: Self.cellIdentifier)
        collectionView.register(PackageDependencyNodeCell.self, forItemWithIdentifier: Self.packageCellIdentifier)

        // NSCollectionView 必须放在 NSScrollView 中才能滚动
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = collectionView

        view.addSubview(scrollView)

        // 启用拖放：支持文件 URL 拖出到输入框等目标，以及拖入目录 cell 移动文件
        collectionView.registerForDraggedTypes([.fileURL])

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupDataSource() {
        dataSource = FileTreeDiffableDataSource(collectionView: collectionView) { [weak self] _, indexPath, item in
            guard let self = self else { return nil }

            switch item {
            case .file(let fileItem):
                let cell = self.collectionView.makeItem(
                    withIdentifier: Self.cellIdentifier,
                    for: indexPath
                ) as? FileTreeNodeCell ?? FileTreeNodeCell()

                let isSelected = self.selectionState.isSelected(fileItem.url)
                let isHovered = self.hoveredItemURL == fileItem.url
                let gitStatus = self.gitStatus(for: fileItem.url)
                let itemFlashOpacity: Double = (self.flashItemURL == fileItem.url) ? self.flashOpacity : 0

                cell.configure(
                    with: fileItem,
                    isSelected: isSelected,
                    isHovered: isHovered,
                    gitStatus: gitStatus,
                    theme: self.theme,
                    flashOpacity: itemFlashOpacity
                )

                return cell

            case .packageHeader, .packageDependency:
                let cell = self.collectionView.makeItem(
                    withIdentifier: Self.packageCellIdentifier,
                    for: indexPath
                ) as? PackageDependencyNodeCell ?? PackageDependencyNodeCell()

                cell.configure(
                    with: item,
                    isSelected: false,
                    isHovered: false,
                    theme: self.theme
                )

                return cell
            }
        }

        collectionView.delegate = self
        collectionView.dataSource = dataSource
    }

    private func setupBindings() {
        fileTreeDataSource.onItemsChanged = { [weak self] items in
            guard let self = self else { return }

            var snapshot = NSDiffableDataSourceSnapshot<Section, CollectionItem>()
            snapshot.appendSections([.main])
            snapshot.appendItems(items, toSection: .main)

            self.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }

    private func setupTrackingArea() {
        trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        if let trackingArea = trackingArea {
            view.addTrackingArea(trackingArea)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = collectionView.convert(event.locationInWindow, from: nil)

        var hitURL: URL?
        for indexPath in collectionView.indexPathsForVisibleItems() {
            guard let item = dataSource.itemIdentifier(for: indexPath),
                  let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else {
                continue
            }
            if frame.contains(point) {
                if case .file(let fileItem) = item {
                    hitURL = fileItem.url
                }
                break
            }
        }

        if hitURL == hoveredItemURL { return }
        hoveredItemURL = hitURL

        syncHoverState(hitURL: hitURL)
    }

    override func mouseExited(with event: NSEvent) {
        guard hoveredItemURL != nil else { return }
        hoveredItemURL = nil
        syncHoverState(hitURL: nil)
    }

    private func syncHoverState(hitURL: URL?) {
        for cell in collectionView.visibleItems() {
            guard let indexPath = collectionView.indexPath(for: cell) else { continue }
            guard let item = dataSource.itemIdentifier(for: indexPath) else { continue }

            switch (cell, item) {
            case (let fileCell as FileTreeNodeCell, .file(let fileItem)):
                fileCell.updateHovered(fileItem.url == hitURL)
            case (let packageCell as PackageDependencyNodeCell, _):
                packageCell.updateHovered(false)
            default:
                break
            }
        }
    }

    // MARK: - Public API

    func setProjectRoot(_ path: String) {
        if isViewLoaded {
            if Self.verbose {
                Self.logger.info("\(Self.t)设置项目根路径：\(path)")
            }
            fileTreeDataSource.setProjectRoot(path)
        } else {
            pendingProjectRoot = path
            if Self.verbose {
                Self.logger.info("\(Self.t)预存项目路径（待 viewDidLoad 后加载）：\(path)")
            }
        }
    }

    func setPackageDependencies(_ dependencies: [PackageDependency]) {
        fileTreeDataSource.setPackageDependencies(dependencies)
    }

    func reloadDirectory(at url: URL) {
        fileTreeDataSource.reloadDirectory(at: url)
    }

    func fullRefresh() {
        fileTreeDataSource.fullRefresh()
    }

    func updateGitStatus(_ snapshot: GitStatusSnapshot) {
        gitStatusSnapshot = snapshot
        reloadVisibleItems()
    }

    func triggerFlash(path: String) {
        guard EditorFileTreeV2Plugin.flashHighlightEnabled else { return }
        let targetURL = URL(fileURLWithPath: path)
        flashItemURL = targetURL
        flashOpacity = 0.25
        reloadVisibleItems()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(0.6 * 1_000_000_000))
            flashOpacity = 0
            reloadVisibleItems()
            try? await Task.sleep(nanoseconds: UInt64(0.4 * 1_000_000_000))
            flashItemURL = nil
            flashOpacity = 0
        }
    }

    private func reloadVisibleItems() {
        let visibleItems = collectionView.indexPathsForVisibleItems()
        guard !visibleItems.isEmpty else { return }
        collectionView.reloadItems(at: Set(visibleItems))
    }

    private func gitStatus(for url: URL) -> GitStatus? {
        guard !gitStatusSnapshot.isEmpty,
              !gitStatusSnapshot.repoRootPath.isEmpty else { return nil }
        let repoRoot = gitStatusSnapshot.repoRootPath
        let path = url.path
        guard path.hasPrefix(repoRoot) else { return nil }
        let relativePath = path.dropFirst(repoRoot.count)
            .trimmingCharacters(in: ["/"])
        return gitStatusSnapshot.statusForPath(relativePath)
            ?? gitStatusSnapshot.aggregateStatusForDirectory(relativePath)
    }

    func getProjectRootPath() -> String {
        return fileTreeDataSource.projectRootPath
    }

    // MARK: - Layout

    static func makeLayout() -> NSCollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(24)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(24)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 0

        let layout = NSCollectionViewCompositionalLayout(section: section)
        return layout
    }
}

// MARK: - NSCollectionViewDelegate

extension FileTreeCollectionViewController: NSCollectionViewDelegate {

    func collectionView(
        _ collectionView: NSCollectionView,
        didSelectItemsAt indexPaths: Set<IndexPath>
    ) {
        guard let indexPath = indexPaths.first,
              let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        // 只处理 file 类型的点击
        guard case .file(let fileItem) = item else {
            collectionView.deselectItems(at: indexPaths)
            return
        }

        let modifiers = ModifierFlags.currentClick

        selectionState.handleTap(
            url: fileItem.url,
            isDirectory: fileItem.isDirectory,
            modifiers: modifiers,
            onOpenFile: {
                self.onSelect?(fileItem.url)
            },
            onToggleExpand: {
                self.fileTreeDataSource.toggleExpansion(at: fileItem.url)
                let relativePath = PathFormatter.expansionPath(
                    for: fileItem.url,
                    projectRootPath: fileItem.projectRootPath
                )
                self.onExpansionChange?(relativePath, !fileItem.isExpanded)
            }
        )

        // 刷新所有可见 cell 以同步选中状态（避免上一个选中项的高亮残留）
        reloadVisibleItems()
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        menuForItemsAt indexPaths: Set<IndexPath>
    ) -> NSMenu? {
        guard let indexPath = indexPaths.first,
              let item = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }

        guard case .file(let fileItem) = item else {
            return nil
        }

        return buildMenu(for: fileItem.url, isDirectory: fileItem.isDirectory)
    }

    func menuForItem(atWindowLocation location: NSPoint) -> NSMenu? {
        let point = collectionView.convert(location, from: nil)
        for indexPath in collectionView.indexPathsForVisibleItems() {
            guard let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else {
                continue
            }
            if frame.contains(point) {
                guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
                if case .file(let fileItem) = item {
                    return buildMenu(for: fileItem.url, isDirectory: fileItem.isDirectory)
                }
                return nil
            }
        }
        return nil
    }

    private func buildMenu(for url: URL, isDirectory: Bool) -> NSMenu {
        let menu = NSMenu()

        if isDirectory {
            menu.addItem(menuItem(
                title: LumiPluginLocalization.string("New File", bundle: .module),
                action: #selector(newFile(_:)),
                url: url
            ))
            menu.addItem(menuItem(
                title: LumiPluginLocalization.string("New Folder", bundle: .module),
                action: #selector(newFolder(_:)),
                url: url
            ))
            menu.addItem(.separator())
        }

        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Rename", bundle: .module),
            action: #selector(renameItem(_:)),
            url: url
        ))
        menu.addItem(.separator())

        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Add to Conversation", bundle: .module),
            action: #selector(addToConversation(_:)),
            url: url
        ))

        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Reveal in Finder", bundle: .module),
            action: #selector(revealInFinder(_:)),
            url: url
        ))
        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Open in VS Code", bundle: .module),
            action: #selector(openInVSCode(_:)),
            url: url
        ))
        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Open in Terminal", bundle: .module),
            action: #selector(openInTerminal(_:)),
            url: url
        ))
        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Copy Path", bundle: .module),
            action: #selector(copyPath(_:)),
            url: url
        ))

        menu.addItem(.separator())

        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Move to Trash", bundle: .module),
            action: #selector(deleteItem(_:)),
            url: url
        ))

        return menu
    }

    private func menuItem(title: String, action: Selector, url: URL) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.representedObject = url
        item.target = self
        return item
    }

    // MARK: - Menu Actions

    @objc private func newFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        guard let name = FileTreeActions.presentNamePrompt(
            title: LumiPluginLocalization.string("New File", bundle: .module),
            message: LumiPluginLocalization.string("Enter the name for the new file.", bundle: .module),
            defaultName: "",
            confirmButton: LumiPluginLocalization.string("Create", bundle: .module)
        ) else { return }

        guard let newURL = FileTreeFacade.createFile(in: url, name: name) else {
            alert_error(LumiPluginLocalization.string(
                "Could not create the file. The name may be invalid or a file with that name already exists.",
                bundle: .module
            ))
            return
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)创建文件：\(newURL.path)")
        }
        ensureDirectoryExpanded(url)
        refreshAfterMutation(parentURL: url)
        alert_success(LumiPluginLocalization.string("New File", bundle: .module),
                      subtitle: name)
    }

    @objc private func newFolder(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        guard let name = FileTreeActions.presentNamePrompt(
            title: LumiPluginLocalization.string("New Folder", bundle: .module),
            message: LumiPluginLocalization.string("Enter the name for the new folder.", bundle: .module),
            defaultName: "",
            confirmButton: LumiPluginLocalization.string("Create", bundle: .module)
        ) else { return }

        guard let newURL = FileTreeFacade.createFolder(in: url, name: name) else {
            alert_error(LumiPluginLocalization.string(
                "Could not create the folder. The name may be invalid or a folder with that name already exists.",
                bundle: .module
            ))
            return
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)创建文件夹：\(newURL.path)")
        }
        ensureDirectoryExpanded(url)
        refreshAfterMutation(parentURL: url)
        alert_success(LumiPluginLocalization.string("New Folder", bundle: .module),
                      subtitle: name)
    }

    @objc private func renameItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        guard let newName = FileTreeActions.presentNamePrompt(
            title: LumiPluginLocalization.string("Rename", bundle: .module),
            message: LumiPluginLocalization.string("Enter the new name for this item.", bundle: .module),
            defaultName: url.lastPathComponent,
            confirmButton: LumiPluginLocalization.string("Rename", bundle: .module)
        ) else { return }

        guard newName != url.lastPathComponent else { return }

        guard let newURL = FileTreeFacade.renameItem(at: url, newName: newName) else {
            alert_error(LumiPluginLocalization.string(
                "Could not rename the item. The name may be invalid or an item with that name already exists.",
                bundle: .module
            ))
            return
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)重命名: \(url.lastPathComponent) → \(newURL.lastPathComponent)")
        }
        onRenameEditorTab?(url, newURL)
        refreshAfterMutation(parentURL: newURL.deletingLastPathComponent())
        alert_success(LumiPluginLocalization.string("Rename", bundle: .module),
                      subtitle: "\(url.lastPathComponent) → \(newURL.lastPathComponent)")
    }

    @objc private func deleteItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        guard FileTreeActions.presentDeleteConfirmation(url: url) else { return }

        guard FileTreeFacade.trashItem(at: url) else {
            alert_error(LumiPluginLocalization.string(
                "Could not move the item to the Trash.", bundle: .module
            ))
            return
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)删除: \(url.path)")
        }
        onCloseEditorTabs?([url])
        selectionState.clearSelection()
        refreshAfterMutation(parentURL: url.deletingLastPathComponent())
        alert_success(LumiPluginLocalization.string("Moved to Trash", bundle: .module),
                      subtitle: url.lastPathComponent)
    }

    @objc private func revealInFinder(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        FileTreeFacade.openInFinder(url)
    }

    @objc private func openInVSCode(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        FileTreeFacade.openInVSCode(url)
    }

    @objc private func openInTerminal(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        FileTreeFacade.openInTerminal(url)
    }

    @objc private func copyPath(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        FileTreeFacade.copyPath(url)
        alert_success(LumiPluginLocalization.string("Path copied to clipboard", bundle: .module),
                      subtitle: url.lastPathComponent)
    }

    @objc private func addToConversation(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        onAddToConversation?([url])
        alert_success(LumiPluginLocalization.string("Added to Conversation", bundle: .module),
                      subtitle: url.lastPathComponent)
    }

    // MARK: - File Operation Helpers

    private func ensureDirectoryExpanded(_ url: URL) {
        guard let item = fileTreeDataSource.items.first(where: {
            if case .file(let fileItem) = $0, fileItem.url == url { return true }
            return false
        }), case .file(let fileItem) = item,
              fileItem.isDirectory, !fileItem.isExpanded else { return }
        fileTreeDataSource.toggleExpansion(at: url)
        let relativePath = PathFormatter.expansionPath(
            for: url, projectRootPath: fileTreeDataSource.projectRootPath
        )
        onExpansionChange?(relativePath, true)
    }

    private func refreshAfterMutation(parentURL: URL) {
        onTreeMutation?()
        fileTreeDataSource.reloadDirectory(at: parentURL)
    }

    // MARK: - Drag & Drop

    func handleDropFiles(targetURL: URL, sourceURLs: [URL]) -> Bool {
        let result = FileTreeDropProcessor.process(
            enabled: EditorFileTreeV2Plugin.dragAndDropEnabled,
            targetURL: targetURL,
            sourceURLs: sourceURLs,
            isTargetDirectory: FileTreeFacade.isDirectory,
            moveItem: { FileTreeFacade.moveItem(from: $0, to: $1) }
        )

        switch result {
        case .rejected:
            return false
        case .moved(let pairs, let affectedParents):
            for (old, new) in pairs {
                onRenameEditorTab?(old, new)
            }

            onTreeMutation?()

            for parent in affectedParents {
                fileTreeDataSource.reloadDirectory(at: parent)
            }

            ensureDirectoryExpanded(targetURL)
            return true
        }
    }

    // MARK: - Drag & Drop (Source)

    func collectionView(
        _ collectionView: NSCollectionView,
        pasteboardWriterForItemAt item: NSCollectionViewItem
    ) -> NSPasteboardWriting? {
        guard let indexPath = collectionView.indexPath(for: item),
              let collectionItem = dataSource.itemIdentifier(for: indexPath),
              case .file(let fileItem) = collectionItem else {
            return nil
        }
        return NSURL(fileURLWithPath: fileItem.url.path) as NSURL
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        validateDrop draggingInfo: NSDraggingInfo,
        proposedIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation {
        let indexPath = proposedIndexPath.pointee as IndexPath
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case .file(let fileItem) = item,
              fileItem.isDirectory else {
            return []
        }
        proposedDropOperation.pointee = .on
        return .move
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        acceptDrop draggingInfo: NSDraggingInfo,
        index: Int,
        dropOperation: NSCollectionView.DropOperation
    ) -> Bool {
        let indexPath = IndexPath(item: index, section: 0)
        let pasteboard = draggingInfo.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty else { return false }

        guard let targetItem = dataSource.itemIdentifier(for: indexPath),
              case .file(let targetFile) = targetItem,
              targetFile.isDirectory else { return false }

        return handleDropFiles(targetURL: targetFile.url, sourceURLs: urls)
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        draggingItemsFor indexPaths: [IndexPath]
    ) -> [NSDraggingItem] {
        indexPaths.compactMap { indexPath -> NSDraggingItem? in
            guard let item = dataSource.itemIdentifier(for: indexPath),
                  case .file(let fileItem) = item else { return nil }

            let draggingItem = NSDraggingItem(
                pasteboardWriter: NSURL(fileURLWithPath: fileItem.url.path) as NSURL
            )

            let preview = NSHostingView(
                rootView: FileTreeDragPreview(fileURL: fileItem.url, isDirectory: fileItem.isDirectory)
            )
            draggingItem.setDraggingFrame(preview.bounds, contents: preview)

            return draggingItem
        }
    }
}

// MARK: - NSCollectionViewDataSource

extension FileTreeCollectionViewController: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return dataSource.snapshot().numberOfItems
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        return dataSource.collectionView(collectionView, itemForRepresentedObjectAt: indexPath)
    }
}
