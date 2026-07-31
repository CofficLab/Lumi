import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

/// 工作区服务实现
///
/// 同时承担两职责（合并自原 LayoutProviding + UIManaging）：
/// 1. **布局几何**——工作区可见性、视图容器、rail/bottom tab 选中、分隔条位置；
///    持久化由 LayoutStore 负责，在状态变更时 debounce 0.3s 自动保存。
/// 2. **插件 UI 贡献注册表**——聚合各插件向标题栏/聊天分区/状态栏/面板/菜单栏/
///    根覆盖层贡献的组件，按 order 排序后供视图层 reactive 读取。
@MainActor
public final class LayoutManager: WorkspaceProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout.service")
    nonisolated public static let emoji = "📐"
    nonisolated static let verbose = false

    // MARK: - Layout State

    /// 布局状态（用于视图绑定和运行时状态）
    public let layoutState: LayoutState

    /// 布局持久化存储
    private let store: LayoutStore

    /// 持久化数据目录（`layout-info.json` 所在的 settings 子目录）。
    /// 供设置视图等外部消费者展示/打开数据目录用。
    public var settingsDirectory: URL { store.settingsDirectory }

    /// 订阅 `layoutState.objectWillChange`,转发到本服务。
    ///
    /// `activeRailTabID`、`bottomPanelVisible` 等运行时状态都存放在 `LayoutState` 的
    /// `@Published` 属性里。Kernel 只订阅本服务(通过 `WorkspaceProviding`)的
    /// `objectWillChange`,若不在此转发,任何 `LayoutState` 的变更都无法触发
    /// `@ObservedObject kernel` 的视图重绘——表现为 Rail 标签栏高亮不随点击切换等故障。
    private var layoutStateSubscription: AnyCancellable?

    /// 持久化订阅：`LayoutState` 任一状态变更后，debounce 0.3s 自动落盘。
    ///
    /// 这样无论 rail/bottom tab 是经协议写入还是视图直接改 `layoutState`，都能可靠地
    /// 持久化到磁盘，避免漏存；debounce 也合并高频变更（如连续切换 tab）成一次写入。
    private var persistenceSubscription: AnyCancellable?

    // MARK: - Title Toolbar

    public private(set) var allTitleToolbarItems: [TitleToolbarItem] = []

    private var titleToolbarItems: [String: TitleToolbarItem] = [:]
    private var titleToolbarItemOrder: [String] = []

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

    // MARK: - Status Bar

    public private(set) var allStatusBarItems: [StatusBarItem] = []

    private var statusBarItems: [String: StatusBarItem] = [:]
    private var statusBarItemOrder: [String] = []

    // MARK: - Panel

    public private(set) var allPanelHeaderItems: [PanelHeaderItem] = []
    public private(set) var allPanelBottomTabItems: [PanelBottomTabItem] = []
    public private(set) var allPanelRailTabItems: [PanelRailTabItem] = []

    private var panelHeaderItems: [String: PanelHeaderItem] = [:]
    private var panelBottomTabItems: [String: PanelBottomTabItem] = [:]
    private var panelBottomTabOrder: [String] = []
    private var panelRailTabItems: [String: PanelRailTabItem] = [:]
    private var panelRailTabOrder: [String] = []

    // MARK: - Menu Bar

    public private(set) var allMenuBarContents: [MenuBarContentItem] = []
    public private(set) var allMenuBarPopups: [MenuBarPopupItem] = []

    private var menuBarContents: [String: MenuBarContentItem] = [:]
    private var menuBarContentOrder: [String] = []
    private var menuBarPopups: [String: MenuBarPopupItem] = [:]
    private var menuBarPopupOrder: [String] = []

    // MARK: - Root Overlays

    public private(set) var allRootOverlays: [LumiRootOverlayItem] = []

    private var rootOverlays: [String: LumiRootOverlayItem] = [:]
    private var rootOverlayOrder: [String] = []

    // MARK: - Initialization

    public init(store: LayoutStore) {
        self.store = store
        self.layoutState = LayoutState()

        // 把 LayoutState 的变更重新发布到 LayoutManager,使经 WorkspaceProviding
        // 订阅本服务的消费者(kernel 及其视图)能收到通知。
        self.layoutStateSubscription = layoutState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }

        // 任一状态变更后 debounce 0.3s 自动落盘（rail/bottom tab 等）。
        self.persistenceSubscription = layoutState.objectWillChange
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.saveState()
            }

        if Self.verbose {
            Self.logger.info("\(Self.t)LayoutManager initialized")
        }
    }

    // MARK: - Workspace Visibility

    public var isRailVisible: Bool { layoutState.isRailVisible }
    public var isChatVisible: Bool { layoutState.isChatVisible }
    public var isContentVisible: Bool { layoutState.isContentVisible }
    public var isPanelVisible: Bool { layoutState.isPanelVisible }
    public var isPanelBottomVisible: Bool { layoutState.isPanelBottomVisible }

    // MARK: - Workspace Commands

    public func setRailVisible(_ visible: Bool) { layoutState.setRailVisible(visible) }
    public func setChatVisible(_ visible: Bool) { layoutState.setChatVisible(visible) }
    public func setContentVisible(_ visible: Bool) { layoutState.setContentVisible(visible) }
    public func setPanelVisible(_ visible: Bool) { layoutState.setPanelVisible(visible) }
    public func setPanelBottomVisible(_ visible: Bool) { layoutState.setPanelBottomVisible(visible) }

    public func activateContainer(id: String) {
        let container = self.layoutState.viewContainer(id: id)
        let containerBottomVisible = container?.isPanelBottomVisible
        if Self.verbose {
            Self.logger.info("\(Self.t)activateContainer(id: \(id), container.isPanelBottomVisible: \(containerBottomVisible.map { String($0) } ?? "nil"))")
        }
        self.layoutState.activateContainer(id: id)
        let bottomVisible = self.layoutState.isPanelBottomVisible
        if Self.verbose {
            Self.logger.info("\(Self.t)activateContainer done, isPanelBottomVisible = \(bottomVisible)")
        }
        // 保存到磁盘
        saveState()
    }

    /// 保存当前状态到磁盘
    private func saveState() {
        let info = LayoutStateInfo(
            activeViewContainerID: self.layoutState.activeViewContainerID,
            chatSectionVisible: self.layoutState.isChatVisible,
            railVisible: self.layoutState.isRailVisible,
            contentVisible: self.layoutState.isContentVisible,
            panelVisible: self.layoutState.isPanelVisible,
            panelBottomVisible: self.layoutState.isPanelBottomVisible,
            activeRailTabIDs: self.layoutState.activeRailTabIDsDictionary,
            activeBottomTabIDs: self.layoutState.activeBottomTabIDsDictionary,
            visibilityOverrides: self.layoutState.visibilityOverridesDictionary
        )
        self.store.saveLayoutInfo(info)
        if Self.verbose {
            Self.logger.info("\(Self.t)saveState: activeViewContainerID=\(info.activeViewContainerID ?? "nil"), railTabs=\(info.activeRailTabIDs.count), bottomTabs=\(info.activeBottomTabIDs.count), visibilityOverrides=\(info.visibilityOverrides.count)")
        }
    }

    public func applyVisibility(rail: Bool?, chat: Bool?, content: Bool?, panel: Bool?) {
        if Self.verbose {
            Self.logger.info("\(Self.t)applyVisibility(rail: \(rail.map { String($0) } ?? "-"), chat: \(chat.map { String($0) } ?? "-"), content: \(content.map { String($0) } ?? "-"), panel: \(panel.map { String($0) } ?? "-"))")
        }
        layoutState.applyVisibility(rail: rail, chat: chat, content: content, panel: panel)
    }

    public func addContainerObserver(_ observer: @escaping (String) -> Void) {
        layoutState.addContainerObserver(observer)
    }

    // MARK: - View Containers

    public var allViewContainers: [ViewContainerItem] { layoutState.allViewContainers }
    public func viewContainer(id: String) -> ViewContainerItem? { layoutState.viewContainer(id: id) }
    public func registerViewContainer(_ container: ViewContainerItem) { layoutState.registerViewContainer(container) }
    public func unregisterViewContainer(id: String) { layoutState.unregisterViewContainer(id: id) }

    // MARK: - Container

    public var activeViewContainerID: String? { layoutState.activeViewContainerID }

    public var currentViewContainer: ViewContainerItem? {
        guard let id = activeViewContainerID else { return nil }
        return viewContainer(id: id)
    }

    // MARK: - Rail Tabs

    public func activeRailTabID(for viewContainerID: String) -> String {
        layoutState.activeRailTabID(for: viewContainerID)
    }

    public func presentRailTab(id: String, for viewContainerID: String) {
        layoutState.presentRailTab(id: id, for: viewContainerID)
    }

    // MARK: - Bottom Panel

    public var bottomPanelVisible: Bool { layoutState.bottomPanelVisible }

    public func activeBottomTabID(for viewContainerID: String) -> String {
        layoutState.activeBottomTabID(for: viewContainerID)
    }

    public func presentBottomTab(id: String, viewContainerID: String) {
        layoutState.presentBottomTab(id: id, viewContainerID: viewContainerID)
    }

    // MARK: - Dividers

    public func railDivider(for viewContainerID: String, fallback: CGFloat?) -> CGFloat {
        layoutState.railDivider(for: viewContainerID, fallback: fallback)
    }

    public func setRailDivider(_ position: CGFloat, for viewContainerID: String) {
        layoutState.setRailDivider(position, for: viewContainerID)
    }

    public func chatSectionDivider(for viewContainerID: String, layout: LumiChatSectionLayout, fallback: CGFloat?) -> CGFloat {
        layoutState.chatSectionDivider(for: viewContainerID, layout: layout, fallback: fallback)
    }

    public func setChatSectionDivider(_ position: CGFloat, for viewContainerID: String, layout: LumiChatSectionLayout) {
        layoutState.setChatSectionDivider(position, for: viewContainerID, layout: layout)
    }

    public func bottomPanelDivider(for viewContainerID: String, fallback: CGFloat?) -> CGFloat {
        layoutState.bottomPanelDivider(for: viewContainerID, fallback: fallback)
    }

    public func setBottomPanelDivider(_ position: CGFloat, for viewContainerID: String) {
        layoutState.setBottomPanelDivider(position, for: viewContainerID)
    }

    // MARK: - Title Toolbar

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

    // MARK: - Private

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
