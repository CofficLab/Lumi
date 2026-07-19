import Foundation
import LumiKernel
import SwiftUI

// MARK: - Default Menu Bar Provider

/// 默认菜单栏服务实现
///
/// 负责管理所有插件的菜单栏内容和弹出项的注册、排序和查询。
@MainActor
public final class DefaultMenuBarProviding: MenuBarProviding {
    public private(set) var allMenuBarContents: [MenuBarContentItem] = []
    public private(set) var allMenuBarPopups: [MenuBarPopupItem] = []

    private var menuBarContents: [String: MenuBarContentItem] = [:]
    private var menuBarContentOrder: [String] = []
    private var menuBarPopups: [String: MenuBarPopupItem] = [:]
    private var menuBarPopupOrder: [String] = []

    public init() {}

    public func registerMenuBarContent(_ content: MenuBarContentItem) {
        if menuBarContents[content.id] == nil {
            menuBarContentOrder.append(content.id)
        }
        menuBarContents[content.id] = content
        updateSortedContents()
    }

    public func unregisterMenuBarContent(id: String) {
        menuBarContents.removeValue(forKey: id)
        menuBarContentOrder.removeAll { $0 == id }
        updateSortedContents()
    }

    public func registerMenuBarPopup(_ popup: MenuBarPopupItem) {
        if menuBarPopups[popup.id] == nil {
            menuBarPopupOrder.append(popup.id)
        }
        menuBarPopups[popup.id] = popup
        updateSortedPopups()
    }

    public func unregisterMenuBarPopup(id: String) {
        menuBarPopups.removeValue(forKey: id)
        menuBarPopupOrder.removeAll { $0 == id }
        updateSortedPopups()
    }

    private func updateSortedContents() {
        allMenuBarContents = menuBarContentOrder.compactMap { menuBarContents[$0] }
            .sorted { $0.order < $1.order }
    }

    private func updateSortedPopups() {
        allMenuBarPopups = menuBarPopupOrder.compactMap { menuBarPopups[$0] }
            .sorted { $0.order < $1.order }
    }
}
