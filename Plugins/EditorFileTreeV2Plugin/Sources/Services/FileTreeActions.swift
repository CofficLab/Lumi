import AppKit
import EditorFileTreePlugin
import LumiCoreKit

/// 文件树操作辅助
///
/// 封装 NSAlert 输入弹窗与文件操作，让 FileTreeCollectionViewController 只做编排。
/// 标记 @MainActor：NSAlert 只能在主线程使用。
@MainActor
enum FileTreeActions {
    /// 弹出命名输入框，返回用户输入的名字（空字符串或取消均返回 nil）。
    /// - Parameters:
    ///   - title: 弹窗标题
    ///   - message: 提示信息
    ///   - defaultName: 输入框预填文本（重命名时为当前文件名）
    ///   - confirmButton: 确认按钮文案
    /// - Returns: 用户确认输入的名字；取消返回 nil
    static func presentNamePrompt(
        title: String,
        message: String,
        defaultName: String,
        confirmButton: String
    ) -> String? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        textField.stringValue = defaultName
        textField.placeholderString = defaultName.isEmpty ? LumiPluginLocalization.string("name", bundle: .module) : defaultName
        // 预填时全选，方便整体替换
        textField.currentEditor()?.selectAll(nil)
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        alert.addButton(withTitle: confirmButton)
        alert.addButton(withTitle: LumiPluginLocalization.string("Cancel", bundle: .module))

        // 运行模态弹窗，回车等价于点确认
        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    /// 弹出删除确认框。
    /// - Parameter url: 待删除的文件/目录 URL
    /// - Returns: 用户确认删除返回 true，否则 false
    static func presentDeleteConfirmation(url: URL) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(
            format: LumiPluginLocalization.string("Are you sure you want to delete \"%@\"?", bundle: .module),
            url.lastPathComponent
        )
        alert.informativeText = LumiPluginLocalization.string(
            "This item will be moved to the Trash.",
            bundle: .module
        )
        alert.addButton(withTitle: LumiPluginLocalization.string("Move to Trash", bundle: .module))
        alert.addButton(withTitle: LumiPluginLocalization.string("Cancel", bundle: .module))
        return alert.runModal() == .alertFirstButtonReturn
    }
}
