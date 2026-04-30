import SwiftUI

// MARK: - Notification Extension (Editor / LSP Actions)

extension Notification.Name {
    static let lumiEditorUndo = Notification.Name("LumiEditorUndo")
    static let lumiEditorRedo = Notification.Name("LumiEditorRedo")
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

    /// 请求向右分栏
    static let lumiEditorSplitRight = Notification.Name("LumiEditorSplitRight")

    /// 请求向下分栏
    static let lumiEditorSplitDown = Notification.Name("LumiEditorSplitDown")

    /// 请求关闭分栏
    static let lumiEditorCloseSplit = Notification.Name("LumiEditorCloseSplit")

    /// 请求聚焦下一个编辑器分组
    static let lumiEditorFocusNextGroup = Notification.Name("LumiEditorFocusNextGroup")

    /// 请求聚焦上一个编辑器分组
    static let lumiEditorFocusPreviousGroup = Notification.Name("LumiEditorFocusPreviousGroup")

    /// 请求把当前 editor 移到下一个分组
    static let lumiEditorMoveToNextGroup = Notification.Name("LumiEditorMoveToNextGroup")

    /// 请求把当前 editor 移到上一个分组
    static let lumiEditorMoveToPreviousGroup = Notification.Name("LumiEditorMoveToPreviousGroup")

    /// 请求触发补全
    static let lumiEditorTriggerCompletion = Notification.Name("LumiEditorTriggerCompletion")

    /// 请求触发参数提示
    static let lumiEditorTriggerSignatureHelp = Notification.Name("LumiEditorTriggerSignatureHelp")

    /// Xcode 项目上下文已更新
    static let lumiEditorXcodeContextDidChange = Notification.Name("LumiEditorXcodeContextDidChange")

    /// 当前编辑器文件对应的 Xcode 上下文快照已更新
    static let lumiEditorXcodeSnapshotDidChange = Notification.Name("LumiEditorXcodeSnapshotDidChange")

    /// 编辑器设置已更新
    static let lumiEditorSettingsDidChange = Notification.Name("LumiEditorSettingsDidChange")
}

// MARK: - NotificationCenter Helpers

extension NotificationCenter {
    static func postLumiEditorUndo() {
        NotificationCenter.default.post(name: .lumiEditorUndo, object: nil)
    }

    static func postLumiEditorRedo() {
        NotificationCenter.default.post(name: .lumiEditorRedo, object: nil)
    }

    static func postLumiEditorFormatDocument() {
        NotificationCenter.default.post(name: .lumiEditorFormatDocument, object: nil)
    }

    static func postLumiEditorFindReferences() {
        NotificationCenter.default.post(name: .lumiEditorFindReferences, object: nil)
    }

    static func postLumiEditorQuickFix() {
        NotificationCenter.default.post(name: .lumiEditorQuickFix, object: nil)
    }

    static func postLumiEditorRenameSymbol() {
        NotificationCenter.default.post(name: .lumiEditorRenameSymbol, object: nil)
    }

    static func postLumiEditorWorkspaceSymbols() {
        NotificationCenter.default.post(name: .lumiEditorWorkspaceSymbols, object: nil)
    }

    static func postLumiEditorCallHierarchy() {
        NotificationCenter.default.post(name: .lumiEditorCallHierarchy, object: nil)
    }

    static func postLumiEditorToggleFind() {
        NotificationCenter.default.post(name: .lumiEditorToggleFind, object: nil)
    }

    static func postLumiEditorSearchInFiles() {
        NotificationCenter.default.post(name: .lumiEditorSearchInFiles, object: nil)
    }

    static func postLumiEditorShowCommandPalette() {
        NotificationCenter.default.post(name: .lumiEditorShowCommandPalette, object: nil)
    }

    static func postLumiEditorFindNext() {
        NotificationCenter.default.post(name: .lumiEditorFindNext, object: nil)
    }

    static func postLumiEditorFindPrevious() {
        NotificationCenter.default.post(name: .lumiEditorFindPrevious, object: nil)
    }

    static func postLumiEditorReplaceCurrent() {
        NotificationCenter.default.post(name: .lumiEditorReplaceCurrent, object: nil)
    }

    static func postLumiEditorReplaceAll() {
        NotificationCenter.default.post(name: .lumiEditorReplaceAll, object: nil)
    }

    static func postLumiEditorSettingsDidChange() {
        NotificationCenter.default.post(name: .lumiEditorSettingsDidChange, object: nil)
    }

    static func postLumiEditorToggleOpenEditorsPanel() {
        NotificationCenter.default.post(name: .lumiEditorToggleOpenEditorsPanel, object: nil)
    }

    static func postLumiEditorSplitRight() {
        NotificationCenter.default.post(name: .lumiEditorSplitRight, object: nil)
    }

    static func postLumiEditorSplitDown() {
        NotificationCenter.default.post(name: .lumiEditorSplitDown, object: nil)
    }

    static func postLumiEditorCloseSplit() {
        NotificationCenter.default.post(name: .lumiEditorCloseSplit, object: nil)
    }

    static func postLumiEditorFocusNextGroup() {
        NotificationCenter.default.post(name: .lumiEditorFocusNextGroup, object: nil)
    }

    static func postLumiEditorFocusPreviousGroup() {
        NotificationCenter.default.post(name: .lumiEditorFocusPreviousGroup, object: nil)
    }

    static func postLumiEditorMoveToNextGroup() {
        NotificationCenter.default.post(name: .lumiEditorMoveToNextGroup, object: nil)
    }

    static func postLumiEditorMoveToPreviousGroup() {
        NotificationCenter.default.post(name: .lumiEditorMoveToPreviousGroup, object: nil)
    }
}
