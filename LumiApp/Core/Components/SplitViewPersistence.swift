import AppKit
import SwiftUI

// MARK: - SplitView Autosave Configurator

/// 为 macOS 的 `HSplitView` / `VSplitView` 配置 `autosaveName`，以持久化分栏宽度
///
/// 用法：
/// ```swift
/// HSplitView { ... }
///     .background(SplitViewAutosaveConfigurator(autosaveName: "MySplit"))
/// ```
struct SplitViewAutosaveConfigurator: NSViewRepresentable {
    let autosaveName: String

    func makeNSView(context: Context) -> AutosaveConfiguratorView {
        AutosaveConfiguratorView(autosaveName: autosaveName)
    }

    func updateNSView(_ nsView: AutosaveConfiguratorView, context: Context) {
        nsView.autosaveName = autosaveName
    }
}

final class AutosaveConfiguratorView: NSView {
    var autosaveName: String {
        didSet { applyAutosaveIfNeeded() }
    }

    init(autosaveName: String) {
        self.autosaveName = autosaveName
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            applyAutosaveIfNeeded()
        }
    }

    private var hasApplied = false

    private func applyAutosaveIfNeeded() {
        guard !hasApplied, !autosaveName.isEmpty, let splitView = findSplitView() else { return }
        guard splitView.autosaveName != autosaveName else { return }

        splitView.identifier = NSUserInterfaceItemIdentifier(autosaveName)
        splitView.autosaveName = autosaveName
        hasApplied = true
    }

    private func findSplitView() -> NSSplitView? {
        SplitViewFinder.find(from: self)
    }
}

// MARK: - SplitView Finder

/// 统一的 NSSplitView 查找工具
///
/// 从当前视图沿祖先链向上查找最近的 NSSplitView。
/// 对于 SwiftUI `.background()` 放置的辅助视图，NSSplitView 一定是祖先节点，
/// 因此优先向上搜索祖先链，而非搜索兄弟子树。
enum SplitViewFinder {
    static func find(from view: NSView) -> NSSplitView? {
        var current: NSView? = view
        while let node = current {
            if let sv = node as? NSSplitView { return sv }
            current = node.superview
        }
        return nil
    }
}

// MARK: - SplitView Size Persistence

/// 为 SplitView 增加显式尺寸记忆（比例），用于下次主动恢复。
///
/// 自动适配横向（HSplitView）和纵向（VSplitView）。
/// 支持指定 `columnIndex`，控制 SplitView 中第几个子视图的比例。
/// 默认 `columnIndex = 0`，即控制第一个子视图（向后兼容）。
///
/// 数据流：
/// - 读取/写入通过 `LayoutVM.layoutRatios`（纯内存）
/// - `LayoutPlugin` 观察 `LayoutVM` 变化并持久化到磁盘
/// - 应用启动时，`LayoutPlugin` 将保存的比例写回 `LayoutVM`
///
/// 用法：
/// ```swift
/// HSplitView {
///     MyView()
///         .background(SplitViewWidthPersistence(
///             storageKey: "Split.MyPanel.MyView",
///             columnIndex: 1
///         ))
///     OtherView()
/// }
///
/// VSplitView {
///     TopView()
///     BottomView()
///         .background(SplitViewWidthPersistence(
///             storageKey: "Split.MyPanel.Bottom",
///             columnIndex: 1
///         ))
/// }
/// ```
struct SplitViewWidthPersistence: NSViewRepresentable {
    let storageKey: String
    /// 控制第几个子视图的比例（默认 0，向后兼容）
    var columnIndex: Int = 0

    func makeNSView(context: Context) -> SplitViewWidthPersistenceView {
        SplitViewWidthPersistenceView(storageKey: storageKey, columnIndex: columnIndex)
    }

    func updateNSView(_ nsView: SplitViewWidthPersistenceView, context: Context) {
        nsView.storageKey = storageKey
        nsView.columnIndex = columnIndex
        nsView.attachIfNeeded()
    }
}

final class SplitViewWidthPersistenceView: NSView {
    private static let maxApplyRetryCount = 20

    var storageKey: String
    var columnIndex: Int
    private var observedSplitView: NSSplitView?
    private var resizeObserver: NSObjectProtocol?
    private var didApplySavedValue = false
    private var pendingRetryWorkItem: DispatchWorkItem?
    private var pendingApplyRetryWorkItem: DispatchWorkItem?
    private var applyRetryCount = 0

    /// 所有栏的最小保护尺寸
    static let minimumColumnSize: CGFloat = 48

    init(storageKey: String, columnIndex: Int = 0) {
        self.storageKey = storageKey
        self.columnIndex = columnIndex
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachIfNeeded()
    }

    func attachIfNeeded() {
        guard window != nil else { return }
        guard let splitView = SplitViewFinder.find(from: self) else {
            scheduleRetryAttach()
            return
        }
        guard splitView !== observedSplitView else { return }

        pendingRetryWorkItem?.cancel()
        pendingRetryWorkItem = nil
        pendingApplyRetryWorkItem?.cancel()
        pendingApplyRetryWorkItem = nil
        observedSplitView = splitView
        didApplySavedValue = false
        applyRetryCount = 0

        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
            self.resizeObserver = nil
        }

        applySavedRatioIfNeeded()

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: splitView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistCurrentRatio()
            }
        }
    }

    /// NSSplitView.isVertical 含义：divider 方向
    /// - true  = 竖直 divider → HSplitView（左右布局）→ 主轴是 width
    /// - false = 水平 divider → VSplitView（上下布局）→ 主轴是 height
    private var isHorizontalLayout: Bool {
        observedSplitView?.isVertical ?? true
    }

    private func applySavedRatioIfNeeded() {
        guard !didApplySavedValue else { return }
        guard let splitView = observedSplitView else { return }
        let idx = columnIndex
        guard idx >= 0, splitView.arrangedSubviews.count > idx, splitView.arrangedSubviews.count >= 2 else { return }

        // 从 LayoutVM 读取比例（由 LayoutPlugin 在启动时从磁盘恢复）
        let savedRatio = RootViewContainer.shared.layoutVM.layoutRatios[storageKey]
        guard let savedRatio, savedRatio > 0.0, savedRatio < 1.0 else {
            scheduleApplyRetry()
            return
        }

        pendingApplyRetryWorkItem?.cancel()
        pendingApplyRetryWorkItem = nil

        let isLastColumn = idx == splitView.arrangedSubviews.count - 1

        DispatchQueue.main.async { [weak self, weak splitView] in
            guard let self, let splitView else { return }
            guard splitView.arrangedSubviews.count > self.columnIndex else { return }
            let total = self.primarySize(of: splitView.bounds)
            guard total > 0 else {
                self.scheduleApplyRetry()
                return
            }

            let dividersCount = splitView.arrangedSubviews.count - 1
            let usableSize = max(1, total - CGFloat(dividersCount) * splitView.dividerThickness)

            let targetSize = max(Self.minimumColumnSize, min(usableSize - Self.minimumColumnSize, usableSize * savedRatio))

            let dividerIndex: Int
            let position: CGFloat

            if isLastColumn {
                dividerIndex = max(0, self.columnIndex - 1)
                position = max(
                    Self.minimumColumnSize,
                    total - targetSize - splitView.dividerThickness
                )
            } else {
                dividerIndex = self.columnIndex

                var nextPosition: CGFloat = 0
                for i in 0..<dividerIndex {
                    nextPosition += self.childPrimarySize(of: splitView.arrangedSubviews[i].frame)
                    nextPosition += splitView.dividerThickness
                }
                nextPosition += targetSize
                position = nextPosition
            }

            splitView.setPosition(position, ofDividerAt: dividerIndex)
            self.didApplySavedValue = true
        }
    }

    private func persistCurrentRatio() {
        guard let splitView = observedSplitView else { return }
        let idx = columnIndex
        guard idx >= 0, splitView.arrangedSubviews.count > idx, splitView.arrangedSubviews.count >= 2 else { return }

        let total = primarySize(of: splitView.bounds)
        guard total > 0 else { return }

        let dividersCount = splitView.arrangedSubviews.count - 1
        let usableSize = total - CGFloat(dividersCount) * splitView.dividerThickness
        guard usableSize > 1 else { return }

        let columnSizeValue = childPrimarySize(of: splitView.arrangedSubviews[idx].frame)
        let ratio = columnSizeValue / usableSize
        guard ratio > 0.0, ratio < 1.0 else { return }

        // 写入 LayoutVM（LayoutPlugin 会观察变化并持久化到磁盘）
        RootViewContainer.shared.layoutVM.setLayoutRatio(ratio, forKey: storageKey)
    }

    // MARK: - Size Helpers

    /// 获取 SplitView 主轴方向的总尺寸
    /// - HSplitView (isVertical=true)  → width
    /// - VSplitView (isVertical=false) → height
    private func primarySize(of bounds: CGRect) -> CGFloat {
        isHorizontalLayout ? bounds.width : bounds.height
    }

    /// 获取子视图在主轴方向的尺寸
    private func childPrimarySize(of frame: CGRect) -> CGFloat {
        isHorizontalLayout ? frame.width : frame.height
    }

    private func scheduleRetryAttach() {
        pendingRetryWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.attachIfNeeded()
        }
        pendingRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func scheduleApplyRetry() {
        guard !didApplySavedValue else { return }
        guard applyRetryCount < Self.maxApplyRetryCount else {
            return
        }

        pendingApplyRetryWorkItem?.cancel()
        applyRetryCount += 1

        let workItem = DispatchWorkItem { [weak self] in
            self?.applySavedRatioIfNeeded()
        }
        pendingApplyRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
}
