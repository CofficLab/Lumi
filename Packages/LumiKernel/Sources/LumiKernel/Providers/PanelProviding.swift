import Foundation
import SwiftUI

// MARK: - Panel Capability Protocol

/// 面板能力协议
///
/// 定义 LumiCore 需要的面板管理功能，由具体布局插件实现。
/// 负责管理面板各项（顶部标题栏、底部标签、侧边栏标签）的注册、排序和查询。
@MainActor
public protocol PanelProviding: ObservableObject {
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
}
