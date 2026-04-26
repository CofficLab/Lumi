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
/// 用法：
/// ```swift
/// HSplitView {
///     MyView()
///         .background(SplitViewWidthPersistence(storageKey: "Split.MyPanel.MyView"))
///     OtherView()
/// }
/// ```
struct SplitViewWidthPersistence: NSViewRepresentable {
    let storageKey: String

    func makeNSView(context: Context) -> SplitViewWidthPersistenceView {
        SplitViewWidthPersistenceView(storageKey: storageKey)
    }

    func updateNSView(_ nsView: SplitViewWidthPersistenceView, context: Context) {
        nsView.storageKey = storageKey
        nsView.attachIfNeeded()
    }
}

final class SplitViewWidthPersistenceView: NSView {
    var storageKey: String
    private var observedSplitView: NSSplitView?
    private var resizeObserver: NSObjectProtocol?
    private var didApplySavedValue = false
    private var pendingRetryWorkItem: DispatchWorkItem?

    init(storageKey: String) {
        self.storageKey = storageKey
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
        observedSplitView = splitView
        didApplySavedValue = false

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
        guard splitView.arrangedSubviews.count >= 2 else { return }

        let savedRatio = UserDefaults.standard.double(forKey: storageKey)
        guard savedRatio > 0.0, savedRatio < 1.0 else {
            didApplySavedValue = true
            return
        }

        DispatchQueue.main.async { [weak self, weak splitView] in
            guard let self, let splitView else { return }
            guard splitView.arrangedSubviews.count >= 2 else { return }
            let total = splitView.bounds.width
            guard total > 0 else { return }

            let dividerThickness = splitView.dividerThickness
            let usableWidth = max(1, total - dividerThickness)
            let target = max(0, min(usableWidth, usableWidth * savedRatio))
            splitView.setPosition(target, ofDividerAt: 0)
            self.didApplySavedValue = true
        }
    }

    private func persistCurrentRatio() {
        guard let splitView = observedSplitView else { return }
        guard splitView.arrangedSubviews.count >= 2 else { return }

        let total = splitView.bounds.width
        guard total > 0 else { return }

        let usableWidth = total - splitView.dividerThickness
        guard usableWidth > 1 else { return }

        let firstWidth = splitView.arrangedSubviews[0].frame.width
        let ratio = firstWidth / usableWidth
        guard ratio > 0.0, ratio < 1.0 else { return }

        UserDefaults.standard.set(ratio, forKey: storageKey)
    }

    private func findSplitView() -> NSSplitView? {
        var current: NSView? = self
        while let node = current {
            if let sv = node as? NSSplitView { return sv }
            current = node.superview
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
}
