import SwiftUI

// MARK: - Notification Extension (Editor / LSP Actions)

extension Notification.Name {
    /// 请求执行「格式化文档」
    static let lumiEditorFormatDocument = Notification.Name("LumiEditorFormatDocument")

    /// 请求执行「查找引用」
    static let lumiEditorFindReferences = Notification.Name("LumiEditorFindReferences")

    /// 请求执行「重命名符号」
    static let lumiEditorRenameSymbol = Notification.Name("LumiEditorRenameSymbol")
}

// MARK: - NotificationCenter Helpers

extension NotificationCenter {
    static func postLumiEditorFormatDocument() {
        NotificationCenter.default.post(name: .lumiEditorFormatDocument, object: nil)
    }

    static func postLumiEditorFindReferences() {
        NotificationCenter.default.post(name: .lumiEditorFindReferences, object: nil)
    }

    static func postLumiEditorRenameSymbol() {
        NotificationCenter.default.post(name: .lumiEditorRenameSymbol, object: nil)
    }
}

