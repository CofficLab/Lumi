import AppKit
import SwiftUI
import EditorFileTreePlugin
import LumiCoreKit
import LumiUI
import MagicAlert
import SuperLogKit

/// 文件树集合视图控制器
///
/// 使用 NSCollectionView 实现高性能文件树渲染。
@MainActor
final class FileTreeCollectionViewController: NSViewController, SuperLog {
    nonisolated static let emoji = "📂"

    
    private let collectionView: NSCollectionView = {
        let cv = NSCollectionView()
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.isSelectable = true
        cv.allowsMultipleSelection = true
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
        EditorFileTreeV2Plugin.logger.info("\(Self.t)视图加载完成")

        // bindings 就绪后再加载数据
        if let path = pendingProjectRoot, !path.isEmpty {
            EditorFileTreeV2Plugin.logger.info("\(Self.t)延迟加载项目：\(path)")
            fileTreeDataSource.setProjectRoot(path)
            pendingProjectRoot = nil
        }
    }
    
    private func setupCollectionView() {
        let layout = Self.makeLayout()
        collectionView.collectionViewLayout = layout

        // 注册 cell 类以启用复用池。register(_:forItemWithIdentifier:) 会让
        // makeItem 走类初始化路径（不查 nib），从而复用已创建的 cell，避免每次都 new。
        collectionView.register(FileTreeNodeCell.self, forItemWithIdentifier: Self.cellIdentifier)

        // NSCollectionView 必须放在 NSScrollView 中才能滚动
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = collectionView

        view.addSubview(scrollView)

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

            // 走复用池：命中已存在的 cell 就复用，不会每次都新建 cell + NSHostingView
            let cell = self.collectionView.makeItem(
                withIdentifier: Self.cellIdentifier,
                for: indexPath
            ) as? FileTreeNodeCell ?? FileTreeNodeCell()

            let isSelected = self.selectionState.isSelected(item.url)
            let isHovered = self.hoveredItemURL == item.url
            let gitStatus = self.gitStatus(for: item.url)
            let itemFlashOpacity: Double = (self.flashItemURL == item.url) ? self.flashOpacity : 0

            cell.configure(
                with: item,
                isSelected: isSelected,
                isHovered: isHovered,
                gitStatus: gitStatus,
                theme: self.theme,
                flashOpacity: itemFlashOpacity
            )

            return cell
        }

        collectionView.delegate = self
        collectionView.dataSource = dataSource
    }
    
    private func setupBindings() {
        fileTreeDataSource.onItemsChanged = { [weak self] items in
            guard let self = self else { return }
            
            var snapshot = NSDiffableDataSourceSnapshot<Section, FileTreeNodeItem>()
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
        // 必须转换到 collectionView 的坐标系，与 layoutAttributesForItem 的 frame 保持一致。
        let point = collectionView.convert(event.locationInWindow, from: nil)

        var hitURL: URL?
        for indexPath in collectionView.indexPathsForVisibleItems() {
            guard let item = dataSource.itemIdentifier(for: indexPath),
                  let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else {
                continue
            }
            if frame.contains(point) {
                hitURL = item.url
                break
            }
        }

        // 没有变化就不做任何操作
        if hitURL == hoveredItemURL { return }
        hoveredItemURL = hitURL

        // 直接遍历可见 cell 实例同步更新 hover 状态——不走 reloadItems（异步排期，
        // 快速移动时多批次叠加会残留多个高亮）也不走 item(at:)（diffable data source
        // 下查找不可靠会返回 nil）。visibleItems() 直接返回 cell 对象，一定能拿到。
        // 一次遍历把所有可见 cell 同步到正确状态，既不漏亮也不残留。
        syncHoverState(hitURL: hitURL)
    }

    override func mouseExited(with event: NSEvent) {
        guard hoveredItemURL != nil else { return }
        hoveredItemURL = nil
        syncHoverState(hitURL: nil)
    }

    /// 遍历所有可见 cell，把 hover 状态同步为「仅 hitURL 高亮」。
    private func syncHoverState(hitURL: URL?) {
        for case let cell as FileTreeNodeCell in collectionView.visibleItems() {
            guard let indexPath = collectionView.indexPath(for: cell),
                  let item = dataSource.itemIdentifier(for: indexPath) else { continue }
            cell.updateHovered(item.url == hitURL)
        }
    }
    
    // MARK: - Public API
    
    func setProjectRoot(_ path: String) {
        if isViewLoaded {
            EditorFileTreeV2Plugin.logger.info("\(Self.t)设置项目根路径：\(path)")
            fileTreeDataSource.setProjectRoot(path)
        } else {
            // viewDidLoad 之前，暂存路径
            pendingProjectRoot = path
            EditorFileTreeV2Plugin.logger.info("\(Self.t)预存项目路径（待 viewDidLoad 后加载）：\(path)")
        }
    }
    
    func reloadDirectory(at url: URL) {
        fileTreeDataSource.reloadDirectory(at: url)
    }
    
    func fullRefresh() {
        fileTreeDataSource.fullRefresh()
    }
    
    func updateGitStatus(_ snapshot: GitStatusSnapshot) {
        gitStatusSnapshot = snapshot
        // 触发可见 cell 重绘以显示 Git 状态标记
        reloadVisibleItems()
    }

    /// 触发指定路径的闪烁高亮动画
    func triggerFlash(path: String) {
        guard EditorFileTreePanelPlugin.flashHighlightEnabled else { return }
        let targetURL = URL(fileURLWithPath: path)
        flashItemURL = targetURL
        flashOpacity = 0.25
        reloadVisibleItems()

        // 延迟后淡出并清除闪烁状态
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(0.6 * 1_000_000_000))
            flashOpacity = 0
            reloadVisibleItems()
            try? await Task.sleep(nanoseconds: UInt64(0.4 * 1_000_000_000))
            flashItemURL = nil
            flashOpacity = 0
        }
    }

    /// 重新加载可见 cell，用于 Git 状态更新和闪烁动画
    private func reloadVisibleItems() {
        let visibleItems = collectionView.indexPathsForVisibleItems()
        guard !visibleItems.isEmpty else { return }
        collectionView.reloadItems(at: Set(visibleItems))
    }

    /// 根据文件 URL 查询 Git 状态
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

        let modifiers = ModifierFlags.currentClick

        selectionState.handleTap(
            url: item.url,
            isDirectory: item.isDirectory,
            modifiers: modifiers,
            onOpenFile: {
                self.onSelect?(item.url)
            },
            onToggleExpand: {
                self.fileTreeDataSource.toggleExpansion(at: item.url)
                let relativePath = PathFormatter.expansionPath(
                    for: item.url,
                    projectRootPath: item.projectRootPath
                )
                self.onExpansionChange?(relativePath, !item.isExpanded)
            }
        )

        collectionView.deselectItems(at: indexPaths)
    }
    
    func collectionView(
        _ collectionView: NSCollectionView,
        menuForItemsAt indexPaths: Set<IndexPath>
    ) -> NSMenu? {
        guard let indexPath = indexPaths.first,
              let item = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        return buildMenu(for: item.url, isDirectory: item.isDirectory)
    }

    /// 根据鼠标位置（window 坐标）构建右键菜单。
    /// 供 hosting view 在 rightMouseDown 时调用——NSCollectionView 内部的命中测试
    /// 在 NSHostingView 承载的 cell 上会失效（menuForItemsAt 不被调用），所以这里
    /// 自己用 layoutAttributes 做命中测试，绕过该限制。
    func menuForItem(atWindowLocation location: NSPoint) -> NSMenu? {
        let point = collectionView.convert(location, from: nil)
        for indexPath in collectionView.indexPathsForVisibleItems() {
            guard let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else {
                continue
            }
            if frame.contains(point) {
                guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
                return buildMenu(for: item.url, isDirectory: item.isDirectory)
            }
        }
        return nil
    }

    /// 构建指定节点 url 的右键菜单（顺序对齐 V1）。
    private func buildMenu(for url: URL, isDirectory: Bool) -> NSMenu {
        let menu = NSMenu()

        // New File / New Folder（仅目录）
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

        // Rename
        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Rename", bundle: .module),
            action: #selector(renameItem(_:)),
            url: url
        ))
        menu.addItem(.separator())

        // Add to Conversation
        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Add to Conversation", bundle: .module),
            action: #selector(addToConversation(_:)),
            url: url
        ))

        // Reveal in Finder
        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Reveal in Finder", bundle: .module),
            action: #selector(revealInFinder(_:)),
            url: url
        ))
        // Open in VS Code
        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Open in VS Code", bundle: .module),
            action: #selector(openInVSCode(_:)),
            url: url
        ))
        // Open in Terminal
        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Open in Terminal", bundle: .module),
            action: #selector(openInTerminal(_:)),
            url: url
        ))
        // Copy Path
        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Copy Path", bundle: .module),
            action: #selector(copyPath(_:)),
            url: url
        ))

        menu.addItem(.separator())

        // Move to Trash
        menu.addItem(menuItem(
            title: LumiPluginLocalization.string("Move to Trash", bundle: .module),
            action: #selector(deleteItem(_:)),
            url: url
        ))

        return menu
    }

    /// 便捷构建菜单项，统一设置 target 与 representedObject。
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
        EditorFileTreeV2Plugin.logger.info("\(Self.t)创建文件：\(newURL.path)")
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
        EditorFileTreeV2Plugin.logger.info("\(Self.t)创建文件夹：\(newURL.path)")
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

        // 名字没变就不操作
        guard newName != url.lastPathComponent else { return }

        guard let newURL = FileTreeFacade.renameItem(at: url, newName: newName) else {
            alert_error(LumiPluginLocalization.string(
                "Could not rename the item. The name may be invalid or an item with that name already exists.",
                bundle: .module
            ))
            return
        }
        Self.logger.info("[FileTreeV2] 重命名: \(url.lastPathComponent) → \(newURL.lastPathComponent)")
        // 联动编辑器：关闭旧 tab，打开新路径
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
        Self.logger.info("[FileTreeV2] 删除: \(url.path)")
        // 联动编辑器：关闭对应 tab
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

    /// 确保目录处于展开状态（新建文件/文件夹后让新项立即可见）。
    private func ensureDirectoryExpanded(_ url: URL) {
        guard let item = fileTreeDataSource.items.first(where: { $0.url == url }),
              item.isDirectory, !item.isExpanded else { return }
        fileTreeDataSource.toggleExpansion(at: url)
        // 同步展开状态到持久化（与正常点击展开走同一路径）
        let relativePath = PathFormatter.expansionPath(
            for: url, projectRootPath: fileTreeDataSource.projectRootPath
        )
        onExpansionChange?(relativePath, true)
    }

    /// 文件操作后刷新：通知 SwiftUI 层 + 精准重载父目录。
    private func refreshAfterMutation(parentURL: URL) {
        onTreeMutation?()
        fileTreeDataSource.reloadDirectory(at: parentURL)
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
