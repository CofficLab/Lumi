import Foundation

@MainActor
final class EditorCallHierarchyController {
    func openCallHierarchy(
        currentFileURL: URL?,
        cursorLine: Int,
        cursorColumn: Int,
        prepare: @escaping (_ uri: String, _ line: Int, _ character: Int) async -> Void,
        hasRootItem: @escaping () -> Bool,
        showWarning: (_ message: String) -> Void,
        openPanel: (_ command: EditorPanelCommand) -> Void
    ) async {
        guard let fileURL = currentFileURL else { return }
        let line = max(cursorLine - 1, 0)
        let character = max(cursorColumn - 1, 0)

        await prepare(fileURL.absoluteString, line, character)

        guard hasRootItem() else {
            showWarning("未找到调用层级信息")
            return
        }

        openPanel(.openCallHierarchy)
    }
}
