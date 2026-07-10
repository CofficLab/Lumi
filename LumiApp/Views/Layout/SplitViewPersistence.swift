import AppKit
import SuperLogKit
import LumiCoreKit
import os
import SwiftUI

struct SplitDimensionConstraints: Equatable {
    var defaultSize: CGFloat
    var minSize: CGFloat
    var maxSize: CGFloat
    var minimumOppositeSize: CGFloat

    static let rail = SplitDimensionConstraints(
        defaultSize: 240,
        minSize: 180,
        maxSize: 480,
        minimumOppositeSize: 280
    )

    static let bottomPanel = SplitDimensionConstraints(
        defaultSize: 200,
        minSize: 80,
        maxSize: 600,
        minimumOppositeSize: 120
    )

    static func chatSection(_ layout: LumiChatSectionLayout) -> SplitDimensionConstraints {
        SplitDimensionConstraints(
            defaultSize: layout.defaultWidth,
            minSize: layout.minWidth,
            maxSize: layout.maximumWidth,
            minimumOppositeSize: layout.minimumRemainingWidth
        )
    }
}

/// 分栏尺寸的访问层。
///
/// 视图层不直接读写磁盘或插件存储，而是通过此闭包桥接与 `LumiLayoutState` 交互：
/// - `readInitialSize`: 从内核状态读取上一次保存的尺寸（无值时返回 nil，由调用方回退到默认值）
/// - `persist`: 把用户拖拽后的尺寸写回内核状态（内核变更会发通知，由插件负责落盘）
///
/// 这样 `SplitDimensionPersistenceView`（一个 NSView）无需持有 `ObservableObject`，
/// 也不依赖 SwiftUI 的观察机制，保持与 AppKit 的交互方式不变。
///
/// 两个闭包均标记 `@MainActor`，因为它们最终调用 `LumiLayoutState`（`@MainActor`）的方法。
struct SplitDimensionAccess {
    let readInitialSize: @MainActor () -> CGFloat?
    let persist: @MainActor (CGFloat) -> Void
    /// 调试用角色标识，用于日志区分 rail / chatSection / bottomPanel。
    let debugRole: String
}

/// 描述一个分栏尺寸的角色，用于在视图层语义化地选择读写哪一类尺寸。
enum SplitDimensionRole {
    case rail(viewContainerID: String)
    case bottomPanelHeight(viewContainerID: String)
    case chatSectionWidth(viewContainerID: String, layout: LumiChatSectionLayout)
}

extension SplitDimensionRole {
    /// 基于该角色与内核 `layoutState` 构造读写桥接。
    @MainActor
    func makeAccess(layoutState: LumiLayoutState) -> SplitDimensionAccess {
        switch self {
        case let .rail(viewContainerID):
            return SplitDimensionAccess(
                readInitialSize: { layoutState.storedRailWidth(for: viewContainerID) },
                persist: { layoutState.setRailWidth($0, for: viewContainerID) },
                debugRole: "rail[\(viewContainerID)]"
            )
        case let .bottomPanelHeight(viewContainerID):
            return SplitDimensionAccess(
                readInitialSize: { layoutState.storedBottomPanelHeight(for: viewContainerID) },
                persist: { layoutState.setBottomPanelHeight($0, for: viewContainerID) },
                debugRole: "bottomPanel[\(viewContainerID)]"
            )
        case let .chatSectionWidth(viewContainerID, layout):
            return SplitDimensionAccess(
                readInitialSize: { layoutState.storedChatSectionWidth(for: viewContainerID, layout: layout) },
                persist: { layoutState.setChatSectionWidth($0, for: viewContainerID, layout: layout) },
                debugRole: "chatSection[\(viewContainerID).\(layout.persistenceKeySuffix)]"
            )
        }
    }
}

struct SplitViewAutosaveConfigurator: NSViewRepresentable {
    let autosaveName: String

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            enclosingSplitView(from: nsView)?.autosaveName = autosaveName
        }
    }
}

struct SplitDimensionPersistence: NSViewRepresentable {
    enum Axis: CustomStringConvertible {
        case horizontal
        case vertical

        var description: String {
            switch self {
            case .horizontal: return "horizontal"
            case .vertical: return "vertical"
            }
        }
    }

    let access: SplitDimensionAccess
    let constraints: SplitDimensionConstraints
    let axis: Axis

    func makeNSView(context: Context) -> SplitDimensionPersistenceView {
        SplitDimensionPersistenceView(
            access: access,
            constraints: constraints,
            axis: axis
        )
    }

    func updateNSView(_ nsView: SplitDimensionPersistenceView, context: Context) {
        nsView.updateConfiguration(
            access: access,
            constraints: constraints,
            axis: axis
        )
    }

    static func dismantleNSView(_ nsView: SplitDimensionPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

struct SplitViewWidthPersistence: NSViewRepresentable {
    let layoutState: LumiLayoutState
    let viewContainerID: String
    var constraints: SplitDimensionConstraints = .rail

    private var access: SplitDimensionAccess {
        SplitDimensionRole.rail(viewContainerID: viewContainerID).makeAccess(layoutState: layoutState)
    }

    func makeNSView(context: Context) -> SplitDimensionPersistenceView {
        SplitDimensionPersistenceView(
            access: access,
            constraints: constraints,
            axis: .horizontal
        )
    }

    func updateNSView(_ nsView: SplitDimensionPersistenceView, context: Context) {
        nsView.updateConfiguration(
            access: access,
            constraints: constraints,
            axis: .horizontal
        )
    }

    static func dismantleNSView(_ nsView: SplitDimensionPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

struct ChatSectionWidthPersistence: NSViewRepresentable {
    let layoutState: LumiLayoutState
    let viewContainerID: String
    let layout: LumiChatSectionLayout

    private var access: SplitDimensionAccess {
        SplitDimensionRole.chatSectionWidth(viewContainerID: viewContainerID, layout: layout)
            .makeAccess(layoutState: layoutState)
    }

    func makeNSView(context: Context) -> SplitDimensionPersistenceView {
        SplitDimensionPersistenceView(
            access: access,
            constraints: .chatSection(layout),
            axis: .horizontal
        )
    }

    func updateNSView(_ nsView: SplitDimensionPersistenceView, context: Context) {
        nsView.updateConfiguration(
            access: access,
            constraints: .chatSection(layout),
            axis: .horizontal
        )
    }

    static func dismantleNSView(_ nsView: SplitDimensionPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

struct SplitViewHeightPersistence: NSViewRepresentable {
    static let minimumHeight = SplitDimensionConstraints.bottomPanel.minSize
    static let maximumHeight = SplitDimensionConstraints.bottomPanel.maxSize
    static let minimumOppositeHeight = SplitDimensionConstraints.bottomPanel.minimumOppositeSize

    let layoutState: LumiLayoutState
    let viewContainerID: String
    var constraints: SplitDimensionConstraints = .bottomPanel

    private var access: SplitDimensionAccess {
        SplitDimensionRole.bottomPanelHeight(viewContainerID: viewContainerID)
            .makeAccess(layoutState: layoutState)
    }

    func makeNSView(context: Context) -> SplitDimensionPersistenceView {
        SplitDimensionPersistenceView(
            access: access,
            constraints: constraints,
            axis: .vertical
        )
    }

    func updateNSView(_ nsView: SplitDimensionPersistenceView, context: Context) {
        nsView.updateConfiguration(
            access: access,
            constraints: constraints,
            axis: .vertical
        )
    }

    static func dismantleNSView(_ nsView: SplitDimensionPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

/// 轻量级 NSSplitViewDelegate，在分割线拖拽结束时回调。
/// 使用 weak 持有 SplitDimensionPersistenceView，避免循环引用。
/// 注意：SwiftUI 的 HSplitView/VSplitView 内部由 NSSplitViewController 管理，
/// 不能直接设置 delegate。所以我们用本地事件监控来检测拖拽结束。
@MainActor
final class SplitViewResizeDelegate: NSObject {
    weak var target: SplitDimensionPersistenceView?
    private var eventMonitor: Any?
    private weak var trackedSplitView: NSSplitView?
    private var isDragging = false

    func startTracking(_ splitView: NSSplitView) {
        trackedSplitView = splitView
        
        // 监控左键按下事件：检测是否开始拖拽分割线
        let downMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let trackedSplitView else { return event }
            let locationInWindow = event.locationInWindow
            let location = trackedSplitView.convert(locationInWindow, from: nil)
            
            // 检查是否点击在分割线附近（容差范围内）
            for i in 0..<trackedSplitView.arrangedSubviews.count - 1 {
                if let dividerRect = self.dividerRect(at: i, in: trackedSplitView) {
                    // 扩大容差范围到 10 个点
                    let expandedRect = dividerRect.insetBy(dx: -10, dy: -10)
                    if expandedRect.contains(location) {
                        self.isDragging = true
                        break
                    }
                }
            }
            return event
        }
        
        // 监控左键松开事件：如果之前在拖拽，则触发保存
        let upMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self else { return event }
            if self.isDragging {
                self.isDragging = false
                // 拖拽结束，持久化当前尺寸
                self.target?.persistCurrentSize()
            }
            return event
        }
        
        // 将两个 monitor 保存在一起
        eventMonitor = [downMonitor, upMonitor]
    }

    func stopTracking() {
        if let monitors = eventMonitor as? [Any] {
            for monitor in monitors {
                NSEvent.removeMonitor(monitor)
            }
        }
        eventMonitor = nil
        trackedSplitView = nil
        isDragging = false
    }
    
    private func dividerRect(at index: Int, in splitView: NSSplitView) -> CGRect? {
        guard index < splitView.arrangedSubviews.count - 1 else { return nil }
        
        let thickness = splitView.dividerThickness
        var position: CGFloat = 0
        
        if splitView.isVertical {
            // 水平分割线（垂直布局）
            for i in 0...index {
                if i == index {
                    return CGRect(x: position, y: 0, width: thickness, height: splitView.bounds.height)
                }
                position += splitView.arrangedSubviews[i].frame.width + thickness
            }
        } else {
            // 垂直分割线（水平布局）
            for i in 0...index {
                if i == index {
                    return CGRect(x: 0, y: position, width: splitView.bounds.width, height: thickness)
                }
                position += splitView.arrangedSubviews[i].frame.height + thickness
            }
        }
        return nil
    }
}

@MainActor
final class SplitDimensionPersistenceView: NSView, SuperLog {
    nonisolated static let emoji = "📐"
    nonisolated static let verbose = true
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "split-view.persistence")
    private static let maxApplyRetryCount = 20

    private var access: SplitDimensionAccess
    private var dimensionConstraints: SplitDimensionConstraints
    private var axis: SplitDimensionPersistence.Axis

    private weak var observedSplitView: NSSplitView?
    private var resizeObserver: NSObjectProtocol?
    private var didApplySize = false
    private var applyRetryCount = 0
    private var pendingRetryWorkItem: DispatchWorkItem?
    /// 上一次回写到内核的尺寸，用于在拖拽过程中抑制重复通知。
    private var lastPersistedSize: CGFloat?
    /// 代理对象，用于接收 NSSplitView 的 delegate 方法。
    private var splitViewDelegate: SplitViewResizeDelegate?

    init(
        access: SplitDimensionAccess,
        constraints: SplitDimensionConstraints,
        axis: SplitDimensionPersistence.Axis
    ) {
        self.access = access
        self.dimensionConstraints = constraints
        self.axis = axis
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateConfiguration(
        access: SplitDimensionAccess,
        constraints: SplitDimensionConstraints,
        axis: SplitDimensionPersistence.Axis
    ) {
        let constraintsChanged = self.dimensionConstraints != constraints || self.axis != axis
        self.access = access
        self.dimensionConstraints = constraints
        self.axis = axis
        // 闭包无法比较相等性：只要约束或轴向变化就重新应用一次，
        // 否则保持已应用状态，避免在 SwiftUI 频繁重渲染时反复重置用户拖拽后的尺寸。
        guard constraintsChanged else { return }
        didApplySize = false
        lastPersistedSize = nil
        if Self.verbose {
            Self.logger.info("\(self.t)config updated")
        }
        applySizeIfPossible()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if Self.verbose {
            Self.logger.info("\(self.t)view moved to window")
        }
        attachIfPossible()
    }

    func detach() {
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
            self.resizeObserver = nil
        }
        splitViewDelegate?.stopTracking()
        splitViewDelegate = nil
        pendingRetryWorkItem?.cancel()
        pendingRetryWorkItem = nil
        observedSplitView = nil
    }

    private func attachIfPossible() {
        guard window != nil else {
            if Self.verbose {
                Self.logger.info("\(self.t)no window yet")
            }
            return
        }
        guard let splitView = enclosingSplitView() else {
            if Self.verbose {
                Self.logger.info("\(self.t)\(self.access.debugRole) no enclosing split view, retry=\(self.applyRetryCount)")
                if self.applyRetryCount == 0 {
                    var chain: [String] = []
                    var current: NSView? = self
                    while let view = current {
                        chain.append("\(type(of: view))")
                        current = view.superview
                    }
                    Self.logger.info("\(self.t)\(self.access.debugRole) superview chain: \(chain.joined(separator: " → "))")
                }
            }
            scheduleRetry()
            return
        }
        guard splitView !== observedSplitView else {
            if Self.verbose {
                Self.logger.info("\(self.t)already attached to same split view")
            }
            applySizeIfPossible()
            return
        }

        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }

        observedSplitView = splitView
        didApplySize = false
        applyRetryCount = 0

        // 使用本地事件监控代替 NSSplitViewDelegate，
        // 因为 SwiftUI 的 HSplitView/VSplitView 内部由 NSSplitViewController 管理，
        // 不能直接设置 delegate。
        let delegate = SplitViewResizeDelegate()
        delegate.target = self
        delegate.startTracking(splitView)
        splitViewDelegate = delegate

        if Self.verbose {
            Self.logger.info("\(self.t)attached \(self.access.debugRole) to split view, vertical=\(splitView.isVertical)")
        }
        applySizeIfPossible()

        // 保留通知 observer 作为备份（处理程序化 resize）
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: splitView,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if Self.verbose {
                    Self.logger.info("\(Self.t)\(self.access.debugRole) [resizeNotification] didResizeSubviews fired")
                }
                self.persistCurrentSize()
            }
        }
    }

    private func applySizeIfPossible() {
        guard !didApplySize else {
            if Self.verbose {
                Self.logger.info("\(self.t)already applied, skipping")
            }
            return
        }
        guard let splitView = observedSplitView ?? enclosingSplitView() else {
            if Self.verbose {
                Self.logger.info("\(self.t)no split view found")
            }
            scheduleRetry()
            return
        }
        let paneIndex = containingPaneIndex(in: splitView)
        guard paneIndex != nil,
              splitView.arrangedSubviews.count >= 2,
              splitView.isVertical == (axis == .horizontal)
        else {
            if Self.verbose {
                Self.logger.info("\(self.t)\(self.access.debugRole) guard failed: pane=\(paneIndex.map { "\($0)" } ?? "nil"), arrangedCount=\(splitView.arrangedSubviews.count), isVertical=\(splitView.isVertical), axis=\(self.axis)")
            }
            scheduleRetry()
            return
        }

        let totalSize = axis == .horizontal ? splitView.bounds.width : splitView.bounds.height
        guard totalSize > 0 else {
            if Self.verbose {
                Self.logger.info("\(self.t)totalSize is zero")
            }
            scheduleRetry()
            return
        }

        // 从内核状态读取上一次保存的尺寸；无值时回退到约束默认值。
        let savedSize = access.readInitialSize()
        let requestedSize = savedSize ?? dimensionConstraints.defaultSize
        let targetSize = clampedSize(
            requestedSize,
            totalSize: totalSize,
            dividerCount: splitView.arrangedSubviews.count - 1,
            dividerThickness: splitView.dividerThickness
        )

        if Self.verbose {
            Self.logger.info("\(self.t)\(self.access.debugRole) [applySize] axis=\(self.axis), paneIndex=\(paneIndex ?? -1), arrangedCount=\(splitView.arrangedSubviews.count), totalSize=\(totalSize), savedSize=\(savedSize.map { String(describing: $0) } ?? "nil"), defaultSize=\(self.dimensionConstraints.defaultSize), requestedSize=\(requestedSize), targetSize=\(targetSize)")
        }

        guard let idx = paneIndex else { return }

        // 延迟到下一个 RunLoop 执行，避免在 SwiftUI 布局过程中 setPosition 被覆盖
        DispatchQueue.main.async { [weak self, weak splitView] in
            guard let self, let splitView, !self.didApplySize else {
                if Self.verbose {
                    Self.logger.info("[applySize] \(self?.access.debugRole ?? "") skipped in async block, didApplySize=\(self?.didApplySize ?? true)")
                }
                return
            }
            self.setPane(idx, size: targetSize, in: splitView)
            splitView.layoutSubtreeIfNeeded()
            self.didApplySize = true
            if Self.verbose {
                Self.logger.info("\(self.t)\(self.access.debugRole) [applySize] DONE, paneIndex=\(idx), size=\(targetSize)")
            }
        }
    }

    func persistCurrentSize() {
        guard let splitView = observedSplitView else {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(self.access.debugRole) [persist] guard failed: observedSplitView is nil")
            }
            return
        }
        guard let paneIndex = containingPaneIndex(in: splitView) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(self.access.debugRole) [persist] guard failed: containingPaneIndex is nil")
            }
            return
        }
        guard splitView.arrangedSubviews.count > paneIndex else {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(self.access.debugRole) [persist] guard failed: arrangedSubviews.count=\(splitView.arrangedSubviews.count) <= paneIndex=\(paneIndex)")
            }
            return
        }
        guard splitView.isVertical == (axis == .horizontal) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(self.access.debugRole) [persist] guard failed: isVertical=\(splitView.isVertical), axis=\(self.axis)")
            }
            return
        }

        let paneSize = axis == .horizontal
            ? splitView.arrangedSubviews[paneIndex].frame.width
            : splitView.arrangedSubviews[paneIndex].frame.height
        guard paneSize.isFinite, paneSize >= dimensionConstraints.minSize else {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(self.access.debugRole) [persist] guard failed: paneSize=\(paneSize), minSize=\(self.dimensionConstraints.minSize)")
            }
            return
        }

        let clamped = min(max(paneSize, dimensionConstraints.minSize), dimensionConstraints.maxSize)
        // 仅当与上次回写的值有实际差异时才写回内核，避免拖拽过程中产生大量重复通知。
        let lastWritten = lastPersistedSize
        guard lastWritten.map({ abs($0 - clamped) > 0.5 }) ?? true else {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(self.access.debugRole) [persist] skipped: clamped=\(clamped) ~= lastWritten=\(lastWritten ?? -1)")
            }
            return
        }
        lastPersistedSize = clamped
        access.persist(clamped)
        if Self.verbose {
            Self.logger.info("\(self.t)\(self.access.debugRole) persisted size, old=\(lastWritten.map { "\($0)" } ?? "nil"), new=\(clamped)")
        }
    }

    private func clampedSize(
        _ requestedSize: CGFloat,
        totalSize: CGFloat,
        dividerCount: Int,
        dividerThickness: CGFloat
    ) -> CGFloat {
        let dividersSize = CGFloat(dividerCount) * dividerThickness
        let usableSize = max(1, totalSize - dividersSize)
        let maximumAvailableSize = max(
            dimensionConstraints.minSize,
            usableSize - dimensionConstraints.minimumOppositeSize
        )
        return min(
            max(requestedSize, dimensionConstraints.minSize),
            min(dimensionConstraints.maxSize, maximumAvailableSize)
        )
    }

    private func setPane(_ paneIndex: Int, size: CGFloat, in splitView: NSSplitView) {
        let dividerIndex: Int
        let position: CGFloat
        let totalSize = axis == .horizontal ? splitView.bounds.width : splitView.bounds.height

        if paneIndex == splitView.arrangedSubviews.count - 1 {
            dividerIndex = max(0, paneIndex - 1)
            position = max(
                dimensionConstraints.minimumOppositeSize,
                totalSize - size - splitView.dividerThickness
            )
        } else if axis == .vertical {
            dividerIndex = max(0, paneIndex - 1)
            position = max(
                dimensionConstraints.minimumOppositeSize,
                totalSize - size - splitView.dividerThickness
            )
        } else {
            dividerIndex = paneIndex
            var nextPosition: CGFloat = 0
            for index in 0..<dividerIndex {
                nextPosition += splitView.arrangedSubviews[index].frame.width
                nextPosition += splitView.dividerThickness
            }
            nextPosition += size
            position = nextPosition
        }

        splitView.setPosition(position, ofDividerAt: dividerIndex)
    }

    private func containingPaneIndex(in splitView: NSSplitView) -> Int? {
        splitView.arrangedSubviews.firstIndex { arrangedSubview in
            isContained(in: arrangedSubview)
        }
    }

    private func isContained(in candidateAncestor: NSView) -> Bool {
        var current: NSView? = self
        while let view = current {
            if view === candidateAncestor { return true }
            current = view.superview
        }
        return false
    }

    private func enclosingSplitView() -> NSSplitView? {
        var current = superview
        while let view = current {
            if let splitView = view as? NSSplitView {
                // Only return split views whose orientation matches our axis.
                // Horizontal axis (width persistence) → isVertical == true
                // Vertical axis (height persistence) → isVertical == false
                if splitView.isVertical == (axis == .horizontal) {
                    return splitView
                }
            }
            current = view.superview
        }
        return nil
    }

    private func scheduleRetry() {
        guard applyRetryCount < Self.maxApplyRetryCount else { return }
        pendingRetryWorkItem?.cancel()
        applyRetryCount += 1

        let workItem = DispatchWorkItem { [weak self] in
            self?.attachIfPossible()
        }
        pendingRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
}

@MainActor
private func enclosingSplitView(from view: NSView) -> NSSplitView? {
    var current = view.superview
    while let view = current {
        if let splitView = view as? NSSplitView {
            return splitView
        }
        current = view.superview
    }
    return nil
}
