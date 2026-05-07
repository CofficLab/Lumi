import Foundation
import CodeEditSourceEditor

enum EditorInteractionUpdate {
    case sourceEditorBinding(EditorSourceEditorBindingUpdate)
    case findReplace(EditorFindReplaceState)
    case scroll(EditorScrollState)
    case cursor(EditorCursorUpdate)
    case explicitCursor([CursorPosition], fallbackLine: Int, fallbackColumn: Int)
    case sessionRestore(EditorSessionRestoreResult)
}

struct ResolvedEditorInteractionUpdate {
    let bridgeState: EditorBridgeState?
    let scrollState: EditorScrollState?
}
