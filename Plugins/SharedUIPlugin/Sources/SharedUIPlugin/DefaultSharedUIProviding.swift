import Foundation
import LumiKernel
import SwiftUI

// MARK: - Default Shared UI Provider

/// 默认共享 UI 服务实现
///
/// 合并管理所有外部共享的 UI 组件（标题栏工具栏、聊天分区、状态栏、面板、菜单栏）。
@MainActor
public final class DefaultSharedUIProviding: SharedUIProviding {
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

    // MARK: - Initialization

    public init() {}

    // MARK: - Title Toolbar

    public func titleToolbarItems(placement: TitleToolbarPlacement) -> [TitleToolbarItem] {
        allTitleToolbarItems.filter { $0.placement == placement }
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
        allTitleToolbarItems = titleToolbarItemOrder.compactMap { titleToolbarItems[$0] }
            .sorted { $0.order < $1.order }
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
        allStatusBarItems = statusBarItemOrder.compactMap { statusBarItems[$0] }
            .sorted { $0.order < $1.order }
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
        allPanelBottomTabItems = panelBottomTabOrder.compactMap { panelBottomTabItems[$0] }
            .sorted { $0.order < $1.order }
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
        allPanelRailTabItems = panelRailTabOrder.compactMap { panelRailTabItems[$0] }
            .sorted { $0.order < $1.order }
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
        allMenuBarContents = menuBarContentOrder.compactMap { menuBarContents[$0] }
            .sorted { $0.order < $1.order }
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
        allMenuBarPopups = menuBarPopupOrder.compactMap { menuBarPopups[$0] }
            .sorted { $0.order < $1.order }
    }

    // MARK: - Clear

    public func clearAllContributions() {
        // Title Toolbar
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
    }

    // MARK: - Private

    private func updateSortedChatSectionItems() {
        allChatSectionItems = chatSectionItemOrder.compactMap { chatSectionItems[$0] }
            .sorted { $0.order < $1.order }
    }

    private func updateSortedChatSectionToolbarItems() {
        allChatSectionToolbarItems = chatSectionToolbarItemOrder.compactMap { chatSectionToolbarItems[$0] }
            .sorted { $0.order < $1.order }
    }

    private func updateSortedChatSectionToolbarBars() {
        allChatSectionToolbarBarItems = chatSectionToolbarBarOrder.compactMap { chatSectionToolbarBars[$0] }
            .sorted { $0.order < $1.order }
    }

    private func updateSortedChatSectionHeaders() {
        allChatSectionHeaderItems = chatSectionHeaderOrder.compactMap { chatSectionHeaders[$0] }
            .sorted { $0.order < $1.order }
    }

    private func updateSortedChatSectionActionBars() {
        allChatSectionActionBarItems = chatSectionActionBarOrder.compactMap { chatSectionActionBars[$0] }
            .sorted { $0.order < $1.order }
    }
}
