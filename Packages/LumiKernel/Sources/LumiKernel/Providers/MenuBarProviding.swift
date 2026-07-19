import Foundation
import SwiftUI

// MARK: - Menu Bar Capability Protocol

/// 菜单栏能力协议
///
/// 定义 LumiCore 需要的菜单栏管理功能，由具体布局插件实现。
/// 负责管理菜单栏内容和弹出项的注册、排序和查询。
@MainActor
public protocol MenuBarProviding: ObservableObject {
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
}
