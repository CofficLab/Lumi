import Foundation
import SwiftUI

// MARK: - Chat Section Capability Protocol

/// 聊天分区能力协议
///
/// 定义 LumiCore 需要的聊天分区管理功能，由具体布局插件实现。
/// 负责管理聊天分区、工具栏、标题项的注册、排序和查询。
@MainActor
public protocol ChatSectionProviding: ObservableObject {
    /// 所有聊天分区项（按 order 排序）
    var allChatSectionItems: [ChatSectionItem] { get }

    /// 所有聊天分区工具栏项（按 order 排序）
    var allChatSectionToolbarItems: [ChatSectionToolbarItem] { get }

    /// 所有聊天分区工具栏条（按 order 排序）
    var allChatSectionToolbarBarItems: [ChatSectionToolbarBarItem] { get }

    /// 所有聊天分区标题项（按 order 排序）
    var allChatSectionHeaderItems: [ChatSectionHeaderItem] { get }

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
}
