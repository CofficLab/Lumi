import Foundation
import SwiftUI

/// 共享 UI 能力协议
///
/// 统一管理所有外部共享的 UI 组件（标题栏工具栏、聊天分区、状态栏、面板、菜单栏）。
@MainActor
public protocol SharedUIProviding: ObservableObject {
    // MARK: - Title Toolbar

    /// 所有标题栏工具栏项（按 order 排序）
    var allTitleToolbarItems: [TitleToolbarItem] { get }

    /// 按位置获取标题栏工具栏项
    func titleToolbarItems(placement: TitleToolbarPlacement) -> [TitleToolbarItem]

    /// 注册标题栏工具栏项
    func registerTitleToolbarItem(_ item: TitleToolbarItem)

    /// 注销标题栏工具栏项
    func unregisterTitleToolbarItem(id: String)

    // MARK: - Chat Section

    /// 所有聊天分区项（按 order 排序）
    var allChatSectionItems: [ChatSectionItem] { get }

    /// 所有聊天分区工具栏项（按 order 排序）
    var allChatSectionToolbarItems: [ChatSectionToolbarItem] { get }

    /// 所有聊天分区工具栏条（按 order 排序）
    var allChatSectionToolbarBarItems: [ChatSectionToolbarBarItem] { get }

    /// 所有聊天分区标题项（按 order 排序）
    var allChatSectionHeaderItems: [ChatSectionHeaderItem] { get }

    /// 所有聊天分区动作栏项（按 order 排序）
    var allChatSectionActionBarItems: [ChatSectionActionBarItem] { get }

    /// 按位置获取聊天分区项
    func chatSectionItems(placement: ChatSectionPlacement) -> [ChatSectionItem]

    /// 按位置获取聊天分区工具栏项
    func chatSectionToolbarItems(placement: ChatSectionToolbarPlacement) -> [ChatSectionToolbarItem]

    /// 注册聊天分区项
    func registerChatSectionItem(_ item: ChatSectionItem)

    /// 注销聊天分区项
    func unregisterChatSectionItem(id: String)

    /// 注册聊天分区工具栏项
    func registerChatSectionToolbarItem(_ item: ChatSectionToolbarItem)

    /// 注销聊天分区工具栏项
    func unregisterChatSectionToolbarItem(id: String)

    /// 注册聊天分区工具栏条
    func registerChatSectionToolbarBarItem(_ item: ChatSectionToolbarBarItem)

    /// 注销聊天分区工具栏条
    func unregisterChatSectionToolbarBarItem(id: String)

    /// 注册聊天分区标题项
    func registerChatSectionHeaderItem(_ item: ChatSectionHeaderItem)

    /// 注销聊天分区标题项
    func unregisterChatSectionHeaderItem(id: String)

    /// 注册聊天分区动作栏项
    func registerChatSectionActionBarItem(_ item: ChatSectionActionBarItem)

    /// 注销聊天分区动作栏项
    func unregisterChatSectionActionBarItem(id: String)

    // MARK: - Status Bar

    /// 所有已注册的状态栏项（按注册顺序）
    var allStatusBarItems: [StatusBarItem] { get }

    /// 按位置获取状态栏项
    func statusBarItems(placement: StatusBarPlacement) -> [StatusBarItem]

    /// 注册状态栏项
    func registerStatusBarItem(_ item: StatusBarItem)

    /// 注销状态栏项
    func unregisterStatusBarItem(id: String)

    // MARK: - Panel

    /// 所有面板顶部标题栏项
    var allPanelHeaderItems: [PanelHeaderItem] { get }

    /// 所有面板底部标签项（按 order 排序）
    var allPanelBottomTabItems: [PanelBottomTabItem] { get }

    /// 所有侧边栏标签项（按 order 排序）
    var allPanelRailTabItems: [PanelRailTabItem] { get }

    /// 注册面板顶部标题栏项
    func registerPanelHeaderItem(_ item: PanelHeaderItem)

    /// 注销面板顶部标题栏项
    func unregisterPanelHeaderItem(id: String)

    /// 注册面板底部标签项
    func registerPanelBottomTabItem(_ item: PanelBottomTabItem)

    /// 注销面板底部标签项
    func unregisterPanelBottomTabItem(id: String)

    /// 注册侧边栏标签项
    func registerPanelRailTabItem(_ item: PanelRailTabItem)

    /// 注销侧边栏标签项
    func unregisterPanelRailTabItem(id: String)

    // MARK: - Menu Bar

    /// 所有菜单栏内容（按 order 排序）
    var allMenuBarContents: [MenuBarContentItem] { get }

    /// 所有菜单栏弹出项（按 order 排序）
    var allMenuBarPopups: [MenuBarPopupItem] { get }

    /// 注册菜单栏内容
    func registerMenuBarContent(_ content: MenuBarContentItem)

    /// 注销菜单栏内容
    func unregisterMenuBarContent(id: String)

    /// 注册菜单栏弹出项
    func registerMenuBarPopup(_ popup: MenuBarPopupItem)

    /// 注销菜单栏弹出项
    func unregisterMenuBarPopup(id: String)

    // MARK: - Clear

    /// 清空所有插件贡献(供全量重建使用)。默认 no-op。
    func clearAllContributions()
}

public extension SharedUIProviding {
    func clearAllContributions() {}
}
