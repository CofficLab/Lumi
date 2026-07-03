# EditorFileTree 原生渲染重写方案（NSCollectionView）

## 1. 问题背景

### 1.1 当前痛点

当前 `EditorFileTreePlugin` 使用纯 SwiftUI `LazyVStack` 渲染文件树，存在以下性能瓶颈：

| 场景 | 表现 |
|------|------|
| 空闲状态滚动 | 轻微卡顿（SwiftUI 布局开销） |
| LLM 流式响应期间滚动 | 明显卡顿掉帧 |
| 大型项目（500+ 可见节点） | 滚动持续卡顿 |
| 开启 ContextMenu/DragDrop | 卡顿加剧 |

### 1.2 为什么 Editor 不卡？

- **Editor**：底层使用 `NSTextView`，走 AppKit 原生 Core Text 渲染管线，布局独立于主 Runloop 的 SwiftUI 阶段
- **EditorFileTree**：纯 SwiftUI `LazyVStack`，每行 `NodeView` 挂载 10+ 修饰符，滚动时逐行求值 `body`，LLM 流式期间主线程布局预算被压缩 → 掉帧

### 1.3 解决方案对比

| 方案 | 工作量 | 效果 | 维护成本 |
|------|--------|------|----------|
| A. 隔离渲染视图 | 低 | 缓解 20-30% | 低 |
| B. 合并修饰符 | 中 | 缓解 15-25% | 中 |
| C. 流式期间降级 | 低 | 临时缓解 | 低 |
| **D. NSCollectionView 重写** | **高** | **彻底解决** | **中高** |

---

## 2. 目标与约束

### 2.1 设计目标

1. **滚动性能**：在 LLM 流式响应期间滚动文件树，帧率稳定 55-60 FPS
2. **功能对等**：保持现有所有交互功能（展开/折叠、多选、右键菜单、拖拽、Git 状态、闪烁定位）
3. **API 兼容**：对外暴露相同的 `TreeView` SwiftUI 视图，内部实现替换为桥接层
4. **渐进式迁移**：允许新旧实现通过 `EditorFileTreePanelPlugin` 开关切换

### 2.2 技术约束

- 仅 macOS 13+ 目标（Lumi 现有部署目标）
- 使用 `NSCollectionView`（而非 `NSTableView`），因为 `NSCollectionViewCompositionalLayout` 更适合树形缩进渲染
- 数据源保持与现有 `RefreshCoordinator` 兼容
- 复用现有的 `NodeView` 视觉逻辑（通过 `NSCollectionViewItem` 承载 SwiftUI 子视图）

---

## 3. 整体架构

### 3.1 架构图

```
┌─────────────────────────────────────────────────────────┐
│                     SwiftUI TreeView                     │
│                    (对外公开接口)                          │
├─────────────────────────────────────────────────────────┤
│              FileTreeNSViewBridge                        │
│          (NSViewRepresentable 桥接层)                     │
├─────────────────────────────────────────────────────────┤
│               FileTreeCollectionViewController           │
│              (NSViewController 容器)                      │
├──────────────┬──────────────────────────────────────────┤
│ NSCollectionView │ FileTreeDataSource                    │
│ • Compositional  │ • 扁平化节点列表                        │
│   Layout         │ • 展开/折叠状态管理                     │
│ • Delegate       │ • 精准刷新适配                         │
├──────────────┼──────────────────────────────────────────┤
│ FileTreeNodeCell │ FileTreeNodeItem                      │
│ (CollectionView  │ • URL 路径                             │
│  Item 宿主)       │ • depth 缩进层级                        │
│                  │ • isDirectory / isExpanded              │
│  ┌────────────┐  │ • GitStatus                           │
│  │ SwiftUI    │  │ • iconMetadata                        │
│  │ NodeRowView│  │ • Equatable                           │
│  │ (纯视觉渲染)│  │                                       │
│  └────────────┘  │                                       │
└──────────────────┴───────────────────────────────────────┘
```

### 3.2 核心设计决策

| 决策点 | 方案 | 理由 |
|--------|------|------|
| 数据模型 | **扁平化列表** | 树形结构展开后是线性序列，CollectionView 最适合线性数据 |
| Cell 渲染 | **NSHostingView + 精简 SwiftUI 视图** | 保留 SwiftUI 声明式优势，但移除所有交互修饰符 |
| 交互处理 | **NSCollectionViewDelegate** | 点击、右键菜单、拖拽等由原生代理处理，不依赖 SwiftUI 修饰符 |
| 布局引擎 | **Compositional Layout** | 原生支持固定行高、间距、缩进 |
| 刷新机制 | **Diffable Data Source** | 类似 `NSDiffableDataSourceSnapshot`，自动计算插入/删除/移动动画 |

---

## 4. 详细实现

### 4.1 数据模型层

#### 4.1.1 FileTreeNodeItem

文件树节点的扁平化数据模型。仅存储渲染所需的只读信息，不包含业务逻辑。

```swift
/// 文件树节点的扁平化数据模型
struct FileTreeNodeItem: Hashable {
    let url: URL
    let depth: Int
    let isDirectory: Bool
    let isExpanded: Bool
    let iconMetadata: FileTreeIconMetadata
    let gitRelativePath: String
    let fileName: String
    
    var id: URL { url }
    
    init(
        url: URL,
        depth: Int,
        isDirectory: Bool,
        isExpanded: Bool,
        projectRootPath: String
    ) {
        self.url = url
        self.depth = depth
        self.isDirectory = isDirectory
        self.isExpanded = isExpanded
        self.iconMetadata = FileTreeIconMetadata(
            fileName: url.lastPathComponent,
            fileExtension: url.pathExtension.lowercased(),
            isDirectory: isDirectory,
            isSwiftPackageDirectory: isDirectory && FileManager.default.fileExists(
                atPath: url.appendingPathComponent("Package.swift", isDirectory: false).path
            )
        )
        self.gitRelativePath = PathFormatter.gitPath(for: url, projectRootPath: projectRootPath)
        self.fileName = url.lastPathComponent
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(depth)
        hasher.combine(isExpanded)
    }
    
    static func == (lhs: FileTreeNodeItem, rhs: FileTreeNodeItem) -> Bool {
        lhs.url == rhs.url && lhs.depth == rhs.depth && lhs.isExpanded == rhs.isExpanded
    }
}

private struct FileTreeIconMetadata {
    let fileName: String
    let fileExtension: String
    let isDirectory: Bool
    let isSwiftPackageDirectory: Bool
}
```

#### 4.1.2 FileTreeDataSource

数据源负责将树形结构展平为线性列表，处理展开/折叠和精准刷新。

```swift
@MainActor
final class FileTreeDataSource: NSObject {
    
    /// 当前扁平化的节点列表（按可见顺序排列）
    private(set) var items: [FileTreeNodeItem] = []
    
    /// 展开状态存储（与现有 FileTreeSettings 兼容）
    private var expandedPaths: Set<String> = []
    
    /// 项目根路径
    private var projectRootPath: String = ""
    
    /// 数据变化回调
    var onItemsChanged: (([FileTreeNodeItem]) -> Void)?
    
    /// 设置项目根目录，重新构建节点列表
    func setProjectRoot(_ path: String) {
        projectRootPath = path
        expandedPaths = FileTreeSettings.shared.expandedPaths(for: path)
        rebuildItems()
    }
    
    private func rebuildItems() {
        guard !projectRootPath.isEmpty else {
            items = []
            onItemsChanged?(items)
            return
        }
        let rootURL = URL(fileURLWithPath: projectRootPath)
        items = expandDirectory(rootURL, depth: 0)
        onItemsChanged?(items)
    }
    
    /// 递归展开目录，返回扁平化的可见节点列表
    private func expandDirectory(_ url: URL, depth: Int) -> [FileTreeNodeItem] {
        var result: [FileTreeNodeItem] = []
        let relativePath = PathFormatter.expansionPath(for: url, projectRootPath: projectRootPath)
        let isExpanded = expandedPaths.contains(relativePath)
        let isDirectory = FileTreeFacade.isDirectory(url)
        
        result.append(FileTreeNodeItem(
            url: url, depth: depth, isDirectory: isDirectory,
            isExpanded: isExpanded, projectRootPath: projectRootPath
        ))
        
        if isDirectory && isExpanded {
            do {
                let children = try FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                let sorted = try FileTreeFacade.sortItems(children)
                for childURL in sorted {
                    result.append(contentsOf: expandDirectory(childURL, depth: depth + 1))
                }
            } catch { /* 权限错误或目录不可读，静默处理 */ }
        }
        
        return result
    }
    
    /// 切换指定目录的展开状态
    func toggleExpansion(at url: URL) {
        guard let item = items.first(where: { $0.url == url }), item.isDirectory else { return }
        let relativePath = PathFormatter.expansionPath(for: url, projectRootPath: projectRootPath)
        
        if expandedPaths.contains(relativePath) {
            expandedPaths.remove(relativePath)
            FileTreeSettings.shared.removeExpandedPath(relativePath, for: projectRootPath)
            collapseChildren(of: url)
        } else {
            expandedPaths.insert(relativePath)
            FileTreeSettings.shared.addExpandedPath(relativePath, for: projectRootPath)
        }
        rebuildItems()
    }
    
    private func collapseChildren(of url: URL) {
        let urlPath = url.path
        expandedPaths = expandedPaths.filter { !$0.hasPrefix(urlPath) }
    }
    
    /// 精准刷新：仅重载指定目录的子节点
    func reloadDirectory(at url: URL) {
        guard let index = items.firstIndex(where: { $0.url == url }),
              items[index].isDirectory else { return }
        
        let item = items[index]
        var endIndex = index + 1
        while endIndex < items.count, items[endIndex].depth > item.depth {
            endIndex += 1
        }
        
        if item.isExpanded {
            let newChildren = expandDirectory(url, depth: item.depth)
            items.replaceSubrange(index..<endIndex, with: newChildren)
        } else {
            items[index] = FileTreeNodeItem(
                url: url, depth: item.depth, isDirectory: true,
                isExpanded: false, projectRootPath: projectRootPath
            )
        }
        onItemsChanged?(items)
    }
    
    func fullRefresh() { rebuildItems() }
}
```

---

### 4.2 布局引擎

使用 `NSCollectionViewCompositionalLayout`，固定行高避免动态布局计算。

```swift
extension FileTreeCollectionViewController {
    
    static func makeLayout() -> NSCollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(28)  // 固定行高，避免动态计算
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(28)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        section.interGroupSpacing = 2  // 对应原 LazyVStack spacing: 2
        
        return NSCollectionViewCompositionalLayout(section: section)
    }
}
```

---

### 4.3 Diffable Data Source

```swift
typealias FileTreeDiffableDataSource = NSCollectionViewDiffableDataSource<Section, FileTreeNodeItem>

enum Section: CaseIterable { case main }

extension FileTreeCollectionViewController {
    
    private func setupDataSource() {
        dataSource = FileTreeDiffableDataSource(
            collectionView: collectionView,
            itemProvider: { [weak self] collectionView, indexPath, item in
                guard let self else { return nil }
                let cell = collectionView.makeItem(
                    withIdentifier: Self.cellIdentifier, for: indexPath
                ) as? FileTreeNodeCell
                
                cell?.configure(
                    with: item,
                    isSelected: self.selectionState.isSelected(item.url),
                    isHovered: self.hoveredItemURL == item.url,
                    gitStatus: self.gitStatusSnapshot.statusForPath(item.gitRelativePath),
                    theme: self.currentTheme
                )
                return cell
            }
        )
    }
    
    func applySnapshot(animated: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, FileTreeNodeItem>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems(dataSource.items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: animated)
    }
}
```

---

### 4.4 Cell 实现

#### 4.4.1 FileTreeNodeCell

Cell 使用 `NSHostingView` 包装精简版 SwiftUI 视图。关键原则：**Cell 内部不包含任何交互修饰符**。

```swift
final class FileTreeNodeCell: NSCollectionViewItem {
    
    private var hostingView: NSHostingView<NodeRowView>!
    
    override func loadView() {
        view = NSView()
        hostingView = NSHostingView(rootView: NodeRowView.placeholder)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    func configure(
        with item: FileTreeNodeItem,
        isSelected: Bool,
        isHovered: Bool,
        gitStatus: GitStatus?,
        theme: any LumiAppChromeTheme
    ) {
        let rowView = NodeRowView(
            item: item, isSelected: isSelected, isHovered: isHovered,
            gitStatus: gitStatus, theme: theme
        )
        hostingView.rootView = rowView
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        hostingView.rootView = .placeholder
    }
}
```

#### 4.4.2 NodeRowView（精简版 SwiftUI 视图）

仅负责视觉渲染。**不包含** `.contextMenu`、`.onDrag`、`.onHover`、`.onChange` 等任何交互修饰符。

```swift
struct NodeRowView: View {
    let item: FileTreeNodeItem
    let isSelected: Bool
    let isHovered: Bool
    let gitStatus: GitStatus?
    let theme: any LumiAppChromeTheme
    
    var body: some View {
        HStack(spacing: 4) {
            // 展开/折叠箭头
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
                    .frame(width: 12)
                    .rotationEffect(.degrees(item.isExpanded ? 90 : 0))
            } else {
                Color.clear.frame(width: 12)
            }
            
            // 文件图标
            fileIconView(item)
                .font(.system(size: 12))
                .foregroundColor(item.isDirectory ? theme.primary : theme.textSecondary)
                .frame(width: 16)
            
            // 文件名
            Text(item.fileName)
                .font(.appCaption)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            // Git 状态标记
            if let gitStatus = gitStatus {
                Text(gitStatus.displayLetter)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(gitStatusColor(gitStatus, isSelected: isSelected))
                    .frame(width: 16, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .padding(.leading, CGFloat(item.depth) * 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground())
    }
    
    private func fileIconView(_ item: FileTreeNodeItem) -> Image {
        let context = LumiFileIconContext(
            url: item.url,
            fileName: item.iconMetadata.fileName,
            fileExtension: item.iconMetadata.fileExtension,
            isDirectory: item.iconMetadata.isDirectory,
            isExpanded: item.isExpanded,
            isSwiftPackageDirectory: item.iconMetadata.isSwiftPackageDirectory,
            projectRootPath: ""
        )
        let icon = LumiDefaultFileIconThemeContributor().icon(for: context)
        return icon?.image ?? Image(systemName: item.isDirectory ? "folder" : "doc")
    }
    
    private func rowBackground() -> some View {
        ZStack(alignment: .leading) {
            if isSelected {
                theme.sidebarSelectionColor()
            } else if isHovered {
                theme.textPrimary.opacity(0.06)
            } else {
                Color.clear
            }
        }
    }
    
    private func gitStatusColor(_ status: GitStatus, isSelected: Bool) -> Color {
        let base: Color = switch status {
        case .modified: .orange
        case .added, .untracked: .green
        case .deleted: .red
        case .renamed: .purple
        case .staged: .orange.opacity(0.7)
        case .conflicted: .red
        }
        return isSelected ? base.opacity(0.9) : base.opacity(0.7)
    }
}

extension NodeRowView {
    static var placeholder: Self {
        let placeholderURL = URL(fileURLWithPath: "/placeholder")
        return NodeRowView(
            item: FileTreeNodeItem(
                url: placeholderURL, depth: 0, isDirectory: false,
                isExpanded: false, projectRootPath: ""
            ),
            isSelected: false, isHovered: false,
            gitStatus: nil, theme: LumiUITh```

---

### 4.5 CollectionViewController 实现

整合 Data Source、Layout、Delegate 和所有交互逻辑。

```swift
@MainActor
final class FileTreeCollectionViewController: NSViewController {
    
    // MARK: - Properties
    
    static let cellIdentifier = NSUserInterfaceItemIdentifier("FileTreeNodeCell")
    
    private(set) var collectionView: NSCollectionView!
    private var dataSource: FileTreeDiffableDataSource!
    private let dataSourceModel = FileTreeDataSource()
    private let selectionState = SelectionState()
    private var gitStatusSnapshot: GitStatusSnapshot = .empty
    
    /// Hover 追踪
    private var trackingArea: NSTrackingArea?
    private var hoveredItemURL: URL?
    
    /// 与现有 TreeView 的协作
    var onSelect: ((URL) -> Void)?
    var onExpansionChange: ((String, Bool) -> Void)?
    var onTreeMutation: (() -> Void)?
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupDataSource()
        setupBindings()
    }
    
    private func setupCollectionView() {
        collectionView = NSCollectionView()
        collectionView.dataSource = dataSource
        collectionView.delegate = self
        collectionView.layout = Self.makeLayout()
        collectionView.register(
            FileTreeNodeCell.self,
            forItemWithIdentifier: Self.cellIdentifier
        )
        collectionView.allowsMultipleSelection = true
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]
        
        // 移除默认选中环（与 SwiftUI 风格一致）
        collectionView.selectionHighlightStyle = .none
        
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // 滚动视图包裹
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = collectionView
        
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        collectionView.removeFromSuperview()
        scrollView.documentView = collectionView
    }
    
    private func setupBindings() {
        dataSourceModel.onItemsChanged = { [weak self] items in
            guard let self else { return }
            var snapshot = NSDiffableDataSourceSnapshot<Section, FileTreeNodeItem>()
            snapshot.appendSections(Section.allCases)
            snapshot.appendItems(items, toSection: .main)
            dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
    
    // MARK: - Public API
    
    func setProjectRoot(_ path: String) {
        dataSourceModel.setProjectRoot(path)
    }
    
    func updateGitStatus(_ snapshot: GitStatusSnapshot) {
        gitStatusSnapshot = snapshot
        // 仅更新可见 Cell 的 Git 状态标记
        for indexPath in collectionView.indexPathsForVisibleItems() {
            guard let cell = collectionView.item(at: indexPath) as? FileTreeNodeCell,
                  let item = dataSource.itemIdentifier(for: indexPath) else { continue }
            cell.configure(
                with: item,
                isSelected: selectionState.isSelected(item.url),
                isHovered: hoveredItemURL == item.url,
                gitStatus: snapshot.statusForPath(item.gitRelativePath),
                theme: currentTheme
            )
        }
    }
    
    func reloadDirectory(at url: URL) {
        dataSourceModel.reloadDirectory(at: url)
    }
    
    func fullRefresh() {
        dataSourceModel.fullRefresh()
    }
    
    func flashAndSelect(url: URL) {
        // 定位到文件并闪烁（通过 Delegate 实现滚动 + 选中）
        if let indexPath = dataSource.indexPath(for: url) {
            collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredVertically)
            collectionView.selectItems(at: [indexPath], byExtendingSelection: false)
        }
    }
}
```

---

### 4.6 Delegate 实现（交互层）

所有交互逻辑（点击、展开/折叠、右键菜单、拖拽、多选）由 `NSCollectionViewDelegate` 处理。

```swift
extension FileTreeCollectionViewController: NSCollectionViewDelegate {
    
    // MARK: - 点击处理
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first,
              let item = dataSource.itemIdentifier(for: indexPath) else { return }
        
        if item.isDirectory {
            dataSourceModel.toggleExpansion(at: item.url)
            onExpansionChange?(
                PathFormatter.expansionPath(for: item.url, projectRootPath: dataSourceModel.projectRootPath),
                item.isExpanded
            )
        } else {
            onSelect?(item.url)
        }
    }
    
    // MARK: - 右键菜单
    
    func collectionView(
        _ collectionView: NSCollectionView,
        menuForItemsAt indexPaths: Set<IndexPath>
    ) -> NSMenu? {
        guard let indexPath = indexPaths.first,
              let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        
        let menu = NSMenu()
        
        // 新建文件/文件夹（仅目录）
        if item.isDirectory {
            menu.addItem(withTitle: "New File", action: #selector(newFile(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "New Folder", action: #selector(newFolder(_:)), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
        }
        
        // 重命名
        menu.addItem(withTitle: "Rename", action: #selector(rename(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        
        // 打开操作
        menu.addItem(withTitle: "Reveal in Finder", action: #selector(revealInFinder(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy Path", action: #selector(copyPath(_:)), keyEquivalent: "")
        
        return menu
    }
    
    // MARK: - Hover 追踪
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            view.removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        if let area = trackingArea {
            view.addTrackingArea(area)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = collectionView.convert(event.locationInWindow, from: nil)
        let indexPath = collectionView.indexPathForItem(at: location)
        
        if let indexPath = indexPath,
           let item = dataSource.itemIdentifier(for: indexPath),
           hoveredItemURL != item.url {
            let previousURL = hoveredItemURL
            hoveredItemURL = item.url
            updateHoverState(previousURL: previousURL, newURL: item.url)
        } else if hoveredItemURL != nil, indexPath == nil {
            let previousURL = hoveredItemURL
            hoveredItemURL = nil
            updateHoverState(previousURL: previousURL, newURL: nil)
        }
    }
    
    private func updateHoverState(previousURL: URL?, newURL: URL?) {
        // 更新前一个 hover Cell
        if let previousURL = previousURL,
           let prevIndex = dataSource.indexPath(for: previousURL),
           let prevCell = collectionView.item(at: prevIndex) as? FileTreeNodeCell,
           let prevItem = dataSource.itemIdentifier(for: prevIndex) {
            prevCell.configure(
                with: prevItem, isSelected: selectionState.isSelected(prevItem.url),
                isHovered: false, gitStatus: gitStatusSnapshot.statusForPath(prevItem.gitRelativePath),
                theme: currentTheme
            )
        }
        
        // 更新新的 hover Cell
        if let newURL = newURL,
           let newIndex = dataSource.indexPath(for: newURL),
           let newCell = collectionView.item(at: newIndex) as? FileTreeNodeCell,
           let newItem = dataSource.itemIdentifier(for: newIndex) {
            newCell.configure(
                with: newItem, isSelected: selectionState.isSelected(newItem.url),
                isHovered: true, gitStatus: gitStatusSnapshot.statusForPath(newItem.gitRelativePath),
                theme: currentTheme
            )
        }
    }
    
    // MARK: - 拖拽支持
    
    override func registerForDraggedTypes() {
        // 注册拖出（文件 URL）
        collectionView.registerForDraggedTypes([.fileURL])
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.url.path, forType: .fileURL)
        return pasteboardItem
    }
}

// MARK: - Menu Actions

extension FileTreeCollectionViewController {
    
    @objc private func newFile(_ sender: Any?) { /* ... */ }
    @objc private func newFolder(_ sender: Any?) { /* ... */ }
    @objc private func rename(_ sender: Any?) { /* ... */ }
    @objc private func revealInFinder(_ sender: Any?) { /* ... */ }
    @objc private func copyPath(_ sender: Any?) { /* ... */ }
}
```

---

### 4.7 SwiftUI 桥接层

```swift
struct FileTreeNSViewBridge: NSViewRepresentable {
    
    @EnvironmentObject var editorContext: EditorContext
    @EnvironmentObject var selectionState: SelectionState
    @ObservedObject var coordinator: RefreshCoordinator
    
    let projectRootPath: String
    let onSelect: (URL) -> Void
    let onExpansionChange: ((String, Bool) -> Void)?
    let onTreeMutation: (() -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let controller = FileTreeCollectionViewController()
        controller.onSelect = onSelect
        controller.onExpansionChange = onExpansionChange
        controller.onTreeMutation = onTreeMutation
        controller.environmentObject = editorContext
        controller.selectionState = selectionState
        controller.setProjectRoot(projectRootPath)
        
        context.coordinator.viewController = controller
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = controller.collectionView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let controller = context.coordinator.viewController else { return }
        controller.updateGitStatus(coordinator.gitStatusSnapshot)
        // 处理 projectRootPath 变化
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        weak var viewController: FileTreeCollectionViewController?
    }
}
```

---

### 4.8 TreeView 开关切换

在现有 `TreeView.swift` 中增加性能开关，允许渐进式迁移：

```swift
// EditorFileTreePlugin.swift
public enum EditorFileTreePanelPlugin: LumiPlugin, SuperLog {
    /// 是否使用 NSCollectionView 原生渲染（关闭则使用 SwiftUI LazyVStack）
    public static let nativeRenderingEnabled: Bool = false
}

// TreeView.swift
public var body: some View {
    if EditorFileTreePanelPlugin.nativeRenderingEnabled {
        FileTreeNSViewBridge(
            coordinator: coordinator,
            projectRootPath: projectPath,
            onSelect: { selectedURL in openProjectFile(selectedURL) },
            onExpansionChange: { relativePath, isExpanded in
                handleExpansionChange(relativePath: relativePath, isExpanded: isExpanded)
            },
            onTreeMutation: { refreshTreeAfterMutation() }
        )
    } else {
        // 现有 SwiftUI 实现
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                NodeView(...)
            }
        }
    }
}
```

---

## 5. 实施步骤

### Phase 1：基础设施（~2 天）

1. 创建 `FileTreeNodeItem` 数据模型
2. 创建 `FileTreeDataSource` 扁平化数据源
3. 编写单元测试验证展开/折叠逻辑

### Phase 2：渲染层（~3 天）

4. 创建 `NodeRowView` 精简版视图（无交互修饰符）
5. 创建 `FileTreeNodeCell` 和 `NSHostingView` 宿主
6. 实现 `CompositionalLayout` 和 `DiffableDataSource`
7. 验证基础渲染和滚动性能

### Phase 3：交互层（~3 天）

8. 实现 `NSCollectionViewDelegate` 点击处理（展开/折叠、文件打开）
9. 实现右键菜单（NSMenu）
10. 实现 Hover 追踪（NSTrackingArea）
11. 实现多选支持

### Phase 4：高级功能（~3 天）

12. Git 状态集成
13. 拖拽支持（NSPasteboard）
14. 闪烁定位动画
15. 新建/重命名/删除对话框

### Phase 5：集成与测试（~2 天）

16. 创建 `NSViewRepresentable` 桥接层
17. 在 `TreeView` 中集成开关
18. 性能对比测试（LLM 流式期间滚动帧率）
19. 功能回归测试

---

## 6. 性能验证

### 6.1 预期效果

| 指标 | SwiftUI LazyVStack | NSCollectionView |
|------|-------------------|------------------|
| 空闲滚动 FPS | 50-55 | 58-60 |
| LLM 流式期间 FPS | 25-40 | 50-58 |
| 500+ 节点内存 | ~45MB | ~22MB |
| body 求值/帧 | 500+ 次 | ~30 次（仅可见 Cell） |

### 6.2 验证方法

使用 Instruments Time Profiler + Core Animation 工具：
1. 打开一个大型项目（如 Lumi 自身）
2. 展开所有目录达到 500+ 可见节点
3. 发起 LLM 对话并等待流式响应
4. 滚动文件树，记录帧率和 CPU 时间分布
5. 切换开关对比新旧实现

---

## 7. 注意事项与陷阱

### 7.1 NSHostingView 性能

- `NSHostingView` 本身也有渲染开销，但远小于 SwiftUI 布局引擎的完整 `body` 求值
- 确保 `NodeRowView` 是 **纯值类型**，不依赖 `@Environment`、`@State` 等动态属性
- 使用 `NSViewAppearanceObserver` 在主题切换时批量更新，而非逐个 Cell 更新

### 7.2 Diffable DataSource 动画

- 展开/折叠时使用 `animatingDifferences: false` 可避免不必要的布局动画
- 精准刷新时使用 `animatingDifferences: true` 获得平滑插入/删除动画

### 7.3 内存管理

- `collectionView.indexPathsForVisibleItems` 仅返回当前可见的 Cell 索引，利用此特性批量更新 Git 状态
- Cell 复用时必须调用 `prepareForReuse()` 重置状态，避免脏数据

### 7.4 事件传播

- `NSCollectionView` 的点击事件优先级高于 `NSHostingView` 内部的 SwiftUI `onTapGesture`
- 确保所有点击处理都在 Delegate 层完成，避免冲突

### 7.5 线程安全

- 所有 UI 操作必须在 `@MainActor` 上执行
- `FileTreeDataSource` 的文件系统 I/O 应在后台线程执行，结果回调到主线程

---

## 8. 未来优化

- **虚拟滚动预取**：监听 `visibleItemsInvalidationHandler`，在用户快速滚动时预取即将可见的 Cell 数据
- **符号化图标缓存**：`NSImage` 级别缓存 SF Symbol，避免重复解析
- **增量刷新**：利用 `NSDiffableDataSource` 的 `apply` 差异计算，仅刷新变化节点而非整树
- **直接 AppKit 渲染**：终极优化可考虑将 `NodeRowView` 从 `NSHostingView` 迁移到纯 `NSView` 绘制，进一步降低开销
