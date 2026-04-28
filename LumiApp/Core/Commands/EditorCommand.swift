import SwiftUI
import MagicKit

/// 编辑器命令：提供 LSP 快捷动作入口
struct EditorCommand: Commands, SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = false

    var body: some Commands {
        #if os(macOS)
        CommandMenu("编辑器") {
            Button("查找") {
                NotificationCenter.postLumiEditorToggleFind()
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("查找下一个") {
                NotificationCenter.postLumiEditorFindNext()
            }
            .keyboardShortcut("g", modifiers: .command)

            Button("查找上一个") {
                NotificationCenter.postLumiEditorFindPrevious()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Divider()

            Button("向右分栏") {
                NotificationCenter.postLumiEditorSplitRight()
            }
            .keyboardShortcut("\\", modifiers: .command)

            Button("向下分栏") {
                NotificationCenter.postLumiEditorSplitDown()
            }
            .keyboardShortcut("\\", modifiers: [.command, .shift])

            Button("关闭分栏") {
                NotificationCenter.postLumiEditorCloseSplit()
            }
            .keyboardShortcut("\\", modifiers: [.command, .option])

            Button("聚焦下一个分组") {
                NotificationCenter.postLumiEditorFocusNextGroup()
            }
            .keyboardShortcut("]", modifiers: [.command, .option])

            Button("聚焦上一个分组") {
                NotificationCenter.postLumiEditorFocusPreviousGroup()
            }
            .keyboardShortcut("[", modifiers: [.command, .option])

            Button("移动到下一个分组") {
                NotificationCenter.postLumiEditorMoveToNextGroup()
            }
            .keyboardShortcut("]", modifiers: [.command, .option, .shift])

            Button("移动到上一个分组") {
                NotificationCenter.postLumiEditorMoveToPreviousGroup()
            }
            .keyboardShortcut("[", modifiers: [.command, .option, .shift])

            Divider()

            Button("格式化文档") {
                NotificationCenter.postLumiEditorFormatDocument()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift, .option])

            Button("查找引用") {
                NotificationCenter.postLumiEditorFindReferences()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])

            Button("重命名符号") {
                NotificationCenter.postLumiEditorRenameSymbol()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("工作区符号搜索") {
                NotificationCenter.postLumiEditorWorkspaceSymbols()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("调用层级") {
                NotificationCenter.postLumiEditorCallHierarchy()
            }
            .keyboardShortcut("h", modifiers: [.command, .option])
        }
        #endif
    }
}
