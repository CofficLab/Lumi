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
        var current: NSView? = self
        while let node = current {
            if let sv = node as? NSSplitView { return sv }
            if let parent = node.superview {
                for sibling in parent.subviews where sibling !== node {
                    if let found = findSplitViewRecursive(in: sibling) {
                        return found
                    }
                }
            }
            current = node.superview
        }
        return nil
    }

    private func findSplitViewRecursive(in view: NSView?) -> NSSplitView? {
        guard let view = view else { return nil }
        if let sv = view as? NSSplitView { return sv }
        for subview in view.subviews {
            if let found = findSplitViewRecursive(in: subview) { return found }
        }
        return nil
    }
}

// MARK: - SplitView Width Persistence

/// 为 SplitView 增加显式宽度记忆（比例），用于下次主动恢复。
///
/// 支持指定 `columnIndex`，控制 SplitView 中第几个子视图的宽度比例。
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
/// ```
struct SplitViewWidthPersistence: NSViewRepresentable {
    let storageKey: String
    /// 控制第几个子视图的宽度比例（默认 0，向后兼容）
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

    /// 所有栏的最小保护宽度
    static let minimumColumnWidth: CGFloat = 48

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
        guard let splitView = findSplitView() else {
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
            let total = splitView.bounds.width
            guard total > 0 else {
                self.scheduleApplyRetry()
                return
            }

            let dividersCount = splitView.arrangedSubviews.count - 1
            let usableWidth = max(1, total - CGFloat(dividersCount) * splitView.dividerThickness)

            // 计算此栏之前所有栏占用的宽度（从 ratio 推算）
            let targetWidth = max(Self.minimumColumnWidth, min(usableWidth - Self.minimumColumnWidth, usableWidth * savedRatio))

            let dividerIndex: Int
            let position: CGFloat

            if isLastColumn {
                // 最后一栏没有“右侧 divider”，需要移动它左边那个 divider。
                dividerIndex = max(0, self.columnIndex - 1)
                position = max(
                    Self.minimumColumnWidth,
                    total - targetWidth - splitView.dividerThickness
                )
            } else {
                // 非最后一栏：移动该栏右侧的 divider。
                dividerIndex = self.columnIndex

                var nextPosition: CGFloat = 0
                for i in 0..<dividerIndex {
                    // 前面尚未恢复的栏使用当前实际宽度
                    nextPosition += splitView.arrangedSubviews[i].frame.width
                    nextPosition += splitView.dividerThickness
                }
                nextPosition += targetWidth
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

        let total = splitView.bounds.width
        guard total > 0 else { return }

        let dividersCount = splitView.arrangedSubviews.count - 1
        let usableWidth = total - CGFloat(dividersCount) * splitView.dividerThickness
        guard usableWidth > 1 else { return }

        let columnWidth = splitView.arrangedSubviews[idx].frame.width
        let ratio = columnWidth / usableWidth
        guard ratio > 0.0, ratio < 1.0 else { return }

        // 写入 LayoutVM（LayoutPlugin 会观察变化并持久化到磁盘）
        RootViewContainer.shared.layoutVM.setLayoutRatio(ratio, forKey: storageKey)
    }

    private func findSplitView() -> NSSplitView? {
        var current: NSView? = self
        while let node = current {
            if let sv = node as? NSSplitView { return sv }
            if let parent = node.superview {
                for sibling in parent.subviews where sibling !== node {
                    if let found = findSplitViewRecursive(in: sibling) {
                        return found
                    }
                }
            }
            current = node.superview
        }
        return nil
    }

    private func findSplitViewRecursive(in view: NSView?) -> NSSplitView? {
        guard let view else { return nil }
        if let sv = view as? NSSplitView { return sv }
        for subview in view.subviews {
            if let found = findSplitViewRecursive(in: subview) {
                return found
            }
        }
        return nil
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
