import Foundation
import SwiftUI

// MARK: - Command Capability Protocol

/// 命令能力协议
///
/// 定义 LumiCore 需要的命令菜单管理功能，由具体布局插件实现。
/// 负责管理所有插件的命令菜单注册、分组和查询。
@MainActor
public protocol CommandProviding: ObservableObject {
    /// 所有命令组（按注册顺序排序）
    var allCommandGroups: [CommandMenuGroup] { get }

    /// 按菜单名查询命令组
    func commandGroup(named name: String) -> CommandMenuGroup?

    /// 注册命令组
    func registerCommandGroup(_ group: CommandMenuGroup)

    /// 注册单个命令项（自动分组）
    func registerCommand(menu: String, item: CommandItem)

    /// 注销命令组
    func unregisterCommandGroup(id: String)
}
