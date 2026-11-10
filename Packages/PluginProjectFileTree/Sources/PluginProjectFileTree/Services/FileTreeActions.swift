import AppKit

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
        textField.placeholderString = defaultName.isEmpty ? pluginLocalization.string("name") : defaultName
        // 预填时全选，方便整体替换
        textField.selectText(nil)
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        alert.addButton(withTitle: confirmButton)
        alert.addButton(withTitle: pluginLocalization.string("Cancel"))

        // 运行模态弹窗，回车等价于点确认
        if alert.runModal() == .alertFirstButtonReturn {
            // 返回原始输入：首尾空格可能是合法文件名的一部分，重命名不能擅自裁剪
            // （回归 #1108）。新建路径的空白校验交给 creationName。
            let name = textField.stringValue
            return name.isEmpty ? nil : name
        }
        return nil
    }

    /// 新建文件/目录时的最终名称：首尾空格视为无效输入的一部分并裁掉。
    static func creationName(from input: String) -> String? {
        let name = input.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    /// 重命名目标名称：保留用户输入的原始首尾空格；与当前名称相同或为空时返回 nil
    /// （no-op），避免未修改预填名称的确认被当成一次真实重命名（回归 #1108）。
    static func renameTarget(from input: String, currentName: String) -> String? {
        guard !input.isEmpty, input != currentName else { return nil }
        return input
    }

    /// 弹出删除确认框。
    /// - Parameter urls: 待删除的文件/目录 URL；多于一个时使用批量文案
    /// - Returns: 用户确认删除返回 true，否则 false
    static func presentDeleteConfirmation(urls: [URL]) -> Bool {
        guard let firstURL = urls.first else { return false }
        let alert = NSAlert()
        alert.alertStyle = .warning
        if urls.count == 1 {
            alert.messageText = String(
                format: pluginLocalization.string("Are you sure you want to delete \"%@\"?"),
                firstURL.lastPathComponent
            )
            alert.informativeText = pluginLocalization.string("This item will be moved to the Trash.")
        } else {
            alert.messageText = String(
                format: pluginLocalization.string("Are you sure you want to delete %lld items?"),
                urls.count
            )
            alert.informativeText = pluginLocalization.string("These items will be moved to the Trash.")
        }
        alert.addButton(withTitle: pluginLocalization.string("Move to Trash"))
        alert.addButton(withTitle: pluginLocalization.string("Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
}
