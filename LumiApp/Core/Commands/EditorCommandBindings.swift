import SwiftUI
import MagicKit

struct EditorCommandBinding {
    let key: String
    let modifiers: [EditorCommandShortcut.Modifier]

    /// 默认快捷键（不可被用户覆盖改变）
    var defaultKernelShortcut: EditorCommandShortcut {
        EditorCommandShortcut(key: key, modifiers: modifiers)
    }

    /// 实际生效的快捷键（用户自定义优先，否则默认）
    var kernelShortcut: EditorCommandShortcut {
        // 不在 @MainActor 上下文中时使用默认值
        // 实际 resolve 通过 resolveKernelShortcut(for:) 完成
        defaultKernelShortcut
    }

    /// 解析命令的实际快捷键（用户自定义优先）
    @MainActor
    func resolveKernelShortcut(for commandID: String) -> EditorCommandShortcut {
        EditorKeybindingStore.shared.shortcut(
            for: commandID,
            default: defaultKernelShortcut
        ) ?? defaultKernelShortcut
    }

    var keyEquivalent: KeyEquivalent {
        KeyEquivalent(Character(key.lowercased()))
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

enum EditorCommandBindings {
    static let undo = EditorCommandBinding(key: "z", modifiers: [.command])
    static let redo = EditorCommandBinding(key: "z", modifiers: [.command, .shift])
    static let find = EditorCommandBinding(key: "f", modifiers: [.command])
    static let commandPalette = EditorCommandBinding(key: "p", modifiers: [.command, .shift])
    static let findNext = EditorCommandBinding(key: "g", modifiers: [.command])
    static let findPrevious = EditorCommandBinding(key: "g", modifiers: [.command, .shift])
    static let openEditors = EditorCommandBinding(key: "e", modifiers: [.command, .shift])

    static let splitRight = EditorCommandBinding(key: "\\", modifiers: [.command])
    static let splitDown = EditorCommandBinding(key: "\\", modifiers: [.command, .shift])
    static let closeSplit = EditorCommandBinding(key: "\\", modifiers: [.command, .option])
    static let focusNextGroup = EditorCommandBinding(key: "]", modifiers: [.command, .option])
    static let focusPreviousGroup = EditorCommandBinding(key: "[", modifiers: [.command, .option])
    static let moveToNextGroup = EditorCommandBinding(key: "]", modifiers: [.command, .option, .shift])
    static let moveToPreviousGroup = EditorCommandBinding(key: "[", modifiers: [.command, .option, .shift])

    static let formatDocument = EditorCommandBinding(key: "f", modifiers: [.command, .shift, .option])
    static let findReferences = EditorCommandBinding(key: "r", modifiers: [.command, .option])
    static let renameSymbol = EditorCommandBinding(key: "r", modifiers: [.command, .shift])
    static let workspaceSymbols = EditorCommandBinding(key: "o", modifiers: [.command, .shift])
    static let callHierarchy = EditorCommandBinding(key: "h", modifiers: [.command, .option])

    // MARK: - Line Editing (Phase 9)

    static let deleteLine = EditorCommandBinding(key: "k", modifiers: [.command, .shift])
    static let copyLineUp = EditorCommandBinding(key: "↑", modifiers: [.option, .shift])
    static let copyLineDown = EditorCommandBinding(key: "↓", modifiers: [.option, .shift])
    static let moveLineUp = EditorCommandBinding(key: "↑", modifiers: [.option])
    static let moveLineDown = EditorCommandBinding(key: "↓", modifiers: [.option])
    static let insertLineBelow = EditorCommandBinding(key: "\r", modifiers: [.command])
    static let insertLineAbove = EditorCommandBinding(key: "\r", modifiers: [.command, .shift])
    static let toggleLineComment = EditorCommandBinding(key: "/", modifiers: [.command])
    static let transpose = EditorCommandBinding(key: "t", modifiers: [.control])
}
