import AppKit
import SwiftUI
import EditorFileTreePlugin
import LumiUI
import os

/// 文件树集合视图控制器
///
/// 使用 NSCollectionView 实现高性能文件树渲染。
@MainActor
final class FileTreeCollectionViewController: NSViewController {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree-v2")

    
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
        Self.logger.info("[FileTreeCollectionViewController] viewDidLoad 完成")
        
        // bindings 就绪后再加载数据
        if let path = pendingProjectRoot, !path.isEmpty {
            Self.logger.info("[FileTreeCollectionViewController] 延迟加载项目: \(path)")
            fileTreeDataSource.setProjectRoot(path)
            pendingProjectRoot = nil
        }
    }
    
    private func setupCollectionView() {
        // 注意：不注册 Cell 类，避免 makeItem 尝试加载不存在的 nib 导致崩溃
        let layout = Self.makeLayout()
        collectionView.collectionViewLayout = layout
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupDataSource() {
        dataSource = FileTreeDiffableDataSource(collectionView: collectionView) { [weak self] _, indexPath, item in
            guard let self = self else { return nil }
            
            // 手动创建 cell，不使用 makeItem 避免 nib 查找崩溃
            let cell = FileTreeNodeCell()
            cell.loadView()
            
            let isSelected = self.selectionState.isSelected(item.url)
            let isHovered = self.hoveredItemURL == item.url
            
            cell.configure(
                with: item,
                isSelected: isSelected,
                isHovered: isHovered,
                gitStatus: nil,
                theme: self.theme
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
        let point = view.convert(event.locationInWindow, from: nil)
        
        for indexPath in collectionView.indexPathsForVisibleItems() {
            guard let item = dataSource.itemIdentifier(for: indexPath),
                  let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else {
                continue
            }
            
            if frame.contains(point) {
                if hoveredItemURL != item.url {
                    hoveredItemURL = item.url
                    reloadVisibleItems()
                }
                return
            }
        }
        
        if hoveredItemURL != nil {
            hoveredItemURL = nil
            reloadVisibleItems()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if hoveredItemURL != nil {
            hoveredItemURL = nil
            reloadVisibleItems()
        }
    }
    
    private func reloadVisibleItems() {
        collectionView.reloadSections(IndexSet(integer: 0))
    }
    
    // MARK: - Public API
    
    func setProjectRoot(_ path: String) {
        if isViewLoaded {
            Self.logger.info("[FileTreeCollectionViewController] setProjectRoot: \(path)")
            fileTreeDataSource.setProjectRoot(path)
        } else {
            // viewDidLoad 之前，暂存路径
            pendingProjectRoot = path
            Self.logger.info("[FileTreeCollectionViewController] 预存项目路径: \(path)")
        }
    }
    
    func reloadDirectory(at url: URL) {
        fileTreeDataSource.reloadDirectory(at: url)
    }
    
    func fullRefresh() {
        fileTreeDataSource.fullRefresh()
    }
    
    func updateGitStatus(_ snapshot: GitStatusSnapshot) {
        // Git 状态更新通过 onItemsChanged 触发
        fileTreeDataSource.fullRefresh()
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
        
        if item.isDirectory {
            fileTreeDataSource.toggleExpansion(at: item.url)
            
            let relativePath = PathFormatter.expansionPath(
                for: item.url,
                projectRootPath: item.projectRootPath
            )
            onExpansionChange?(relativePath, !item.isExpanded)
        } else {
            selectionState.syncFromEditorHighlight(item.url)
            onSelect?(item.url)
        }
        
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
        
        let menu = NSMenu()
        
        if item.isDirectory {
            let newFileItem = NSMenuItem(title: "New File", action: #selector(newFile(_:)), keyEquivalent: "")
            newFileItem.representedObject = item.url
            newFileItem.target = self
            menu.addItem(newFileItem)
            
            let newFolderItem = NSMenuItem(title: "New Folder", action: #selector(newFolder(_:)), keyEquivalent: "")
            newFolderItem.representedObject = item.url
            newFolderItem.target = self
            menu.addItem(newFolderItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        let renameItem = NSMenuItem(title: "Rename", action: #selector(renameItem(_:)), keyEquivalent: "")
        renameItem.representedObject = item.url
        renameItem.target = self
        menu.addItem(renameItem)
        
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteItem(_:)), keyEquivalent: "")
        deleteItem.representedObject = item.url
        deleteItem.target = self
        menu.addItem(deleteItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(revealInFinder(_:)), keyEquivalent: "")
        revealItem.representedObject = item.url
        revealItem.target = self
        menu.addItem(revealItem)
        
        return menu
    }
    
    // MARK: - Menu Actions
    
    @objc private func newFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        // TODO: 实现新建文件逻辑
    }
    
    @objc private func newFolder(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        // TODO: 实现新建文件夹逻辑
    }
    
    @objc private func renameItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        // TODO: 实现重命名逻辑
    }
    
    @objc private func deleteItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        // TODO: 实现删除逻辑
    }
    
    @objc private func revealInFinder(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
