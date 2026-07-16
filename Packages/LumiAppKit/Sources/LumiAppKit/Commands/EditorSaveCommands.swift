import EditorService
import SwiftUI

/// 编辑器保存命令（⌘S）。
///
/// 通过 `@FocusedValue` 读取当前活跃窗口的 `EditorService`，因此无论焦点
/// 在侧边栏、聊天面板还是编辑器，⌘S 都能触发保存——对齐 VS Code 行为。
///
/// 注：编辑器内部的 `CommandRegistry` 仍保留 `builtin.save`（供命令面板），
/// 两者最终都调用 `EditorFileService.saveNow()`。
struct EditorSaveCommands: Commands {
    @FocusedValue(\.activeEditorService) private var editorService: EditorService?

    var body: some Commands {
        // 替换系统默认的「保存」菜单组，确保菜单位于 File 菜单且绑定 ⌘S
        CommandGroup(replacing: .saveItem) {
            Button(String(localized: "Save", bundle: .module)) {
                editorService?.files.saveNow()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(editorService == nil || editorService?.files.hasUnsavedChanges == false)
        }
    }
}
