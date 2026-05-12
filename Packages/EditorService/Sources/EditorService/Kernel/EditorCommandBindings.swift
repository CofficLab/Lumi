import EditorKernelCore
import SwiftUI

public struct EditorCommandBinding: Sendable {
    public let key: String
    public let modifiers: [EditorCommandShortcut.Modifier]

    public init(key: String, modifiers: [EditorCommandShortcut.Modifier]) {
        self.key = key
        self.modifiers = modifiers
    }

    /// 默认快捷键（不可被用户覆盖改变）
    public var defaultKernelShortcut: EditorCommandShortcut {
        EditorCommandShortcut(key: key, modifiers: modifiers)
    }

    /// 实际生效的快捷键（用户自定义优先，否则默认）
    public var kernelShortcut: EditorCommandShortcut {
        // 不在 @MainActor 上下文中时使用默认值
        // 实际 resolve 通过 resolveKernelShortcut(for:) 完成
        defaultKernelShortcut
    }

    /// 解析命令的实际快捷键（用户自定义优先）
    @MainActor
    public func resolveKernelShortcut(for commandID: String) -> EditorCommandShortcut {
        EditorKeybindingStore.shared.shortcut(
            for: commandID,
            default: defaultKernelShortcut
        ) ?? defaultKernelShortcut
    }

    public var keyEquivalent: KeyEquivalent {
        KeyEquivalent(Character(key.lowercased()))
    }

    public var eventModifiers: EventModifiers {
        var result: EventModifiers = []
        for modifier in modifiers {
            switch modifier {
            case .command:
                result.insert(.command)
            case .shift:
                result.insert(.shift)
            case .option:
                result.insert(.option)
            case .control:
                result.insert(.control)
            }
        }
        return result
    }
}

public extension EditorCommandShortcut {
    var keyEquivalent: KeyEquivalent {
        switch key {
        case "\r", "return", "enter":
            return .return
        case "\t", "tab":
            return .tab
        case "↑", "uparrow", "up":
            return .upArrow
        case "↓", "downarrow", "down":
            return .downArrow
        case "←", "leftarrow", "left":
            return .leftArrow
        case "→", "rightarrow", "right":
            return .rightArrow
        case " ", "space":
            return .space
        case "\u{1b}", "escape", "esc":
            return .escape
        case "\u{8}", "\u{7f}", "delete", "backspace":
            return .delete
        default:
            return KeyEquivalent(Character(key.lowercased()))
        }
    }

    var eventModifiers: EventModifiers {
        var result: EventModifiers = []
        for modifier in modifiers {
            switch modifier {
            case .command:
                result.insert(.command)
            case .shift:
                result.insert(.shift)
            case .option:
                result.insert(.option)
            case .control:
                result.insert(.control)
            }
        }
        return result
    }
}

public enum EditorCommandBindings {
    public static let undo = EditorCommandBinding(key: "z", modifiers: [.command])
    public static let redo = EditorCommandBinding(key: "z", modifiers: [.command, .shift])
    public static let find = EditorCommandBinding(key: "f", modifiers: [.command])
    public static let searchInFiles = EditorCommandBinding(key: "f", modifiers: [.command, .shift])
    public static let commandPalette = EditorCommandBinding(key: "p", modifiers: [.command, .shift])
    public static let findNext = EditorCommandBinding(key: "g", modifiers: [.command])
    public static let findPrevious = EditorCommandBinding(key: "g", modifiers: [.command, .shift])
    public static let openEditors = EditorCommandBinding(key: "e", modifiers: [.command, .shift])
    public static let save = EditorCommandBinding(key: "s", modifiers: [.command])

    public static let formatDocument = EditorCommandBinding(key: "f", modifiers: [.command, .shift, .option])
    public static let findReferences = EditorCommandBinding(key: "r", modifiers: [.command, .option])
    public static let quickFix = EditorCommandBinding(key: ".", modifiers: [.command])
    public static let renameSymbol = EditorCommandBinding(key: "r", modifiers: [.command, .shift])
    public static let workspaceSymbols = EditorCommandBinding(key: "o", modifiers: [.command, .shift])
    public static let callHierarchy = EditorCommandBinding(key: "h", modifiers: [.command, .option])

    // MARK: - Line Editing (Phase 9)

    public static let deleteLine = EditorCommandBinding(key: "k", modifiers: [.command, .shift])
    public static let copyLineUp = EditorCommandBinding(key: "↑", modifiers: [.option, .shift])
    public static let copyLineDown = EditorCommandBinding(key: "↓", modifiers: [.option, .shift])
    public static let moveLineUp = EditorCommandBinding(key: "↑", modifiers: [.option])
    public static let moveLineDown = EditorCommandBinding(key: "↓", modifiers: [.option])
    public static let insertLineBelow = EditorCommandBinding(key: "\r", modifiers: [.command])
    public static let insertLineAbove = EditorCommandBinding(key: "\r", modifiers: [.command, .shift])
    public static let toggleLineComment = EditorCommandBinding(key: "/", modifiers: [.command])
    public static let transpose = EditorCommandBinding(key: "t", modifiers: [.control])
}
