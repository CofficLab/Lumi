import Combine
import CoreGraphics
import Foundation
import LumiKernel
import os
import SuperLogKit
import SwiftUI

/// 工作区服务实现
///
/// 同时承担两职责（合并自原 LayoutProviding + UIManaging）：
/// 1. **布局几何**——工作区可见性、视图容器、rail/bottom tab 选中、分隔条位置；
///    持久化由 LayoutStore 负责，在状态变更时 debounce 0.3s 自动保存。
/// 2. **插件 UI 贡献注册表**——聚合各插件向标题栏/聊天分区/状态栏/面板/菜单栏/
///    根覆盖层贡献的组件，按 order 排序后供视图层 reactive 读取。
///
/// 布局状态原存放在独立的 `LayoutState` 类里，再经 Combine 转发到本服务。
/// 现已内联：所有 `@Published` 状态直接长在本类上，`objectWillChange` 天然连通
/// kernel → 视图，不再需要中间转发层（少一处"信号丢失导致 UI 不刷新"的隐患）。
@MainActor
public final class LayoutManager: WorkspaceProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout.service")
    nonisolated public static let emoji = "📐"
    nonisolated static let verbose = false

    // MARK: - Persistence

    /// 布局持久化存储
    private let store: LayoutStore

    /// 持久化数据目录（`layout-info.json` 所在的 settings 子目录）。
    /// 供设置视图等外部消费者展示/打开数据目录用。
    public var settingsDirectory: URL { store.settingsDirectory }

    /// 持久化订阅：任一布局状态变更后，debounce 0.3s 自动落盘。
    ///
    /// 这样无论 rail/bottom tab 是经协议写入还是视图直接改，都能可靠地持久化到
    /// 磁盘，避免漏存；debounce 也合并高频变更（如连续切换 tab）成一次写入。
    private var persistenceSubscription: AnyCancellable?

    // MARK: - Active Container

    @Published public var activeViewContainerID: String? {
        didSet {
            guard activeViewContainerID != oldValue else { return }
            let value = activeViewContainerID
            if Self.verbose {
                Self.logger.info("\(Self.t)[ActivityBarTrace] activeViewContainerID old=\(oldValue ?? "nil", privacy: .public) new=\(value ?? "nil", privacy: .public)")
            }
            NotificationCenter.postActiveViewContainerIDDidChange(containerID: value)
        }
    }

    public var currentViewContainer: ViewContainerItem? {
        guard let id = activeViewContainerID else { return nil }
        return viewContainer(id: id)
    }

    // MARK: - Visibility (global runtime flags)

    @Published public var chatSectionVisible: Bool = true {
        didSet {
            guard chatSectionVisible != oldValue else { return }
            let value = chatSectionVisible
            if Self.verbose {
                Self.logger.info("\(Self.t)chatSectionVisible → \(value)")
            }
            NotificationCenter.postChatSectionVisibleDidChange(visible: value)
        }
    }

    @Published public var bottomPanelVisible: Bool = true {
        didSet {
            guard bottomPanelVisible != oldValue else { return }
            let value = bottomPanelVisible
            if Self.verbose {
                Self.logger.info("\(Self.t)bottomPanelVisible → \(value)")
            }
            NotificationCenter.postBottomPanelVisibleDidChange(visible: value)
        }
    }

    /// Rail 视图是否可见
    @Published public var isRailVisible: Bool = true {
        didSet {
            guard isRailVisible != oldValue else { return }
            NotificationCenter.postRailVisibleDidChange(visible: isRailVisible)
        }
    }

    /// Chat 区域是否可见
    @Published public var isChatVisible: Bool = true {
        didSet {
            guard isChatVisible != oldValue else { return }
            // 使用现有的 chatSectionVisible 通知
            NotificationCenter.postChatSectionVisibleDidChange(visible: isChatVisible)
        }
    }

    /// Panel Header 是否可见
    @Published public var isPanelHeaderVisible: Bool = true

    /// Panel Body 是否可见
    @Published public var isPanelBodyVisible: Bool = true

    /// 底部 Panel 底部是否可见
    @Published public var isPanelBottomVisible: Bool = true

    // MARK: - Visibility Overrides (per-container)

    /// 用户手动调整过的可见性覆盖层（键为容器 ID）。
    ///
    /// 解析某容器可见性时的优先级：用户覆盖 > 容器静态声明 > 全局默认(true)。
    /// 这里的值由 `setXxxVisible` 在有激活容器时自动记录。
    @Published private var visibilityOverrides: [String: VisibilityFlags] = [:]

    /// 供持久化序列化使用的只读快照。
    public var visibilityOverridesDictionary: [String: VisibilityFlags] { visibilityOverrides }

    /// 供设置视图等只读消费：查询单个容器的可见性覆盖（nil 表示未调整）。
    public func visibilityOverride(for containerID: String) -> VisibilityFlags? {
        visibilityOverrides[containerID]
    }

    /// 从磁盘恢复覆盖层（不发送通知，启动阶段用）。
    public func restoreVisibilityOverrides(_ overrides: [String: VisibilityFlags]) {
        visibilityOverrides = overrides
    }

    /// 把用户对某开关的调整记录到当前激活容器的覆盖层（若有激活容器）。
    private func recordUserOverride<T>(_ keyPath: WritableKeyPath<VisibilityFlags, T?>, _ value: T) {
        guard let containerID = activeViewContainerID else { return }
        visibilityOverrides[containerID, default: VisibilityFlags()][keyPath: keyPath] = value
    }

    // MARK: - Rail Tabs

    /// 每个 ViewContainer 上次选中的侧边栏 Rail Tab（键为容器 ID，值为 tab ID）。
    /// 对齐底部 tab 的 `activeBottomTabIDs`：同一套 rail tab 在不同容器下各自记忆选中项。
    @Published private var activeRailTabIDs: [String: String] = [:]

    /// 默认 Rail Tab ID，供查询时兜底（实际选中由视图 `ensureValidSelection` 自愈）。
    public static let defaultRailTabID = "explorer"

    /// 查询某容器当前选中的 Rail Tab。
    public func activeRailTabID(for viewContainerID: String) -> String {
        activeRailTabIDs[viewContainerID] ?? Self.defaultRailTabID
    }

    /// 设置某容器选中的 Rail Tab，并发送变更通知。
    public func setActiveRailTabID(_ id: String, for viewContainerID: String) {
        guard activeRailTabIDs[viewContainerID] != id else { return }
        activeRailTabIDs[viewContainerID] = id
        if Self.verbose {
            Self.logger.info("\(Self.t)activeRailTabID[\(viewContainerID)] → \(id)")
        }
        NotificationCenter.postActiveRailTabIDDidChange(containerID: viewContainerID, railTabID: id)
    }

    /// 从磁盘恢复某容器的 Rail Tab（不发送通知）。
    public func restoreActiveRailTabID(_ id: String, for viewContainerID: String) {
        activeRailTabIDs[viewContainerID] = id
    }

    /// 供持久化序列化使用的只读快照。
    public var activeRailTabIDsDictionary: [String: String] { activeRailTabIDs }

    // MARK: - View Containers

    /// 容器注册表（私有）。视图不直接读它，而是经 `allViewContainers` →
    /// `@Published sortedViewContainers` 拿到排序后的快照。
    /// 重要不变量：任何对 `viewContainers` 的写入都必须随后调用
    /// `updateSortedViewContainers()`，否则视图不会刷新。
    private var viewContainers: [String: ViewContainerItem] = [:]
    private var viewContainerOrder: [String] = []
    @Published private var sortedViewContainers: [ViewContainerItem] = []

    /// 所有视图容器（按 order 排序）
    public var allViewContainers: [ViewContainerItem] {
        sortedViewContainers
    }

    /// 按 ID 查询视图容器
    public func viewContainer(id: String) -> ViewContainerItem? {
        viewContainers[id]
    }

    /// 注册视图容器
    public func registerViewContainer(_ container: ViewContainerItem) {
        guard viewContainers[container.id] == nil else { return }
        viewContainers[container.id] = container
        viewContainerOrder.append(container.id)
        updateSortedViewContainers()
        // 若尚无激活容器（典型场景：启动期无持久化值），自动选中排序最靠前的容器。
        // `activeViewContainerID == nil` 守卫保证只赋值一次——持久化恢复的值（在
        // 注册前于 onReady 写入）优先，用户后续手动选择也不会被覆盖。
        if activeViewContainerID == nil, sortedViewContainers.first?.id == container.id {
            activeViewContainerID = container.id
        }
    }

    /// 注销视图容器
    public func unregisterViewContainer(id: String) {
        viewContainers.removeValue(forKey: id)
        viewContainerOrder.removeAll { $0 == id }
        updateSortedViewContainers()
    }

    private func updateSortedViewContainers() {
        sortedViewContainers = viewContainerOrder.compactMap { viewContainers[$0] }
            .sorted { $0.order < $1.order }
    }

    // MARK: - Container Observers

    private var containerObservers: [(String) -> Void] = []

    public func addContainerObserver(_ observer: @escaping (String) -> Void) {
        containerObservers.append(observer)
    }

    @Published public private(set) var bottomPanelFocusGeneration = 0

    public static let defaultBottomTabID = "editor-bottom-problems"

    @Published private var railDividers: [String: CGFloat] = [:]
    @Published private var chatSectionDividers: [String: CGFloat] = [:]
    @Published private var bottomPanelDividers: [String: CGFloat] = [:]
    @Published private var activeBottomTabIDs: [String: String] = [:]
    @Published private(set) var legacyBottomTabID: String?

    private var panelColumnWidths: [String: CGFloat] = [:]

    private let defaultRailDivider: CGFloat
    private let defaultChatSectionDivider: CGFloat
    private let defaultBottomPanelDivider: CGFloat

    // MARK: - Initialization

    public init(
        store: LayoutStore,
        defaultRailDivider: CGFloat = 240,
        defaultChatSectionDivider: CGFloat = 320,
        defaultBottomPanelDivider: CGFloat = 400
    ) {
        self.store = store
        self.defaultRailDivider = defaultRailDivider
        self.defaultChatSectionDivider = defaultChatSectionDivider
        self.defaultBottomPanelDivider = defaultBottomPanelDivider

        // 任一状态变更后 debounce 0.3s 自动落盘（rail/bottom tab 等）。
        self.persistenceSubscription = objectWillChange
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.saveState()
            }

        if Self.verbose {
            Self.logger.info("\(Self.t)LayoutManager initialized")
        }
    }

    // MARK: - Workspace Commands

    public func setRailVisible(_ visible: Bool) {
        guard (currentViewContainer?.railVisibility ?? .visibleByDefault).allowsUserVisibilityOverride else { return }
        isRailVisible = visible
        recordUserOverride(\.isRailVisible, visible)
    }
    public func setChatVisible(_ visible: Bool) {
        guard (currentViewContainer?.chatVisibility ?? .visibleByDefault).allowsUserVisibilityOverride else { return }
        isChatVisible = visible
        recordUserOverride(\.isChatVisible, visible)
    }
    public func setPanelHeaderVisible(_ visible: Bool) {
        let policy = currentViewContainer?.panelHeaderVisibility ?? .visibleByDefault
        guard policy.allowsUserVisibilityOverride else {
            isPanelHeaderVisible = policy.defaultIsVisible
            return
        }
        isPanelHeaderVisible = visible
        recordUserOverride(\.isPanelHeaderVisible, visible)
    }
    public func setPanelBodyVisible(_ visible: Bool) {
        let policy = currentViewContainer?.panelBodyVisibility ?? .visibleByDefault
        guard policy.allowsUserVisibilityOverride else {
            isPanelBodyVisible = policy.defaultIsVisible
            return
        }
        isPanelBodyVisible = visible
        recordUserOverride(\.isPanelBodyVisible, visible)
    }
    public func setPanelBottomVisible(_ visible: Bool) {
        guard (currentViewContainer?.panelBottomVisibility ?? .visibleByDefault).allowsUserVisibilityOverride else { return }
        isPanelBottomVisible = visible
        recordUserOverride(\.isPanelBottomVisible, visible)
    }

    public func activateContainer(id: String) {
        if Self.verbose {
            Self.logger.info("\(Self.t)[ActivityBarTrace] activateContainer requested=\(id, privacy: .public) active-before=\(self.activeViewContainerID ?? "nil", privacy: .public)")
        }
        activeViewContainerID = id
        applyContainerVisibility(for: id)
        for observer in containerObservers {
            observer(id)
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)[ActivityBarTrace] activateContainer completed=\(id, privacy: .public) active-after=\(self.activeViewContainerID ?? "nil", privacy: .public)")
        }
        // 保存到磁盘
        saveState()
    }

    public func applyContainerVisibility(for id: String) {
        guard let container = viewContainer(id: id) else { return }
        applyResolvedVisibility(for: id, container: container)
    }

    /// 解析某容器的可见性并应用到全局标志（当前激活容器的运行时视图）。
    private func applyResolvedVisibility(for id: String, container: ViewContainerItem) {
        let user = visibilityOverrides[id]
        isRailVisible = container.railVisibility.resolvedVisibility(userOverride: user?.isRailVisible)
        isChatVisible = container.chatVisibility.resolvedVisibility(userOverride: user?.isChatVisible)
        isPanelHeaderVisible = container.panelHeaderVisibility.resolvedVisibility(
            userOverride: user?.isPanelHeaderVisible
        )
        isPanelBodyVisible = container.panelBodyVisibility.resolvedVisibility(
            userOverride: user?.isPanelBodyVisible
        )
        isPanelBottomVisible = container.panelBottomVisibility.resolvedVisibility(userOverride: user?.isPanelBottomVisible)
    }

    // MARK: - Rail Tabs (commands)

    public func presentRailTab(id: String, for viewContainerID: String) {
        setActiveRailTabID(id, for: viewContainerID)
    }

    // MARK: - Bottom Panel

    public func activeBottomTabID(for viewContainerID: String) -> String {
        activeBottomTabIDs[viewContainerID] ?? legacyBottomTabID ?? Self.defaultBottomTabID
    }

    /// 供持久化序列化使用的只读快照。
    public var activeBottomTabIDsDictionary: [String: String] { activeBottomTabIDs }

    public func setActiveBottomTabID(_ id: String, for viewContainerID: String) {
        guard activeBottomTabIDs[viewContainerID] != id else { return }
        activeBottomTabIDs[viewContainerID] = id
        if Self.verbose {
            Self.logger.info("\(Self.t)activeBottomTabID[\(viewContainerID)] → \(id)")
        }
        NotificationCenter.postActiveBottomTabIDDidChange(containerID: viewContainerID, bottomTabID: id)
    }

    public func restoreActiveBottomTabID(_ id: String, for viewContainerID: String) {
        activeBottomTabIDs[viewContainerID] = id
    }

    public func restoreLegacyBottomTabID(_ id: String) {
        legacyBottomTabID = id
    }

    public func presentBottomTab(id: String, viewContainerID: String) {
        setActiveBottomTabID(id, for: viewContainerID)
        bottomPanelFocusGeneration += 1
    }

    // MARK: - Dividers

    public func railDivider(for viewContainerID: String, fallback: CGFloat? = nil) -> CGFloat {
        railDividers[viewContainerID] ?? fallback ?? defaultRailDivider
    }

    public func storedRailDivider(for viewContainerID: String) -> CGFloat? {
        railDividers[viewContainerID]
    }

    public func setRailDivider(_ position: CGFloat, for viewContainerID: String) {
        let clamped = position
        guard railDividers[viewContainerID] != clamped else { return }
        railDividers[viewContainerID] = clamped
        if Self.verbose {
            Self.logger.info("\(Self.t)railDivider[\(viewContainerID)] → \(clamped)")
        }
        logThreeColumnWidths(for: viewContainerID)
        NotificationCenter.postRailDividerDidChange(containerID: viewContainerID, position: clamped)
    }

    public func restoreRailDivider(_ position: CGFloat, for viewContainerID: String) {
        railDividers[viewContainerID] = position
    }

    public func chatSectionDivider(
        for viewContainerID: String,
        layout: LumiChatSectionLayout,
        fallback: CGFloat? = nil
    ) -> CGFloat {
        chatSectionDividers[chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)]
            ?? fallback ?? defaultChatSectionDivider
    }

    public func storedChatSectionDivider(
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> CGFloat? {
        chatSectionDividers[chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)]
    }

    public func setChatSectionDivider(
        _ position: CGFloat,
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) {
        let key = chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)
        guard chatSectionDividers[key] != position else { return }
        chatSectionDividers[key] = position
        if Self.verbose {
            Self.logger.info("\(Self.t)chatSectionDivider[\(viewContainerID).\(layout.persistenceKeySuffix)] → \(position)")
        }
        logThreeColumnWidths(for: viewContainerID)
        NotificationCenter.postChatSectionDividerDidChange(
            containerID: viewContainerID,
            layout: layout.persistenceKeySuffix,
            position: position
        )
    }

    public func restoreChatSectionDivider(
        _ position: CGFloat,
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) {
        chatSectionDividers[chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)] = position
    }

    public func bottomPanelDivider(for viewContainerID: String, fallback: CGFloat? = nil) -> CGFloat {
        bottomPanelDividers[viewContainerID] ?? fallback ?? defaultBottomPanelDivider
    }

    public func storedBottomPanelDivider(for viewContainerID: String) -> CGFloat? {
        bottomPanelDividers[viewContainerID]
    }

    public func setBottomPanelDivider(_ position: CGFloat, for viewContainerID: String) {
        guard bottomPanelDividers[viewContainerID] != position else { return }
        bottomPanelDividers[viewContainerID] = position
        if Self.verbose {
            Self.logger.info("\(Self.t)bottomPanelDivider[\(viewContainerID)] → \(position)")
        }
        NotificationCenter.postBottomPanelDividerDidChange(containerID: viewContainerID, position: position)
    }

    public func restoreBottomPanelDivider(_ position: CGFloat, for viewContainerID: String) {
        bottomPanelDividers[viewContainerID] = position
    }

    private func chatSectionDividerKey(
        viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> String {
        "\(viewContainerID).\(layout.persistenceKeySuffix)"
    }

    public func setPanelColumnWidth(_ width: CGFloat, for viewContainerID: String) {
        guard width > 0 else { return }
        panelColumnWidths[viewContainerID] = width
    }

    public func panelColumnWidth(for viewContainerID: String) -> CGFloat? {
        panelColumnWidths[viewContainerID]
    }

    private func logThreeColumnWidths(for viewContainerID: String) {
        let rail = railDividers[viewContainerID]
        let panel = panelColumnWidths[viewContainerID]
        let middle: CGFloat? = {
            guard let rail, let panel else { return nil }
            return max(0, panel - rail)
        }()
        let chatEntries = chatSectionDividers
            .filter { $0.key.hasPrefix("\(viewContainerID).") }
            .sorted { $0.key < $1.key }
        let chatText: String
        if chatEntries.isEmpty {
            chatText = "n/a"
        } else {
            chatText = chatEntries.map { k, v -> String in
                let suffix = k.replacingOccurrences(of: "\(viewContainerID).", with: "")
                return "\(suffix)=\(String(format: "%.1f", v))"
            }.joined(separator: ",")
        }
        let parts: [String] = [
            rail.map { "rail=\(String(format: "%.1f", $0))" } ?? "rail=n/a",
            middle.map { "middle=\(String(format: "%.1f", $0))" } ?? "middle=n/a",
            "chatDivider=[\(chatText)]",
        ]

        if Self.verbose {
            Self.logger.info("\(Self.t)三栏宽度[\(viewContainerID)]: \(parts.joined(separator: ", "))")
        }
    }

    // MARK: - Persistence

    /// 保存当前状态到磁盘
    private func saveState() {
        let info = LayoutStateInfo(
            activeViewContainerID: activeViewContainerID,
            chatSectionVisible: isChatVisible,
            railVisible: isRailVisible,
            panelBottomVisible: isPanelBottomVisible,
            activeRailTabIDs: activeRailTabIDsDictionary,
            activeBottomTabIDs: activeBottomTabIDsDictionary,
            visibilityOverrides: visibilityOverridesDictionary
        )
        store.saveLayoutInfo(info)
        if Self.verbose {
            Self.logger.info("\(Self.t)saveState: activeViewContainerID=\(info.activeViewContainerID ?? "nil"), railTabs=\(info.activeRailTabIDs.count), bottomTabs=\(info.activeBottomTabIDs.count), visibilityOverrides=\(info.visibilityOverrides.count)")
        }
    }

    // MARK: - Title Toolbar

    public private(set) var allTitleToolbarItems: [TitleToolbarItem] = []

    private var titleToolbarItems: [String: TitleToolbarItem] = [:]
    private var titleToolbarItemOrder: [String] = []

    public func titleToolbarItems(placement: TitleToolbarPlacement) -> [TitleToolbarItem] {
        allTitleToolbarItems
            .filter { $0.placement == placement }
            .sorted {
                if $0.order == $1.order {
                    return $0.id < $1.id
                }
                return $0.order < $1.order
            }
    }

    public func registerTitleToolbarItem(_ item: TitleToolbarItem) {
        if titleToolbarItems[item.id] == nil {
            titleToolbarItemOrder.append(item.id)
        }
        titleToolbarItems[item.id] = item
        updateSortedTitleToolbarItems()
    }

    public func unregisterTitleToolbarItem(id: String) {
        titleToolbarItems.removeValue(forKey: id)
        titleToolbarItemOrder.removeAll { $0 == id }
        updateSortedTitleToolbarItems()
    }

    private func updateSortedTitleToolbarItems() {
        objectWillChange.send()
        allTitleToolbarItems = titleToolbarItemOrder.compactMap { titleToolbarItems[$0] }
            .sorted {
                if $0.order == $1.order {
                    return $0.id < $1.id
                }
                return $0.order < $1.order
            }
    }

    // MARK: - Chat Section

    public private(set) var allChatSectionItems: [ChatSectionItem] = []
    public private(set) var allChatSectionToolbarItems: [ChatSectionToolbarItem] = []
    public private(set) var allChatSectionToolbarBarItems: [ChatSectionToolbarBarItem] = []
    public private(set) var allChatSectionHeaderItems: [ChatSectionHeaderItem] = []
    public private(set) var allChatSectionActionBarItems: [ChatSectionActionBarItem] = []

    private var chatSectionItems: [String: ChatSectionItem] = [:]
    private var chatSectionItemOrder: [String] = []
    private var chatSectionToolbarItems: [String: ChatSectionToolbarItem] = [:]
    private var chatSectionToolbarItemOrder: [String] = []
    private var chatSectionToolbarBars: [String: ChatSectionToolbarBarItem] = [:]
    private var chatSectionToolbarBarOrder: [String] = []
    private var chatSectionHeaders: [String: ChatSectionHeaderItem] = [:]
    private var chatSectionHeaderOrder: [String] = []
    private var chatSectionActionBars: [String: ChatSectionActionBarItem] = [:]
    private var chatSectionActionBarOrder: [String] = []

    public func chatSectionItems(placement: ChatSectionPlacement) -> [ChatSectionItem] {
        allChatSectionItems.filter { $0.placement == placement }
    }

    public func chatSectionToolbarItems(placement: ChatSectionToolbarPlacement) -> [ChatSectionToolbarItem] {
        allChatSectionToolbarItems.filter { $0.placement == placement }
    }

    public func registerChatSectionItem(_ item: ChatSectionItem) {
        if chatSectionItems[item.id] == nil {
            chatSectionItemOrder.append(item.id)
        }
        chatSectionItems[item.id] = item
        updateSortedChatSectionItems()
    }

    public func unregisterChatSectionItem(id: String) {
        chatSectionItems.removeValue(forKey: id)
        chatSectionItemOrder.removeAll { $0 == id }
        updateSortedChatSectionItems()
    }

    public func registerChatSectionToolbarItem(_ item: ChatSectionToolbarItem) {
        if chatSectionToolbarItems[item.id] == nil {
            chatSectionToolbarItemOrder.append(item.id)
        }
        chatSectionToolbarItems[item.id] = item
        updateSortedChatSectionToolbarItems()
    }

    public func unregisterChatSectionToolbarItem(id: String) {
        chatSectionToolbarItems.removeValue(forKey: id)
        chatSectionToolbarItemOrder.removeAll { $0 == id }
        updateSortedChatSectionToolbarItems()
    }

    public func registerChatSectionToolbarBarItem(_ item: ChatSectionToolbarBarItem) {
        if chatSectionToolbarBars[item.id] == nil {
            chatSectionToolbarBarOrder.append(item.id)
        }
        chatSectionToolbarBars[item.id] = item
        updateSortedChatSectionToolbarBars()
    }

    public func unregisterChatSectionToolbarBarItem(id: String) {
        chatSectionToolbarBars.removeValue(forKey: id)
        chatSectionToolbarBarOrder.removeAll { $0 == id }
        updateSortedChatSectionToolbarBars()
    }

    public func registerChatSectionHeaderItem(_ item: ChatSectionHeaderItem) {
        if chatSectionHeaders[item.id] == nil {
            chatSectionHeaderOrder.append(item.id)
        }
        chatSectionHeaders[item.id] = item
        updateSortedChatSectionHeaders()
    }

    public func unregisterChatSectionHeaderItem(id: String) {
        chatSectionHeaders.removeValue(forKey: id)
        chatSectionHeaderOrder.removeAll { $0 == id }
        updateSortedChatSectionHeaders()
    }

    public func registerChatSectionActionBarItem(_ item: ChatSectionActionBarItem) {
        if chatSectionActionBars[item.id] == nil {
            chatSectionActionBarOrder.append(item.id)
        }
        chatSectionActionBars[item.id] = item
        updateSortedChatSectionActionBars()
    }

    public func unregisterChatSectionActionBarItem(id: String) {
        chatSectionActionBars.removeValue(forKey: id)
        chatSectionActionBarOrder.removeAll { $0 == id }
        updateSortedChatSectionActionBars()
    }

    // MARK: - Status Bar

    public private(set) var allStatusBarItems: [StatusBarItem] = []

    private var statusBarItems: [String: StatusBarItem] = [:]
    private var statusBarItemOrder: [String] = []

    public func statusBarItems(placement: StatusBarPlacement) -> [StatusBarItem] {
        allStatusBarItems.filter { $0.placement == placement }
    }

    public func registerStatusBarItem(_ item: StatusBarItem) {
        if statusBarItems[item.id] == nil {
            statusBarItemOrder.append(item.id)
        }
        statusBarItems[item.id] = item
        updateSortedStatusBarItems()
    }

    public func unregisterStatusBarItem(id: String) {
        statusBarItems.removeValue(forKey: id)
        statusBarItemOrder.removeAll { $0 == id }
        updateSortedStatusBarItems()
    }

    private func updateSortedStatusBarItems() {
        objectWillChange.send()
        allStatusBarItems = statusBarItemOrder.compactMap { statusBarItems[$0] }
            .sorted(by: { $0.order < $1.order })
    }

    // MARK: - Panel

    public func registerPanelHeaderItem(_ item: PanelHeaderItem) {
        panelHeaderItems[item.id] = item
        allPanelHeaderItems = Array(panelHeaderItems.values)
    }

    public func unregisterPanelHeaderItem(id: String) {
        panelHeaderItems.removeValue(forKey: id)
        allPanelHeaderItems = Array(panelHeaderItems.values)
    }

    public func registerPanelBottomTabItem(_ item: PanelBottomTabItem) {
        if panelBottomTabItems[item.id] == nil {
            panelBottomTabOrder.append(item.id)
        }
        panelBottomTabItems[item.id] = item
        updateSortedPanelBottomTabItems()
    }

    public func unregisterPanelBottomTabItem(id: String) {
        panelBottomTabItems.removeValue(forKey: id)
        panelBottomTabOrder.removeAll { $0 == id }
        updateSortedPanelBottomTabItems()
    }

    private func updateSortedPanelBottomTabItems() {
        objectWillChange.send()
        allPanelBottomTabItems = panelBottomTabOrder.compactMap { panelBottomTabItems[$0] }
            .sorted(by: { $0.order < $1.order })
    }

    public func registerPanelRailTabItem(_ item: PanelRailTabItem) {
        if panelRailTabItems[item.id] == nil {
            panelRailTabOrder.append(item.id)
        }
        panelRailTabItems[item.id] = item
        updateSortedPanelRailTabItems()
    }

    public func unregisterPanelRailTabItem(id: String) {
        panelRailTabItems.removeValue(forKey: id)
        panelRailTabOrder.removeAll { $0 == id }
        updateSortedPanelRailTabItems()
    }

    private func updateSortedPanelRailTabItems() {
        objectWillChange.send()
        allPanelRailTabItems = panelRailTabOrder.compactMap { panelRailTabItems[$0] }
            .sorted(by: { $0.order < $1.order })
    }

    // MARK: - Menu Bar

    public func registerMenuBarContent(_ content: MenuBarContentItem) {
        if menuBarContents[content.id] == nil {
            menuBarContentOrder.append(content.id)
        }
        menuBarContents[content.id] = content
        updateSortedMenuBarContents()
    }

    public func unregisterMenuBarContent(id: String) {
        menuBarContents.removeValue(forKey: id)
        menuBarContentOrder.removeAll { $0 == id }
        updateSortedMenuBarContents()
    }

    private func updateSortedMenuBarContents() {
        objectWillChange.send()
        allMenuBarContents = menuBarContentOrder.compactMap { menuBarContents[$0] }
            .sorted(by: { $0.order < $1.order })
    }

    public func registerMenuBarPopup(_ popup: MenuBarPopupItem) {
        if menuBarPopups[popup.id] == nil {
            menuBarPopupOrder.append(popup.id)
        }
        menuBarPopups[popup.id] = popup
        updateSortedMenuBarPopups()
    }

    public func unregisterMenuBarPopup(id: String) {
        menuBarPopups.removeValue(forKey: id)
        menuBarPopupOrder.removeAll { $0 == id }
        updateSortedMenuBarPopups()
    }

    private func updateSortedMenuBarPopups() {
        objectWillChange.send()
        allMenuBarPopups = menuBarPopupOrder.compactMap { menuBarPopups[$0] }
            .sorted(by: { $0.order < $1.order })
    }

    // MARK: - Root Overlays

    public func registerRootOverlayItem(_ item: LumiRootOverlayItem) {
        if rootOverlays[item.id] == nil {
            rootOverlayOrder.append(item.id)
        }
        rootOverlays[item.id] = item
        updateSortedRootOverlays()
    }

    public func unregisterRootOverlayItem(id: String) {
        rootOverlays.removeValue(forKey: id)
        rootOverlayOrder.removeAll { $0 == id }
        updateSortedRootOverlays()
    }

    private func updateSortedRootOverlays() {
        objectWillChange.send()
        allRootOverlays = rootOverlayOrder.compactMap { rootOverlays[$0] }
            .sorted(by: { $0.order < $1.order })
    }

    // MARK: - Clear

    public func clearAllContributions() {
        titleToolbarItems.removeAll()
        titleToolbarItemOrder.removeAll()
        updateSortedTitleToolbarItems()

        // Chat Section
        chatSectionItems.removeAll()
        chatSectionItemOrder.removeAll()
        chatSectionToolbarItems.removeAll()
        chatSectionToolbarItemOrder.removeAll()
        chatSectionToolbarBars.removeAll()
        chatSectionToolbarBarOrder.removeAll()
        chatSectionHeaders.removeAll()
        chatSectionHeaderOrder.removeAll()
        chatSectionActionBars.removeAll()
        chatSectionActionBarOrder.removeAll()
        updateSortedChatSectionItems()
        updateSortedChatSectionToolbarItems()
        updateSortedChatSectionToolbarBars()
        updateSortedChatSectionHeaders()
        updateSortedChatSectionActionBars()

        // Status Bar
        statusBarItems.removeAll()
        statusBarItemOrder.removeAll()
        updateSortedStatusBarItems()

        // Panel
        panelHeaderItems.removeAll()
        allPanelHeaderItems = []
        panelBottomTabItems.removeAll()
        panelBottomTabOrder.removeAll()
        updateSortedPanelBottomTabItems()
        panelRailTabItems.removeAll()
        panelRailTabOrder.removeAll()
        updateSortedPanelRailTabItems()

        // Menu Bar
        menuBarContents.removeAll()
        menuBarContentOrder.removeAll()
        updateSortedMenuBarContents()
        menuBarPopups.removeAll()
        menuBarPopupOrder.removeAll()
        updateSortedMenuBarPopups()

        // Root Overlays
        rootOverlays.removeAll()
        rootOverlayOrder.removeAll()
        updateSortedRootOverlays()
    }

    // MARK: - UI Contribution Storage

    public private(set) var allPanelHeaderItems: [PanelHeaderItem] = []
    public private(set) var allPanelBottomTabItems: [PanelBottomTabItem] = []
    public private(set) var allPanelRailTabItems: [PanelRailTabItem] = []

    public private(set) var allMenuBarContents: [MenuBarContentItem] = []
    public private(set) var allMenuBarPopups: [MenuBarPopupItem] = []

    public private(set) var allRootOverlays: [LumiRootOverlayItem] = []

    private var panelHeaderItems: [String: PanelHeaderItem] = [:]
    private var panelBottomTabItems: [String: PanelBottomTabItem] = [:]
    private var panelBottomTabOrder: [String] = []
    private var panelRailTabItems: [String: PanelRailTabItem] = [:]
    private var panelRailTabOrder: [String] = []
    private var menuBarContents: [String: MenuBarContentItem] = [:]
    private var menuBarContentOrder: [String] = []
    private var menuBarPopups: [String: MenuBarPopupItem] = [:]
    private var menuBarPopupOrder: [String] = []
    private var rootOverlays: [String: LumiRootOverlayItem] = [:]
    private var rootOverlayOrder: [String] = []

    private func updateSortedChatSectionItems() {
        objectWillChange.send()
        allChatSectionItems = chatSectionItemOrder.compactMap { chatSectionItems[$0] }
            .sorted(by: { $0.order < $1.order })
    }

    private func updateSortedChatSectionToolbarItems() {
        objectWillChange.send()
        allChatSectionToolbarItems = chatSectionToolbarItemOrder.compactMap { chatSectionToolbarItems[$0] }
            .sorted(by: { $0.order < $1.order })
    }

    private func updateSortedChatSectionToolbarBars() {
        objectWillChange.send()
        allChatSectionToolbarBarItems = chatSectionToolbarBarOrder.compactMap { chatSectionToolbarBars[$0] }
            .sorted(by: { $0.order < $1.order })
    }

    private func updateSortedChatSectionHeaders() {
        objectWillChange.send()
        allChatSectionHeaderItems = chatSectionHeaderOrder.compactMap { chatSectionHeaders[$0] }
            .sorted(by: { $0.order < $1.order })
    }

    private func updateSortedChatSectionActionBars() {
        objectWillChange.send()
        allChatSectionActionBarItems = chatSectionActionBarOrder.compactMap { chatSectionActionBars[$0] }
            .sorted(by: { $0.order < $1.order })
    }
}
