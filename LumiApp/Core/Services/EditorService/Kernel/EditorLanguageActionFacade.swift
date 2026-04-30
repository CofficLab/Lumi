import Foundation
import LanguageServerProtocol

@MainActor
final class EditorLanguageActionFacade {
    func formatDocument(
        formattingController: EditorFormattingController,
        canPreview: Bool,
        isEditable: Bool,
        tabSize: Int,
        insertSpaces: Bool,
        requestFormatting: @escaping (_ tabSize: Int, _ insertSpaces: Bool) async -> [TextEdit]?,
        applyTextEdits: @escaping (_ edits: [TextEdit], _ reason: String) -> Void,
        showStatus: @escaping (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void
    ) async {
        await formattingController.formatDocument(
            canPreview: canPreview,
            isEditable: isEditable,
            tabSize: tabSize,
            insertSpaces: insertSpaces,
            requestFormatting: requestFormatting,
            applyTextEdits: applyTextEdits,
            showStatus: showStatus
        )
    }

    func showReferences(
        currentFileURL: URL?,
        relativeFilePath: String,
        projectRootPath: String?,
        requestGenerationNext: () -> UInt64,
        isRequestCurrent: (UInt64) -> Bool,
        currentPosition: () -> (line: Int, character: Int),
        requestReferences: @escaping (_ line: Int, _ character: Int) async -> [Location],
        lspActionController: EditorLSPActionController,
        clearReferences: () -> Void,
        setReferenceResults: ([ReferenceResult]) -> Void,
        updateReferenceVisibility: (Bool) -> Void,
        syncSession: () -> Void,
        showStatus: (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void
    ) async {
        guard let fileURL = currentFileURL else { return }
        let requestGeneration = requestGenerationNext()
        let requestFileURL = fileURL
        showStatus(
            String(localized: "Finding references...", table: "LumiEditor"),
            .info,
            1.2
        )
        let position = currentPosition()
        let references = await requestReferences(position.line, position.character)
        guard isRequestCurrent(requestGeneration),
              currentFileURL == requestFileURL else { return }
        guard !references.isEmpty else {
            clearReferences()
            syncSession()
            showStatus(
                String(localized: "No references found", table: "LumiEditor"),
                .warning,
                1.8
            )
            return
        }

        let sortedItems = lspActionController.referenceResults(
            from: references,
            currentFileURL: fileURL,
            relativeFilePath: relativeFilePath,
            projectRootPath: projectRootPath,
            previewLine: { [weak lspActionController] url, line in
                lspActionController?.previewLine(from: url, at: line)
            }
        )
        guard isRequestCurrent(requestGeneration),
              currentFileURL == requestFileURL else { return }
        setReferenceResults(sortedItems)
        updateReferenceVisibility(!sortedItems.isEmpty)
        syncSession()
        showStatus(
            String(localized: "Found references:", table: "LumiEditor") + " \(sortedItems.count)",
            .success,
            1.8
        )
    }

    func jump(
        selection: NSRange,
        kind: EditorLSPActionController.JumpKind,
        lspActionController: EditorLSPActionController,
        showStatus: (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void,
        perform: @escaping (_ range: NSRange) async -> Void
    ) async {
        guard selection.location != NSNotFound else { return }
        showStatus(lspActionController.jumpKindStatusMessage(kind), .info, 1.2)
        await perform(selection)
    }

    func promptRenameSymbol(
        canPreview: Bool,
        isEditable: Bool,
        renameController: EditorRenameController,
        showStatus: (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void,
        runRename: @escaping (_ newName: String) -> Void
    ) {
        guard canPreview, isEditable else { return }
        guard let newName = renameController.promptForNewName() else {
            showStatus(renameController.cancelledMessage(), .warning, 1.8)
            return
        }

        showStatus(renameController.inProgressMessage(), .info, 1.2)
        runRename(newName)
    }

    func rename(
        newName: String,
        currentURI: String?,
        currentPosition: () -> (line: Int, character: Int),
        requestRename: @escaping (_ line: Int, _ character: Int, _ newName: String) async -> WorkspaceEdit?,
        workspaceEditController: EditorWorkspaceEditController,
        renameController: EditorRenameController,
        applyCurrentDocumentEdits: @escaping (_ edits: [TextEdit], _ reason: String) -> Void,
        applyExternalFileEdits: @escaping (_ edits: [TextEdit], _ url: URL) -> Bool,
        showStatus: (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void
    ) async {
        guard let currentURI else { return }
        let position = currentPosition()
        guard let edit = await requestRename(position.line, position.character, newName) else {
            showStatus(renameController.failedMessage(), .error, 1.8)
            return
        }

        let changedFiles = workspaceEditController.apply(
            changes: edit.changes,
            documentChanges: edit.documentChanges,
            currentURI: currentURI,
            applyCurrentDocumentEdits: applyCurrentDocumentEdits,
            applyExternalFileEdits: applyExternalFileEdits
        )

        if changedFiles == 0 {
            showStatus(renameController.notAppliedMessage(), .warning, 1.8)
            return
        }

        showStatus(renameController.completedMessage(changedFiles: changedFiles), .success, 1.8)
    }

    func openCallHierarchy(
        callHierarchyController: EditorCallHierarchyController,
        currentFileURL: URL?,
        cursorLine: Int,
        cursorColumn: Int,
        prepare: @escaping (_ uri: String, _ line: Int, _ character: Int) async -> Void,
        hasRootItem: @escaping () -> Bool,
        showWarning: @escaping (_ message: String) -> Void,
        openPanel: @escaping (_ command: EditorPanelCommand) -> Void
    ) async {
        await callHierarchyController.openCallHierarchy(
            currentFileURL: currentFileURL,
            cursorLine: cursorLine,
            cursorColumn: cursorColumn,
            prepare: prepare,
            hasRootItem: hasRootItem,
            showWarning: showWarning,
            openPanel: openPanel
        )
    }
}
