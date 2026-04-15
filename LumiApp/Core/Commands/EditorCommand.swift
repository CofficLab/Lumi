import SwiftUI
import MagicKit

/// 编辑器命令：提供 LSP 快捷动作入口
struct EditorCommand: Commands, SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = false

    var body: some Commands {
        #if os(macOS)
        CommandMenu("编辑器") {
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
        }
        #endif
    }
}

