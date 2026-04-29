import SwiftUI
import MagicKit

/// 编辑器命令：提供 LSP 快捷动作入口
struct EditorCommand: Commands, SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = false
    @ObservedObject private var keybindingStore = EditorKeybindingStore.shared

    @MainActor
    private func resolvedShortcut(
        _ binding: EditorCommandBinding,
        commandID: String
    ) -> EditorCommandShortcut {
        binding.resolveKernelShortcut(for: commandID)
    }

    var body: some Commands {
        #if os(macOS)
        CommandMenu("编辑器") {
            Button("撤销") {
                NotificationCenter.postLumiEditorUndo()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.undo, commandID: "builtin.undo").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.undo, commandID: "builtin.undo").eventModifiers
            )

            Button("重做") {
                NotificationCenter.postLumiEditorRedo()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.redo, commandID: "builtin.redo").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.redo, commandID: "builtin.redo").eventModifiers
            )

            Divider()

            Button("命令面板") {
                NotificationCenter.postLumiEditorShowCommandPalette()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.commandPalette, commandID: "builtin.command-palette").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.commandPalette, commandID: "builtin.command-palette").eventModifiers
            )

            Divider()

            Button("查找") {
                NotificationCenter.postLumiEditorToggleFind()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.find, commandID: "builtin.find").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.find, commandID: "builtin.find").eventModifiers
            )

            Button("查找下一个") {
                NotificationCenter.postLumiEditorFindNext()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.findNext, commandID: "builtin.find-next").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.findNext, commandID: "builtin.find-next").eventModifiers
            )

            Button("查找上一个") {
                NotificationCenter.postLumiEditorFindPrevious()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.findPrevious, commandID: "builtin.find-previous").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.findPrevious, commandID: "builtin.find-previous").eventModifiers
            )

            Button("打开编辑项") {
                NotificationCenter.postLumiEditorToggleOpenEditorsPanel()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.openEditors, commandID: "builtin.open-editors-panel").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.openEditors, commandID: "builtin.open-editors-panel").eventModifiers
            )

            Divider()

            Button("向右分栏") {
                NotificationCenter.postLumiEditorSplitRight()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.splitRight, commandID: "builtin.split-right").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.splitRight, commandID: "builtin.split-right").eventModifiers
            )

            Button("向下分栏") {
                NotificationCenter.postLumiEditorSplitDown()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.splitDown, commandID: "builtin.split-down").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.splitDown, commandID: "builtin.split-down").eventModifiers
            )

            Button("关闭分栏") {
                NotificationCenter.postLumiEditorCloseSplit()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.closeSplit, commandID: "builtin.close-split").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.closeSplit, commandID: "builtin.close-split").eventModifiers
            )

            Button("聚焦下一个分组") {
                NotificationCenter.postLumiEditorFocusNextGroup()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.focusNextGroup, commandID: "builtin.focus-next-group").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.focusNextGroup, commandID: "builtin.focus-next-group").eventModifiers
            )

            Button("聚焦上一个分组") {
                NotificationCenter.postLumiEditorFocusPreviousGroup()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.focusPreviousGroup, commandID: "builtin.focus-previous-group").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.focusPreviousGroup, commandID: "builtin.focus-previous-group").eventModifiers
            )

            Button("移动到下一个分组") {
                NotificationCenter.postLumiEditorMoveToNextGroup()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.moveToNextGroup, commandID: "builtin.move-to-next-group").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.moveToNextGroup, commandID: "builtin.move-to-next-group").eventModifiers
            )

            Button("移动到上一个分组") {
                NotificationCenter.postLumiEditorMoveToPreviousGroup()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.moveToPreviousGroup, commandID: "builtin.move-to-previous-group").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.moveToPreviousGroup, commandID: "builtin.move-to-previous-group").eventModifiers
            )

            Divider()

            Button("格式化文档") {
                NotificationCenter.postLumiEditorFormatDocument()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.formatDocument, commandID: "builtin.format-document").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.formatDocument, commandID: "builtin.format-document").eventModifiers
            )

            Button("查找引用") {
                NotificationCenter.postLumiEditorFindReferences()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.findReferences, commandID: "builtin.find-references").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.findReferences, commandID: "builtin.find-references").eventModifiers
            )

            Button("重命名符号") {
                NotificationCenter.postLumiEditorRenameSymbol()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.renameSymbol, commandID: "builtin.rename-symbol").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.renameSymbol, commandID: "builtin.rename-symbol").eventModifiers
            )

            Button("工作区符号搜索") {
                NotificationCenter.postLumiEditorWorkspaceSymbols()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.workspaceSymbols, commandID: "builtin.workspace-symbols").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.workspaceSymbols, commandID: "builtin.workspace-symbols").eventModifiers
            )

            Button("调用层级") {
                NotificationCenter.postLumiEditorCallHierarchy()
            }
            .keyboardShortcut(
                resolvedShortcut(EditorCommandBindings.callHierarchy, commandID: "builtin.call-hierarchy").keyEquivalent,
                modifiers: resolvedShortcut(EditorCommandBindings.callHierarchy, commandID: "builtin.call-hierarchy").eventModifiers
            )
        }
        #endif
    }
}
