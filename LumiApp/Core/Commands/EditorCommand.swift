import SwiftUI
import MagicKit

/// 编辑器命令：提供 LSP 快捷动作入口
struct EditorCommand: Commands, SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = false

    var body: some Commands {
        #if os(macOS)
        CommandMenu("编辑器") {
            Button("撤销") {
                NotificationCenter.postLumiEditorUndo()
            }
            .keyboardShortcut(EditorCommandBindings.undo.keyEquivalent, modifiers: EditorCommandBindings.undo.eventModifiers)

            Button("重做") {
                NotificationCenter.postLumiEditorRedo()
            }
            .keyboardShortcut(EditorCommandBindings.redo.keyEquivalent, modifiers: EditorCommandBindings.redo.eventModifiers)

            Divider()

            Button("命令面板") {
                NotificationCenter.postLumiEditorShowCommandPalette()
            }
            .keyboardShortcut(EditorCommandBindings.commandPalette.keyEquivalent, modifiers: EditorCommandBindings.commandPalette.eventModifiers)

            Divider()

            Button("查找") {
                NotificationCenter.postLumiEditorToggleFind()
            }
            .keyboardShortcut(EditorCommandBindings.find.keyEquivalent, modifiers: EditorCommandBindings.find.eventModifiers)

            Button("查找下一个") {
                NotificationCenter.postLumiEditorFindNext()
            }
            .keyboardShortcut(EditorCommandBindings.findNext.keyEquivalent, modifiers: EditorCommandBindings.findNext.eventModifiers)

            Button("查找上一个") {
                NotificationCenter.postLumiEditorFindPrevious()
            }
            .keyboardShortcut(EditorCommandBindings.findPrevious.keyEquivalent, modifiers: EditorCommandBindings.findPrevious.eventModifiers)

            Button("打开编辑项") {
                NotificationCenter.postLumiEditorToggleOpenEditorsPanel()
            }
            .keyboardShortcut(EditorCommandBindings.openEditors.keyEquivalent, modifiers: EditorCommandBindings.openEditors.eventModifiers)

            Divider()

            Button("向右分栏") {
                NotificationCenter.postLumiEditorSplitRight()
            }
            .keyboardShortcut(EditorCommandBindings.splitRight.keyEquivalent, modifiers: EditorCommandBindings.splitRight.eventModifiers)

            Button("向下分栏") {
                NotificationCenter.postLumiEditorSplitDown()
            }
            .keyboardShortcut(EditorCommandBindings.splitDown.keyEquivalent, modifiers: EditorCommandBindings.splitDown.eventModifiers)

            Button("关闭分栏") {
                NotificationCenter.postLumiEditorCloseSplit()
            }
            .keyboardShortcut(EditorCommandBindings.closeSplit.keyEquivalent, modifiers: EditorCommandBindings.closeSplit.eventModifiers)

            Button("聚焦下一个分组") {
                NotificationCenter.postLumiEditorFocusNextGroup()
            }
            .keyboardShortcut(EditorCommandBindings.focusNextGroup.keyEquivalent, modifiers: EditorCommandBindings.focusNextGroup.eventModifiers)

            Button("聚焦上一个分组") {
                NotificationCenter.postLumiEditorFocusPreviousGroup()
            }
            .keyboardShortcut(EditorCommandBindings.focusPreviousGroup.keyEquivalent, modifiers: EditorCommandBindings.focusPreviousGroup.eventModifiers)

            Button("移动到下一个分组") {
                NotificationCenter.postLumiEditorMoveToNextGroup()
            }
            .keyboardShortcut(EditorCommandBindings.moveToNextGroup.keyEquivalent, modifiers: EditorCommandBindings.moveToNextGroup.eventModifiers)

            Button("移动到上一个分组") {
                NotificationCenter.postLumiEditorMoveToPreviousGroup()
            }
            .keyboardShortcut(EditorCommandBindings.moveToPreviousGroup.keyEquivalent, modifiers: EditorCommandBindings.moveToPreviousGroup.eventModifiers)

            Divider()

            Button("格式化文档") {
                NotificationCenter.postLumiEditorFormatDocument()
            }
            .keyboardShortcut(EditorCommandBindings.formatDocument.keyEquivalent, modifiers: EditorCommandBindings.formatDocument.eventModifiers)

            Button("查找引用") {
                NotificationCenter.postLumiEditorFindReferences()
            }
            .keyboardShortcut(EditorCommandBindings.findReferences.keyEquivalent, modifiers: EditorCommandBindings.findReferences.eventModifiers)

            Button("重命名符号") {
                NotificationCenter.postLumiEditorRenameSymbol()
            }
            .keyboardShortcut(EditorCommandBindings.renameSymbol.keyEquivalent, modifiers: EditorCommandBindings.renameSymbol.eventModifiers)

            Button("工作区符号搜索") {
                NotificationCenter.postLumiEditorWorkspaceSymbols()
            }
            .keyboardShortcut(EditorCommandBindings.workspaceSymbols.keyEquivalent, modifiers: EditorCommandBindings.workspaceSymbols.eventModifiers)

            Button("调用层级") {
                NotificationCenter.postLumiEditorCallHierarchy()
            }
            .keyboardShortcut(EditorCommandBindings.callHierarchy.keyEquivalent, modifiers: EditorCommandBindings.callHierarchy.eventModifiers)
        }
        #endif
    }
}
