import SwiftUI

// MARK: - Notification Extension (Editor / LSP Actions)

extension Notification.Name {
    static let lumiEditorUndo = Notification.Name("LumiEditorUndo")
    static let lumiEditorRedo = Notification.Name("LumiEditorRedo")

    static let lumiEditorSave = Notification.Name("LumiEditorSave")
    /// 请求执行「格式化文档」
    static let lumiEditorFormatDocument = Notification.Name("LumiEditorFormatDocument")

    /// 请求执行「查找引用」
    static let lumiEditorFindReferences = Notification.Name("LumiEditorFindReferences")

    /// 请求执行「快速修复」
    static let lumiEditorQuickFix = Notification.Name("LumiEditorQuickFix")

    /// 请求执行「重命名符号」
    static let lumiEditorRenameSymbol = Notification.Name("LumiEditorRenameSymbol")

    /// 请求执行「工作区符号搜索」
    static let lumiEditorWorkspaceSymbols = Notification.Name("LumiEditorWorkspaceSymbols")

    /// 请求执行「调用层级」
    static let lumiEditorCallHierarchy = Notification.Name("LumiEditorCallHierarchy")

    /// 请求切换查找面板
    static let lumiEditorToggleFind = Notification.Name("LumiEditorToggleFind")

    /// 请求执行「在文件中搜索」
    static let lumiEditorSearchInFiles = Notification.Name("LumiEditorSearchInFiles")

    /// 请求显示命令面板
    static let lumiEditorShowCommandPalette = Notification.Name("LumiEditorShowCommandPalette")

    /// 请求选择下一个查找结果
    static let lumiEditorFindNext = Notification.Name("LumiEditorFindNext")

    /// 请求选择上一个查找结果
    static let lumiEditorFindPrevious = Notification.Name("LumiEditorFindPrevious")

    /// 请求替换当前查找结果
    static let lumiEditorReplaceCurrent = Notification.Name("LumiEditorReplaceCurrent")

    /// 请求全部替换查找结果
    static let lumiEditorReplaceAll = Notification.Name("LumiEditorReplaceAll")

    /// 请求切换 Open Editors 面板
    static let lumiEditorToggleOpenEditorsPanel = Notification.Name("LumiEditorToggleOpenEditorsPanel")

    /// 请求切换 Outline 面板
    static let lumiEditorToggleOutlinePanel = Notification.Name("LumiEditorToggleOutlinePanel")

    /// 请求触发补全
    static let lumiEditorTriggerCompletion = Notification.Name("LumiEditorTriggerCompletion")

    /// 请求触发参数提示
    static let lumiEditorTriggerSignatureHelp = Notification.Name("LumiEditorTriggerSignatureHelp")

    /// 项目上下文已更新
    static let lumiEditorProjectContextDidChange = Notification.Name("LumiEditorProjectContextDidChange")

    /// 当前编辑器文件对应的项目上下文快照已更新
    static let lumiEditorProjectSnapshotDidChange = Notification.Name("LumiEditorProjectSnapshotDidChange")

    /// 编辑器设置已更新
    static let lumiEditorSettingsDidChange = Notification.Name("LumiEditorSettingsDidChange")
}

// MARK: - NotificationCenter Helpers

extension NotificationCenter {
    private static func postEditorCommand(_ name: Notification.Name, windowId: UUID?) {
        NotificationCenter.default.post(
            name: name,
            object: nil,
            userInfo: ["windowId": windowId as Any]
        )
    }

    static func postLumiEditorUndo(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorUndo, windowId: windowId)
    }

    static func postLumiEditorRedo(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorRedo, windowId: windowId)
    }

    static func postLumiEditorSave(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorSave, windowId: windowId)
    }

    static func postLumiEditorFormatDocument(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorFormatDocument, windowId: windowId)
    }

    static func postLumiEditorFindReferences(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorFindReferences, windowId: windowId)
    }

    static func postLumiEditorQuickFix(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorQuickFix, windowId: windowId)
    }

    static func postLumiEditorRenameSymbol(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorRenameSymbol, windowId: windowId)
    }

    static func postLumiEditorWorkspaceSymbols(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorWorkspaceSymbols, windowId: windowId)
    }

    static func postLumiEditorCallHierarchy(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorCallHierarchy, windowId: windowId)
    }

    static func postLumiEditorToggleFind(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorToggleFind, windowId: windowId)
    }

    static func postLumiEditorSearchInFiles(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorSearchInFiles, windowId: windowId)
    }

    static func postLumiEditorShowCommandPalette(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorShowCommandPalette, windowId: windowId)
    }

    static func postLumiEditorFindNext(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorFindNext, windowId: windowId)
    }

    static func postLumiEditorFindPrevious(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorFindPrevious, windowId: windowId)
    }

    static func postLumiEditorReplaceCurrent(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorReplaceCurrent, windowId: windowId)
    }

    static func postLumiEditorReplaceAll(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorReplaceAll, windowId: windowId)
    }

    static func postLumiEditorSettingsDidChange() {
        NotificationCenter.default.post(name: .lumiEditorSettingsDidChange, object: nil)
    }

    static func postLumiEditorToggleOpenEditorsPanel(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorToggleOpenEditorsPanel, windowId: windowId)
    }

    static func postLumiEditorToggleOutlinePanel(windowId: UUID? = nil) {
        postEditorCommand(.lumiEditorToggleOutlinePanel, windowId: windowId)
    }
}
