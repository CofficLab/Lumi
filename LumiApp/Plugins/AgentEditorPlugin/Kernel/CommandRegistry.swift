import Foundation

// MARK: - Command Registry
//
// 中央命令注册中心。
//
// 所有编辑器行为（format、rename、find、multi-cursor 等）统一注册为 Command，
// 通过 command ID 在任何上下文中（toolbar、menu、keybinding、command palette）执行。
//
// 设计原则：
// 1. 命令定义与执行解耦
// 2. 启用状态由 context 决定，不依赖 UI 状态
// 3. 每个命令有唯一的 string ID

/// 命令执行上下文中的键。
/// 用于 context-based enablement（如 `hasSelection`、`languageId`）。
struct CommandKey: Hashable {
    let rawValue: String
    init(_ rawValue: String) { self.rawValue = rawValue }
}

/// 命令执行上下文。
/// 一组键值对，用于决定命令是否可用。
struct CommandContext {
    private(set) var values: [String: AnyHashable] = [:]

    subscript(_ key: CommandKey) -> AnyHashable? {
        get { values[key.rawValue] }
        set { values[key.rawValue] = newValue }
    }

    /// 是否有文本选区
    var hasSelection: Bool {
        get { values[CommandKey.hasSelection.rawValue] as? Bool ?? false }
        set { values[CommandKey.hasSelection.rawValue] = newValue }
    }

    /// 当前语言 ID
    var languageId: String? {
        get { values[CommandKey.languageId.rawValue] as? String }
        set { values[CommandKey.languageId.rawValue] = newValue }
    }

    /// 当前行号（0-based）
    var line: Int? {
        get { values[CommandKey.line.rawValue] as? Int }
        set { values[CommandKey.line.rawValue] = newValue }
    }

    /// 当前列号（0-based）
    var character: Int? {
        get { values[CommandKey.character.rawValue] as? Int }
        set { values[CommandKey.character.rawValue] = newValue }
    }

    /// 是否有可编辑的文件打开
    var isEditorActive: Bool {
        get { values[CommandKey.isEditorActive.rawValue] as? Bool ?? false }
        set { values[CommandKey.isEditorActive.rawValue] = newValue }
    }

    /// 是否处于多光标模式
    var isMultiCursor: Bool {
        get { values[CommandKey.isMultiCursor.rawValue] as? Bool ?? false }
        set { values[CommandKey.isMultiCursor.rawValue] = newValue }
    }
}

extension CommandKey {
    static let hasSelection = CommandKey("hasSelection")
    static let languageId = CommandKey("languageId")
    static let line = CommandKey("line")
    static let character = CommandKey("character")
    static let isEditorActive = CommandKey("isEditorActive")
    static let isMultiCursor = CommandKey("isMultiCursor")
}

/// 命令启用条件。
/// 声明命令在什么 context 下可用。
enum CommandEnablement {
    /// 始终可用
    case always
    /// 当 context 中的指定键为 true 时可用
    case whenTrue(CommandKey)
    /// 当 context 中的指定键为非 nil 时可用
    case whenPresent(CommandKey)
    /// 自定义闭包判断
    case custom((CommandContext) -> Bool)

    func evaluate(in context: CommandContext) -> Bool {
        switch self {
        case .always:
            return true
        case .whenTrue(let key):
            return (context.values[key.rawValue] as? Bool) == true
        case .whenPresent(let key):
            return context.values[key.rawValue] != nil
        case .custom(let predicate):
            return predicate(context)
        }
    }
}

/// 编辑器命令（Kernel 层）。
/// 统一的行为定义，可在 toolbar/menu/keybinding/command palette 中使用。
/// 注意：区别于 SwiftUI 的 `EditorCommand`，这是编辑器内核的命令模型。
struct KernelEditorCommand: Identifiable {
    let id: String
    let title: String
    let icon: String?
    let category: String?
    let enablement: CommandEnablement
    let handler: () -> Void

    /// 在给定 context 下是否可用
    func isEnabled(in context: CommandContext) -> Bool {
        enablement.evaluate(in: context)
    }

    /// 创建一个始终可用的命令。
    static func command(
        id: String,
        title: String,
        icon: String? = nil,
        category: String? = nil,
        enablement: CommandEnablement = .always,
        handler: @escaping () -> Void
    ) -> KernelEditorCommand {
        KernelEditorCommand(
            id: id,
            title: title,
            icon: icon,
            category: category,
            enablement: enablement,
            handler: handler
        )
    }

    /// 创建一个需要选区才能使用的命令。
    static func selectionCommand(
        id: String,
        title: String,
        icon: String? = nil,
        category: String? = nil,
        handler: @escaping () -> Void
    ) -> KernelEditorCommand {
        KernelEditorCommand(
            id: id,
            title: title,
            icon: icon,
            category: category,
            enablement: .whenTrue(.hasSelection),
            handler: handler
        )
    }
}

/// 中央命令注册中心。
@MainActor
final class CommandRegistry {
    static let shared = CommandRegistry()

    private var commands: [String: KernelEditorCommand] = [:]

    private init() {}

    /// 注册命令。如果 ID 已存在则覆盖。
    func register(_ command: KernelEditorCommand) {
        commands[command.id] = command
    }

    /// 批量注册。
    func register(_ commands: [KernelEditorCommand]) {
        for command in commands {
            register(command)
        }
    }

    /// 根据 ID 获取命令。
    func command(id: String) -> KernelEditorCommand? {
        commands[id]
    }

    /// 获取所有注册的命令。
    func allCommands() -> [KernelEditorCommand] {
        Array(commands.values).sorted { $0.id < $1.id }
    }

    /// 根据 context 过滤出可用的命令。
    func availableCommands(in context: CommandContext) -> [KernelEditorCommand] {
        commands.values.filter { $0.isEnabled(in: context) }
            .sorted { $0.id < $1.id }
    }

    /// 执行指定命令。
    func execute(id: String, context: CommandContext) -> Bool {
        guard let command = commands[id], command.isEnabled(in: context) else {
            return false
        }
        command.handler()
        return true
    }

    /// 注销指定 ID 的命令。
    func unregister(id: String) {
        commands.removeValue(forKey: id)
    }

    /// 清除所有命令。
    func clear() {
        commands.removeAll()
    }
}
