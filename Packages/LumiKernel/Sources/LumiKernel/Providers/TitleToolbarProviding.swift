import Foundation
import SwiftUI

// MARK: - Title Toolbar Capability Protocol

/// 标题栏工具栏能力协议
///
/// 定义 LumiCore 需要的标题栏工具栏管理功能，由具体布局插件实现。
/// 负责管理标题栏工具栏项的注册、排序和查询。
@MainActor
public protocol TitleToolbarProviding: ObservableObject {
    /// 所有标题栏工具栏项（按 order 排序）
    var allTitleToolbarItems: [TitleToolbarItem] { get }

    /// 按位置获取标题栏工具栏项
    func titleToolbarItems(placement: TitleToolbarPlacement) -> [TitleToolbarItem]

    /// 注册标题栏工具栏项
    func registerTitleToolbarItem(_ item: TitleToolbarItem)

    /// 注销标题栏工具栏项
    func unregisterTitleToolbarItem(id: String)

    /// 清空所有插件贡献(供全量重建使用)。默认 no-op。
    func clearAllContributions()
}

public extension TitleToolbarProviding {
    func clearAllContributions() {}
}
