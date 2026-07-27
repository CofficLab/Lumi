import Foundation
import SwiftUI

/// 命令菜单项
///
/// 插件通过此结构注册菜单命令，由 LumiCore 统一消费。
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

/// 命令菜单在 macOS 菜单栏中的放置位置
///
/// 控制由 `CommandMenuGroup` 注册的命令出现在哪个 SwiftUI `CommandGroup` 中。
/// 新增值时，`AppCommands` 需同步增加对应的 `CommandGroup` 渲染分支。
public enum CommandMenuPlacement: String, Sendable, CaseIterable {
    /// 应用菜单（macOS 上的 Lumi 菜单），渲染在 `.appInfo` 系统组之后
    /// （紧跟 "About" 项）。
    case appMenu

    /// 工具栏区域，渲染在 `.toolbar` 系统组之后。
    /// 未指定 placement 时的默认值。
    case toolbar
}

/// 命令菜单组
///
/// 将命令项按菜单分组。`placement` 控制该组在 macOS 菜单栏中的位置。
public struct CommandMenuGroup: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let items: [CommandItem]
    public let placement: CommandMenuPlacement

    public init(
        id: String? = nil,
        name: String,
        items: [CommandItem],
        placement: CommandMenuPlacement = .toolbar
    ) {
        self.id = id ?? name
        self.name = name
        self.items = items
        self.placement = placement
    }
}
