import Foundation
import SwiftUI

/// 菜单栏展示能力
///
/// 这里只定义“如何把内核收集到的菜单栏内容/弹窗展示出来”，
/// 真正的 `NSStatusItem` / `NSPopover` 实现应放在宿主层（例如 `FactoryCore`）。
@MainActor
public protocol MenuBarPresenting: AnyObject {
    /// 当前是否已挂载菜单栏宿主。
    var isMenuBarPresented: Bool { get }

    /// 安装或更新菜单栏宿主。
    ///
    /// - Parameters:
    ///   - contentItems: 菜单栏图标区内容项，通常由 `WorkspaceProviding.allMenuBarContents` 提供。
    ///   - popupItems: 菜单栏弹窗内容项，通常由 `WorkspaceProviding.allMenuBarPopups` 提供。
    func presentMenuBar(
        contentItems: [MenuBarContentItem],
        popupItems: [MenuBarPopupItem]
    )

    /// 仅刷新当前菜单栏内容，不改变宿主存在性。
    func refreshMenuBar(
        contentItems: [MenuBarContentItem],
        popupItems: [MenuBarPopupItem]
    )

    /// 卸载菜单栏宿主。
    func dismissMenuBar()
}
