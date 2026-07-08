import AppKit
import SwiftUI
import EditorFileTreePlugin
import LumiUI

/// 文件树节点单元格
///
/// NSCollectionViewItem 宿主，使用 NSHostingView 承载 NodeRowView。
final class FileTreeNodeCell: NSCollectionViewItem {

    private var hostingView: NodeRowHostingView?
    private var isHovered = false
    // 缓存上一次 configure 的入参，updateHovered 时复用，避免重建整套 SwiftUI 视图。
    // 注意不能命名为 isSelected，会与 NSCollectionViewItem.isSelected 冲突。
    private var cachedItem: FileTreeNodeItem?
    private var cachedIsSelected = false
    private var cachedGitStatus: GitStatus?
    private var cachedTheme: (any LumiAppChromeTheme)?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        // 使用自定义 hosting view：NSHostingView 默认会消费 rightMouseDown（即使
        // SwiftUI 内容没有 .contextMenu 也会），导致 NSCollectionViewDelegate.menuForItemsAt
        // 不被调用。子类化后把右键事件转发给 NSCollectionView，恢复原生右键菜单。
        hostingView = NodeRowHostingView(rootView: NodeRowView.placeholder)
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
        self.cachedItem = item
        self.cachedIsSelected = isSelected
        self.cachedGitStatus = gitStatus
        self.cachedTheme = theme

        hostingView?.rootView = NodeRowView(
            item: item,
            isSelected: isSelected,
            isHovered: isHovered,
            gitStatus: gitStatus,
            theme: theme
        )
    }

    /// 轻量更新悬停状态，避免重建 SwiftUI 视图。
    /// 悬停频繁切换时只改 rootView，不触发 cell/createView 重建。
    /// 不做 isHovered 去重——mouseMoved 已在外层判断了 hoveredItemURL 是否变化，
    /// 这里必须无条件生效，避免因状态不同步导致高亮残留。
    func updateHovered(_ hovered: Bool) {
        guard let item = cachedItem, let theme = cachedTheme else { return }
        isHovered = hovered
        hostingView?.rootView = NodeRowView(
            item: item,
            isSelected: cachedIsSelected,
            isHovered: hovered,
            gitStatus: cachedGitStatus,
            theme: theme
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingView?.rootView = NodeRowView.placeholder
        isHovered = false
        cachedItem = nil
        cachedIsSelected = false
        cachedGitStatus = nil
        cachedTheme = nil
    }
}

/// 承载 NodeRowView 的 NSHostingView 子类
///
/// NSHostingView 默认会消费 rightMouseDown（即使 SwiftUI 内容没有 .contextMenu），
/// 导致右键事件不沿响应者链传到 NSCollectionView，于是 delegate 的 menuForItemsAt
/// 不被调用、右键菜单不弹出。
///
/// 这里重写 rightMouseDown，不调用 super（避免被 NSHostingView 消费），而是把事件
/// 转发给 NSCollectionView.rightMouseDown——它会根据命中位置计算 indexPath、调用
/// delegate.menuForItemsAt 并弹出原生右键菜单。menu(for:) 同步转发，覆盖 control-click
/// 等其他触发路径。
final class NodeRowHostingView: NSHostingView<NodeRowView> {
    override func rightMouseDown(with event: NSEvent) {
        // NSHostingView 会消费 rightMouseDown（即使 SwiftUI 内容没有 .contextMenu），
        // 且 NSCollectionView 内部的命中测试在 NSHostingView 承载的 cell 上会失效
        // （menuForItemsAt 不被调用）。这里完全接管：找到 controller，由它自己做命中
        // 测试并构建菜单，然后在这里弹出。
        guard let controller = enclosingFileTreeController() else {
            super.rightMouseDown(with: event)
            return
        }
        if let menu = controller.menuForItem(atWindowLocation: event.locationInWindow) {
            let point = convert(event.locationInWindow, from: nil)
            menu.popUp(positioning: nil, at: point, in: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    /// 沿 superview 链找到 NSCollectionView，再取其 delegate（即 controller）。
    private func enclosingFileTreeController() -> FileTreeCollectionViewController? {
        var ancestor: NSView? = superview
        while let current = ancestor {
            if let cv = current as? NSCollectionView {
                return cv.delegate as? FileTreeCollectionViewController
            }
            ancestor = current.superview
        }
        return nil
    }
}
