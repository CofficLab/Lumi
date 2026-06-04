import Foundation

extension Notification.Name {
    static let lumiEditorUndo = Notification.Name("LumiEditorUndo")
    static let lumiEditorRedo = Notification.Name("LumiEditorRedo")
    static let lumiEditorSave = Notification.Name("LumiEditorSave")
    static let lumiEditorFormatDocument = Notification.Name("LumiEditorFormatDocument")
    static let lumiEditorFindReferences = Notification.Name("LumiEditorFindReferences")
    static let lumiEditorQuickFix = Notification.Name("LumiEditorQuickFix")
    static let lumiEditorRenameSymbol = Notification.Name("LumiEditorRenameSymbol")
    static let lumiEditorWorkspaceSymbols = Notification.Name("LumiEditorWorkspaceSymbols")
    static let lumiEditorCallHierarchy = Notification.Name("LumiEditorCallHierarchy")
    static let lumiEditorToggleFind = Notification.Name("LumiEditorToggleFind")
    static let lumiEditorSearchInFiles = Notification.Name("LumiEditorSearchInFiles")
    static let lumiEditorShowCommandPalette = Notification.Name("LumiEditorShowCommandPalette")
    static let lumiEditorFindNext = Notification.Name("LumiEditorFindNext")
    static let lumiEditorFindPrevious = Notification.Name("LumiEditorFindPrevious")
    static let lumiEditorReplaceCurrent = Notification.Name("LumiEditorReplaceCurrent")
    static let lumiEditorReplaceAll = Notification.Name("LumiEditorReplaceAll")
    static let lumiEditorToggleOutlinePanel = Notification.Name("LumiEditorToggleOutlinePanel")
    static let applicationDidResignActive = Notification.Name("applicationDidResignActive")
}
