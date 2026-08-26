import AppKit
import Foundation
import KernelCore
import ProviderCommand
import ProviderStorage

/// `CommandProviding` 的默认实现。
///
/// 管理命令的注册、注销和查询。
@MainActor
public final class CommandManager: CommandProviding {
    @Published public private(set) var allCommandGroups: [CommandMenuGroup] = []

    public init() {}

    public func registerCommandGroup(_ group: CommandMenuGroup) {
        if let index = allCommandGroups.firstIndex(where: { $0.id == group.id }) {
            allCommandGroups[index] = group
        } else {
            allCommandGroups.append(group)
        }
    }

    public func unregisterCommandGroup(id: String) {
        allCommandGroups.removeAll { $0.id == id }
    }
}
