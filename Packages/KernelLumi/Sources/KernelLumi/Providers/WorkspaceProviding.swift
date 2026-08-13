import Combine
import CoreGraphics
import Foundation
import SwiftUI

/// 应用界面总服务协议
///
/// 统一管理整个应用界面的呈现：既管**布局几何**（工作区可见性、视图容器、
/// rail/bottom tab 选中、分隔条位置），也管**插件贡献的各区域 UI 清单**
/// （标题栏工具栏、聊天分区、状态栏、面板、菜单栏、根覆盖层）。
///
/// 合并自原 `LayoutProviding`（布局状态机）与 `UIManaging`（插件 UI 贡献注册表），
/// 由 `LayoutManager` 实现。布局状态直接内联在 `LayoutManager` 上，故本协议
/// 不再暴露 `layoutState`——消费者通过下方的访问器读写。
@MainActor
public protocol WorkspaceProviding: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 持久化数据目录（供设置视图等消费者展示/打开数据目录用）。
    var settingsDirectory: URL { get }

    // MARK: - Workspace Visibility

    var isRailVisible: Bool { get }
    var isChatVisible: Bool { get }
    var isPanelHeaderVisible: Bool { get }
    var isPanelBodyVisible: Bool { get }
    var isPanelBottomVisible: Bool { get }

    // MARK: - Workspace Commands

    func setRailVisible(_ visible: Bool)
    func setChatVisible(_ visible: Bool)
    func setPanelHeaderVisible(_ visible: Bool)
    func setPanelBodyVisible(_ visible: Bool)
    func setPanelBottomVisible(_ visible: Bool)

    func activateContainer(id: String)
    /// 将容器声明的可见性策略及已持久化的用户覆盖解析到当前运行时布局。
    func applyContainerVisibility(for id: String)
    func addContainerObserver(_ observer: @escaping (String) -> Void)

    // MARK: - View Containers

    /// 所有视图容器（按 order 排序）
    var allViewContainers: [ViewContainerItem] { get }

    /// 按 ID 查询视图容器
    func viewContainer(id: String) -> ViewContainerItem?

    /// 注册视图容器
    func registerViewContainer(_ container: ViewContainerItem)

    /// 注销视图容器
    func unregisterViewContainer(id: String)

    var activeViewContainerID: String? { get }

    /// 当前活跃的视图容器（computed，直接返回完整的 ViewContainerItem）
    var currentViewContainer: ViewContainerItem? { get }

    // MARK: - Rail Tabs

    /// 查询某 ViewContainer 当前选中的侧边栏 Rail Tab。
    func activeRailTabID(for viewContainerID: String) -> String

    /// 设置某 ViewContainer 选中的 Rail Tab（同时触发持久化）。
    func presentRailTab(id: String, for viewContainerID: String)

    // MARK: - Bottom Panel

    var bottomPanelVisible: Bool { get }

    /// 查询某 ViewContainer 当前选中的底部面板 Tab。
    func activeBottomTabID(for viewContainerID: String) -> String

    /// 设置某 ViewContainer 选中的底部面板 Tab（同时触发持久化）。
    func presentBottomTab(id: String, viewContainerID: String)

    // MARK: - Dividers

    func railDivider(for viewContainerID: String, fallback: CGFloat?) -> CGFloat
    func setRailDivider(_ position: CGFloat, for viewContainerID: String)

    func chatSectionDivider(for viewContainerID: String, layout: LumiChatSectionLayout, fallback: CGFloat?) -> CGFloat
    func setChatSectionDivider(_ position: CGFloat, for viewContainerID: String, layout: LumiChatSectionLayout)

    func bottomPanelDivider(for viewContainerID: String, fallback: CGFloat?) -> CGFloat
    func setBottomPanelDivider(_ position: CGFloat, for viewContainerID: String)

    /// 持久化的 rail 宽度（无值时返回 nil，由调用方回退到默认值）。
    func storedRailDivider(for viewContainerID: String) -> CGFloat?

    /// 持久化的 chat 区宽度（无值时返回 nil，由调用方回退到默认值）。
    func storedChatSectionDivider(for viewContainerID: String, layout: LumiChatSectionLayout) -> CGFloat?

    /// 持久化的底部面板高度（无值时返回 nil，由调用方回退到默认值）。
    func storedBottomPanelDivider(for viewContainerID: String) -> CGFloat?

    /// 用户对某容器手动调整过的可见性覆盖（nil 表示未调整）。
    func visibilityOverride(for containerID: String) -> VisibilityFlags?

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

    // MARK: - Root Overlays

    /// 所有根覆盖层（按 order 排序）
    var allRootOverlays: [LumiRootOverlayItem] { get }

    /// 注册根覆盖层
    func registerRootOverlayItem(_ item: LumiRootOverlayItem)

    /// 注销根覆盖层
    func unregisterRootOverlayItem(id: String)

    // MARK: - Clear

    /// 清空所有插件贡献(供全量重建使用)。默认 no-op。
    func clearAllContributions()
}

public extension WorkspaceProviding {
    func clearAllContributions() {}
}
