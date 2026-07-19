import Foundation
import SwiftUI

/// 命令菜单项
///
/// 插件通过此结构注册菜单命令，由 LumiFactory 统一消费。
public struct CommandItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let action: @MainActor @Sendable () -> Void
    public let shortcut: KeyEquivalent?
    public let modifiers: EventModifiers?

    public init(
        id: String? = nil,
        title: String,
        shortcut: KeyEquivalent? = nil,
        modifiers: EventModifiers? = nil,
        action: @MainActor @Sendable @escaping () -> Void
    ) {
        self.id = id ?? title
        self.title = title
        self.shortcut = shortcut
        self.modifiers = modifiers
        self.action = action
    }
}

/// 命令菜单组
///
/// 将命令项按菜单分组。
public struct CommandMenuGroup: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let items: [CommandItem]

    public init(id: String? = nil, name: String, items: [CommandItem]) {
        self.id = id ?? name
        self.name = name
        self.items = items
    }
}