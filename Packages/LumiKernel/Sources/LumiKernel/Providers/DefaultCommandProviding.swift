import Foundation
import SwiftUI

// MARK: - Default Command Provider

/// 默认命令服务实现
///
/// 负责管理所有插件的命令菜单注册、分组和查询。
@MainActor
public final class DefaultCommandProviding: CommandProviding {
    public private(set) var allCommandGroups: [CommandMenuGroup] = []
    private var commandGroups: [String: CommandMenuGroup] = [:]
    private var commandGroupOrder: [String] = []

    public init() {}

    public func commandGroup(named name: String) -> CommandMenuGroup? {
        commandGroups[name]
    }

    public func registerCommandGroup(_ group: CommandMenuGroup) {
        if commandGroups[group.id] == nil {
            commandGroupOrder.append(group.id)
        }
        commandGroups[group.id] = group
        updateSortedGroups()
    }

    public func registerCommand(menu: String, item: CommandItem) {
        let group = commandGroups[menu] ?? CommandMenuGroup(id: menu, title: menu, items: [])
        var updated = group
        updated.items.append(item)
        registerCommandGroup(updated)
    }

    public func unregisterCommandGroup(id: String) {
        commandGroups.removeValue(forKey: id)
        commandGroupOrder.removeAll { $0 == id }
        updateSortedGroups()
    }

    private func updateSortedGroups() {
        allCommandGroups = commandGroupOrder.compactMap { commandGroups[$0] }
    }
}
